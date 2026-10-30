/// Result of running a short-lived helper process to completion.
final class ProcessOutput {
  /// Creates the captured output of a finished process.
  const ProcessOutput({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// Exit code, or `-1` when the process failed or timed out.
  final int exitCode;

  /// Captured standard output.
  final String stdout;

  /// Captured standard error, or the failure reason.
  final String stderr;

  /// Whether the process exited successfully.
  bool get ok => exitCode == 0;
}

/// Runs a short-lived helper process and captures its output.
///
/// Test seam: version probing runs against canned output in tests.
abstract interface class ProcessExecutor {
  /// Runs [executable] with [arguments] and never throws.
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 5),
  });
}
