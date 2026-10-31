import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/gateways/process_executor.dart';

/// Runs short-lived helper processes through `dart:io`.
///
/// `Process.run` offers no handle to kill, so the process is started
/// explicitly and its pipes are captured here.
final class DartProcessExecutor implements ProcessExecutor {
  /// Creates an executor.
  const DartProcessExecutor();

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    Process? process;
    try {
      process = await Process.start(executable, arguments, runInShell: false);
      final stdout = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      final stderr = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      final exitCode = await process.exitCode.timeout(timeout);
      return ProcessOutput(
        exitCode: exitCode,
        stdout: await stdout,
        stderr: await stderr,
      );
    } on TimeoutException {
      _kill(process);
      return ProcessOutput(
        exitCode: -1,
        stdout: '',
        stderr: 'timed out after ${timeout.inSeconds}s',
      );
    } on ProcessException catch (error) {
      return ProcessOutput(exitCode: -1, stdout: '', stderr: error.message);
    } on Object catch (error) {
      return ProcessOutput(exitCode: -1, stdout: '', stderr: '$error');
    }
  }

  static void _kill(Process? process) {
    if (process == null) {
      return;
    }
    try {
      if (Platform.isWindows) {
        process.kill();
      } else {
        process.kill(ProcessSignal.sigkill);
      }
    } on ProcessException {
      // The process is already gone.
    }
  }
}
