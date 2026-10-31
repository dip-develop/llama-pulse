import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import 'server_dashboard_state.dart';
import 'server_event.dart';

/// Drives the server dashboard: configuration, lifecycle and live output.
///
/// The controller that owns the process is owned by DI and outlives the bloc;
/// [close] only cancels the subscriptions and never disposes it.
class ServerBloc extends Bloc<ServerEvent, ServerDashboardState> {
  /// Creates the bloc over the configuration repository and the controller.
  ///
  /// [stateRepository] reads the document the supervisor and the CLI share, so
  /// the dashboard can report on a server it did not start.
  ///
  /// [externalStatePollInterval] is how often the shared document is re-read
  /// while [ServerDashboardState.externalRun] is true; tests shorten it.
  ServerBloc(
    this._configRepository,
    this._validator,
    this._controller,
    this._stateRepository, {
    this.externalStatePollInterval = const Duration(seconds: 2),
  }) : super(ServerDashboardState.initial(serverState: _controller.state)) {
    on<ServerDashboardStarted>(_onStarted);
    on<ServerConfigChanged>(_onConfigChanged);
    on<ServerSaveRequested>(_onSaveRequested);
    on<ServerReloadRequested>(_onReloadRequested);
    on<ServerStartRequested>(_onStartRequested);
    on<ServerStartCompleted>(_onStartCompleted);
    on<ServerStopRequested>(_onStopRequested);
    on<ServerStopCompleted>(_onStopCompleted);
    on<ServerTestConnectionRequested>(_onTestConnectionRequested);
    on<ServerLogsCleared>(_onLogsCleared);
    on<ServerControllerStateReceived>(_onControllerState);
    on<ServerControllerMetricsReceived>(_onControllerMetrics);
    on<ServerControllerLogReceived>(_onControllerLog);
    on<ServerControllerStreamEnded>(_onControllerStreamEnded);
    on<ServerExternalStatePolled>(_onExternalStatePolled);
  }

  /// Keeps the dashboard bounded, regardless of how long the server runs.
  static const int maxMetricsHistory = 120;

  /// Keeps the log pane bounded; older lines stay in the log file.
  static const int maxLogs = 1000;

  /// How often the shared state document is re-read during an external run.
  final Duration externalStatePollInterval;

  final ServerConfigRepository _configRepository;
  final ServerConfigValidator _validator;
  final ServerController _controller;
  final ServerStateRepository _stateRepository;

  StreamSubscription<ServerState>? _stateSubscription;
  StreamSubscription<ServerMetrics>? _metricsSubscription;
  StreamSubscription<ServerLogEntry>? _logSubscription;
  Timer? _externalPollTimer;
  bool _subscribed = false;

  Future<void> _onStarted(
    ServerDashboardStarted event,
    Emitter<ServerDashboardState> emit,
  ) async {
    ServerConfig config;
    ServerFailure? loadFailure;
    try {
      config = await _configRepository.load();
    } on Object catch (error) {
      config = ServerConfig.defaults();
      loadFailure = _failure(
        ServerFailureCode.unknown,
        'Could not load the server configuration: $error',
      );
    }
    if (isClosed) {
      return;
    }
    _emit(
      emit,
      state.rebuild((b) {
        b
          ..config.replace(config)
          ..dirty = false;
        if (loadFailure != null) {
          b.failure.replace(loadFailure);
        } else {
          b.failure = null;
        }
      }),
    );
    // Subscribe before the remaining awaits so no transition published while
    // the binary is probed is lost.
    _subscribe();

    try {
      final ServerBinaryInfo binary = await _controller.locateBinary(config);
      if (isClosed) {
        return;
      }
      _emit(emit, state.rebuild((b) => b..binaryInfo.replace(binary)));
    } on ServerException catch (exception) {
      if (isClosed) {
        return;
      }
      _emit(emit, state.rebuild((b) => b..failure.replace(exception.failure)));
    } on Object catch (error) {
      if (isClosed) {
        return;
      }
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..failure.replace(
              _failure(
                ServerFailureCode.unknown,
                'Could not inspect llama-server: $error',
              ),
            ),
        ),
      );
    }

    final ServerState? recorded = await _loadRecordedState();
    if (isClosed) {
      return;
    }

    // A run recorded in the shared document that this controller does not own
    // belongs to the CLI: show it, but never pretend to own its process.
    final ServerState localState = _controller.state;
    final bool externalRun =
        recorded != null && recorded.isActive && !localState.isActive;
    _emit(
      emit,
      state.rebuild(
        (b) => b
          ..serverState.replace(externalRun ? recorded : localState)
          ..externalRun = externalRun,
      ),
    );
    // The CLI may stop the run at any time: keep the document under watch for
    // as long as it is the only report on the server.
    _syncExternalPolling(externalRun);
  }

  Future<ServerState?> _loadRecordedState() async {
    try {
      return await _stateRepository.load();
    } on Object {
      // The document is a reporting snapshot: a broken one means "unknown".
      return null;
    }
  }

  void _onConfigChanged(
    ServerConfigChanged event,
    Emitter<ServerDashboardState> emit,
  ) {
    _emit(
      emit,
      state.rebuild(
        (b) => b
          ..config.replace(event.config)
          ..dirty = true,
      ),
    );
  }

  Future<void> _onSaveRequested(
    ServerSaveRequested event,
    Emitter<ServerDashboardState> emit,
  ) async {
    final List<String> violations = _validator.validate(state.config);
    if (violations.isNotEmpty) {
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..failure.replace(
              _failure(ServerFailureCode.invalidConfig, violations.join('; ')),
            ),
        ),
      );
      return;
    }
    _emit(emit, state.rebuild((b) => b..saving = true));
    try {
      await _configRepository.save(state.config);
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..saving = false
            ..dirty = false
            ..failure = null,
        ),
      );
    } on Object catch (error) {
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..saving = false
            ..failure.replace(
              _failure(
                ServerFailureCode.unknown,
                'Could not save the server configuration: $error',
              ),
            ),
        ),
      );
    }
  }

  Future<void> _onReloadRequested(
    ServerReloadRequested event,
    Emitter<ServerDashboardState> emit,
  ) async {
    ServerConfig? config;
    ServerFailure? loadFailure;
    try {
      config = await _configRepository.load();
    } on Object catch (error) {
      loadFailure = _failure(
        ServerFailureCode.unknown,
        'Could not load the server configuration: $error',
      );
    }
    if (isClosed) {
      return;
    }
    // Reloading discards edits, so it also refreshes the run the dashboard
    // reports: the shared document is the only source for an external one.
    await _refreshExternalState(emit);
    if (isClosed) {
      return;
    }
    final ServerConfig? loaded = config;
    _emit(
      emit,
      state.rebuild((b) {
        if (loaded != null) {
          b
            ..config.replace(loaded)
            ..dirty = false
            ..failure = null;
        }
        if (loadFailure != null) {
          b.failure.replace(loadFailure);
        }
      }),
    );
  }

  /// Re-reads the shared document and updates the run the dashboard reports.
  ///
  /// Returns whether the run is still external. Only the controller owns a
  /// local process, so an active controller state always wins over the
  /// document.
  Future<bool> _refreshExternalState(Emitter<ServerDashboardState> emit) async {
    final ServerState? recorded = await _loadRecordedState();
    if (isClosed) {
      return false;
    }
    final ServerState localState = _controller.state;
    final bool externalRun =
        recorded != null && recorded.isActive && !localState.isActive;
    final ServerState next = externalRun ? recorded : localState;
    if (!externalRun) {
      _stopExternalPolling();
    } else {
      _ensureExternalPolling();
    }
    if (next != state.serverState || externalRun != state.externalRun) {
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..serverState.replace(next)
            ..externalRun = externalRun,
        ),
      );
    }
    return externalRun;
  }

  Future<void> _onExternalStatePolled(
    ServerExternalStatePolled event,
    Emitter<ServerDashboardState> emit,
  ) async {
    if (!state.externalRun) {
      _stopExternalPolling();
      return;
    }
    await _refreshExternalState(emit);
  }

  Future<void> _onStartRequested(
    ServerStartRequested event,
    Emitter<ServerDashboardState> emit,
  ) async {
    final List<String> violations = _validator.validateForStart(state.config);
    if (violations.isNotEmpty) {
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..failure.replace(
              _failure(ServerFailureCode.invalidConfig, violations.join('; ')),
            ),
        ),
      );
      return;
    }
    final ServerConfig config = state.config;
    // Never await the controller here: it publishes `starting` while `start`
    // runs, and waiting would queue that state behind this handler.
    _emit(emit, state.rebuild((b) => b..failure = null));
    if (state.externalRun) {
      // The document may be stale: re-read it before the recorded run blocks a
      // legitimate start.
      final bool stillExternal = await _refreshExternalState(emit);
      if (isClosed) {
        return;
      }
      if (stillExternal) {
        _emit(
          emit,
          state.rebuild((b) => b..failure.replace(_externalRunFailure())),
        );
        return;
      }
    }
    unawaited(_start(config));
  }

  Future<void> _start(ServerConfig config) async {
    ServerFailure? failure;
    try {
      await _controller.start(config);
    } on ServerException catch (exception) {
      failure = exception.failure;
    } on Object catch (error) {
      failure = _failure(
        ServerFailureCode.unknown,
        'Could not start llama-server: $error',
      );
    }
    _add(ServerStartCompleted(failure: failure));
  }

  void _onStartCompleted(
    ServerStartCompleted event,
    Emitter<ServerDashboardState> emit,
  ) {
    final ServerFailure? failure = event.failure;
    if (failure != null) {
      _emit(emit, state.rebuild((b) => b..failure.replace(failure)));
      return;
    }
    // The controller owns the process now, whatever the shared document
    // reported before.
    _stopExternalPolling();
    _emit(
      emit,
      state.rebuild(
        (b) => b
          ..failure = null
          ..externalRun = false,
      ),
    );
  }

  void _onStopRequested(
    ServerStopRequested event,
    Emitter<ServerDashboardState> emit,
  ) {
    if (state.externalRun) {
      _emit(
        emit,
        state.rebuild((b) => b..failure.replace(_externalRunFailure())),
      );
      return;
    }
    _emit(emit, state.rebuild((b) => b..failure = null));
    unawaited(_stop());
  }

  Future<void> _stop() async {
    ServerFailure? failure;
    try {
      await _controller.stop();
    } on ServerException catch (exception) {
      failure = exception.failure;
    } on Object catch (error) {
      failure = _failure(
        ServerFailureCode.unknown,
        'Could not stop llama-server: $error',
      );
    }
    _add(ServerStopCompleted(failure: failure));
  }

  void _onStopCompleted(
    ServerStopCompleted event,
    Emitter<ServerDashboardState> emit,
  ) {
    final ServerFailure? failure = event.failure;
    if (failure == null) {
      // A local stop never happens during an external run, but no refresh may
      // outlive a run this app no longer reports as external.
      _stopExternalPolling();
    }
    _emit(
      emit,
      state.rebuild((b) {
        if (failure == null) {
          b.failure = null;
        } else {
          b.failure.replace(failure);
        }
      }),
    );
  }

  Future<void> _onTestConnectionRequested(
    ServerTestConnectionRequested event,
    Emitter<ServerDashboardState> emit,
  ) async {
    _emit(
      emit,
      state.rebuild(
        (b) => b
          ..testingConnection = true
          ..connectionLatencyMs = null
          ..connectionMessage = null,
      ),
    );
    final ServerConfig config = await _configForProbe();
    if (isClosed) {
      return;
    }
    try {
      final ServerProbeResult result = await _controller.testConnection(config);
      _emit(
        emit,
        state.rebuild((b) {
          b
            ..testingConnection = false
            ..connectionLatencyMs = result.latencyMs
            ..connectionMessage = result.message;
          if (result.ok) {
            b.failure = null;
          }
        }),
      );
    } on Object catch (error) {
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..testingConnection = false
            ..connectionMessage = '$error',
        ),
      );
    }
  }

  /// The configuration to probe: the stored one whenever this app does not own
  /// the running process, so unsaved edits cannot probe the wrong endpoint.
  Future<ServerConfig> _configForProbe() async {
    if (!state.externalRun && _controller.state.isActive) {
      return state.config;
    }
    try {
      return await _configRepository.load();
    } on Object {
      return state.config;
    }
  }

  void _onLogsCleared(
    ServerLogsCleared event,
    Emitter<ServerDashboardState> emit,
  ) {
    _emit(emit, state.rebuild((b) => b..logs = ListBuilder<ServerLogEntry>()));
  }

  void _onControllerState(
    ServerControllerStateReceived event,
    Emitter<ServerDashboardState> emit,
  ) {
    final ServerState next = event.state;
    // An active state means this controller now owns the process.
    final bool externalRun = next.isActive ? false : state.externalRun;
    if (!externalRun) {
      _stopExternalPolling();
    }
    _emit(
      emit,
      state.rebuild(
        (b) => b
          ..serverState.replace(next)
          ..externalRun = externalRun,
      ),
    );
  }

  void _onControllerMetrics(
    ServerControllerMetricsReceived event,
    Emitter<ServerDashboardState> emit,
  ) {
    final ListBuilder<ServerMetrics> history = ListBuilder<ServerMetrics>(
      state.metricsHistory,
    )..add(event.metrics);
    if (history.length > maxMetricsHistory) {
      history.removeRange(0, history.length - maxMetricsHistory);
    }
    _emit(emit, state.rebuild((b) => b..metricsHistory = history));
  }

  void _onControllerLog(
    ServerControllerLogReceived event,
    Emitter<ServerDashboardState> emit,
  ) {
    final ListBuilder<ServerLogEntry> logs = ListBuilder<ServerLogEntry>(
      state.logs,
    )..add(event.entry);
    if (logs.length > maxLogs) {
      logs.removeRange(0, logs.length - maxLogs);
    }
    _emit(emit, state.rebuild((b) => b..logs = logs));
  }

  void _onControllerStreamEnded(
    ServerControllerStreamEnded event,
    Emitter<ServerDashboardState> emit,
  ) {
    if (state.phase == ServerPhase.stopped) {
      return;
    }
    final Object? error = event.error;
    _emit(
      emit,
      state.rebuild(
        (b) => b
          ..failure.replace(
            _failure(
              ServerFailureCode.unknown,
              error == null
                  ? 'the server controller closed its stream'
                  : '$error',
            ),
          ),
      ),
    );
  }

  void _subscribe() {
    if (_subscribed) {
      return;
    }
    _subscribed = true;
    _stateSubscription = _controller.states.listen(
      (ServerState state) => _add(ServerControllerStateReceived(state)),
      onError: (Object error) => _add(ServerControllerStreamEnded(error)),
      onDone: () => _add(const ServerControllerStreamEnded(null)),
    );
    _metricsSubscription = _controller.metrics.listen(
      (ServerMetrics metrics) => _add(ServerControllerMetricsReceived(metrics)),
      onError: (Object error) => _add(ServerControllerStreamEnded(error)),
      onDone: () => _add(const ServerControllerStreamEnded(null)),
    );
    _logSubscription = _controller.logs.listen(
      (ServerLogEntry entry) => _add(ServerControllerLogReceived(entry)),
      onError: (Object error) => _add(ServerControllerStreamEnded(error)),
      onDone: () => _add(const ServerControllerStreamEnded(null)),
    );
  }

  /// Keeps the refresh timer in step with the external-run flag.
  void _syncExternalPolling(bool externalRun) {
    if (externalRun) {
      _ensureExternalPolling();
    } else {
      _stopExternalPolling();
    }
  }

  void _ensureExternalPolling() {
    if (isClosed || _externalPollTimer != null) {
      return;
    }
    _externalPollTimer = Timer.periodic(
      externalStatePollInterval,
      (_) => _add(const ServerExternalStatePolled()),
    );
  }

  void _stopExternalPolling() {
    _externalPollTimer?.cancel();
    _externalPollTimer = null;
  }

  ServerFailure _externalRunFailure() => _failure(
    ServerFailureCode.unknown,
    'server was started outside this app; use `llamapulse stop`',
  );

  void _add(ServerEvent event) {
    if (isClosed) {
      return;
    }
    add(event);
  }

  ServerFailure _failure(
    ServerFailureCode code,
    String message, {
    String? details,
  }) => ServerFailure(
    (b) => b
      ..code = code
      ..message = message
      ..details = details,
  );

  void _emit(Emitter<ServerDashboardState> emit, ServerDashboardState next) {
    if (isClosed) {
      return;
    }
    emit(next);
  }

  @override
  Future<void> close() async {
    _stopExternalPolling();
    _subscribed = false;
    await _stateSubscription?.cancel();
    await _metricsSubscription?.cancel();
    await _logSubscription?.cancel();
    _stateSubscription = null;
    _metricsSubscription = null;
    _logSubscription = null;
    return super.close();
  }
}
