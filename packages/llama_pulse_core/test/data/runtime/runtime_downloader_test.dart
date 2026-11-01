import 'dart:io';
import 'dart:typed_data';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/runtime/archive_fixtures.dart';
import '../../support/runtime/fake_runtime_fetcher.dart';

RuntimeAsset _asset({
  required Uint8List bytes,
  String assetName = 'llama-b11960-bin-ubuntu-x64.tar.gz',
  RuntimeBackend backend = RuntimeBackend.cpu,
  RuntimePlatform platform = RuntimePlatform.linuxX64,
  String? sha256,
  int? sizeBytes,
  RuntimeAsset? cudartAsset,
}) => RuntimeAsset(
  tag: 'v0.8.0',
  backend: backend,
  platform: platform,
  assetName: assetName,
  sha256: sha256 ?? sha256Hex(bytes),
  sizeBytes: sizeBytes ?? bytes.length,
  cudartAsset: cudartAsset,
);

Matcher _runtimeError(RuntimeFailureCode code) => throwsA(
  isA<RuntimeException>().having((error) => error.code, 'code', code),
);

void main() {
  late Directory workspace;
  late Directory target;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('llama_download_');
    target = Directory(p.join(workspace.path, '.tmp-test'));
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  RuntimeDownloader downloaderFor(
    FakeRuntimeFetcher fetcher, {
    ProcessExecutor? executor,
  }) => RuntimeDownloader(fetcher: fetcher, clock: () => 0, executor: executor);

  test('downloads, verifies, extracts and reports progress', () async {
    final bytes = normalTarGz();
    final asset = _asset(bytes: bytes);
    final fetcher = FakeRuntimeFetcher(
      routes: <String, List<int>>{asset.url: bytes},
      chunkSize: 32,
    );
    final progress = <RuntimeProgress>[];

    final result = await downloaderFor(fetcher)
        .download(asset: asset, targetParent: target, onProgress: progress.add);

    expect(result.tag, 'v0.8.0');
    expect(result.assetName, asset.assetName);
    expect(result.sha256, asset.sha256);
    expect(result.sizeBytes, asset.sizeBytes);
    expect(result.assets, hasLength(1));
    expect(result.files, 3);
    expect(result.payloadDir.path, p.join(target.path, 'payload'));
    expect(
      File(p.join(target.path, 'payload', 'llama-server')).existsSync(),
      isTrue,
    );
    expect(
      Link(p.join(target.path, 'payload', 'libllama.so')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(target.path, 'payload', 'README.md')).readAsStringSync(),
      '# llama.cpp\n',
    );
    expect(
      await target.list().map((entry) => p.basename(entry.path)).toList(),
      <String>['payload'],
    );

    expect(progress, isNotEmpty);
    expect(progress.first.received, 0);
    for (var index = 1; index < progress.length; index++) {
      expect(
        progress[index].received,
        greaterThanOrEqualTo(progress[index - 1].received),
      );
    }
    expect(progress.last.received, asset.sizeBytes);
    expect(progress.last.total, asset.sizeBytes);
    expect(progress.last.bytesPerSecond, greaterThanOrEqualTo(0));
  });

  test('a checksum mismatch deletes the partial file', () async {
    final bytes = normalTarGz();
    final asset = _asset(bytes: bytes, sha256: '0' * 64);
    final fetcher = FakeRuntimeFetcher(
      routes: <String, List<int>>{asset.url: bytes},
    );

    await expectLater(
      downloaderFor(fetcher)
          .download(asset: asset, targetParent: target, onProgress: (_) {}),
      _runtimeError(RuntimeFailureCode.checksumMismatch),
    );

    expect(File(p.join(target.path, 'asset.part')).existsSync(), isFalse);
    expect(Directory(p.join(target.path, 'payload')).existsSync(), isFalse);
  });

  test('a truncated stream is a size mismatch', () async {
    final bytes = normalTarGz();
    final asset = _asset(bytes: bytes);
    final fetcher = FakeRuntimeFetcher(
      routes: <String, List<int>>{asset.url: bytes},
      truncateTo: 20,
    );

    await expectLater(
      downloaderFor(fetcher)
          .download(asset: asset, targetParent: target, onProgress: (_) {}),
      _runtimeError(RuntimeFailureCode.sizeMismatch),
    );

    expect(File(p.join(target.path, 'asset.part')).existsSync(), isFalse);
  });

  test('an HTTP 404 becomes an httpStatus failure', () async {
    final bytes = normalTarGz();
    final asset = _asset(bytes: bytes);
    final fetcher = FakeRuntimeFetcher(routes: <String, List<int>>{});

    await expectLater(
      downloaderFor(fetcher)
          .download(asset: asset, targetParent: target, onProgress: (_) {}),
      _runtimeError(RuntimeFailureCode.httpStatus),
    );
  });

  test(
    'cancelling mid-stream deletes the partial file and the payload',
    () async {
      final bytes = normalTarGz();
      final asset = _asset(bytes: bytes);
      final cancel = RuntimeCancelToken();
      final fetcher = FakeRuntimeFetcher(
        routes: <String, List<int>>{asset.url: bytes},
        chunkSize: 16,
        onChunk: (sent, token) {
          if (sent >= 16) {
            token?.cancel();
          }
        },
      );

      await expectLater(
        downloaderFor(fetcher).download(
          asset: asset,
          targetParent: target,
          onProgress: (_) {},
          cancel: cancel,
        ),
        _runtimeError(RuntimeFailureCode.cancelled),
      );

      expect(await target.exists(), isTrue);
      expect(await target.list().toList(), isEmpty);
    },
  );

  test('resumes a 206 response from the partial file', () async {
    final bytes = normalTarGz();
    final asset = _asset(bytes: bytes);
    const prefixLength = 64;
    await target.create(recursive: true);
    await File(p.join(target.path, 'asset.part'))
        .writeAsBytes(bytes.sublist(0, prefixLength));
    final fetcher = FakeRuntimeFetcher(
      routes: <String, List<int>>{asset.url: bytes},
      chunkSize: 32,
    );

    final result = await downloaderFor(fetcher)
        .download(asset: asset, targetParent: target, onProgress: (_) {});

    expect(fetcher.requests.single.resumeFrom, prefixLength);
    expect(result.files, 3);
    expect(File(p.join(target.path, 'asset.part')).existsSync(), isFalse);
  });

  test('restarts when the server ignores the range and answers 200', () async {
    final bytes = normalTarGz();
    final asset = _asset(bytes: bytes);
    const prefixLength = 64;
    await target.create(recursive: true);
    await File(p.join(target.path, 'asset.part'))
        .writeAsBytes(List<int>.filled(prefixLength, 0));
    final fetcher = FakeRuntimeFetcher(
      routes: <String, List<int>>{asset.url: bytes},
      chunkSize: 32,
      honourResume: false,
    );

    final result = await downloaderFor(fetcher)
        .download(asset: asset, targetParent: target, onProgress: (_) {});

    expect(fetcher.requests.single.resumeFrom, prefixLength);
    expect(result.files, 3);
    expect(
      File(p.join(target.path, 'payload', 'llama-server')).existsSync(),
      isTrue,
    );
    expect(File(p.join(target.path, 'asset.part')).existsSync(), isFalse);
  });

  test(
    'downloads and verifies the cudart archive into the same payload',
    () async {
      final bytes = normalTarGz();
      final cudartBytes = cudartTarGz();
      final cudartAsset = _asset(
        bytes: cudartBytes,
        assetName: 'cudart-llama-b11960-bin-ubuntu-x64.tar.gz',
        backend: RuntimeBackend.cuda12,
      );
      final asset = _asset(
        bytes: bytes,
        assetName: 'llama-b11960-bin-ubuntu-cuda-12.8-x64.tar.gz',
        backend: RuntimeBackend.cuda12,
        cudartAsset: cudartAsset,
      );
      final fetcher = FakeRuntimeFetcher(
        routes: <String, List<int>>{
          asset.url: bytes,
          cudartAsset.url: cudartBytes,
        },
        chunkSize: 32,
      );

      final progress = <RuntimeProgress>[];
      final result = await downloaderFor(
        fetcher,
      ).download(asset: asset, targetParent: target, onProgress: progress.add);

      expect(result.assets, hasLength(2));
      expect(result.assets[1].assetName, cudartAsset.assetName);
      expect(result.files, 4);
      expect(
        File(p.join(target.path, 'payload', 'libcudart.so.12')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(target.path, 'payload', 'llama-server')).existsSync(),
        isTrue,
      );
      expect(Directory(p.join(target.path, 'cudart')).existsSync(), isFalse);
      for (var index = 1; index < progress.length; index++) {
        expect(
          progress[index].received,
          greaterThanOrEqualTo(progress[index - 1].received),
        );
      }
      expect(progress.last.total, asset.sizeBytes + cudartBytes.length);
      expect(progress.last.received, asset.sizeBytes + cudartBytes.length);
    },
  );

  test('probes llama-server when an executor is armed', () async {
    final bytes = normalTarGz();
    final asset = _asset(bytes: bytes);
    final fetcher = FakeRuntimeFetcher(
      routes: <String, List<int>>{asset.url: bytes},
    );
    final executor = FakeProcessExecutor(
      const ProcessOutput(
        exitCode: 0,
        stdout: 'version: 0.8.0 (build 11960, commit 8642541)\n',
        stderr: '',
      ),
    );

    final result = await downloaderFor(
      fetcher,
      executor: executor,
    ).download(asset: asset, targetParent: target, onProgress: (_) {});

    expect(executor.executable, endsWith('llama-server'));
    expect(executor.arguments, <String>['--version']);
    expect(result.serverVersion, '0.8.0');
    expect(result.buildNumber, 11960);
    expect(result.buildId, 'b11960');
    expect(result.commit, '8642541');
  });

  test('a failed probe does not fail the install', () async {
    final bytes = normalTarGz();
    final asset = _asset(bytes: bytes);
    final fetcher = FakeRuntimeFetcher(
      routes: <String, List<int>>{asset.url: bytes},
    );
    final executor = FakeProcessExecutor(
      const ProcessOutput(exitCode: 1, stdout: '', stderr: 'boom'),
    );

    final result = await downloaderFor(
      fetcher,
      executor: executor,
    ).download(asset: asset, targetParent: target, onProgress: (_) {});

    expect(result.serverVersion, isNull);
    expect(result.buildNumber, isNull);
    expect(result.buildId, 'b11960');
    expect(
      File(p.join(target.path, 'payload', 'llama-server')).existsSync(),
      isTrue,
    );
  });

  test('refuses a non-empty staging directory', () async {
    final bytes = normalTarGz();
    final asset = _asset(bytes: bytes);
    final fetcher = FakeRuntimeFetcher(
      routes: <String, List<int>>{asset.url: bytes},
    );
    await target.create(recursive: true);
    await File(p.join(target.path, 'stray.txt')).writeAsString('stray');

    await expectLater(
      downloaderFor(fetcher)
          .download(asset: asset, targetParent: target, onProgress: (_) {}),
      throwsA(isA<StateError>()),
    );
    expect(fetcher.requests, isEmpty);
  });
}
