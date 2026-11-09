import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../tool/packaging/package_plan.dart';
import '../../../tool/packaging/package_target.dart';

void main() {
  group('versionFromPubspecText', () {
    test('reads a plain version', () {
      expect(
        versionFromPubspecText('name: llama_pulse\nversion: 1.2.3\n'),
        '1.2.3',
      );
    });

    test('drops the +build suffix', () {
      expect(
        versionFromPubspecText('name: llama_pulse\nversion: 0.1.0+1\n'),
        '0.1.0',
      );
    });

    test('keeps a prerelease but drops the build metadata', () {
      expect(versionFromPubspecText('version: 2.0.0-rc.1+42\n'), '2.0.0-rc.1');
    });

    test('ignores surrounding whitespace and quote-free lines', () {
      expect(versionFromPubspecText('  version:   3.4.5  \n'), '3.4.5');
    });

    test('rejects a missing version field', () {
      expect(
        () => versionFromPubspecText('name: llama_pulse\n'),
        throwsFormatException,
      );
    });

    test('rejects an empty version', () {
      expect(() => versionFromPubspecText('version:\n'), throwsFormatException);
    });

    test('rejects a malformed version', () {
      expect(
        () => versionFromPubspecText('version: not-a-version\n'),
        throwsFormatException,
      );
      expect(
        () => versionFromPubspecText('version: 1.2\n'),
        throwsFormatException,
      );
      expect(
        () => versionFromPubspecText('version: +1\n'),
        throwsFormatException,
      );
    });
  });

  group('stage names', () {
    test('reproduces the Linux name shipped today', () {
      expect(
        stageName('0.1.0', PackageTarget.linux, arch: 'x64'),
        'llama-pulse-0.1.0-linux-x64',
      );
    });

    test('uses the target artifact id on every platform', () {
      expect(
        stageName('0.1.0', PackageTarget.windows, arch: 'x64'),
        'llama-pulse-0.1.0-windows-x64',
      );
      expect(
        stageName('0.1.0', PackageTarget.macos, arch: 'arm64'),
        'llama-pulse-0.1.0-macos-arm64',
      );
      expect(
        stageName('0.1.0', PackageTarget.macos, arch: 'x64'),
        'llama-pulse-0.1.0-macos-x64',
      );
    });
  });

  group('archive names', () {
    test('match the stage name and archive kind', () {
      expect(
        archiveName('0.1.0', PackageTarget.linux, arch: 'x64'),
        'llama-pulse-0.1.0-linux-x64.tar.gz',
      );
      expect(
        archiveName('0.1.0', PackageTarget.windows, arch: 'x64'),
        'llama-pulse-0.1.0-windows-x64.zip',
      );
      expect(
        archiveName('0.1.0', PackageTarget.macos, arch: 'arm64'),
        'llama-pulse-0.1.0-macos-arm64.zip',
      );
    });
  });

  group('required entries', () {
    final stage = p.join('/tmp', 'stage');

    List<String> relative(String target, [RuntimeSelection? runtime]) {
      final entries = requiredEntries(
        PackageTarget.values.byName(target),
        stage,
        runtime: runtime,
      );
      return <String>[
        for (final entry in entries)
          entry.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), ''),
      ];
    }

    test('Linux', () {
      expect(relative('linux'), <String>[
        'llama_pulse',
        'lib',
        'data/flutter_assets',
        'README.md',
        'LICENSE',
      ]);
    });

    test('Windows', () {
      expect(relative('windows'), <String>[
        'llama_pulse.exe',
        'flutter_windows.dll',
        'data/icudtl.dat',
        'data/flutter_assets',
        'README.md',
        'LICENSE',
      ]);
    });

    test('macOS', () {
      expect(relative('macos'), <String>[
        'llama_pulse.app/Contents/MacOS/llama_pulse',
        'llama_pulse.app/Contents/Info.plist',
        'llama_pulse.app/Contents/Frameworks/FlutterMacOS.framework',
        'llama_pulse.app/Contents/Resources/flutter_assets',
        'README.md',
        'LICENSE',
      ]);
    });

    test('Linux adds the runtime directory, server and manifest', () {
      expect(relative('linux', (tag: 'v0.8.0', backend: 'cpu')), <String>[
        'llama_pulse',
        'lib',
        'data/flutter_assets',
        'README.md',
        'LICENSE',
        'runtime/v0.8.0/cpu',
        'runtime/v0.8.0/cpu/llama-server',
        'runtime/v0.8.0/cpu/runtime.yaml',
      ]);
    });

    test('Windows adds llama-server.exe', () {
      expect(
        relative('windows', (tag: 'v0.8.0', backend: 'cuda13')),
        contains('runtime/v0.8.0/cuda13/llama-server.exe'),
      );
    });

    test('macOS adds the runtime below Contents/Resources', () {
      expect(
        relative('macos', (tag: 'v0.8.0', backend: 'cpu')),
        containsAll(<String>[
          'llama_pulse.app/Contents/Resources/runtime/v0.8.0/cpu',
          'llama_pulse.app/Contents/Resources/runtime/v0.8.0/cpu/'
              'llama-server',
          'llama_pulse.app/Contents/Resources/runtime/v0.8.0/cpu/runtime.yaml',
        ]),
      );
    });
  });

  group('verifyLayout', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('llama_pulse_layout_');
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    Future<void> populate(
      PackageTarget target, {
      RuntimeSelection? runtime,
    }) async {
      for (final entry in requiredEntries(
        target,
        root.path,
        runtime: runtime,
      )) {
        final path = p.join(root.path, entry);
        final isDirectory =
            entry.endsWith('/') ||
            entry.endsWith(p.separator) ||
            entry.endsWith('FlutterMacOS.framework');
        if (isDirectory) {
          await Directory(path).create(recursive: true);
        } else {
          await File(path).create(recursive: true);
        }
      }
    }

    test('is empty for a complete Linux stage', () async {
      await populate(PackageTarget.linux);
      expect(verifyLayout(root.path, PackageTarget.linux), isEmpty);
    });

    test('is empty for a complete macOS stage with a runtime', () async {
      await populate(
        PackageTarget.macos,
        runtime: (tag: 'v0.8.0', backend: 'cpu'),
      );
      expect(
        verifyLayout(
          root.path,
          PackageTarget.macos,
          runtime: (tag: 'v0.8.0', backend: 'cpu'),
        ),
        isEmpty,
      );
    });

    test('reports a missing executable', () async {
      await populate(PackageTarget.windows);
      await File(p.join(root.path, 'llama_pulse.exe')).delete();
      expect(verifyLayout(root.path, PackageTarget.windows), <String>[
        p.join(root.path, 'llama_pulse.exe'),
      ]);
    });

    test('reports a missing runtime manifest', () async {
      await populate(
        PackageTarget.linux,
        runtime: (tag: 'v0.8.0', backend: 'cpu'),
      );
      final manifest = p.join(
        root.path,
        'runtime',
        'v0.8.0',
        'cpu',
        'runtime.yaml',
      );
      await File(manifest).delete();
      expect(
        verifyLayout(
          root.path,
          PackageTarget.linux,
          runtime: (tag: 'v0.8.0', backend: 'cpu'),
        ),
        <String>[manifest],
      );
    });
  });

  group('archFromAbi', () {
    test('maps the desktop ABIs', () {
      expect(archNameForAbi(Abi.linuxX64), 'x64');
      expect(archNameForAbi(Abi.windowsX64), 'x64');
      expect(archNameForAbi(Abi.macosX64), 'x64');
      expect(archNameForAbi(Abi.macosArm64), 'arm64');
      expect(archNameForAbi(Abi.linuxArm64), 'arm64');
      expect(archNameForAbi(Abi.linuxArm), 'arm');
      expect(archNameForAbi(Abi.linuxIA32), 'ia32');
      expect(archNameForAbi(Abi.linuxRiscv64), 'riscv64');
    });

    test('returns a known architecture for the current process', () {
      expect(
        archFromAbi(),
        isIn(<String>['x64', 'arm64', 'arm', 'ia32', 'riscv64']),
      );
    });
  });

  group('repoRootFromScript', () {
    test('walks three directories up from tool/', () {
      final repo = p.join(Directory.systemTemp.path, 'repo');
      final script = Uri.file(
        p.join(
          repo,
          'packages',
          'llama_pulse_core',
          'tool',
          'package_app.dart',
        ),
      );
      expect(repoRootFromScript(script), repo);
    });

    test('rejects non-file URIs', () {
      expect(
        () => repoRootFromScript(Uri.parse('https://example.com/tool.dart')),
        throwsArgumentError,
      );
    });
  });
}
