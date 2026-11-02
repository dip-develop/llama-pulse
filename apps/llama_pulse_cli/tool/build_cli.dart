import 'dart:io';

/// Compiles the CLI to a native executable.
///
/// `dart compile exe` does not create its output directory, and `mkdir -p` is
/// not valid in PowerShell, so the directory is created here. That makes the
/// same `melos run build:cli` work from bash, zsh, cmd and PowerShell.
Future<void> main() async {
  final output = Platform.isWindows
      ? 'build/llamapulse.exe'
      : 'build/llamapulse';
  Directory('build').createSync(recursive: true);

  final process = await Process.start(Platform.resolvedExecutable, <String>[
    'compile',
    'exe',
    'bin/llamapulse.dart',
    '-o',
    output,
  ], mode: ProcessStartMode.inheritStdio);
  final code = await process.exitCode;
  if (code != 0) {
    exitCode = code;
  }
}
