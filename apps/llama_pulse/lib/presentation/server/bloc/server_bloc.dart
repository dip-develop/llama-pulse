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
  ServerBloc(this._configRepository, this._validator, this._controller)
    : super(ServerDashboardState.initial(serverState: _controller.state)) {
    on<ServerDashboardStarted>(_onStarted);
    on<ServerConfigChanged>(_onConfigChanged);
    on<ServerSaveRequested>(_onSaveRequested);
    on<ServerReloadRequested>(_onReloadRequested);
    on<ServerStartRequested>(_onStartRequested);
    on<ServerStopRequested>(_onStopRequested);
    on<ServerTestConnectionRequested>(_onTestConnectionRequested);
    on<ServerLogsCleared>(_onLogsCleared);
    on<ServerControllerStateReceived>(_onControllerState);
    on<ServerControllerMetricsReceived>(_onControllerMetrics);
    on<ServerControllerLogReceived>(_onControllerLog);
    on<ServerControllerStreamEnded>(_onControllerStreamEnded);
  }

  /// Keeps the dashboard bounded, regardless of how long the server runs.
  static const int maxMetricsHistory = 120;

  /// Keeps the log pane bounded; older lines stay in the log file.
  static const int maxLogs = 1000;

  final ServerConfigRepository _configRepository;
  final ServerConfigValidator _validator;
  final ServerController _controller;

  StreamSubscription<ServerState>? _stateSubscription;
  StreamSubscription<ServerMetrics>? _metricsSubscription;
  StreamSubscription<ServerLogEntry>? _logSubscription;
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

    try {
      final ServerBinaryInfo binary = await _controller.locateBinary(config);
      _emit(emit, state.rebuild((b) => b..binaryInfo.replace(binary)));
    } on ServerException catch (exception) {
      _emit(emit, state.rebuild((b) => b..failure.replace(exception.failure)));
    } on Object catch (error) {
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

    _subscribe();
    _emit(
      emit,
      state.rebuild((b) => b..serverState.replace(_controller.state)),
    );
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
    try {
      final ServerConfig config = await _configRepository.load();
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..config.replace(config)
            ..dirty = false
            ..failure = null,
        ),
      );
    } on Object catch (error) {
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..failure.replace(
              _failure(
                ServerFailureCode.unknown,
                'Could not load the server configuration: $error',
              ),
            ),
        ),
      );
    }
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
    try {
      await _controller.start(state.config);
    } on ServerException catch (exception) {
      _emit(emit, state.rebuild((b) => b..failure.replace(exception.failure)));
    } on Object catch (error) {
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..failure.replace(
              _failure(
                ServerFailureCode.unknown,
                'Could not start llama-server: $error',
              ),
            ),
        ),
      );
    }
  }

  Future<void> _onStopRequested(
    ServerStopRequested event,
    Emitter<ServerDashboardState> emit,
  ) async {
    try {
      await _controller.stop();
    } on ServerException catch (exception) {
      _emit(emit, state.rebuild((b) => b..failure.replace(exception.failure)));
    } on Object catch (error) {
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..failure.replace(
              _failure(
                ServerFailureCode.unknown,
                'Could not stop llama-server: $error',
              ),
            ),
        ),
      );
    }
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
    try {
      final ServerProbeResult result = await _controller.testConnection(
        state.config,
      );
      _emit(
        emit,
        state.rebuild(
          (b) => b
            ..testingConnection = false
            ..connectionLatencyMs = result.latencyMs
            ..connectionMessage = result.message,
        ),
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
    _emit(emit, state.rebuild((b) => b..serverState.replace(event.state)));
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
