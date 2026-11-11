import 'dart:io';

import 'package:llama_pulse_core/src/data/runtime/bundled_runtimes.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory executableDirectory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('llama_pulse_bundle_');
    executableDirectory = Directory(p.join(root.path, 'app'));
    await executableDirectory.create(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Future<String> directory(String relative) async {
    final created = Directory(
      p.join(executableDirectory.path, 'runtime', relative),
    );
    await created.create(recursive: true);
    return p.normalize(created.path);
  }

  test('returns an empty list when the bundle has no runtime directory', () {
    expect(BundledRuntimes.directories(executableDirectory.path), isEmpty);
  });

  test('lists every tag and backend directory, reverse path order', () async {
    final cuda = await directory(p.join('v0.8.0', 'cuda13'));
    final cpu = await directory(p.join('v0.8.0', 'cpu'));
    final older = await directory(p.join('v0.7.0', 'cpu'));

    expect(BundledRuntimes.directories(executableDirectory.path), [
      cuda,
      cpu,
      older,
    ]);
  });

  test('ignores files beside the runtime directories', () async {
    final cpu = await directory(p.join('v0.8.0', 'cpu'));
    await File(p.join(executableDirectory.path, 'runtime', 'README.md'))
        .writeAsString('not a runtime');
    await File(p.join(cpu, 'llama-server')).writeAsString('binary');

    expect(BundledRuntimes.directories(executableDirectory.path), [cpu]);
  });

  test('rootFor points at <exeDir>/runtime', () {
    expect(
      BundledRuntimes.rootFor('/opt/llama-pulse'),
      p.join('/opt/llama-pulse', 'runtime'),
    );
  });

  group('macOS bundle', () {
    late Directory executableDirectory;

    Future<String> resources(String relative) async {
      final created = Directory(
        p.join(
          root.path,
          'X.app',
          'Contents',
          'Resources',
          'runtime',
          relative,
        ),
      );
      await created.create(recursive: true);
      return p.normalize(created.path);
    }

    setUp(() async {
      executableDirectory = Directory(
        p.join(root.path, 'X.app', 'Contents', 'MacOS'),
      );
      await executableDirectory.create(recursive: true);
    });

    test('resources root points at Contents/Resources/runtime', () {
      expect(
        BundledRuntimes.macOsResourcesRootFor(executableDirectory.path),
        p.normalize(
          p.join(root.path, 'X.app', 'Contents', 'Resources', 'runtime'),
        ),
      );
    });

    test('lists Contents/Resources only when asked for a bundle', () async {
      final metal = await resources(p.join('v0.8.0', 'metal'));
      await File(p.join(metal, 'libllama.dylib')).writeAsString('');

      expect(BundledRuntimes.directories(executableDirectory.path), isEmpty);
      expect(
        BundledRuntimes.directories(
          executableDirectory.path,
          macOsBundle: true,
        ),
        [metal],
      );
    });

    test('Resources wins over MacOS when both carry a runtime', () async {
      final fromMacOs = Directory(
        p.join(executableDirectory.path, 'runtime', 'v0.8.0', 'cpu'),
      );
      await fromMacOs.create(recursive: true);
      final fromResources = await resources(p.join('v0.8.0', 'cpu'));

      expect(
        BundledRuntimes.directories(
          executableDirectory.path,
          macOsBundle: true,
        ),
        [fromResources, p.normalize(fromMacOs.path)],
      );
    });
  });
}
