import '../entities/server_binary_info.dart';
import '../entities/server_config.dart';
import '../entities/server_log_entry.dart';
import '../entities/server_metrics.dart';
import '../entities/server_probe_result.dart';
import '../entities/server_state.dart';

/// Owns the lifetime of one supervised `llama-server` process.
///
/// Implementations spawn and stop the process, probe it and publish state,
/// metrics and log lines. All streams are broadcast and stay open for the
/// lifetime of the controller.
abstract interface class ServerController {
  /// Most recent state, available synchronously for cheap reads.
  ServerState get state;

  /// State after every supervisor transition.
  Stream<ServerState> get states;

  /// Samples polled from the running server.
  Stream<ServerMetrics> get metrics;

  /// Supervisor and `llama-server` output.
  Stream<ServerLogEntry> get logs;

  /// Resolves the executable and reads its version without starting a server.
  Future<ServerBinaryInfo> locateBinary(ServerConfig config);

  /// Validates [config], writes the state and starts the process.
  Future<void> start(ServerConfig config);

  /// Stops the process, if any. Safe to call when nothing runs.
  Future<void> stop();

  /// Sends one HTTP probe to the server described by [config].
  Future<ServerProbeResult> testConnection(ServerConfig config);

  /// Stops the process and releases streams and resources.
  Future<void> dispose();
}
