import 'dart:io';

/// Runs an external process.
///
/// Tests substitute a fake so the packaging planner can be exercised without
/// building anything.
abstract interface class ProcessRunner {
  /// Runs [executable] with [arguments] and waits for it to exit.
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  });
}

/// [ProcessRunner] backed by `dart:io`'s [Process.run].
final class SystemProcessRunner implements ProcessRunner {
  /// Creates a runner that spawns real processes.
  const SystemProcessRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) => Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
  );
}

/// Flutter launcher for the host, `flutter.bat` on Windows.
///
/// [isWindows] defaults to the current platform and is injectable for tests.
String flutterExecutable({bool? isWindows}) =>
    (isWindows ?? Platform.isWindows) ? 'flutter.bat' : 'flutter';
