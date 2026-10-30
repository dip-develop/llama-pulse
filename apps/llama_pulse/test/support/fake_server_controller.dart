import 'dart:async';

import 'package:llama_pulse_core/llama_pulse_core.dart';

/// A [ServerController] that scripts every stream and records calls.
///
/// It starts no process and touches no file; tests push states, samples and
/// log lines through [emitState], [emitMetrics] and [emitLog].
final class FakeServerController implements ServerController {
  /// Creates a controller reporting [state] until a test emits another one.
  FakeServerController({
    ServerState? state,
    this.binaryInfo,
    this.probeResult = const ServerProbeResult(
      ok: true,
      latencyMs: 12,
      message: 'ok',
    ),
  }) : _state = state ?? ServerState.stopped(updatedAtEpochMs: 0);

  /// Executable reported by [locateBinary], unless [binaryError] is set.
  ServerBinaryInfo? binaryInfo;

  /// Error [locateBinary] throws instead of returning [binaryInfo].
  Object? binaryError;

  /// Result returned by [testConnection].
  ServerProbeResult probeResult;

  /// Error [start] throws instead of starting.
  ServerException? startFailure;

  /// Configurations passed to [start], in call order.
  final List<ServerConfig> startedConfigs = [];

  /// Configurations passed to [testConnection], in call order.
  final List<ServerConfig> probedConfigs = [];

  /// Number of times [stop] was called.
  int stopCalls = 0;

  /// Number of times [locateBinary] was called.
  int locateBinaryCalls = 0;

  /// Number of times [dispose] was called.
  int disposeCalls = 0;

  final StreamController<ServerState> _states =
      StreamController<ServerState>.broadcast();
  final StreamController<ServerMetrics> _metrics =
      StreamController<ServerMetrics>.broadcast();
  final StreamController<ServerLogEntry> _logs =
      StreamController<ServerLogEntry>.broadcast();

  ServerState _state;
  bool _disposed = false;

  @override
  ServerState get state => _state;

  @override
  Stream<ServerState> get states => _states.stream;

  @override
  Stream<ServerMetrics> get metrics => _metrics.stream;

  @override
  Stream<ServerLogEntry> get logs => _logs.stream;

  /// Publishes [state] to [states] and makes it the current state.
  void emitState(ServerState state) {
    _state = state;
    if (!_states.isClosed) {
      _states.add(state);
    }
  }

  /// Publishes one metrics sample.
  void emitMetrics(ServerMetrics metrics) {
    if (!_metrics.isClosed) {
      _metrics.add(metrics);
    }
  }

  /// Publishes one log line.
  void emitLog(ServerLogEntry entry) {
    if (!_logs.isClosed) {
      _logs.add(entry);
    }
  }

  /// Closes one of the streams, as a controller crash would.
  Future<void> closeStates() => _states.close();

  @override
  Future<ServerBinaryInfo> locateBinary(ServerConfig config) async {
    locateBinaryCalls++;
    final Object? error = binaryError;
    if (error != null) {
      throw error;
    }
    return binaryInfo ?? _binaryInfo();
  }

  @override
  Future<void> start(ServerConfig config) async {
    startedConfigs.add(config);
    final ServerException? failure = startFailure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<ServerProbeResult> testConnection(ServerConfig config) async {
    probedConfigs.add(config);
    return probeResult;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _states.close();
    await _metrics.close();
    await _logs.close();
  }

  static ServerBinaryInfo _binaryInfo() => ServerBinaryInfo(
    (b) => b
      ..path = '/opt/llama-server'
      ..version = '0.8.0'
      ..buildNumber = 11960
      ..supported = true
      ..rawOutput = 'llama-server 0.8.0',
  );
}
