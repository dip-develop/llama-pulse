import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../tool/packaging/package_plan.dart';
import '../../../tool/packaging/package_target.dart';
import '../../../tool/packaging/process_runner.dart';
import '../../../tool/packaging/staging.dart';

final class RecordedCall {
  RecordedCall(this.executable, this.arguments, this.workingDirectory);

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  @override
  String toString() => '$executable $arguments (cwd: $workingDirectory)';
}

final class RecordingRunner implements ProcessRunner {
  final List<RecordedCall> calls = <RecordedCall>[];
  int exitCode = 0;
  String stderr = '';

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async {
    calls.add(RecordedCall(executable, arguments, workingDirectory));
    return ProcessResult(0, exitCode, '', stderr);
  }

  Iterable<RecordedCall> named(String executable) =>
      calls.where((call) => call.executable == executable);
}

void main() {
  late Directory root;
  late String repoRoot;
  late RecordingRunner runner;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('llama_pulse_stage_');
    repoRoot = p.join(root.path, 'repo');
    await Directory(repoRoot).create(recursive: true);
    await File(p.join(repoRoot, 'README.md')).writeAsString('# LlamaPulse\n');
    await File(p.join(repoRoot, 'LICENSE')).writeAsString('MIT\n');
    runner = RecordingRunner();
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Future<String> bundle(PackageTarget target) async {
    final dir = await Directory(p.join(root.path, 'bundle', target.os))
        .create(recursive: true);
    if (target == PackageTarget.macos) {
      final app = await Directory(
        p.join(dir.path, 'llama_pulse.app', 'Contents'),
      ).create(recursive: true);
      await _file(p.join(app.path, 'MacOS', 'llama_pulse'), executable: true);
      await _file(p.join(app.path, 'Info.plist'), text: '<plist/>');
      await _file(
        p.join(
          app.path,
          'Frameworks',
          'FlutterMacOS.framework',
          'Versions',
          'A',
          'FlutterMacOS',
        ),
      );
      if (!Platform.isWindows) {
        final framework = p.join(
          app.path,
          'Frameworks',
          'FlutterMacOS.framework',
        );
        Link(p.join(framework, 'Versions', 'Current')).createSync('A');
        Link(p.join(framework, 'FlutterMacOS'))
            .createSync('Versions/Current/FlutterMacOS');
      }
      await _file(
        p.join(app.path, 'Resources', 'flutter_assets', 'AssetManifest.bin'),
      );
      return p.join(dir.path, 'llama_pulse.app');
    }
    if (target == PackageTarget.windows) {
      await _file(p.join(dir.path, 'llama_pulse.exe'), executable: true);
      await _file(p.join(dir.path, 'flutter_windows.dll'));
      await _file(p.join(dir.path, 'data', 'icudtl.dat'));
      await _file(
        p.join(dir.path, 'data', 'flutter_assets', 'AssetManifest.bin'),
      );
      await _file(p.join(dir.path, 'llama_pulse.pdb'));
      await _file(p.join(dir.path, 'llama_pulse.exp'));
      await _file(p.join(dir.path, 'llama_pulse.lib'));
    } else {
      await _file(p.join(dir.path, 'llama_pulse'), executable: true);
      await _file(p.join(dir.path, 'lib', 'libapp.so'));
      await _file(
        p.join(dir.path, 'data', 'flutter_assets', 'AssetManifest.bin'),
      );
    }
    return dir.path;
  }

  Future<String> configWithRuntime({
    String tag = 'v0.8.0',
    String backend = 'cpu',
    bool server = true,
    bool manifest = true,
    bool windows = false,
  }) async {
    final config = p.join(root.path, 'config');
    final dir = p.join(config, 'runtime', tag, backend);
    await Directory(dir).create(recursive: true);
    if (server) {
      await _file(
        p.join(dir, windows ? 'llama-server.exe' : 'llama-server'),
        executable: true,
      );
    }
    if (manifest) {
      await File(p.join(dir, 'runtime.yaml')).writeAsString('backend: cpu\n');
    }
    return config;
  }

  test(
    'stages a Linux bundle, preserves the executable bit and verifies',
    () async {
      final source = await bundle(PackageTarget.linux);
      final stageDir = p.join(root.path, 'dist', 'llama-pulse-0.1.0-linux-x64');

      final result = await stage(
        target: PackageTarget.linux,
        bundleDir: source,
        stageDir: stageDir,
        repoRoot: repoRoot,
        runner: runner,
        skipBuild: true,
        arch: 'x64',
      );

      expect(result.problems, isEmpty, reason: '${result.problems}');
      expect(File(p.join(stageDir, 'llama_pulse')).existsSync(), isTrue);
      expect(File(p.join(stageDir, 'README.md')).existsSync(), isTrue);
      expect(File(p.join(stageDir, 'LICENSE')).existsSync(), isTrue);
      if (!Platform.isWindows) {
        final mode = File(p.join(stageDir, 'llama_pulse')).statSync().mode;
        expect(mode & 0x49, isNot(0), reason: 'executable bit must survive');
      }
    },
  );

  test('stages a Windows bundle and drops build artefacts', () async {
    final source = await bundle(PackageTarget.windows);
    final stageDir = p.join(root.path, 'dist', 'llama-pulse-0.1.0-windows-x64');

    final result = await stage(
      target: PackageTarget.windows,
      bundleDir: source,
      stageDir: stageDir,
      repoRoot: repoRoot,
      runner: runner,
      skipBuild: true,
      arch: 'x64',
    );

    expect(result.problems, isEmpty, reason: '${result.problems}');
    expect(File(p.join(stageDir, 'llama_pulse.exe')).existsSync(), isTrue);
    for (final excluded in <String>[
      'llama_pulse.pdb',
      'llama_pulse.exp',
      'llama_pulse.lib',
    ]) {
      expect(
        File(p.join(stageDir, excluded)).existsSync(),
        isFalse,
        reason: '$excluded must not ship',
      );
    }
  });

  test(
    'stages the macOS app as one unit and keeps framework symlinks',
    () async {
      final source = await bundle(PackageTarget.macos);
      final stageDir = p.join(
        root.path,
        'dist',
        'llama-pulse-0.1.0-macos-arm64',
      );

      final result = await stage(
        target: PackageTarget.macos,
        bundleDir: source,
        stageDir: stageDir,
        repoRoot: repoRoot,
        runner: runner,
        skipBuild: true,
        arch: 'arm64',
      );

      expect(result.problems, isEmpty, reason: '${result.problems}');
      final app = p.join(stageDir, 'llama_pulse.app');
      expect(
        File(p.join(app, 'Contents', 'MacOS', 'llama_pulse')).existsSync(),
        isTrue,
      );
      expect(File(p.join(stageDir, 'README.md')).existsSync(), isTrue);
      expect(
        File(p.join(app, 'Contents', 'README.md')).existsSync(),
        isFalse,
        reason: 'README belongs beside the app, never inside Contents/',
      );
      if (!Platform.isWindows) {
        final link = p.join(
          app,
          'Contents',
          'Frameworks',
          'FlutterMacOS.framework',
          'FlutterMacOS',
        );
        expect(
          FileSystemEntity.typeSync(link, followLinks: false),
          FileSystemEntityType.link,
        );
        expect(Link(link).targetSync(), 'Versions/Current/FlutterMacOS');
      }
      expect(runner.named('codesign').single.arguments, <String>[
        '--force',
        '--deep',
        '--sign',
        '-',
        app,
      ]);
    },
  );

  test('places the runtime at the documented path on Linux', () async {
    final source = await bundle(PackageTarget.linux);
    final config = await configWithRuntime();
    final stageDir = p.join(root.path, 'dist', 'llama-pulse-0.1.0-linux-x64');

    final result = await stage(
      target: PackageTarget.linux,
      bundleDir: source,
      stageDir: stageDir,
      repoRoot: repoRoot,
      configDir: config,
      runtimeTag: 'v0.8.0',
      runtimeBackend: 'cpu',
      runner: runner,
      skipBuild: true,
      arch: 'x64',
    );

    expect(result.problems, isEmpty, reason: '${result.problems}');
    expect(
      File(p.join(stageDir, 'runtime', 'v0.8.0', 'cpu', 'llama-server'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(stageDir, 'runtime', 'v0.8.0', 'cpu', 'runtime.yaml'))
          .existsSync(),
      isTrue,
    );
  });

  test('places the runtime below Contents/Resources on macOS', () async {
    final source = await bundle(PackageTarget.macos);
    final config = await configWithRuntime(backend: 'metal');
    final stageDir = p.join(root.path, 'dist', 'llama-pulse-0.1.0-macos-arm64');

    final result = await stage(
      target: PackageTarget.macos,
      bundleDir: source,
      stageDir: stageDir,
      repoRoot: repoRoot,
      configDir: config,
      runtimeTag: 'v0.8.0',
      runtimeBackend: 'metal',
      runner: runner,
      skipBuild: true,
      arch: 'arm64',
    );

    expect(result.problems, isEmpty, reason: '${result.problems}');
    expect(
      File(
        p.join(
          stageDir,
          'llama_pulse.app',
          'Contents',
          'Resources',
          'runtime',
          'v0.8.0',
          'metal',
          'llama-server',
        ),
      ).existsSync(),
      isTrue,
    );
  });

  test('places llama-server.exe on Windows', () async {
    final source = await bundle(PackageTarget.windows);
    final config = await configWithRuntime(windows: true);
    final stageDir = p.join(root.path, 'dist', 'llama-pulse-0.1.0-windows-x64');

    final result = await stage(
      target: PackageTarget.windows,
      bundleDir: source,
      stageDir: stageDir,
      repoRoot: repoRoot,
      configDir: config,
      runtimeTag: 'v0.8.0',
      runtimeBackend: 'cpu',
      runner: runner,
      skipBuild: true,
      arch: 'x64',
    );

    expect(result.problems, isEmpty, reason: '${result.problems}');
    expect(
      File(p.join(stageDir, 'runtime', 'v0.8.0', 'cpu', 'llama-server.exe'))
          .existsSync(),
      isTrue,
    );
  });

  group('failure modes', () {
    test('missing bundle', () async {
      final result = await stage(
        target: PackageTarget.linux,
        bundleDir: p.join(root.path, 'missing'),
        stageDir: p.join(root.path, 'dist', 'stage'),
        repoRoot: repoRoot,
        runner: runner,
        skipBuild: true,
        arch: 'x64',
      );

      expect(result.isOk, isFalse);
      expect(result.problems.single, contains('no bundle at'));
    });

    test('missing server binary', () async {
      final config = await configWithRuntime(server: false);
      final result = await stage(
        target: PackageTarget.linux,
        bundleDir: p.join(root.path, 'unused'),
        stageDir: p.join(root.path, 'dist', 'stage'),
        repoRoot: repoRoot,
        configDir: config,
        runtimeTag: 'v0.8.0',
        runtimeBackend: 'cpu',
        runner: runner,
        skipBuild: true,
        arch: 'x64',
      );

      expect(result.problems.single, contains('no llama-server in'));
    });

    test('missing runtime.yaml', () async {
      final config = await configWithRuntime(manifest: false);
      final result = await stage(
        target: PackageTarget.linux,
        bundleDir: p.join(root.path, 'unused'),
        stageDir: p.join(root.path, 'dist', 'stage'),
        repoRoot: repoRoot,
        configDir: config,
        runtimeTag: 'v0.8.0',
        runtimeBackend: 'cpu',
        runner: runner,
        skipBuild: true,
        arch: 'x64',
      );

      expect(result.problems.single, contains('no runtime.yaml in'));
    });

    test('invalid tag containing ..', () async {
      final result = await stage(
        target: PackageTarget.linux,
        bundleDir: p.join(root.path, 'unused'),
        stageDir: p.join(root.path, 'dist', 'stage'),
        repoRoot: repoRoot,
        configDir: p.join(root.path, 'config'),
        runtimeTag: 'v0.8..0',
        runtimeBackend: 'cpu',
        runner: runner,
        skipBuild: true,
        arch: 'x64',
      );

      expect(result.problems, contains('invalid runtime tag: v0.8..0'));
    });

    test('unknown backend', () async {
      final result = await stage(
        target: PackageTarget.linux,
        bundleDir: p.join(root.path, 'unused'),
        stageDir: p.join(root.path, 'dist', 'stage'),
        repoRoot: repoRoot,
        configDir: p.join(root.path, 'config'),
        runtimeTag: 'v0.8.0',
        runtimeBackend: 'gpu',
        runner: runner,
        skipBuild: true,
        arch: 'x64',
      );

      expect(result.problems, contains('unknown runtime backend: gpu'));
    });

    test('metal on Windows', () async {
      final result = await stage(
        target: PackageTarget.windows,
        bundleDir: p.join(root.path, 'unused'),
        stageDir: p.join(root.path, 'dist', 'stage'),
        repoRoot: repoRoot,
        configDir: p.join(root.path, 'config'),
        runtimeTag: 'v0.8.0',
        runtimeBackend: 'metal',
        runner: runner,
        skipBuild: true,
        arch: 'x64',
      );

      expect(result.problems.single, contains('not published for windows-x64'));
      expect(result.problems.single, contains('cpu, cuda13, vulkan'));
    });

    test('cuda13 on macOS', () async {
      final result = await stage(
        target: PackageTarget.macos,
        bundleDir: p.join(root.path, 'unused'),
        stageDir: p.join(root.path, 'dist', 'stage'),
        repoRoot: repoRoot,
        configDir: p.join(root.path, 'config'),
        runtimeTag: 'v0.8.0',
        runtimeBackend: 'cuda13',
        runner: runner,
        skipBuild: true,
        arch: 'arm64',
      );

      expect(result.problems.single, contains('not published for macos-arm64'));
      expect(result.problems.single, contains('cpu, metal'));
    });

    test('--runtime with macos-x64', () async {
      final result = await stage(
        target: PackageTarget.macos,
        bundleDir: p.join(root.path, 'unused'),
        stageDir: p.join(root.path, 'dist', 'stage'),
        repoRoot: repoRoot,
        configDir: p.join(root.path, 'config'),
        runtimeTag: 'v0.8.0',
        runtimeBackend: 'cpu',
        runner: runner,
        skipBuild: true,
        arch: 'x64',
      );

      expect(result.problems.single, contains('not supported for macos-x64'));
    });
  });

  test('verifyLayout reports every entry that is deleted', () async {
    final source = await bundle(PackageTarget.linux);
    final stageDir = p.join(root.path, 'dist', 'llama-pulse-0.1.0-linux-x64');
    final entries = requiredEntries(PackageTarget.linux, stageDir);

    for (final entry in entries) {
      await stage(
        target: PackageTarget.linux,
        bundleDir: source,
        stageDir: stageDir,
        repoRoot: repoRoot,
        runner: runner,
        skipBuild: true,
        arch: 'x64',
      );
      final path = p.join(stageDir, entry.replaceFirst(RegExp(r'/$'), ''));
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else {
        await File(path).delete();
      }

      final problems = verifyLayout(stageDir, PackageTarget.linux);
      expect(
        problems,
        contains(path + (entry.endsWith('/') ? p.separator : '')),
        reason: 'deleting $entry must be reported',
      );
    }
  });

  test('runs the exact Flutter build command in apps/llama_pulse', () async {
    await bundle(PackageTarget.linux);

    await stage(
      target: PackageTarget.linux,
      bundleDir: p.join(root.path, 'bundle', 'linux'),
      stageDir: p.join(root.path, 'dist', 'llama-pulse-0.1.0-linux-x64'),
      repoRoot: repoRoot,
      runner: runner,
      arch: 'x64',
    );

    final build = runner.named(Platform.isWindows ? 'flutter.bat' : 'flutter');
    expect(build, hasLength(1));
    expect(build.single.arguments, <String>['build', 'linux', '--release']);
    expect(
      build.single.workingDirectory,
      p.join(repoRoot, 'apps', 'llama_pulse'),
    );
  });

  test('codesign only runs for macOS', () async {
    for (final target in <PackageTarget>[
      PackageTarget.linux,
      PackageTarget.windows,
    ]) {
      await bundle(target);
      await stage(
        target: target,
        bundleDir: p.join(root.path, 'bundle', target.os),
        stageDir: p.join(root.path, 'dist', 'stage-${target.os}'),
        repoRoot: repoRoot,
        runner: runner,
        skipBuild: true,
        arch: 'x64',
      );
    }

    expect(runner.named('codesign'), isEmpty);
  });
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
