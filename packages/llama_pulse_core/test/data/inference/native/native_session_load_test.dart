import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:llama_pulse_core/src/data/inference/native/native_llama_session.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../support/native/fake_llama_builder.dart';

void main() {
  late String libraryPath;
  late FakeLlama fake;
  late Directory temp;
  late String modelPath;
  String? skipReason;

  setUpAll(() async {
    if (!await FakeLlamaBuilder.isAvailable) {
      skipReason = 'clang is not installed; the native shim needs a compiler';
      return;
    }
    libraryPath = await FakeLlamaBuilder.build();
    fake = FakeLlama(libraryPath);
  });

  setUp(() {
    if (skipReason != null) {
      return;
    }
    fake.reset();
    fake.setVersion('0.8.0');
    temp = Directory.systemTemp.createTempSync('llama_pulse_load_');
    modelPath = p.join(temp.path, 'tiny.gguf');
    File(modelPath).writeAsStringSync('not a real gguf');
  });

  tearDown(() {
    if (skipReason != null) {
      return;
    }
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  ModelParams params({
    int contextSize = 4096,
    int gpuLayers = 7,
    int threads = 3,
    String? path,
    Map<String, String> catalogParams = const {},
  }) => ModelParams.defaults().copyWith(
    modelPath: path ?? modelPath,
    contextSize: contextSize,
    gpuLayers: gpuLayers,
    threads: threads,
    params: BuiltMap<String, String>(catalogParams),
  );

  Future<NativeLlamaSession> openSession() async {
    final session = NativeLlamaSession(libraryPath: libraryPath);
    addTearDown(session.dispose);
    await session.open(libraryPath);
    return session;
  }

  test('load passes every requested value into llama.cpp', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();

    await session.load(params());

    expect(fake.gpuLayers, 7);
    expect(fake.modelPath, modelPath);
    expect(fake.ctxSize, 4096);
    expect(fake.batchSize, 512);
    expect(fake.ubatchSize, 512);
    expect(fake.threads, 3);
    expect(fake.threadsBatch, 3);
    expect(fake.seqMax, 1);
    expect(fake.noPerf, isFalse);
    expect(session.contextSize, 4096);
    expect(session.batchSize, 512);
    expect(fake.modelFreeCount, 0);
    expect(fake.ctxFreeCount, 0);
  });

  test('a context below the batch cap keeps its own size', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();

    await session.load(params(contextSize: 128, gpuLayers: 0, threads: 2));

    expect(fake.ctxSize, 128);
    expect(fake.batchSize, 128);
    expect(fake.ubatchSize, 128);
    expect(fake.gpuLayers, 0);
    expect(fake.threads, 2);
  });

  test('load uses an explicit batch-size for n_batch and n_ubatch', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();

    await session.load(params(catalogParams: {'batch-size': '256'}));

    expect(fake.ctxSize, 4096);
    expect(fake.batchSize, 256);
    expect(fake.ubatchSize, 256);
    expect(session.batchSize, 256);
  });

  test('load keeps an explicit batch-size above the default cap', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();

    await session.load(params(catalogParams: {'batch-size': '768'}));

    expect(fake.batchSize, 768);
    expect(fake.ubatchSize, 768);
  });

  test('load clamps a batch-size above the context to the context', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();

    await session.load(
      params(contextSize: 512, catalogParams: {'batch-size': '8192'}),
    );

    expect(fake.ctxSize, 512);
    expect(fake.batchSize, 512);
    expect(fake.ubatchSize, 512);
  });

  test('a rejected model load is a nativeError with the path', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();
    fake.setFailModel(true);

    await expectLater(
      session.load(params()),
      throwsA(
        isA<InferenceFailureException>()
            .having(
              (exception) => exception.failure.code,
              'code',
              InferenceFailureCode.nativeError,
            )
            .having(
              (exception) => exception.failure.message,
              'message',
              allOf(contains(modelPath), contains('--gpu-layers')),
            ),
      ),
    );
    expect(fake.modelFreeCount, 0);
    expect(fake.ctxFreeCount, 0);
  });

  test('a rejected context load frees the model and names n_ctx', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();
    fake.setFailContext(true);

    await expectLater(
      session.load(params()),
      throwsA(
        isA<InferenceFailureException>()
            .having(
              (exception) => exception.failure.code,
              'code',
              InferenceFailureCode.nativeError,
            )
            .having(
              (exception) => exception.failure.message,
              'message',
              allOf(contains('n_ctx'), contains('4096')),
            ),
      ),
    );
    expect(fake.modelFreeCount, 1);
    expect(fake.ctxFreeCount, 0);
  });

  test('a missing model file is modelNotFound and stays native free', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();
    final missing = p.join(temp.path, 'missing.gguf');

    await expectLater(
      session.load(params(path: missing)),
      throwsA(
        isA<InferenceFailureException>()
            .having(
              (exception) => exception.failure.code,
              'code',
              InferenceFailureCode.modelNotFound,
            )
            .having(
              (exception) => exception.failure.message,
              'message',
              contains(missing),
            ),
      ),
    );
    expect(fake.gpuLayers, -1, reason: 'no native load may run');
  });

  test('a directory is not accepted as a model file', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();

    await expectLater(
      session.load(params(path: temp.path)),
      throwsA(
        isA<InferenceFailureException>().having(
          (exception) => exception.failure.code,
          'code',
          InferenceFailureCode.modelNotFound,
        ),
      ),
    );
  });

  test('reloading frees the previous model and context exactly once', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();
    await session.load(params());

    await session.load(params(contextSize: 2048));

    expect(fake.ctxSize, 2048);
    expect(fake.batchSize, 512);
    expect(fake.modelFreeCount, 1);
    expect(fake.ctxFreeCount, 1);
    expect(session.contextSize, 2048);
  });

  test('disposing twice frees once', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();
    await session.load(params());

    await session.dispose();
    await session.dispose();

    expect(fake.modelFreeCount, 1);
    expect(fake.ctxFreeCount, 1);
  });

  test('unload frees, then load works again', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();
    await session.load(params());

    await session.unload();

    expect(fake.modelFreeCount, 1);
    expect(fake.ctxFreeCount, 1);
    expect(session.contextSize, isNull);

    await session.load(params(contextSize: 1024));

    expect(fake.ctxSize, 1024);
    expect(fake.batchSize, 512);
    expect(fake.modelFreeCount, 1);
    expect(fake.ctxFreeCount, 1);
  });

  test('cancel before a load is safe and next returns null', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }

    final session = await openSession();

    await session.cancel();
    expect(await session.next(), isNull);
  });
}
