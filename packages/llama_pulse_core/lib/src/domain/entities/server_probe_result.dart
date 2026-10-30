/// Result of one HTTP probe against a running server.
///
/// Transient: a controller produces it on demand, it is never persisted and
/// never compared structurally.
final class ServerProbeResult {
  /// Creates a probe result.
  const ServerProbeResult({
    required this.ok,
    required this.latencyMs,
    required this.message,
  });

  /// Whether the server answered the probe successfully.
  final bool ok;

  /// Round-trip time of the probe in milliseconds.
  final int latencyMs;

  /// Human-readable summary shown by the CLI and the dashboard.
  final String message;
}
