import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/gateways/server_process.dart';

/// Starts supervised processes through `dart:io`.
final class DartProcessLauncher implements ServerProcessLauncher {
  /// Creates a launcher.
  const DartProcessLauncher();

  @override
  Future<ServerProcess> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
  }) async {
    if (executable.isEmpty) {
      throw ArgumentError.value(executable, 'executable', 'must not be empty');
    }
    final process = await Process.start(
      executable,
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: false,
    );
    return _DartServerProcess(process);
  }
}

final class _DartServerProcess implements ServerProcess {
  _DartServerProcess(this._process)
    : _stdoutLines = _lines(_process.stdout),
      _stderrLines = _lines(_process.stderr),
      _exitCode = _process.exitCode;

  static const int _maxLineLength = 8192;
  static final RegExp _ansi = RegExp(r'\x1B\[[0-9;]*[A-Za-z]');

  final Process _process;
  final Stream<String> _stdoutLines;
  final Stream<String> _stderrLines;
  final Future<int> _exitCode;

  @override
  int get pid => _process.pid;

  @override
  Stream<String> get stdoutLines => _stdoutLines;

  @override
  Stream<String> get stderrLines => _stderrLines;

  @override
  Future<int> get exitCode => _exitCode;

  @override
  bool kill(ServerKillMode mode) {
    try {
      if (Platform.isWindows) {
        return _process.kill();
      }
      return _process.kill(
        mode == ServerKillMode.force
            ? ProcessSignal.sigkill
            : ProcessSignal.sigterm,
      );
    } on ProcessException {
      return false;
    }
  }

  static Stream<String> _lines(Stream<List<int>> bytes) => bytes
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter())
      .map(_sanitize)
      .asBroadcastStream();

  static String _sanitize(String line) {
    final stripped = line.replaceAll(_ansi, '');
    if (stripped.length <= _maxLineLength) {
      return stripped;
    }
    return '${stripped.substring(0, _maxLineLength)}…[truncated]';
  }
}
