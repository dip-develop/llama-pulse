import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'server_config.dart';
import 'server_failure.dart';
import 'server_health.dart';
import 'server_phase.dart';

part 'server_state.g.dart';

/// Snapshot of the supervised server that survives app restarts.
///
/// The supervisor is the only writer; the CLI and the app read it to report on
/// a server they did not start themselves.
abstract class ServerState implements Built<ServerState, ServerStateBuilder> {
  /// Version of the YAML document schema that stores this state.
  static const int schemaVersion = 1;

  /// Lifecycle phase of the server.
  ServerPhase get phase;

  /// Result of the most recent health probe.
  ServerHealth get health;

  /// Process id of the supervisor, when one is running.
  int? get supervisorPid;

  /// Process id of `llama-server`, when one is running.
  int? get serverPid;

  /// Address the server binds to.
  String get host;

  /// Port the server listens on.
  int get port;

  /// Path to the model file the server was started with.
  String get modelPath;

  /// Path to the executable the server was started from.
  String get binaryPath;

  /// Version reported by the executable, when it was probed.
  String? get binaryVersion;

  /// When the current run started, as milliseconds since the Unix epoch.
  int? get startedAtEpochMs;

  /// When this state was last written, as milliseconds since the Unix epoch.
  int get updatedAtEpochMs;

  /// Exit code of the last finished process, when it exited on its own.
  int? get lastExitCode;

  /// Failure that moved the server into [ServerPhase.failed].
  ServerFailure? get failure;

  /// Whether a process is running or the supervisor is between transitions.
  bool get isActive =>
      phase != ServerPhase.stopped && phase != ServerPhase.failed;

  /// OpenAI-compatible endpoint root, for example `http://127.0.0.1:8080/v1`.
  String get baseUrl =>
      'http://${ServerConfig.resolveClientHost(host)}:$port/v1';

  factory ServerState([void Function(ServerStateBuilder)? updates]) =
      _$ServerState;

  /// Returns the state written when no server is running.
  factory ServerState.stopped({required int updatedAtEpochMs}) => ServerState(
    (b) => b
      ..phase = ServerPhase.stopped
      ..health = ServerHealth.unknown
      ..host = '127.0.0.1'
      ..port = 8080
      ..modelPath = ''
      ..binaryPath = ''
      ..updatedAtEpochMs = updatedAtEpochMs,
  );

  ServerState._();

  static Serializer<ServerState> get serializer => _$serverStateSerializer;
}
