import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, FileSystemEntityType, Platform, pid;

import '../../domain/entities/server_binary_info.dart';
import '../../domain/entities/server_config.dart';
import '../../domain/entities/server_failure.dart';
import '../../domain/entities/server_failure_code.dart';
import '../../domain/entities/server_health.dart';
import '../../domain/entities/server_log_entry.dart';
import '../../domain/entities/server_log_stream.dart';
import '../../domain/entities/server_metrics.dart';
import '../../domain/entities/server_phase.dart';
import '../../domain/entities/server_probe_result.dart';
import '../../domain/entities/server_state.dart';
import '../../domain/exceptions/server_exception.dart';
import '../../domain/gateways/config_store.dart';
import '../../domain/gateways/port_probe.dart';
import '../../domain/gateways/server_binary_locator.dart';
import '../../domain/gateways/server_controller.dart';
import '../../domain/gateways/server_http_client.dart';
import '../../domain/gateways/server_process.dart';
import '../../domain/gateways/server_state_repository.dart';
import '../../domain/server_config_validator.dart';
import '../config/app_paths.dart';
import '../config/yaml_server_state_repository.dart';
import '../serialization/serializers.dart';
import 'dart_http_client.dart';
import 'dart_process_launcher.dart';
import 'server_argument_builder.dart';
import 'server_binary_locator_impl.dart';
import 'server_log_store.dart';
import 'server_monitor.dart';
import 'socket_port_probe.dart';
import 'supervisor_tuning.dart';

int _nowEpochMs() => DateTime.now().millisecondsSinceEpoch;

/// Supervises one `llama-server` child process.
///
/// The supervisor validates the configuration, locates the binary, spawns the
/// child, waits for `/health` and publishes every lifecycle transition to
/// [states]. While the server runs it samples [metrics] and keeps the health
/// field current. It never retries on its own: a failed or exited server stays
/// failed until the caller starts it again.
final class LlamaServerSupervisor implements ServerController {
  /// Creates a supervisor; every collaborator is injected, no globals.
  LlamaServerSupervisor({
    required this._launcher,
    required this._httpClient,
    required this._portProbe,
    required this._binaryLocator,
    required this._stateRepository,
    required this._logStore,
    required this._validator,
    this._monitor,
    this._argumentBuilder = const ServerArgumentBuilder(),
    this._tuning = const SupervisorTuning(),
    this._clock = _nowEpochMs,
    this._delay = Future<void>.delayed,
  }) {
    _state = ServerState.stopped(updatedAtEpochMs: _clock());
  }

  /// Creates the production wiring: real processes, HTTP probes and files.
  ///
  /// The binary locator resolves `llama-server` from the configuration, the
  /// `LLAMA_PULSE_SERVER` environment variable, the running executable's
  /// directory, [AppPaths.binDirectory] and `PATH`, in that order. State is
  /// stored in `server-state.yaml` and logs in [AppPaths.serverLogFile].
  factory LlamaServerSupervisor.production({
    required AppPaths paths,
    required ConfigStore configStore,
  }) {
    final httpClient = DartServerHttpClient();
    final logStore = ServerLogStore(filePath: paths.serverLogFile);
    // Best effort: a restarted app or CLI should show the previous log lines.
    unawaited(logStore.loadExisting());
    return LlamaServerSupervisor(
      launcher: const DartProcessLauncher(),
      httpClient: httpClient,
      portProbe: const SocketPortProbe(),
      binaryLocator: ServerBinaryLocatorImpl(
        paths: paths,
        executablePath: Platform.resolvedExecutable,
      ),
      stateRepository: YamlServerStateRepository(
        store: configStore,
        serializers: serializers,
      ),
      logStore: logStore,
      validator: const ServerConfigValidator(),
      monitor: ServerMonitor(httpClient: httpClient),
    );
  }

  /// Builds before this one use the legacy `--mlock` / `--no-mmap` flags.
  static const int loadModeMinimumBuild = 10875;

  static final RegExp _bindFailure = RegExp(
    'address already in use|bind failed|couldn.t bind',
    caseSensitive: false,
  );

  final ServerProcessLauncher _launcher;
  final ServerHttpClient _httpClient;
  final PortProbe _portProbe;
  final ServerBinaryLocator _binaryLocator;
  final ServerStateRepository _stateRepository;
  final ServerLogStore _logStore;
  final ServerConfigValidator _validator;
  final ServerMonitor? _monitor;
  final ServerArgumentBuilder _argumentBuilder;
  final SupervisorTuning _tuning;
  final int Function() _clock;
  final Future<void> Function(Duration) _delay;

  final StreamController<ServerState> _statesController =
      StreamController<ServerState>.broadcast();
  final StreamController<ServerMetrics> _metricsController =
      StreamController<ServerMetrics>.broadcast();

  late ServerState _state;
  ServerConfig? _config;
  ServerBinaryInfo? _binary;
  ServerProcess? _process;
  Completer<int>? _exitCompleter;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Future<void> _saveChain = Future<void>.value();
  Future<void>? _startFuture;

  Timer? _metricsTimer;
  Timer? _healthTimer;
  bool _sampling = false;
  bool _healthPolling = false;

  int _runGeneration = 0;
  int? _startedAtEpochMs;
  int? _lastExitCode;
  bool _starting = false;
  bool _stopping = false;
  bool _ready = false;
  bool _bindFailed = false;
  bool _stopRequested = false;
  bool _disposed = false;

  @override
  ServerState get state => _state;

  @override
  Stream<ServerState> get states => _statesController.stream;

  @override
  Stream<ServerMetrics> get metrics => _metricsController.stream;

  @override
  Stream<ServerLogEntry> get logs => _logStore.entries;

  @override
  Future<ServerBinaryInfo> locateBinary(ServerConfig config) async {
    try {
      return await _binaryLocator.locate(config);
    } on ServerException catch (error) {
      if (error.failure.code != ServerFailureCode.unsupportedVersion) {
        rethrow;
      }
      final path = config.binaryPath.trim();
      return ServerBinaryInfo(
        (b) => b
          ..path = path
          ..version = 'unknown'
          ..supported = false
          ..warning = error.failure.message
          ..rawOutput = error.failure.details ?? '',
      );
    }
  }

  @override
  Future<void> start(ServerConfig config) {
    if (_disposed) {
      return Future<void>.error(
        _error(ServerFailureCode.invalidConfig, 'the supervisor is disposed'),
      );
    }
    if (_starting || _state.isActive) {
      return Future<void>.error(
        _error(ServerFailureCode.invalidConfig, 'a server is already running'),
      );
    }

    _stopRequested = false;
    final generation = ++_runGeneration;
    final future = _runStart(config, generation);
    final tracked = future.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    _startFuture = tracked;
    unawaited(
      tracked.whenComplete(() {
        if (identical(_startFuture, tracked)) {
          _startFuture = null;
        }
      }),
    );
    return future;
  }

  Future<void> _runStart(ServerConfig config, int generation) async {
    _starting = true;
    try {
      _throwIfAborted(generation);

      final violations = _validator.validateForStart(config);
      if (violations.isNotEmpty) {
        throw _error(
          ServerFailureCode.invalidConfig,
          'invalid server configuration',
          details: violations.join('\n'),
        );
      }

      await _logStore.loadExisting();
      _throwIfAborted(generation);

      final ServerBinaryInfo binary;
      try {
        binary = await _binaryLocator.locate(config);
      } on ServerException {
        rethrow;
      } catch (error) {
        throw _error(
          ServerFailureCode.binaryNotFound,
          'llama-server not found',
          details: '$error',
        );
      }
      _throwIfAborted(generation);

      final model = File(config.modelPath);
      final modelIsFile =
          await model.exists() &&
          (await model.stat()).type == FileSystemEntityType.file;
      _throwIfAborted(generation);
      if (!modelIsFile) {
        throw _error(
          ServerFailureCode.modelNotFound,
          'model file not found: ${config.modelPath}',
        );
      }

      final available = await _portProbe.isAvailable(config.host, config.port);
      _throwIfAborted(generation);
      if (!available) {
        throw _error(
          ServerFailureCode.portInUse,
          'port ${config.host}:${config.port} is already in use',
        );
      }

      _config = config;
      _binary = binary;
      _startedAtEpochMs = _clock();
      _lastExitCode = null;
      _bindFailed = false;

      _emit(
        _stateFor(
          ServerPhase.starting,
          ServerHealth.loading,
          lastExitCode: null,
        ),
      );
      _logStore.append(
        ServerLogStream.supervisor,
        'starting ${binary.path} on ${config.host}:${config.port}',
      );

      final build = binary.buildNumber;
      final arguments = _argumentBuilder.build(
        config,
        useLoadMode: build == null || build >= loadModeMinimumBuild,
      );

      final ServerProcess process;
      try {
        process = await _launcher.start(binary.path, arguments);
      } catch (error) {
        _throwIfAborted(generation);
        final failure = ServerFailure(
          (b) => b
            ..code = ServerFailureCode.processExited
            ..message = 'llama-server could not be started'
            ..details = '$error',
        );
        _logStore.append(
          ServerLogStream.supervisor,
          'could not start llama-server: $error',
        );
        _emit(
          _stateFor(
            ServerPhase.failed,
            ServerHealth.unreachable,
            failure: failure,
          ),
        );
        throw ServerException(failure);
      }

      _process = process;
      final exit = _exitCompleter = Completer<int>();
      unawaited(_watchExit(process, generation, exit));
      _stdoutSubscription = process.stdoutLines.listen(
        (line) => _onLine(ServerLogStream.stdout, line),
      );
      _stderrSubscription = process.stderrLines.listen(
        (line) => _onLine(ServerLogStream.stderr, line),
      );
      _throwIfAborted(generation);

      _emit(
        _stateFor(
          ServerPhase.starting,
          ServerHealth.loading,
          serverPid: process.pid,
        ),
      );

      await _awaitReady(config, process, generation, exit);
      _throwIfAborted(generation);
      await _probeProps(config);
      _throwIfAborted(generation);

      if (exit.isCompleted) {
        await _failOnExitBeforeReady(config, exit, generation);
      }
      if (_bindFailed) {
        await _failOnBind(config, process, exit, generation);
      }
      _throwIfAborted(generation);

      _ready = true;
      _emit(
        _stateFor(ServerPhase.running, ServerHealth.ok, serverPid: process.pid),
      );
      _logStore.append(
        ServerLogStream.supervisor,
        'llama-server is ready on http://${config.clientHost}:${config.port}',
      );
      _startMonitors(config, generation);
    } on _Aborted {
      await _abortStart(generation);
    } finally {
      _starting = false;
    }
  }

  Future<void> _abortStart(int generation) async {
    if (generation != _runGeneration) {
      return;
    }
    await _cancelSubscriptions();
    _stopMonitors();
    final process = _process;
    final exit = _exitCompleter;
    if (process != null) {
      try {
        if (exit != null) {
          await _terminate(process, exit);
        }
        _process = null;
        _exitCompleter = null;
      } on ServerException {
        // The child survived SIGKILL: keep it and the failed state so a later
        // command can still signal it.
        return;
      }
    }
    _ready = false;
    if (_stopRequested) {
      _emit(
        _stateFor(
          ServerPhase.stopped,
          ServerHealth.unknown,
          lastExitCode: _lastExitCode,
        ),
      );
      _logStore.append(ServerLogStream.supervisor, 'llama-server stopped');
      await _saveChain;
    }
  }

  @override
  Future<void> stop() async {
    _stopRequested = true;
    final inFlight = _startFuture;
    if (inFlight != null) {
      await inFlight;
    }
    if (_stopping) {
      return;
    }
    final process = _process;
    if (process == null || !_state.isActive) {
      return;
    }

    _stopping = true;
    try {
      _ready = false;
      _stopMonitors();
      _emit(_stateFor(ServerPhase.stopping, _state.health));
      final exit = _exitCompleter;
      if (exit == null) {
        throw _error(
          ServerFailureCode.processExited,
          'the server process has no exit watcher',
        );
      }
      await _terminate(process, exit);

      final exitCode = exit.isCompleted ? await exit.future : _lastExitCode;
      _process = null;
      _exitCompleter = null;
      _lastExitCode = exitCode ?? _lastExitCode;
      await _cancelSubscriptions();
      _emit(
        _stateFor(
          ServerPhase.stopped,
          ServerHealth.unknown,
          lastExitCode: _lastExitCode,
        ),
      );
      _logStore.append(ServerLogStream.supervisor, 'llama-server stopped');
      await _saveChain;
    } finally {
      _stopping = false;
    }
  }

  @override
  Future<ServerProbeResult> testConnection(ServerConfig config) async {
    final stopwatch = Stopwatch()..start();
    ServerProbeResult result(bool ok, String message) => ServerProbeResult(
      ok: ok,
      latencyMs: stopwatch.elapsedMilliseconds,
      message: message,
    );

    try {
      final health = await _httpClient
          .get(_healthUri(config))
          .timeout(_tuning.httpTimeout);
      if (health.statusCode == 401 || health.statusCode == 403) {
        return result(false, 'unauthorized');
      }
      if (health.statusCode != 200 || !_isOkBody(health.body)) {
        return result(false, 'HTTP ${health.statusCode}');
      }

      if (config.apiKey.isNotEmpty) {
        final models = await _httpClient
            .get(
              _modelsUri(config),
              headers: <String, String>{
                'Authorization': 'Bearer ${config.apiKey}',
              },
            )
            .timeout(_tuning.httpTimeout);
        if (models.statusCode == 401 || models.statusCode == 403) {
          return result(false, 'unauthorized');
        }
        if (models.statusCode >= 400) {
          return result(false, 'HTTP ${models.statusCode}');
        }
      }

      return result(true, 'ok');
    } catch (_) {
      return result(false, 'unreachable');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await stop();
    await _cancelSubscriptions();
    _stopMonitors();
    await _saveChain;
    _httpClient.close();
    await _logStore.dispose();
    await _statesController.close();
    await _metricsController.close();
  }

  Future<void> _awaitReady(
    ServerConfig config,
    ServerProcess process,
    int generation,
    Completer<int> exit,
  ) async {
    final deadline =
        (_startedAtEpochMs ?? _clock()) + config.startupTimeoutSeconds * 1000;

    while (true) {
      _throwIfAborted(generation);
      if (exit.isCompleted) {
        await _failOnExitBeforeReady(config, exit, generation);
      }
      if (_bindFailed) {
        await _failOnBind(config, process, exit, generation);
      }

      final health = await _probeHealth(config);
      _throwIfAborted(generation);
      if (health == ServerHealth.ok) {
        return;
      }
      _setHealth(health);

      if (_clock() >= deadline) {
        await _failStartupTimeout(config, process, exit, generation);
      }
      await _delay(_tuning.healthPollInterval);
    }
  }

  Future<ServerHealth> _probeHealth(ServerConfig config) async {
    try {
      final response = await _httpClient
          .get(_healthUri(config))
          .timeout(_tuning.httpTimeout);
      if (response.statusCode == 200) {
        return _isOkBody(response.body)
            ? ServerHealth.ok
            : ServerHealth.degraded;
      }
      if (response.statusCode == 503) {
        return ServerHealth.loading;
      }
      return ServerHealth.degraded;
    } catch (_) {
      return ServerHealth.loading;
    }
  }

  Future<ServerHealth> _probeLiveHealth(ServerConfig config) async {
    try {
      final response = await _httpClient
          .get(_healthUri(config))
          .timeout(_tuning.httpTimeout);
      if (response.statusCode == 200 && _isOkBody(response.body)) {
        return ServerHealth.ok;
      }
      return ServerHealth.degraded;
    } catch (_) {
      return ServerHealth.unreachable;
    }
  }

  Future<void> _probeProps(ServerConfig config) async {
    try {
      await _httpClient
          .get(Uri.parse('http://${config.clientHost}:${config.port}/props'))
          .timeout(_tuning.httpTimeout);
    } catch (_) {
      // /props only enriches the dashboard; readiness already succeeded.
      return;
    }
  }

  Future<Never> _failOnExitBeforeReady(
    ServerConfig config,
    Completer<int> exit,
    int generation,
  ) async {
    final exitCode = await exit.future;
    _throwIfAborted(generation);
    _process = null;
    _lastExitCode = exitCode;
    final details = _tail();
    final failure = _bindFailed
        ? ServerFailure(
            (b) => b
              ..code = ServerFailureCode.portInUse
              ..message = 'port ${config.host}:${config.port} is already in use'
              ..details = details,
          )
        : ServerFailure(
            (b) => b
              ..code = ServerFailureCode.processExited
              ..message =
                  'llama-server exited before it became ready '
                  '(exit code $exitCode)'
              ..details = details,
          );
    _logStore.append(
      ServerLogStream.supervisor,
      'llama-server exited before it became ready (exit code $exitCode)',
    );
    _emit(
      _stateFor(
        ServerPhase.failed,
        ServerHealth.unreachable,
        lastExitCode: exitCode,
        failure: failure,
      ),
    );
    throw ServerException(failure);
  }

  Future<Never> _failOnBind(
    ServerConfig config,
    ServerProcess process,
    Completer<int> exit,
    int generation,
  ) async {
    await _terminate(process, exit);
    _throwIfAborted(generation);
    final exitCode = exit.isCompleted ? await exit.future : null;
    _process = null;
    _lastExitCode = exitCode ?? _lastExitCode;
    final failure = ServerFailure(
      (b) => b
        ..code = ServerFailureCode.portInUse
        ..message = 'port ${config.host}:${config.port} is already in use'
        ..details = _tail(),
    );
    _logStore.append(
      ServerLogStream.supervisor,
      'llama-server reported a bind failure on '
      '${config.host}:${config.port}',
    );
    _emit(
      _stateFor(
        ServerPhase.failed,
        ServerHealth.unreachable,
        lastExitCode: _lastExitCode,
        failure: failure,
      ),
    );
    throw ServerException(failure);
  }

  Future<Never> _failStartupTimeout(
    ServerConfig config,
    ServerProcess process,
    Completer<int> exit,
    int generation,
  ) async {
    await _terminate(process, exit);
    _throwIfAborted(generation);
    final exitCode = exit.isCompleted ? await exit.future : null;
    _process = null;
    _lastExitCode = exitCode ?? _lastExitCode;
    final failure = ServerFailure(
      (b) => b
        ..code = ServerFailureCode.startupTimeout
        ..message =
            'llama-server did not become ready within '
            '${config.startupTimeoutSeconds}s'
        ..details = _tail(),
    );
    _logStore.append(
      ServerLogStream.supervisor,
      'llama-server did not become ready within '
      '${config.startupTimeoutSeconds}s',
    );
    _emit(
      _stateFor(
        ServerPhase.failed,
        ServerHealth.unreachable,
        lastExitCode: _lastExitCode,
        failure: failure,
      ),
    );
    throw ServerException(failure);
  }

  Future<void> _terminate(ServerProcess process, Completer<int> exit) async {
    if (exit.isCompleted) {
      return;
    }
    process.kill(ServerKillMode.graceful);
    if (await _waitForExit(_tuning.shutdownGrace, exit)) {
      return;
    }
    process.kill(ServerKillMode.force);
    if (await _waitForExit(_tuning.shutdownGrace, exit)) {
      return;
    }
    final failure = ServerFailure(
      (b) => b
        ..code = ServerFailureCode.processExited
        ..message = 'server did not exit after SIGKILL'
        ..details = _tail(),
    );
    _emit(
      _stateFor(
        ServerPhase.failed,
        ServerHealth.unreachable,
        serverPid: process.pid,
        lastExitCode: _lastExitCode,
        failure: failure,
      ),
    );
    throw ServerException(failure);
  }

  Future<bool> _waitForExit(Duration timeout, Completer<int> exit) async {
    if (exit.isCompleted) {
      return true;
    }
    final deadline = _clock() + timeout.inMilliseconds;
    while (!exit.isCompleted && _clock() < deadline) {
      await _delay(_tuning.stopPollInterval);
    }
    return exit.isCompleted;
  }

  Future<void> _watchExit(
    ServerProcess process,
    int generation,
    Completer<int> exit,
  ) {
    Future<void> handle(int code) async {
      if (generation != _runGeneration || !identical(_process, process)) {
        return;
      }
      if (!exit.isCompleted) {
        exit.complete(code);
      }
      await _handleExit(process, code, generation);
    }

    return process.exitCode.then<void>(
      handle,
      onError: (Object error, StackTrace stackTrace) => handle(-1),
    );
  }

  Future<void> _handleExit(
    ServerProcess process,
    int code,
    int generation,
  ) async {
    if (generation != _runGeneration || !identical(_process, process)) {
      return;
    }
    _process = null;
    _lastExitCode = code;
    if (!_ready || _stopping) {
      return;
    }

    _ready = false;
    _stopMonitors();
    final details = _tail();
    final failure = ServerFailure(
      (b) => b
        ..code = ServerFailureCode.processExited
        ..message = 'llama-server exited unexpectedly (exit code $code)'
        ..details = details,
    );
    _logStore.append(
      ServerLogStream.supervisor,
      'llama-server exited unexpectedly with code $code',
    );
    _emit(
      _stateFor(
        ServerPhase.failed,
        ServerHealth.unreachable,
        lastExitCode: code,
        failure: failure,
      ),
    );
  }

  void _startMonitors(ServerConfig config, int generation) {
    _stopMonitors();
    final monitor = _monitor;
    if (monitor != null) {
      _metricsTimer = Timer.periodic(
        _tuning.metricsInterval,
        (_) => unawaited(_sampleMetrics(config, generation, monitor)),
      );
    }
    _healthTimer = Timer.periodic(
      _tuning.monitorInterval,
      (_) => unawaited(_pollHealth(config, generation)),
    );
  }

  void _stopMonitors() {
    _metricsTimer?.cancel();
    _healthTimer?.cancel();
    _metricsTimer = null;
    _healthTimer = null;
  }

  Future<void> _sampleMetrics(
    ServerConfig config,
    int generation,
    ServerMonitor monitor,
  ) async {
    if (_sampling) {
      return;
    }
    _sampling = true;
    try {
      if (!_isRunning(generation)) {
        return;
      }
      final sample = await monitor.sample(
        config,
        startedAtEpochMs: _startedAtEpochMs,
      );
      if (!_isRunning(generation) || _metricsController.isClosed) {
        return;
      }
      _metricsController.add(sample);
    } on ServerException {
      if (_isRunning(generation)) {
        _setHealth(ServerHealth.degraded);
      }
    } catch (_) {
      // A monitor bug must not take down the supervisor.
    } finally {
      _sampling = false;
    }
  }

  Future<void> _pollHealth(ServerConfig config, int generation) async {
    if (_healthPolling) {
      return;
    }
    _healthPolling = true;
    try {
      if (!_isRunning(generation)) {
        return;
      }
      final health = await _probeLiveHealth(config);
      if (!_isRunning(generation)) {
        return;
      }
      _setHealth(health);
    } finally {
      _healthPolling = false;
    }
  }

  bool _isRunning(int generation) =>
      generation == _runGeneration && _state.phase == ServerPhase.running;

  void _onLine(ServerLogStream stream, String line) {
    _logStore.append(stream, _redact(line));
    if (stream != ServerLogStream.stderr || _ready) {
      return;
    }
    if (_state.phase == ServerPhase.starting && _bindFailure.hasMatch(line)) {
      _bindFailed = true;
    }
  }

  String _redact(String value) {
    final apiKey = _config?.apiKey ?? '';
    if (apiKey.isEmpty) {
      return value;
    }
    return value.replaceAll(apiKey, '***');
  }

  void _setHealth(ServerHealth health) {
    if (_state.health == health) {
      return;
    }
    _emit(
      _stateFor(
        _state.phase,
        health,
        serverPid: _state.serverPid,
        lastExitCode: _state.lastExitCode,
        failure: _state.failure,
      ),
      persist: false,
    );
  }

  void _emit(ServerState next, {bool persist = true}) {
    _state = next;
    if (!_statesController.isClosed) {
      _statesController.add(next);
    }
    if (persist) {
      _persist(next);
    }
  }

  void _persist(ServerState state) {
    _saveChain = _saveChain.then((_) async {
      try {
        await _stateRepository.save(state);
      } catch (error) {
        _logStore.append(
          ServerLogStream.supervisor,
          'could not write server state: $error',
        );
      }
    });
  }

  ServerState _stateFor(
    ServerPhase phase,
    ServerHealth health, {
    int? serverPid,
    int? lastExitCode,
    ServerFailure? failure,
  }) {
    final config = _config;
    final binary = _binary;
    final terminal =
        phase == ServerPhase.stopped || phase == ServerPhase.failed;
    return ServerState((b) {
      b
        ..phase = phase
        ..health = health
        ..supervisorPid = terminal ? null : pid
        ..serverPid = serverPid
        ..host = config?.host ?? _state.host
        ..port = config?.port ?? _state.port
        ..modelPath = config?.modelPath ?? _state.modelPath
        ..binaryPath = binary?.path ?? _state.binaryPath
        ..binaryVersion = binary?.version ?? _state.binaryVersion
        ..startedAtEpochMs = _startedAtEpochMs
        ..updatedAtEpochMs = _clock()
        ..lastExitCode = lastExitCode;
      if (failure != null) {
        b.failure.replace(failure);
      }
    });
  }

  String _tail() {
    final entries = _logStore.recent;
    if (entries.isEmpty) {
      return '';
    }
    final selected = entries.length > _tuning.maxLogTail
        ? entries.sublist(entries.length - _tuning.maxLogTail)
        : entries;
    return selected
        .map((entry) => '${entry.stream.name}: ${_redact(entry.line)}')
        .join('\n');
  }

  Future<void> _cancelSubscriptions() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
  }

  bool _isOkBody(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<Object?, Object?> && decoded['status'] == 'ok';
    } on FormatException {
      return false;
    }
  }

  void _throwIfAborted(int generation) {
    if (_disposed || _stopRequested || generation != _runGeneration) {
      throw const _Aborted();
    }
  }

  Uri _healthUri(ServerConfig config) =>
      Uri.parse('http://${config.clientHost}:${config.port}/health');

  Uri _modelsUri(ServerConfig config) =>
      Uri.parse('http://${config.clientHost}:${config.port}/v1/models');

  ServerException _error(
    ServerFailureCode code,
    String message, {
    String? details,
  }) => ServerException(
    ServerFailure(
      (b) => b
        ..code = code
        ..message = message
        ..details = details,
    ),
  );
}

final class _Aborted implements Exception {
  const _Aborted();
}
