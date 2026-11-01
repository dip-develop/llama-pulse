import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final DateTime _fixedNow = DateTime.utc(2026, 5, 20, 12);

RuntimeManifest _manifest({
  String tag = 'v0.8.0',
  RuntimeBackend backend = RuntimeBackend.cpu,
  RuntimePlatform platform = RuntimePlatform.linuxX64,
  int sizeBytes = 100,
  int installedAtEpochMs = 1000,
}) => RuntimeManifest(
  (b) => b
    ..tag = tag
    ..buildId = 'b11960'
    ..commit = '8642541b255bfb5dc39cd351a178be09013a55d6'
    ..backend = backend
    ..platform = platform
    ..assetName = 'llama-b11960-bin.tar.gz'
    ..sha256 =
        '31cc3a6bc638ac6c48dc4b1b74888f1eaadf3d14227c1e5f67daf9a49541d97a'
    ..sizeBytes = sizeBytes
    ..installedAtEpochMs = installedAtEpochMs
    ..llamaVersion = '0.8.0'
    ..buildNumber = 11960
    ..backendLibs = BuiltList<String>(<String>[
      backend.backendLibs(platform).first,
    ]).toBuilder()
    ..requires = backend.requires
    ..files = 3,
);

var _stagingCounter = 0;

Future<Directory> _stage(
  Directory runtimeRoot,
  RuntimeManifest manifest, {
  bool withBinary = true,
  bool withLibs = true,
  String binaryContent = 'binary',
}) async {
  final staging = Directory(
    p.join(runtimeRoot.path, '.tmp-${_stagingCounter++}'),
  );
  await staging.create(recursive: true);
  if (withBinary) {
    await File(p.join(staging.path, manifest.platform.serverBinaryName))
        .writeAsString(binaryContent);
  }
  if (withLibs) {
    await File(p.join(staging.path, manifest.platform.libraryFileName))
        .writeAsString('library');
    for (final library in manifest.backendLibs) {
      await File(p.join(staging.path, library)).writeAsString('library');
    }
  }
  return staging;
}

void main() {
  late Directory configDirectory;
  late AppPaths paths;
  late YamlRuntimeStore store;
  late Directory runtimeRoot;

  setUp(() async {
    configDirectory = await Directory.systemTemp.createTemp(
      'llama_runtime_store_',
    );
    addTearDown(() async {
      if (await configDirectory.exists()) {
        await configDirectory.delete(recursive: true);
      }
    });
    paths = AppPaths(configDirectory: configDirectory.path);
    runtimeRoot = Directory(paths.runtimeDirectory);
    store = YamlRuntimeStore(paths: paths, clock: () => _fixedNow);
  });

  test('installDirectory is nested under the runtime directory', () {
    expect(
      store.installDirectory('v0.8.0', RuntimeBackend.cuda13),
      p.join(configDirectory.path, 'runtime', 'v0.8.0', 'cuda13'),
    );
  });

  test(
    'commit writes runtime.yaml and adds the install to index.yaml',
    () async {
      final manifest = _manifest();
      final staging = await _stage(runtimeRoot, manifest);

      await store.commit(RuntimeBackend.cpu, manifest, staging);

      expect(await store.manifest('v0.8.0', RuntimeBackend.cpu), manifest);
      final index = await store.index();
      expect(index.installed, hasLength(1));
      final install = index.installed.single;
      expect(install.tag, 'v0.8.0');
      expect(install.backend, RuntimeBackend.cpu);
      expect(install.platform, RuntimePlatform.linuxX64);
      expect(install.installedAtEpochMs, 1000);
      expect(install.sizeBytes, 100);
      expect(index.selectedBackend, isNull);
      expect(index.selectedTag, '');

      final installDirectory = Directory(
        store.installDirectory('v0.8.0', RuntimeBackend.cpu),
      );
      expect(await installDirectory.exists(), isTrue);
      expect(
        await File(p.join(installDirectory.path, 'llama-server')).exists(),
        isTrue,
      );
      expect(
        await File(p.join(installDirectory.path, 'libllama.so')).exists(),
        isTrue,
      );
      final manifestText = await File(
        p.join(installDirectory.path, 'runtime.yaml'),
      ).readAsString();
      expect(manifestText, startsWith('schemaVersion: 1\n'));
      expect(manifestText, contains('build: b11960'));
      expect(manifestText, contains('backend: cpu'));
      expect(manifestText, contains('platform: linux-x64'));

      final indexPath = p.join(runtimeRoot.path, 'index.yaml');
      final indexText = await File(indexPath).readAsString();
      expect(indexText, startsWith('schemaVersion: 1\n'));
      expect(indexText, contains('backend: cpu'));
    },
  );

  test('manifest returns null for a missing or corrupt runtime.yaml', () async {
    expect(await store.manifest('v0.8.0', RuntimeBackend.cpu), isNull);

    final manifest = _manifest();
    final staging = await _stage(runtimeRoot, manifest);
    await store.commit(RuntimeBackend.cpu, manifest, staging);
    final manifestFile = File(
      p.join(
        store.installDirectory('v0.8.0', RuntimeBackend.cpu),
        'runtime.yaml',
      ),
    );
    await manifestFile.writeAsString('not: [valid');
    expect(await store.manifest('v0.8.0', RuntimeBackend.cpu), isNull);

    await manifestFile.delete();
    expect(await store.manifest('v0.8.0', RuntimeBackend.cpu), isNull);
  });

  test(
    'select marks a runtime and remove deletes it and clears selection',
    () async {
      final cpu = _manifest(backend: RuntimeBackend.cpu);
      final cuda = _manifest(backend: RuntimeBackend.cuda13, sizeBytes: 200);
      await store.commit(
        RuntimeBackend.cpu,
        cpu,
        await _stage(runtimeRoot, cpu),
      );
      await store.commit(
        RuntimeBackend.cuda13,
        cuda,
        await _stage(runtimeRoot, cuda),
      );

      await store.select('v0.8.0', RuntimeBackend.cuda13);
      var index = await store.index();
      expect(index.selectedTag, 'v0.8.0');
      expect(index.selectedBackend, RuntimeBackend.cuda13);
      expect(index.selected?.id, 'v0.8.0/cuda13');

      final cudaDirectory = Directory(
        store.installDirectory('v0.8.0', RuntimeBackend.cuda13),
      );
      await store.remove('v0.8.0', RuntimeBackend.cuda13);

      expect(await cudaDirectory.exists(), isFalse);
      index = await store.index();
      expect(
        index.installed.map((install) => install.backend),
        <RuntimeBackend>[RuntimeBackend.cpu],
      );
      expect(index.selectedTag, '');
      expect(index.selectedBackend, isNull);
      expect(index.hasSelection, isFalse);

      await expectLater(
        store.select('v0.8.0', RuntimeBackend.cuda13),
        throwsStateError,
      );
    },
  );

  test('remove of the last install removes the empty tag directory', () async {
    final manifest = _manifest();
    await store.commit(
      RuntimeBackend.cpu,
      manifest,
      await _stage(runtimeRoot, manifest),
    );

    await store.remove('v0.8.0', RuntimeBackend.cpu);

    expect(
      await Directory(p.join(runtimeRoot.path, 'v0.8.0')).exists(),
      isFalse,
    );
    expect(await store.list(), isEmpty);
  });

  test('commit refuses an existing install unless force replaces it', () async {
    final first = _manifest(sizeBytes: 100, installedAtEpochMs: 1);
    await store.commit(
      RuntimeBackend.cpu,
      first,
      await _stage(runtimeRoot, first, binaryContent: 'first'),
    );
    final installDirectory = Directory(
      store.installDirectory('v0.8.0', RuntimeBackend.cpu),
    );
    final marker = File(p.join(installDirectory.path, 'old-marker'))
      ..writeAsStringSync('old');

    final second = _manifest(sizeBytes: 200, installedAtEpochMs: 2);
    final secondStaging = await _stage(
      runtimeRoot,
      second,
      binaryContent: 'second',
    );
    await expectLater(
      store.commit(RuntimeBackend.cpu, second, secondStaging),
      throwsStateError,
    );
    expect(await store.manifest('v0.8.0', RuntimeBackend.cpu), first);
    expect(await secondStaging.exists(), isTrue);

    await store.commit(RuntimeBackend.cpu, second, secondStaging, force: true);

    expect(await store.manifest('v0.8.0', RuntimeBackend.cpu), second);
    expect(await marker.exists(), isFalse);
    expect(
      await File(p.join(installDirectory.path, 'llama-server')).readAsString(),
      'second',
    );
    final index = await store.index();
    expect(index.installed, hasLength(1));
    expect(index.installed.single.sizeBytes, 200);
  });

  test('commit refuses a manifest for a different backend', () async {
    final manifest = _manifest(backend: RuntimeBackend.cuda13);
    final staging = await _stage(runtimeRoot, manifest);

    await expectLater(
      store.commit(RuntimeBackend.cpu, manifest, staging),
      throwsStateError,
    );
    expect(
      await Directory(store.installDirectory('v0.8.0', RuntimeBackend.cpu))
          .exists(),
      isFalse,
    );
  });

  test('commit refuses a staging dir without the expected binary', () async {
    final manifest = _manifest();
    final staging = await _stage(runtimeRoot, manifest, withBinary: false);

    await expectLater(
      store.commit(RuntimeBackend.cpu, manifest, staging),
      throwsStateError,
    );

    expect(
      await Directory(store.installDirectory('v0.8.0', RuntimeBackend.cpu))
          .exists(),
      isFalse,
    );
    expect(await store.list(), isEmpty);
  }, skip: Platform.isWindows);

  test('commit refuses a symlinked runtime file', () async {
    final manifest = _manifest();
    final staging = await _stage(runtimeRoot, manifest);
    final binary = File(
      p.join(staging.path, manifest.platform.serverBinaryName),
    );
    await binary.rename(p.join(staging.path, 'real-binary'));
    await Link(binary.path).create('real-binary');

    await expectLater(
      store.commit(RuntimeBackend.cpu, manifest, staging),
      throwsStateError,
    );
    expect(
      await Directory(store.installDirectory('v0.8.0', RuntimeBackend.cpu))
          .exists(),
      isFalse,
    );
  }, skip: Platform.isWindows);

  test(
    'commit renames the staging tree atomically and leaves no partial dir',
    () async {
      final manifest = _manifest();
      final staging = await _stage(runtimeRoot, manifest);
      final stagingPath = staging.path;

      await store.commit(RuntimeBackend.cpu, manifest, staging);

      expect(await Directory(stagingPath).exists(), isFalse);
      final installDirectory = Directory(
        store.installDirectory('v0.8.0', RuntimeBackend.cpu),
      );
      expect(await installDirectory.exists(), isTrue);
      expect(
        await File(p.join(installDirectory.path, 'llama-server')).exists(),
        isTrue,
      );
      expect(
        await File(p.join(installDirectory.path, 'runtime.yaml')).exists(),
        isTrue,
      );
      final leftovers = runtimeRoot
          .listSync()
          .map((entity) => p.basename(entity.path))
          .where((name) => name.startsWith('.tmp-') || name.contains('.old-'))
          .toList();
      expect(leftovers, isEmpty);
    },
  );

  test(
    'a corrupt index reads as empty and is regenerated on the next write',
    () async {
      await runtimeRoot.create(recursive: true);
      final indexFile = File(p.join(runtimeRoot.path, 'index.yaml'));
      await indexFile.writeAsString('not: [valid');

      expect(await store.list(), isEmpty);
      expect((await store.index()).installed, isEmpty);

      final manifest = _manifest();
      await store.commit(
        RuntimeBackend.cpu,
        manifest,
        await _stage(runtimeRoot, manifest),
      );

      expect(await store.list(), hasLength(1));
      expect(await indexFile.readAsString(), startsWith('schemaVersion: 1\n'));
    },
  );

  test('unknown index keys are tolerated', () async {
    final manifest = _manifest();
    await store.commit(
      RuntimeBackend.cpu,
      manifest,
      await _stage(runtimeRoot, manifest),
    );
    final indexFile = File(p.join(runtimeRoot.path, 'index.yaml'));
    await indexFile.writeAsString(
      '${await indexFile.readAsString()}futureField: ignored\n',
    );

    expect(await store.list(), hasLength(1));
  });

  test('cleanupOrphans deletes only old .tmp directories', () async {
    await runtimeRoot.create(recursive: true);
    final old = Directory(p.join(runtimeRoot.path, '.tmp-old'));
    final fresh = Directory(p.join(runtimeRoot.path, '.tmp-fresh'));
    final other = Directory(p.join(runtimeRoot.path, 'v0.8.0'));
    await old.create(recursive: true);
    await fresh.create(recursive: true);
    await other.create(recursive: true);
    final oldFile = File(p.join(old.path, 'partial'))
      ..writeAsStringSync('partial');
    final freshFile = File(p.join(fresh.path, 'partial'))
      ..writeAsStringSync('partial');
    await oldFile.setLastModified(_fixedNow.subtract(const Duration(days: 2)));
    await freshFile.setLastModified(_fixedNow);

    await store.cleanupOrphans();

    expect(await old.exists(), isFalse);
    expect(await fresh.exists(), isTrue);
    expect(await other.exists(), isTrue);
  });

  test('list never throws on an unreadable index file', () async {
    await runtimeRoot.create(recursive: true);
    await Directory(p.join(runtimeRoot.path, 'index.yaml')).create();

    expect(await store.list(), isEmpty);
  });
}
