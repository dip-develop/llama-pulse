import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Commands accepted by the server dashboard bloc.
///
/// Deliberately a sealed hierarchy rather than `built_value`: events are
/// transient commands that never cross the isolate boundary and are never
/// persisted or compared structurally, so they stay immutable plain classes.
sealed class ServerEvent {
  const ServerEvent();
}

/// Loads the stored configuration and starts watching the controller.
final class ServerDashboardStarted extends ServerEvent {
  const ServerDashboardStarted();
}

/// The user edited the server configuration; nothing is persisted yet.
final class ServerConfigChanged extends ServerEvent {
  const ServerConfigChanged(this.config);

  /// New configuration.
  final ServerConfig config;
}

/// Persists the current configuration.
final class ServerSaveRequested extends ServerEvent {
  const ServerSaveRequested();
}

/// Discards unsaved edits and reads the stored configuration again.
final class ServerReloadRequested extends ServerEvent {
  const ServerReloadRequested();
}

/// Starts the supervised server with the current configuration.
final class ServerStartRequested extends ServerEvent {
  const ServerStartRequested();
}

/// Stops the supervised server, if one runs.
final class ServerStopRequested extends ServerEvent {
  const ServerStopRequested();
}

/// Probes the server described by the current configuration.
final class ServerTestConnectionRequested extends ServerEvent {
  const ServerTestConnectionRequested();
}

/// Removes the log lines held in the dashboard state.
final class ServerLogsCleared extends ServerEvent {
  const ServerLogsCleared();
}

/// Internal plumbing: the controller finished a start request.
///
/// The request itself is not awaited, so the dashboard keeps processing live
/// events while the process spawns; the outcome arrives as this event.
final class ServerStartCompleted extends ServerEvent {
  const ServerStartCompleted({this.failure});

  /// Why the start failed, or `null` when the process was spawned.
  final ServerFailure? failure;
}

/// Internal plumbing: the controller finished a stop request.
final class ServerStopCompleted extends ServerEvent {
  const ServerStopCompleted({this.failure});

  /// Why the stop failed, or `null` when the process is gone.
  final ServerFailure? failure;
}

/// Internal plumbing: a lifecycle state published by the controller.
///
/// It is part of the sealed hierarchy so the bloc can emit states from an
/// event handler, which is the only place `bloc` allows emissions. UI code
/// never adds it.
final class ServerControllerStateReceived extends ServerEvent {
  const ServerControllerStateReceived(this.state);

  /// State published by [ServerController.states].
  final ServerState state;
}

/// Internal plumbing: one metrics sample published by the controller.
final class ServerControllerMetricsReceived extends ServerEvent {
  const ServerControllerMetricsReceived(this.metrics);

  /// Sample published by [ServerController.metrics].
  final ServerMetrics metrics;
}

/// Internal plumbing: one log line published by the controller.
final class ServerControllerLogReceived extends ServerEvent {
  const ServerControllerLogReceived(this.entry);

  /// Line published by [ServerController.logs].
  final ServerLogEntry entry;
}

/// Internal plumbing: one of the controller's streams ended.
final class ServerControllerStreamEnded extends ServerEvent {
  const ServerControllerStreamEnded(this.error);

  /// Error that broke the stream, or `null` for a clean close.
  final Object? error;
}
