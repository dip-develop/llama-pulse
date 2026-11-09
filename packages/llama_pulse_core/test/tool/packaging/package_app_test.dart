import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../tool/package_app.dart';
import '../../../tool/packaging/process_runner.dart';

final class RecordingRunner implements ProcessRunner {
  final List<List<String>> invocations = <List<String>>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async {
    invocations.add(<String>[executable, ...arguments]);
    return ProcessResult(0, 0, '', '');
  }
}

Future<Directory> windowsBundle(String parent) async {
  final bundle = await Directory(p.join(parent, 'windows-bundle'))
      .create(recursive: true);
  Future<void> file(String path) async {
    await File(p.join(bundle.path, path)).create(recursive: true);
  }

  await file('llama_pulse.exe');
  await file('flutter_windows.dll');
  await file(p.join('data', 'icudtl.dat'));
  await file(p.join('data', 'flutter_assets', 'AssetManifest.bin'));
  return bundle;
}

Future<Directory> macosBundle(String parent) async {
  final app = await Directory(p.join(parent, 'llama_pulse.app', 'Contents'))
      .create(recursive: true);
  Future<void> file(String path) async {
    await File(p.join(app.path, path)).create(recursive: true);
  }

  await file(p.join('MacOS', 'llama_pulse'));
  await file('Info.plist');
  await file(
    p.join(
      'Frameworks',
      'FlutterMacOS.framework',
      'Versions',
      'A',
      'FlutterMacOS',
    ),
  );
  await file(
    p.join(
      'Frameworks',
      'App.framework',
      'Resources',
      'flutter_assets',
      'AssetManifest.bin',
    ),
  );
  return app.parent;
}

/// Repo root, found by walking up from the package test directory.
String repoRoot() {
  var directory = Directory.current;
  while (true) {
    if (File(p.join(directory.path, 'apps', 'llama_pulse', 'pubspec.yaml'))
        .existsSync()) {
      return directory.path;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('could not find the repository root');
    }
    directory = parent;
  }
}

void main() {
  late String root;

  setUpAll(() {
    root = repoRoot();
  });

  Future<int> run(
    List<String> arguments, {
    String hostArch = 'x64',
    required StringBuffer out,
    required StringBuffer err,
    ProcessRunner processRunner = const SystemProcessRunner(),
  }) => runPackageApp(
    arguments,
    out: out,
    err: err,
    repoRoot: root,
    hostArch: hostArch,
    processRunner: processRunner,
  );

  test('--help exits 0 and lists every flag', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await run(<String>['--help'], out: out, err: err);

    expect(code, 0);
    expect(err.toString(), isEmpty);
    final help = out.toString();
    for (final flag in <String>[
      '--os',
      '--runtime',
      '--config-dir',
      '--out',
      '--bundle',
      '--skip-build',
      '--check',
      '--help',
    ]) {
      expect(help, contains(flag), reason: 'help must list $flag');
    }
    expect(help, contains('Exit codes'));
  });

  test('unknown flag exits 2 with a usage error', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await run(<String>['--nope'], out: out, err: err);

    expect(code, 2);
    expect(err.toString(), contains('--nope'));
    expect(err.toString(), contains('usage:'));
  });

  test('missing --runtime value exits 2', () async {
    for (final arguments in <List<String>>[
      <String>['--runtime'],
      <String>['--runtime', 'v0.8.0'],
    ]) {
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await run(arguments, out: out, err: err);

      expect(code, 2, reason: '$arguments');
      expect(
        err.toString(),
        contains('--runtime needs a tag and a backend'),
        reason: '$arguments',
      );
    }
  });

  test('--skip-build with a missing bundle exits 1 without writing', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final missing = p.join(
      Directory.systemTemp.path,
      'llama-pulse-missing-$pid-${DateTime.now().microsecondsSinceEpoch}',
    );
    final outDir = p.join(missing, 'dist');

    final code = await run(
      <String>[
        '--os',
        'windows',
        '--skip-build',
        '--bundle',
        missing,
        '--out',
        outDir,
      ],
      out: out,
      err: err,
    );

    expect(code, 1);
    expect(err.toString(), contains('no bundle at $missing'));
    expect(Directory(missing).existsSync(), isFalse);
    expect(Directory(outDir).existsSync(), isFalse);
  });

  test('--runtime is refused for macos-x64 with a clear message', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await run(
      <String>[
        '--os',
        'macos',
        '--runtime',
        'v0.8.0',
        'cpu',
        '--skip-build',
        '--bundle',
        p.join(Directory.systemTemp.path, 'missing-bundle'),
      ],
      hostArch: 'x64',
      out: out,
      err: err,
    );

    expect(code, 2);
    expect(err.toString(), contains('macos-x64'));
    expect(err.toString(), contains('not supported'));
    expect(err.toString(), contains('macos-arm64'));
  });

  test('--runtime is refused for linux-arm64 with a clear message', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await run(
      <String>[
        '--os',
        'linux',
        '--runtime',
        'v0.8.0',
        'cpu',
        '--skip-build',
        '--bundle',
        p.join(Directory.systemTemp.path, 'missing-bundle'),
      ],
      hostArch: 'arm64',
      out: out,
      err: err,
    );

    expect(code, 2);
    expect(err.toString(), contains('linux-arm64'));
    expect(err.toString(), contains('not supported'));
  });

  test('--check stages, verifies and writes no archive', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'llama_pulse_check_',
    );
    addTearDown(() async {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    });
    final bundle = await windowsBundle(workspace.path);
    final outDir = p.join(workspace.path, 'dist');
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await run(
      <String>[
        '--os',
        'windows',
        '--skip-build',
        '--bundle',
        bundle.path,
        '--out',
        outDir,
        '--check',
      ],
      out: out,
      err: err,
    );

    expect(code, 0, reason: err.toString());
    final plan = out.toString();
    expect(plan, contains('windows-x64'));
    expect(plan, contains('llama-pulse-0.1.0-windows-x64'));
    expect(plan, contains('llama-pulse-0.1.0-windows-x64.zip'));
    expect(plan, contains('skipped (--skip-build)'));
    expect(plan, contains('checked'));
    expect(plan, contains('no archive written'));
    expect(Directory(outDir).existsSync(), isFalse);
  });

  test('a non-check run writes and verifies the Windows archive', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'llama_pulse_archive_',
    );
    addTearDown(() async {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    });
    final bundle = await windowsBundle(workspace.path);
    final outDir = p.join(workspace.path, 'dist');
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await run(
      <String>[
        '--os',
        'windows',
        '--skip-build',
        '--bundle',
        bundle.path,
        '--out',
        outDir,
      ],
      out: out,
      err: err,
    );

    expect(code, 0, reason: err.toString());
    final archive = p.join(outDir, 'llama-pulse-0.1.0-windows-x64.zip');
    expect(File(archive).existsSync(), isTrue);
    expect(out.toString(), contains('created $archive'));
    expect(out.toString(), contains('verified'));
    expect(out.toString(), contains('run:'));
  });

  test('--check reports layout problems and exits 1', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'llama_pulse_layout_',
    );
    addTearDown(() async {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    });
    final empty = await Directory(p.join(workspace.path, 'empty'))
        .create(recursive: true);
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await run(
      <String>[
        '--os',
        'windows',
        '--skip-build',
        '--bundle',
        empty.path,
        '--out',
        p.join(workspace.path, 'dist'),
        '--check',
      ],
      out: out,
      err: err,
    );

    expect(code, 1);
    expect(err.toString(), contains('layout problem'));
  });

  test('runs the Flutter build when --skip-build is absent', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'llama_pulse_build_',
    );
    addTearDown(() async {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    });
    final bundle = await macosBundle(workspace.path);
    final runner = RecordingRunner();
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await run(
      <String>[
        '--os',
        'macos',
        '--bundle',
        bundle.path,
        '--out',
        p.join(workspace.path, 'dist'),
        '--check',
      ],
      hostArch: 'arm64',
      out: out,
      err: err,
      processRunner: runner,
    );

    expect(code, 0, reason: err.toString());
    expect(
      runner.invocations.any(
        (invocation) => invocation.join(' ') == 'flutter build macos --release',
      ),
      isTrue,
      reason: '${runner.invocations}',
    );
    expect(out.toString(), contains('flutter'));
    expect(out.toString(), contains('build macos --release'));
    expect(out.toString(), contains('macos-arm64'));
  });
}
