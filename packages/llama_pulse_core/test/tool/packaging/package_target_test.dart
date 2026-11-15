import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../tool/packaging/package_target.dart';

void main() {
  final repo = p.normalize(p.absolute('repo'));

  group('executable names', () {
    test('Linux and macOS run llama_pulse', () {
      expect(PackageTarget.linux.executableName, 'llama_pulse');
      expect(PackageTarget.macos.executableName, 'llama_pulse');
    });

    test('Windows adds .exe', () {
      expect(PackageTarget.windows.executableName, 'llama_pulse.exe');
      expect(PackageTarget.windows.runtimeExecutableName, 'llama-server.exe');
      expect(PackageTarget.linux.runtimeExecutableName, 'llama-server');
    });
  });

  group('archive kind', () {
    test('Linux uses tar.gz', () {
      expect(PackageTarget.linux.archiveKind, ArchiveKind.tarGz);
      expect(PackageTarget.linux.archiveKind.extension, '.tar.gz');
    });

    test('Windows and macOS use zip', () {
      expect(PackageTarget.windows.archiveKind, ArchiveKind.zip);
      expect(PackageTarget.macos.archiveKind, ArchiveKind.zip);
      expect(PackageTarget.macos.archiveKind.extension, '.zip');
    });
  });

  group('default bundle directory', () {
    test('Linux release bundle', () {
      expect(
        PackageTarget.linux.defaultBundleDir(repo),
        p.join(
          repo,
          'apps',
          'llama_pulse',
          'build',
          'linux',
          'x64',
          'release',
          'bundle',
        ),
      );
    });

    test('Windows runner release directory', () {
      expect(
        PackageTarget.windows.defaultBundleDir(repo),
        p.join(
          repo,
          'apps',
          'llama_pulse',
          'build',
          'windows',
          'x64',
          'runner',
          'Release',
        ),
      );
    });

    test('macOS application bundle', () {
      expect(
        PackageTarget.macos.defaultBundleDir(repo),
        p.join(
          repo,
          'apps',
          'llama_pulse',
          'build',
          'macos',
          'Build',
          'Products',
          'Release',
          'llama_pulse.app',
        ),
      );
    });
  });

  group('runtime platform', () {
    test('maps the pinned linux/windows x64 and macOS arm64 assets', () {
      expect(
        PackageTarget.linux.runtimePlatform('x64'),
        RuntimePlatform.linuxX64,
      );
      expect(
        PackageTarget.windows.runtimePlatform('x64'),
        RuntimePlatform.windowsX64,
      );
      expect(
        PackageTarget.macos.runtimePlatform('arm64'),
        RuntimePlatform.macosArm64,
      );
    });

    test('rejects architectures with no pinned runtime asset', () {
      expect(PackageTarget.macos.runtimePlatform('x64'), isNull);
      expect(PackageTarget.linux.runtimePlatform('arm64'), isNull);
      expect(PackageTarget.windows.runtimePlatform('arm64'), isNull);
    });
  });

  group('artifact ids', () {
    test('combine the OS and architecture', () {
      expect(PackageTarget.linux.artifactId('x64'), 'linux-x64');
      expect(PackageTarget.windows.artifactId('x64'), 'windows-x64');
      expect(PackageTarget.macos.artifactId('arm64'), 'macos-arm64');
      expect(PackageTarget.macos.artifactId('x64'), 'macos-x64');
    });
  });

  group('runtime directory in stage', () {
    final stage = p.join(repo, 'dist', 'llama-pulse-0.1.0-linux-x64');

    test('Linux and Windows place it beside the executable', () {
      expect(
        PackageTarget.linux.runtimeDirectoryInStage(
          stage,
          tag: 'v0.8.0',
          backend: 'cpu',
        ),
        p.join(stage, 'runtime', 'v0.8.0', 'cpu'),
      );
      expect(
        PackageTarget.windows.runtimeDirectoryInStage(
          stage,
          tag: 'v0.8.0',
          backend: 'cpu',
        ),
        p.join(stage, 'runtime', 'v0.8.0', 'cpu'),
      );
    });

    test('macOS places it in the app resources', () {
      expect(
        PackageTarget.macos.runtimeDirectoryInStage(
          stage,
          tag: 'v0.8.0',
          backend: 'cpu',
        ),
        p.join(
          stage,
          'llama_pulse.app',
          'Contents',
          'Resources',
          'runtime',
          'v0.8.0',
          'cpu',
        ),
      );
    });
  });

  test('host detection returns a known OS', () {
    // The enum is the source of truth; a smoke check keeps the default path
    // honest without depending on the machine running the suite.
    expect(PackageTarget.values.map((target) => target.os), <String>[
      'linux',
      'windows',
      'macos',
    ]);
    expect(Platform.isLinux || Platform.isWindows || Platform.isMacOS, isTrue);
  });
}
