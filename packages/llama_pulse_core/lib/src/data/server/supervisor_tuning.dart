/// Timings used by the server supervisor and the stub controller.
///
/// Every value is injectable so tests can run with millisecond intervals and
/// never wait for the production defaults. The defaults target a responsive
/// dashboard without hammering a loading `llama-server`.
final class SupervisorTuning {
  /// Creates a tuning set.
  const SupervisorTuning({
    this.healthPollInterval = const Duration(milliseconds: 500),
    this.shutdownGrace = const Duration(seconds: 5),
    this.stopPollInterval = const Duration(milliseconds: 200),
    this.monitorInterval = const Duration(seconds: 1),
    this.httpTimeout = const Duration(seconds: 3),
    this.maxLogTail = 50,
  });

  /// Delay between two readiness probes while the server loads its model.
  final Duration healthPollInterval;

  /// How long a graceful stop may take before the supervisor forces the kill.
  final Duration shutdownGrace;

  /// Delay between exit checks while a stop is in progress.
  final Duration stopPollInterval;

  /// Delay between synthetic metric and log samples in the stub controller.
  final Duration monitorInterval;

  /// Timeout applied to every supervisor HTTP request.
  final Duration httpTimeout;

  /// Maximum number of log lines copied into a failure's details.
  final int maxLogTail;
}
