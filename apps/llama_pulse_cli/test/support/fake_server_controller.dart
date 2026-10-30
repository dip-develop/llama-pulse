import 'dart:async';

import 'package:llama_pulse_core/llama_pulse_core.dart';

/// A scripted [ServerController] that records calls and touches no IO.
final class FakeServerController implements ServerController {
  /// Creates a controller with deterministic defaults.
  FakeServerController({
    ServerBinaryInfo? binary,
    this.locateFailure,
    this.startFailure,
    this.probeResult = const ServerProbeResult(
      ok: true,
      latencyMs: 1,
      message: 'ok',
    ),
    this.supervisorPid = 1234,
    this.serverPid = 4321,
  }) : binary = binary ?? _defaultBinary();

  /// Binary returned by [locateBinary]; override to simulate a version warning.
  final ServerBinaryInfo binary;

  /// Thrown by [locateBinary] when set.
  final ServerException? locateFailure;

  /// Thrown by [start] after a failed state is published when set.
  final ServerException? startFailure;

  /// Answer returned by [testConnection].
  final ServerProbeResult probeResult;

  /// Pid published in state events.
  final int supervisorPid;

  /// Server pid published in running state events.
  final int serverPid;

  final StreamController<ServerState> _states =
      StreamController<ServerState>.broadcast();
  final StreamController<ServerMetrics> _metrics =
      StreamController<ServerMetrics>.broadcast();
  final StreamController<ServerLogEntry> _logs =
      StreamController<ServerLogEntry>.broadcast();

  late ServerState _state = ServerState.stopped(updatedAtEpochMs: 0);
  ServerConfig? _config;
  int? _startedAtEpochMs;
  int _sequence = 0;

  /// Configuration passed to the most recent [start].
  ServerConfig? startConfig;

  /// Number of [start] calls.
  int startCalls = 0;

  /// Number of [stop] calls.
  int stopCalls = 0;

  /// Number of [dispose] calls.
  int disposeCalls = 0;

  /// Number of [locateBinary] calls.
  int locateCalls = 0;

  @override
  ServerState get state => _state;

  @override
  Stream<ServerState> get states => _states.stream;

  @override
  Stream<ServerMetrics> get metrics => _metrics.stream;

  @override
  Stream<ServerLogEntry> get logs => _logs.stream;

  @override
  Future<ServerBinaryInfo> locateBinary(ServerConfig config) async {
    locateCalls++;
    final failure = locateFailure;
    if (failure != null) {
      throw failure;
    }
    return binary;
  }

  @override
  Future<void> start(ServerConfig config) async {
    startCalls++;
    startConfig = config;
    _config = config;
    _startedAtEpochMs = 0;

    final failure = startFailure;
    if (failure != null) {
      _publish(
        _stateFor(
          ServerPhase.failed,
          ServerHealth.unreachable,
          failure: failure.failure,
        ),
      );
      throw failure;
    }

    _publish(_stateFor(ServerPhase.starting, ServerHealth.loading));
    _publish(_stateFor(ServerPhase.running, ServerHealth.ok));
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (!_state.isActive) {
      return;
    }
    _publish(_stateFor(ServerPhase.stopping, _state.health));
    _publish(
      _stateFor(ServerPhase.stopped, ServerHealth.unknown, lastExitCode: 0),
    );
  }

  @override
  Future<ServerProbeResult> testConnection(ServerConfig config) async =>
      probeResult;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _states.close();
    await _metrics.close();
    await _logs.close();
  }

  /// Emits one log line from [stream].
  void emitLog(String line, {ServerLogStream stream = ServerLogStream.stdout}) {
    if (_logs.isClosed) {
      return;
    }
    _logs.add(
      ServerLogEntry(
        (b) => b
          ..sequence = ++_sequence
          ..timestampEpochMs = _sequence
          ..stream = stream
          ..line = line,
      ),
    );
  }

  /// Emits one metrics sample.
  void emitMetrics(ServerMetrics metrics) {
    if (!_metrics.isClosed) {
      _metrics.add(metrics);
    }
  }

  /// Emits a state transition the supervisor would publish on its own.
  void emitState(ServerState state) {
    _state = state;
    if (!_states.isClosed) {
      _states.add(state);
    }
  }

  /// Emits a `failed` state, as an unexpected child exit does.
  void emitFailure(ServerFailure failure, {int? lastExitCode}) {
    final config = _config;
    if (config == null) {
      return;
    }
    emitState(
      _stateFor(
        ServerPhase.failed,
        ServerHealth.unreachable,
        failure: failure,
        lastExitCode: lastExitCode,
      ),
    );
  }

  void _publish(ServerState state) => emitState(state);

  ServerState _stateFor(
    ServerPhase phase,
    ServerHealth health, {
    ServerFailure? failure,
    int? lastExitCode,
  }) {
    final config = _config ?? ServerConfig.defaults();
    return ServerState((b) {
      b
        ..phase = phase
        ..health = health
        ..supervisorPid = supervisorPid
        ..host = config.host
        ..port = config.port
        ..modelPath = config.modelPath
        ..binaryPath = binary.path
        ..binaryVersion = binary.version
        ..startedAtEpochMs = _startedAtEpochMs
        ..updatedAtEpochMs = 0
        ..lastExitCode = lastExitCode;
      b.serverPid = switch (phase) {
        ServerPhase.starting => null,
        ServerPhase.running || ServerPhase.stopping => serverPid,
        _ => null,
      };
      if (failure != null) {
        b.failure.replace(failure);
      }
    });
  }

  static ServerBinaryInfo _defaultBinary() => ServerBinaryInfo(
    (b) => b
      ..path = '/opt/llama.cpp/llama-server'
      ..version = '0.8.0'
      ..buildNumber = 11960
      ..supported = true
      ..rawOutput = 'stub version output',
  );
}
