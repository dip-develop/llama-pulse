import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

part 'server_dashboard_state.g.dart';

/// Immutable snapshot rendered by the server dashboard.
abstract class ServerDashboardState
    implements Built<ServerDashboardState, ServerDashboardStateBuilder> {
  /// Configuration shown in the form and used for the next start.
  ServerConfig get config;

  /// Lifecycle of the supervised server, as reported by the controller.
  ServerState get serverState;

  /// Samples received from the running server, newest last, capped at 120.
  BuiltList<ServerMetrics> get metricsHistory;

  /// Supervisor and server output, oldest first, capped at 1000 lines.
  BuiltList<ServerLogEntry> get logs;

  /// Executable the supervisor resolved, once it has been located.
  ServerBinaryInfo? get binaryInfo;

  /// Details of the last failed action, or `null` when it succeeded.
  ServerFailure? get failure;

  /// Whether a configuration write is in flight.
  bool get saving;

  /// Whether the form holds changes that were not persisted yet.
  bool get dirty;

  /// Whether a connection test is in flight.
  bool get testingConnection;

  /// Whether the running server was started outside this app.
  ///
  /// Such a run is reported from the shared state document, so the dashboard
  /// can observe it, but only the CLI that spawned it may stop it.
  bool get externalRun;

  /// Round-trip time of the last connection test, when it completed.
  int? get connectionLatencyMs;

  /// Summary of the last connection test, when it completed.
  String? get connectionMessage;

  /// OpenAI-compatible endpoint root of the configured server.
  String get endpoint => config.baseUrl;

  /// Lifecycle phase of the supervised server.
  ServerPhase get phase => serverState.phase;

  /// Metrics from the most recent sample, or `null` when none arrived.
  ServerMetrics? get latestMetrics =>
      metricsHistory.isEmpty ? null : metricsHistory.last;

  /// Whether a start request makes sense right now.
  bool get canStart =>
      (phase == ServerPhase.stopped || phase == ServerPhase.failed) &&
      !saving &&
      !(externalRun && serverState.isActive);

  /// Whether a stop request makes sense right now.
  bool get canStop =>
      phase == ServerPhase.starting || phase == ServerPhase.running;

  factory ServerDashboardState([
    void Function(ServerDashboardStateBuilder)? updates,
  ]) = _$ServerDashboardState;

  /// The state shown before the configuration has been loaded.
  factory ServerDashboardState.initial({
    ServerConfig? config,
    required ServerState serverState,
  }) => ServerDashboardState(
    (b) => b
      ..config.replace(config ?? ServerConfig.defaults())
      ..serverState.replace(serverState)
      ..metricsHistory = ListBuilder<ServerMetrics>()
      ..logs = ListBuilder<ServerLogEntry>()
      ..saving = false
      ..dirty = false
      ..testingConnection = false
      ..externalRun = false,
  );

  ServerDashboardState._();

  static Serializer<ServerDashboardState> get serializer =>
      _$serverDashboardStateSerializer;
}
