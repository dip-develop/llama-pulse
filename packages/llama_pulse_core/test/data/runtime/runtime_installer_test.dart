import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/runtime/archive_fixtures.dart';
import '../../support/runtime/fake_runtime_fetcher.dart';

Uint8List _runtimeArchive() => tarGzEntries(<ArchiveFile>[
  ArchiveFile.bytes('llama-b11960/llama-server', <int>[
    ...elfMagic,
    ...'server'.codeUnits,
  ]),
  ArchiveFile.bytes('llama-b11960/libllama.so', <int>[
    ...elfMagic,
    ...'llama'.codeUnits,
  ]),
  ArchiveFile.bytes('llama-b11960/libggml.so', <int>[
    ...elfMagic,
    ...'ggml'.codeUnits,
  ]),
  ArchiveFile.bytes('llama-b11960/libggml-cpu.so', <int>[
    ...elfMagic,
    ...'cpu'.codeUnits,
  ]),
]);

void main() {
  late Directory temp;
  late AppPaths paths;
  late YamlRuntimeStore store;
  late Uint8List bytes;
  late RuntimeAsset asset;
  late FakeRuntimeFetcher fetcher;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('llama_pulse_installer_');
    paths = AppPaths(configDirectory: p.join(temp.path, 'config'));
    store = YamlRuntimeStore(paths: paths, clock: () => DateTime.utc(2026));
    bytes = _runtimeArchive();
    asset = RuntimeAsset(
      tag: 'v0.8.0',
      backend: RuntimeBackend.cpu,
      platform: RuntimePlatform.linuxX64,
      assetName: 'llama-b11960-bin-ubuntu-x64.tar.gz',
      sha256: sha256Hex(bytes),
      sizeBytes: bytes.length,
    );
    fetcher = FakeRuntimeFetcher(routes: <String, List<int>>{asset.url: bytes});
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  RuntimeInstaller installer() => RuntimeInstaller(
    store: store,
    fetcher: fetcher,
    paths: paths,
    clock: () => 1234,
  );

  test('downloads, extracts and commits a runtime', () async {
    final progress = <RuntimeProgress>[];

    final result = await installer().install(
      asset: asset,
      onProgress: progress.add,
    );

    final directory = store.installDirectory('v0.8.0', RuntimeBackend.cpu);
    expect(File(p.join(directory, 'llama-server')).existsSync(), isTrue);
    expect(File(p.join(directory, 'libllama.so')).existsSync(), isTrue);
    expect(File(p.join(directory, 'runtime.yaml')).existsSync(), isTrue);
    expect(result.payloadDir.path, directory);
    expect(progress, isNotEmpty);

    final manifest = await store.manifest('v0.8.0', RuntimeBackend.cpu);
    expect(manifest, isNotNull);
    expect(manifest!.tag, 'v0.8.0');
    expect(manifest.buildId, 'b11960');
    expect(manifest.commit, RuntimeRelease.v080.commit);
    expect(manifest.backend, RuntimeBackend.cpu);
    expect(manifest.platform, RuntimePlatform.linuxX64);
    expect(manifest.assetName, asset.assetName);
    expect(manifest.sha256, asset.sha256);
    expect(manifest.sizeBytes, asset.sizeBytes);
    expect(manifest.installedAtEpochMs, 1234);
    expect(manifest.backendLibs.toList(), <String>['libggml-cpu.so']);
    expect(manifest.files, greaterThanOrEqualTo(3));

    final installs = await store.list();
    expect(installs, hasLength(1));
    expect(installs.single.backend, RuntimeBackend.cpu);
    expect(
      Directory(paths.runtimeDirectory)
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('.tmp-')),
      isEmpty,
    );
  });

  test('refuses an existing runtime unless forced', () async {
    await installer().install(asset: asset, onProgress: (_) {});

    await expectLater(
      installer().install(asset: asset, onProgress: (_) {}),
      throwsStateError,
    );
    expect(fetcher.requests, hasLength(1));

    await installer().install(asset: asset, onProgress: (_) {}, force: true);
    expect(fetcher.requests, hasLength(2));
  });

  test('a cancelled install leaves no staging tree', () async {
    final cancel = RuntimeCancelToken();
    fetcher = FakeRuntimeFetcher(
      routes: <String, List<int>>{asset.url: bytes},
      chunkSize: 8,
      onChunk: (int sent, RuntimeCancelToken? token) => token?.cancel(),
    );

    await expectLater(
      installer().install(asset: asset, onProgress: (_) {}, cancel: cancel),
      throwsA(
        isA<RuntimeException>().having(
          (error) => error.code,
          'code',
          RuntimeFailureCode.cancelled,
        ),
      ),
    );

    expect(await store.list(), isEmpty);
    final leftovers = Directory(paths.runtimeDirectory)
        .listSync()
        .whereType<Directory>()
        .where((d) => p.basename(d.path).startsWith('.tmp-'));
    expect(leftovers, isEmpty);
  });

  test('a checksum mismatch removes the staging tree', () async {
    final tampered = RuntimeAsset(
      tag: asset.tag,
      backend: asset.backend,
      platform: asset.platform,
      assetName: asset.assetName,
      sha256: 'f' * 64,
      sizeBytes: asset.sizeBytes,
    );

    await expectLater(
      installer().install(asset: tampered, onProgress: (_) {}),
      throwsA(
        isA<RuntimeException>().having(
          (error) => error.code,
          'code',
          RuntimeFailureCode.checksumMismatch,
        ),
      ),
    );

    expect(await store.list(), isEmpty);
    expect(
      Directory(paths.runtimeDirectory)
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('.tmp-')),
      isEmpty,
    );
  });
}
