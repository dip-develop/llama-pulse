import 'dart:async';

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
import '../../domain/gateways/server_controller.dart';
import '../../domain/gateways/server_state_repository.dart';
import 'supervisor_tuning.dart';

int _nowEpochMs() => DateTime.now().millisecondsSinceEpoch;

/// A [ServerController] that fabricates a deterministic server lifecycle.
///
/// It opens no sockets, starts no process and touches no file, so the GUI and
/// the CLI can be exercised without `llama-server`. All output is derived from
/// elapsed time, which makes demos reproducible.
final class StubServerController implements ServerController {
  /// Creates a stub controller.
  ///
  /// [stateRepository] is optional: when present, every synthetic state is
  /// persisted, just like the real supervisor does.
  StubServerController({
    this._stateRepository,
    this._tuning = const SupervisorTuning(),
    this._clock = _nowEpochMs,
    this._delay = Future<void>.delayed,
  }) {
    _state = ServerState.stopped(updatedAtEpochMs: _clock());
  }

  /// How long the stub spends in [ServerPhase.starting].
  static const Duration startupDelay = Duration(milliseconds: 50);

  final ServerStateRepository? _stateRepository;
  final SupervisorTuning _tuning;
  final int Function() _clock;
  final Future<void> Function(Duration) _delay;

  final StreamController<ServerState> _statesController =
      StreamController<ServerState>.broadcast();
  final StreamController<ServerMetrics> _metricsController =
      StreamController<ServerMetrics>.broadcast();
  final StreamController<ServerLogEntry> _logsController =
      StreamController<ServerLogEntry>.broadcast();

  late ServerState _state;
  ServerConfig? _config;
  int? _startedAtEpochMs;
  Timer? _metricsTimer;
  Timer? _logTimer;
  int _sequence = 0;
  int _logTick = 0;
  bool _starting = false;
  bool _disposed = false;

  @override
  ServerState get state => _state;

  @override
  Stream<ServerState> get states => _statesController.stream;

  @override
  Stream<ServerMetrics> get metrics => _metricsController.stream;

  @override
  Stream<ServerLogEntry> get logs => _logsController.stream;

  @override
  Future<ServerBinaryInfo> locateBinary(ServerConfig config) async =>
      ServerBinaryInfo(
        (b) => b
          ..path = '/stub/llama-server'
          ..version = '0.8.0'
          ..buildNumber = 11960
          ..supported = true
          ..rawOutput = 'stub llama-server 0.8.0 (build 11960)',
      );

  @override
  Future<void> start(ServerConfig config) async {
    if (_disposed) {
      throw _error(ServerFailureCode.invalidConfig, 'the stub is disposed');
    }
    if (_starting || _state.isActive) {
      throw _error(
        ServerFailureCode.invalidConfig,
        'a server is already running',
      );
    }

    _starting = true;
    try {
      _config = config;
      _startedAtEpochMs = _clock();
      _emit(ServerPhase.starting, ServerHealth.loading);
      await _delay(startupDelay);
      if (_disposed || _state.phase != ServerPhase.starting) {
        return;
      }
      _emit(ServerPhase.running, ServerHealth.ok);
      _appendLog('stub: server listening on ${config.baseUrl}');
      _startTimers();
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> stop() async {
    if (!_state.isActive) {
      return;
    }
    _cancelTimers();
    _emit(ServerPhase.stopping, _state.health);
    _emit(ServerPhase.stopped, ServerHealth.unknown);
  }

  @override
  Future<ServerProbeResult> testConnection(ServerConfig config) async =>
      const ServerProbeResult(ok: true, latencyMs: 12, message: 'ok');

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _cancelTimers();
    if (_state.isActive) {
      _emit(ServerPhase.stopping, _state.health);
      _emit(ServerPhase.stopped, ServerHealth.unknown);
    }
    await _statesController.close();
    await _metricsController.close();
    await _logsController.close();
  }

  void _startTimers() {
    _metricsTimer = Timer.periodic(
      _tuning.monitorInterval,
      (_) => _emitMetrics(),
    );
    _logTimer = Timer.periodic(
      _tuning.monitorInterval * 2,
      (_) => _emitSyntheticLog(),
    );
  }

  void _cancelTimers() {
    _metricsTimer?.cancel();
    _logTimer?.cancel();
    _metricsTimer = null;
    _logTimer = null;
  }

  void _emitMetrics() {
    final config = _config;
    if (config == null || _state.phase != ServerPhase.running) {
      return;
    }
    final now = _clock();
    final elapsedMs = now - (_startedAtEpochMs ?? now);
    final elapsedSeconds = elapsedMs ~/ 1000;
    final tokensPerSecond = 32.0 + (elapsedSeconds % 8) * 4;
    final activeSlots = elapsedSeconds.isEven ? 1 : 0;

    final sample = ServerMetrics(
      (b) => b
        ..promptTokensTotal = elapsedSeconds * 12
        ..promptTokensCachedTotal = elapsedSeconds * 4
        ..tokensPredictedTotal = elapsedSeconds * 20
        ..nDecodeTotal = elapsedSeconds
        ..nTokensMax = 1
        ..requestsProcessing = activeSlots
        ..requestsDeferred = 0
        ..nBusySlotsPerDecode = activeSlots
        ..promptSecondsTotal = elapsedSeconds * 0.2
        ..tokensPredictedSecondsTotal = elapsedSeconds * 0.5
        ..tokensPerSecond = tokensPerSecond
        ..promptTokensPerSecond = 96.0 + (elapsedSeconds % 4) * 8
        ..activeSlots = activeSlots
        ..totalSlots = config.parallelSlots
        ..uptimeSeconds = elapsedSeconds
        ..capturedAtEpochMs = now,
    );
    if (!_metricsController.isClosed) {
      _metricsController.add(sample);
    }
  }

  void _emitSyntheticLog() {
    if (_state.phase != ServerPhase.running) {
      return;
    }
    _logTick++;
    _appendLog(switch ((_logTick - 1) % 4) {
      0 => 'stub: slot 0 waiting for a request',
      1 => 'stub: generated 32 tokens in 1.0s',
      2 => 'stub: no clients connected',
      _ => 'stub: keep-alive tick',
    }, stream: ServerLogStream.stdout);
  }

  void _appendLog(
    String line, {
    ServerLogStream stream = ServerLogStream.supervisor,
  }) {
    final entry = ServerLogEntry(
      (b) => b
        ..sequence = ++_sequence
        ..timestampEpochMs = _clock()
        ..stream = stream
        ..line = line,
    );
    if (!_logsController.isClosed) {
      _logsController.add(entry);
    }
  }

  void _emit(ServerPhase phase, ServerHealth health) {
    final config = _config;
    final state = ServerState(
      (b) => b
        ..phase = phase
        ..health = health
        ..host = config?.host ?? _state.host
        ..port = config?.port ?? _state.port
        ..modelPath = config?.modelPath ?? _state.modelPath
        ..binaryPath = '/stub/llama-server'
        ..binaryVersion = '0.8.0'
        ..startedAtEpochMs = _startedAtEpochMs
        ..updatedAtEpochMs = _clock(),
    );
    _state = state;
    if (!_statesController.isClosed) {
      _statesController.add(state);
    }
    final repository = _stateRepository;
    if (repository != null) {
      unawaited(_save(repository, state));
    }
  }

  Future<void> _save(
    ServerStateRepository repository,
    ServerState state,
  ) async {
    try {
      await repository.save(state);
    } catch (_) {
      // The stub has nothing to report the failure to.
      return;
    }
  }

  ServerException _error(ServerFailureCode code, String message) =>
      ServerException(
        ServerFailure(
          (b) => b
            ..code = code
            ..message = message,
        ),
      );
}
