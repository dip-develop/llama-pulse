import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../tool/package_app.dart';

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
  }) => runPackageApp(
    arguments,
    out: out,
    err: err,
    repoRoot: root,
    hostArch: hostArch,
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

  test('prints a plan for an existing bundle without writing', () async {
    final bundle = await Directory.systemTemp.createTemp('llama_pulse_bundle_');
    addTearDown(() async {
      if (await bundle.exists()) {
        await bundle.delete(recursive: true);
      }
    });
    final outDir = p.join(
      Directory.systemTemp.path,
      'llama-pulse-out-$pid-${DateTime.now().microsecondsSinceEpoch}',
    );
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
    expect(Directory(outDir).existsSync(), isFalse);
  });

  test('plans a Flutter build when --skip-build is absent', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await run(
      <String>[
        '--os',
        'macos',
        '--bundle',
        p.join(Directory.systemTemp.path, 'not-there-yet'),
      ],
      hostArch: 'arm64',
      out: out,
      err: err,
    );

    expect(code, 0, reason: err.toString());
    expect(out.toString(), contains('flutter'));
    expect(out.toString(), contains('build macos --release'));
    expect(out.toString(), contains('macos-arm64'));
  });
}
