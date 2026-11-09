import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'package_plan.dart';
import 'package_target.dart';
import 'process_runner.dart';

/// Thrown when writing or verifying an archive fails for an environmental
/// reason, for example a missing `tar` or a non-zero exit.
final class ArchiveException implements Exception {
  /// Creates an exception with a human-readable [message].
  const ArchiveException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// Writes [stageDir] to [archivePath] in the format [target] ships.
///
/// Linux uses the system `tar`, which preserves the executable bit. Windows
/// builds a ZIP in Dart; modes and symlinks do not exist there. macOS uses
/// `ditto`, which keeps the framework symlinks inside the `.app` intact and
/// adds the resource forks a naive Dart ZIP would drop.
Future<void> writeArchive({
  required PackageTarget target,
  required String stageDir,
  required String archivePath,
  ProcessRunner runner = const SystemProcessRunner(),
}) async {
  if (!Directory(stageDir).existsSync()) {
    throw ArchiveException('no stage directory at $stageDir');
  }
  Directory(p.dirname(archivePath)).createSync(recursive: true);
  final stageName = p.basename(stageDir);

  switch (target) {
    case PackageTarget.linux:
      await _runChecked(runner, 'tar', <String>[
        '-C',
        p.dirname(archivePath),
        '-czf',
        archivePath,
        stageName,
      ], 'tar');
    case PackageTarget.windows:
      _writeZip(stageDir, stageName, archivePath);
    case PackageTarget.macos:
      await _runChecked(runner, 'ditto', <String>[
        '-c',
        '-k',
        '--sequesterRsrc',
        '--keepParent',
        stageDir,
        archivePath,
      ], 'ditto');
  }
}

/// Checks a written archive against [stageDir]'s step-5 layout.
///
/// Returns one problem per missing or misplaced entry, or an empty list when
/// the archive looks complete. Problems are returned, not thrown, so the caller
/// can print every one of them.
///
/// Linux inspects `tar -tzf`; Windows re-opens the ZIP and checks every entry;
/// macOS extracts with `ditto` into a temporary directory, checks the
/// executable bit and verifies the ad-hoc signature. The last two checks only
/// run on a macOS host, where `ditto` and `codesign` are available.
Future<List<String>> verifyArchive({
  required PackageTarget target,
  required String archivePath,
  required String stageDir,
  RuntimeSelection? runtime,
  ProcessRunner runner = const SystemProcessRunner(),
}) async {
  if (!File(archivePath).existsSync()) {
    return <String>['no archive at $archivePath'];
  }
  final stageName = p.basename(stageDir);
  switch (target) {
    case PackageTarget.linux:
      return _verifyTar(
        archivePath: archivePath,
        stageName: stageName,
        target: target,
        runtime: runtime,
        runner: runner,
      );
    case PackageTarget.windows:
      return _verifyZip(
        archivePath: archivePath,
        stageName: stageName,
        target: target,
        runtime: runtime,
      );
    case PackageTarget.macos:
      return _verifyDitto(
        archivePath: archivePath,
        stageDir: stageDir,
        stageName: stageName,
        target: target,
        runtime: runtime,
        runner: runner,
      );
  }
}

Future<List<String>> _verifyTar({
  required String archivePath,
  required String stageName,
  required PackageTarget target,
  required RuntimeSelection? runtime,
  required ProcessRunner runner,
}) async {
  final result = await runner.run('tar', <String>['-tzf', archivePath]);
  if (result.exitCode != 0) {
    return <String>[
      'tar -tzf $archivePath failed with exit ${result.exitCode}: '
          '${result.stderr}',
    ];
  }
  final names = _lines(result.stdout);
  return _checkNames(
    names,
    stageName: stageName,
    target: target,
    runtime: runtime,
  );
}

List<String> _verifyZip({
  required String archivePath,
  required String stageName,
  required PackageTarget target,
  required RuntimeSelection? runtime,
}) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(File(archivePath).readAsBytesSync());
  } on Object catch (error) {
    return <String>['cannot read $archivePath as a zip: $error'];
  }
  final names = <String>[for (final file in archive) file.name];
  return _checkNames(
    names,
    stageName: stageName,
    target: target,
    runtime: runtime,
  );
}

Future<List<String>> _verifyDitto({
  required String archivePath,
  required String stageDir,
  required String stageName,
  required PackageTarget target,
  required RuntimeSelection? runtime,
  required ProcessRunner runner,
}) async {
  final temp = await Directory.systemTemp.createTemp('llama-pulse-verify-');
  try {
    final result = await runner.run('ditto', <String>[
      '-x',
      '-k',
      archivePath,
      temp.path,
    ]);
    if (result.exitCode != 0) {
      return <String>[
        'ditto -x -k $archivePath failed with exit ${result.exitCode}: '
            '${result.stderr}',
      ];
    }
    if (!Platform.isMacOS) {
      return const <String>[];
    }
    final extracted = p.join(temp.path, stageName);
    final problems = verifyLayout(extracted, target, runtime: runtime);
    final executable = File(
      p.join(extracted, 'llama_pulse.app', 'Contents', 'MacOS', 'llama_pulse'),
    );
    if (executable.existsSync() && !_isExecutable(executable.statSync().mode)) {
      problems.add(
        '$extracted/llama_pulse.app/Contents/MacOS/llama_pulse '
        'is not executable',
      );
    }
    final codesign = await runner.run('codesign', <String>[
      '--verify',
      '--deep',
      '--strict',
      p.join(extracted, 'llama_pulse.app'),
    ]);
    if (codesign.exitCode != 0) {
      problems.add('codesign --verify failed: ${codesign.stderr}');
    }
    return problems;
  } finally {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  }
}

List<String> _checkNames(
  List<String> names, {
  required String stageName,
  required PackageTarget target,
  required RuntimeSelection? runtime,
}) {
  final problems = <String>[];
  final prefix = '$stageName/';
  for (final name in names) {
    if (!name.startsWith(prefix)) {
      problems.add('archive entry outside $prefix: $name');
    }
  }
  for (final entry in requiredEntries(target, stageName, runtime: runtime)) {
    final normalized = entry.replaceAll(r'\', '/');
    if (normalized.endsWith('/')) {
      final directoryPrefix = '$stageName/$normalized';
      if (!names.any((name) => name.startsWith(directoryPrefix))) {
        problems.add('archive is missing $directoryPrefix');
      }
    } else {
      final expected = '$stageName/$normalized';
      if (!names.contains(expected)) {
        problems.add('archive is missing $expected');
      }
    }
  }
  return problems;
}

bool _isExecutable(int mode) => (mode & 0x49) != 0;

List<String> _lines(Object? output) => output
    .toString()
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

void _writeZip(String stageDir, String stageName, String archivePath) {
  final archive = Archive();
  final root = Directory(stageDir);
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final relative = p
        .relative(entity.path, from: stageDir)
        .replaceAll(r'\', '/');
    final bytes = entity.readAsBytesSync();
    archive.addFile(ArchiveFile.bytes('$stageName/$relative', bytes));
  }
  File(archivePath).writeAsBytesSync(ZipEncoder().encodeBytes(archive));
}

Future<void> _runChecked(
  ProcessRunner runner,
  String executable,
  List<String> arguments,
  String label,
) async {
  final result = await runner.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ArchiveException(
      '$label failed with exit ${result.exitCode}: ${result.stderr}',
    );
  }
}
