import 'dart:async';
import 'dart:io' show File, FileSystemEntityType, pid;

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
import '../../domain/gateways/port_probe.dart';
import '../../domain/gateways/server_binary_locator.dart';
import '../../domain/gateways/server_controller.dart';
import '../../domain/gateways/server_http_client.dart';
import '../../domain/gateways/server_process.dart';
import '../../domain/gateways/server_state_repository.dart';
import '../../domain/server_config_validator.dart';
import 'server_argument_builder.dart';
import 'server_log_store.dart';
import 'supervisor_tuning.dart';

int _nowEpochMs() => DateTime.now().millisecondsSinceEpoch;

/// Supervises one `llama-server` child process.
///
/// The supervisor validates the configuration, locates the binary, spawns the
/// child, waits for `/health` and publishes every lifecycle transition to
/// [states]. It never retries on its own: a failed or exited server stays
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
    this._argumentBuilder = const ServerArgumentBuilder(),
    this._tuning = const SupervisorTuning(),
    this._clock = _nowEpochMs,
    this._delay = Future<void>.delayed,
  }) {
    _state = ServerState.stopped(updatedAtEpochMs: _clock());
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
  Completer<int> _exitCompleter = Completer<int>();
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Future<void> _saveChain = Future<void>.value();

  int? _startedAtEpochMs;
  int? _lastExitCode;
  bool _starting = false;
  bool _stopping = false;
  bool _ready = false;
  bool _bindFailed = false;
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
  Future<void> start(ServerConfig config) async {
    if (_disposed) {
      throw _error(
        ServerFailureCode.invalidConfig,
        'the supervisor is disposed',
      );
    }
    if (_starting || _state.isActive) {
      throw _error(
        ServerFailureCode.invalidConfig,
        'a server is already running',
      );
    }

    _starting = true;
    try {
      final violations = _validator.validateForStart(config);
      if (violations.isNotEmpty) {
        throw _error(
          ServerFailureCode.invalidConfig,
          'invalid server configuration',
          details: violations.join('\n'),
        );
      }

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

      final model = File(config.modelPath);
      final modelIsFile =
          await model.exists() &&
          (await model.stat()).type == FileSystemEntityType.file;
      if (!modelIsFile) {
        throw _error(
          ServerFailureCode.modelNotFound,
          'model file not found: ${config.modelPath}',
        );
      }

      final available = await _portProbe.isAvailable(config.host, config.port);
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
      _exitCompleter = Completer<int>();
      unawaited(_watchExit(process));
      _stdoutSubscription = process.stdoutLines.listen(
        (line) => _onLine(ServerLogStream.stdout, line),
      );
      _stderrSubscription = process.stderrLines.listen(
        (line) => _onLine(ServerLogStream.stderr, line),
      );

      _emit(
        _stateFor(
          ServerPhase.starting,
          ServerHealth.loading,
          serverPid: process.pid,
        ),
      );

      await _awaitReady(config, process);
      await _probeProps(config);

      if (_exitCompleter.isCompleted) {
        await _failOnExitBeforeReady(config);
      }
      if (_bindFailed) {
        await _failOnBind(config, process);
      }

      _ready = true;
      _emit(
        _stateFor(ServerPhase.running, ServerHealth.ok, serverPid: process.pid),
      );
      _logStore.append(
        ServerLogStream.supervisor,
        'llama-server is ready on http://${config.clientHost}:${config.port}',
      );
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> stop() async {
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
      _emit(_stateFor(ServerPhase.stopping, _state.health));
      await _terminate(process);

      final exitCode = _exitCompleter.isCompleted
          ? await _exitCompleter.future
          : _lastExitCode;
      _process = null;
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

      if (health.statusCode >= 200 && health.statusCode < 300) {
        return result(true, 'ok');
      }
      return result(false, 'HTTP ${health.statusCode}');
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
    await _saveChain;
    _httpClient.close();
    await _logStore.dispose();
    await _statesController.close();
    await _metricsController.close();
  }

  Future<void> _awaitReady(ServerConfig config, ServerProcess process) async {
    final deadline =
        (_startedAtEpochMs ?? _clock()) + config.startupTimeoutSeconds * 1000;

    while (true) {
      if (_exitCompleter.isCompleted) {
        await _failOnExitBeforeReady(config);
      }
      if (_bindFailed) {
        await _failOnBind(config, process);
      }

      final health = await _probeHealth(config);
      if (health == ServerHealth.ok) {
        return;
      }
      _setHealth(health);

      if (_clock() >= deadline) {
        await _failStartupTimeout(config, process);
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
        return response.body.contains('"ok"')
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

  Future<Never> _failOnExitBeforeReady(ServerConfig config) async {
    final exitCode = await _exitCompleter.future;
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

  Future<Never> _failOnBind(ServerConfig config, ServerProcess process) async {
    await _terminate(process);
    final exitCode = _exitCompleter.isCompleted
        ? await _exitCompleter.future
        : null;
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
  ) async {
    await _terminate(process);
    final exitCode = _exitCompleter.isCompleted
        ? await _exitCompleter.future
        : null;
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

  Future<void> _terminate(ServerProcess process) async {
    if (_exitCompleter.isCompleted) {
      return;
    }
    process.kill(ServerKillMode.graceful);
    if (await _waitForExit(_tuning.shutdownGrace)) {
      return;
    }
    process.kill(ServerKillMode.force);
    await _waitForExit(_tuning.shutdownGrace);
  }

  Future<bool> _waitForExit(Duration timeout) async {
    if (_exitCompleter.isCompleted) {
      return true;
    }
    final deadline = _clock() + timeout.inMilliseconds;
    while (!_exitCompleter.isCompleted && _clock() < deadline) {
      await _delay(_tuning.stopPollInterval);
    }
    return _exitCompleter.isCompleted;
  }

  Future<void> _watchExit(ServerProcess process) {
    return process.exitCode.then<void>(
      (code) {
        if (!_exitCompleter.isCompleted) {
          _exitCompleter.complete(code);
        }
        return _handleExit(process, code);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_exitCompleter.isCompleted) {
          _exitCompleter.complete(-1);
        }
        return _handleExit(process, -1);
      },
    );
  }

  Future<void> _handleExit(ServerProcess process, int code) async {
    if (!identical(_process, process)) {
      return;
    }
    _process = null;
    _lastExitCode = code;
    if (!_ready || _stopping) {
      return;
    }

    _ready = false;
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

  void _onLine(ServerLogStream stream, String line) {
    _logStore.append(stream, line);
    if (stream != ServerLogStream.stderr || _ready) {
      return;
    }
    if (_state.phase == ServerPhase.starting && _bindFailure.hasMatch(line)) {
      _bindFailed = true;
    }
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
    return ServerState((b) {
      b
        ..phase = phase
        ..health = health
        ..supervisorPid = pid
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
        .map((entry) => '${entry.stream.name}: ${entry.line}')
        .join('\n');
  }

  Future<void> _cancelSubscriptions() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
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
