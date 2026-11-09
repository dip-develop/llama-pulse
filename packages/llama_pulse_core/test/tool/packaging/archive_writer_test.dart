import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../tool/packaging/archive_writer.dart';
import '../../../tool/packaging/package_plan.dart';
import '../../../tool/packaging/package_target.dart';
import '../../../tool/packaging/process_runner.dart';

final class RecordedCall {
  RecordedCall(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;

  @override
  String toString() => '$executable $arguments';
}

final class ArchiveRunner implements ProcessRunner {
  ArchiveRunner({this.onRun});

  final List<RecordedCall> calls = <RecordedCall>[];
  final ProcessResult Function(String executable, List<String> arguments)?
  onRun;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async {
    calls.add(RecordedCall(executable, arguments));
    return onRun?.call(executable, arguments) ?? ProcessResult(0, 0, '', '');
  }
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('llama_pulse_archive_');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('writes and re-reads a Windows zip with one stage prefix', () async {
    const stageName = 'llama-pulse-0.1.0-windows-x64';
    final stage = p.join(root.path, stageName);
    await _windowsStage(stage);
    final archive = p.join(root.path, 'out', '$stageName.zip');
    final runner = ArchiveRunner();

    await writeArchive(
      target: PackageTarget.windows,
      stageDir: stage,
      archivePath: archive,
      runner: runner,
    );

    expect(File(archive).existsSync(), isTrue);
    final decoded = ZipDecoder().decodeBytes(File(archive).readAsBytesSync());
    final names = decoded.map((file) => file.name).toList();
    expect(names, isNotEmpty);
    for (final name in names) {
      expect(name, startsWith('$stageName/'));
    }
    expect(names, contains('$stageName/llama_pulse.exe'));
    expect(names, contains('$stageName/data/flutter_assets/AssetManifest.bin'));

    final problems = await verifyArchive(
      target: PackageTarget.windows,
      archivePath: archive,
      stageDir: stage,
      runner: runner,
    );
    expect(problems, isEmpty, reason: '$problems');
  });

  test('Linux writes with tar -C and verifies with tar -tzf', () async {
    const stageName = 'llama-pulse-0.1.0-linux-x64';
    final stage = p.join(root.path, stageName);
    await _linuxStage(stage);
    final archive = p.join(root.path, 'out', '$stageName.tar.gz');
    // The `tar -tzf` output is synthesised from `requiredEntries`, so this test
    // pins the verifier's name-prefix handling, not real tar output. The Linux
    // gate job runs the packager against a real bundle and so covers the gap.
    final listing = <String>[
      for (final entry in requiredEntries(PackageTarget.linux, stageName))
        '$stageName/$entry',
    ].join('\n');
    final runner = ArchiveRunner(
      onRun: (executable, arguments) {
        if (executable == 'tar' && arguments.first == '-tzf') {
          return ProcessResult(0, 0, '$listing\n', '');
        }
        return ProcessResult(0, 0, '', '');
      },
    );

    await writeArchive(
      target: PackageTarget.linux,
      stageDir: stage,
      archivePath: archive,
      runner: runner,
    );
    await File(archive).create(recursive: true);
    final problems = await verifyArchive(
      target: PackageTarget.linux,
      archivePath: archive,
      stageDir: stage,
      runner: runner,
    );

    expect(problems, isEmpty, reason: '$problems');
    expect(runner.calls, hasLength(2));
    expect(runner.calls[0].executable, 'tar');
    expect(runner.calls[0].arguments, <String>[
      '-C',
      p.dirname(archive),
      '-czf',
      archive,
      stageName,
    ]);
    expect(runner.calls[1].executable, 'tar');
    expect(runner.calls[1].arguments, <String>['-tzf', archive]);
  });

  test('macOS writes with ditto and verifies with ditto -x', () async {
    const stageName = 'llama-pulse-0.1.0-macos-arm64';
    final stage = p.join(root.path, stageName);
    await _macosStage(stage);
    final archive = p.join(root.path, 'out', '$stageName.zip');
    final runner = ArchiveRunner(
      onRun: (executable, arguments) {
        if (executable == 'ditto' && arguments.first == '-x') {
          _populateExtractedMacos(p.join(arguments.last, stageName));
        }
        return ProcessResult(0, 0, '', '');
      },
    );

    await writeArchive(
      target: PackageTarget.macos,
      stageDir: stage,
      archivePath: archive,
      runner: runner,
    );
    await File(archive).create(recursive: true);
    final problems = await verifyArchive(
      target: PackageTarget.macos,
      archivePath: archive,
      stageDir: stage,
      runner: runner,
    );

    expect(problems, isEmpty, reason: '$problems');
    expect(runner.calls[0].executable, 'ditto');
    expect(runner.calls[0].arguments, <String>[
      '-c',
      '-k',
      '--sequesterRsrc',
      '--keepParent',
      stage,
      archive,
    ]);
    expect(runner.calls[1].executable, 'ditto');
    expect(runner.calls[1].arguments.first, '-x');
    expect(runner.calls[1].arguments[1], '-k');
    expect(runner.calls[1].arguments[2], archive);
  });

  test(
    'writes and verifies a real macOS ditto archive',
    () async {
      const stageName = 'llama-pulse-0.1.0-macos-arm64';
      final stage = p.join(root.path, stageName);
      await _macosStage(stage);
      final app = p.join(stage, 'llama_pulse.app');
      final sign = Process.runSync('codesign', <String>[
        '--force',
        '--deep',
        '--sign',
        '-',
        app,
      ]);
      expect(sign.exitCode, 0, reason: '${sign.stderr}');
      final archive = p.join(root.path, 'out', '$stageName.zip');

      await writeArchive(
        target: PackageTarget.macos,
        stageDir: stage,
        archivePath: archive,
      );
      final problems = await verifyArchive(
        target: PackageTarget.macos,
        archivePath: archive,
        stageDir: stage,
      );

      expect(File(archive).existsSync(), isTrue);
      expect(problems, isEmpty, reason: '$problems');
    },
    skip: Platform.isMacOS
        ? false
        : 'ditto archives are only available on a macOS host',
  );
}

Future<void> _windowsStage(String stage) async {
  await _file(p.join(stage, 'llama_pulse.exe'), executable: true);
  await _file(p.join(stage, 'flutter_windows.dll'));
  await _file(p.join(stage, 'data', 'icudtl.dat'));
  await _file(p.join(stage, 'data', 'flutter_assets', 'AssetManifest.bin'));
  await _file(p.join(stage, 'README.md'), text: '# LlamaPulse\n');
  await _file(p.join(stage, 'LICENSE'), text: 'MIT\n');
}

Future<void> _linuxStage(String stage) async {
  await _file(p.join(stage, 'llama_pulse'), executable: true);
  await _file(p.join(stage, 'lib', 'libapp.so'));
  await _file(p.join(stage, 'data', 'flutter_assets', 'AssetManifest.bin'));
  await _file(p.join(stage, 'README.md'), text: '# LlamaPulse\n');
  await _file(p.join(stage, 'LICENSE'), text: 'MIT\n');
}

Future<void> _macosStage(String stage) async {
  final contents = p.join(stage, 'llama_pulse.app', 'Contents');
  await _file(p.join(contents, 'MacOS', 'llama_pulse'), executable: true);
  await _file(
    p.join(contents, 'Info.plist'),
    text: _bundlePlist(
      executable: 'llama_pulse',
      identifier: 'dev.llamapulse.desktop',
      packageType: 'APPL',
    ),
  );
  await _framework(contents, 'FlutterMacOS');
  await _framework(contents, 'App');
  await _file(
    p.join(
      contents,
      'Frameworks',
      'App.framework',
      'Versions',
      'A',
      'Resources',
      'flutter_assets',
      'AssetManifest.bin',
    ),
  );
  await _file(p.join(stage, 'README.md'), text: '# LlamaPulse\n');
  await _file(p.join(stage, 'LICENSE'), text: 'MIT\n');
}

/// Creates a versioned framework bundle, including the `Info.plist` that
/// `codesign` requires for a nested code object.
Future<void> _framework(String contents, String name) async {
  final framework = p.join(contents, 'Frameworks', '$name.framework');
  await _file(p.join(framework, 'Versions', 'A', name));
  await _file(
    p.join(framework, 'Versions', 'A', 'Resources', 'Info.plist'),
    text: _bundlePlist(
      executable: name,
      identifier: 'dev.llamapulse.desktop.$name',
      packageType: 'FMWK',
    ),
  );
  if (!Platform.isWindows) {
    Link(p.join(framework, 'Versions', 'Current')).createSync('A');
    Link(p.join(framework, name)).createSync('Versions/Current/$name');
    Link(p.join(framework, 'Resources'))
        .createSync('Versions/Current/Resources');
  }
}

String _bundlePlist({
  required String executable,
  required String identifier,
  required String packageType,
}) =>
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
    '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    '<plist version="1.0"><dict>'
    '<key>CFBundleExecutable</key><string>$executable</string>'
    '<key>CFBundleIdentifier</key><string>$identifier</string>'
    '<key>CFBundlePackageType</key><string>$packageType</string>'
    '</dict></plist>\n';

void _populateExtractedMacos(String stage) {
  final contents = p.join(stage, 'llama_pulse.app', 'Contents');
  _syncFile(p.join(contents, 'MacOS', 'llama_pulse'), executable: true);
  _syncFile(p.join(contents, 'Info.plist'), text: '<plist/>');
  Directory(p.join(contents, 'Frameworks', 'FlutterMacOS.framework'))
      .createSync(recursive: true);
  Directory(p.join(contents, 'Frameworks', 'App.framework', 'Resources'))
      .createSync(recursive: true);
  _syncFile(
    p.join(
      contents,
      'Frameworks',
      'App.framework',
      'Resources',
      'flutter_assets',
      'AssetManifest.bin',
    ),
  );
  _syncFile(p.join(stage, 'README.md'), text: '# LlamaPulse\n');
  _syncFile(p.join(stage, 'LICENSE'), text: 'MIT\n');
}

Future<void> _file(
  String path, {
  String text = '',
  bool executable = false,
}) async {
  final file = await File(path).create(recursive: true);
  await file.writeAsString(text);
  if (executable && !Platform.isWindows) {
    Process.runSync('chmod', <String>['755', path]);
  }
}

void _syncFile(String path, {String text = '', bool executable = false}) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
  if (executable && !Platform.isWindows) {
    Process.runSync('chmod', <String>['755', path]);
  }
}
