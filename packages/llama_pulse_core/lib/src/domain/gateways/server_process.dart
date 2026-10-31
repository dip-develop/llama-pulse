/// How a supervised process is asked to stop.
///
/// Transient control flow only: it is never persisted, so it stays a plain
/// `enum` rather than an `EnumClass`.
enum ServerKillMode {
  /// Ask the process to exit and clean up (`SIGTERM`).
  graceful,

  /// Terminate the process immediately (`SIGKILL`).
  force,
}

/// A running supervised process.
///
/// Test seam: the supervisor can be driven against a fake process without
/// spawning a real executable.
abstract interface class ServerProcess {
  /// Operating-system process id.
  int get pid;

  /// Standard output split into lines, with ANSI escapes removed.
  Stream<String> get stdoutLines;

  /// Standard error split into lines, with ANSI escapes removed.
  Stream<String> get stderrLines;

  /// Exit code, completed once the process is gone.
  Future<int> get exitCode;

  /// Sends the terminate signal for [mode]; false when the process is gone.
  bool kill(ServerKillMode mode);
}

/// Starts supervised processes.
///
/// Test seam: substitutes process creation so lifecycle tests need no binary.
abstract interface class ServerProcessLauncher {
  /// Starts [executable] with [arguments] as an argument vector, no shell.
  Future<ServerProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
  });
}
