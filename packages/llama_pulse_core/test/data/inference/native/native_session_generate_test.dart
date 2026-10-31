import 'dart:io';

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
    temp = Directory.systemTemp.createTempSync('llama_pulse_generate_');
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

  ModelParams params({int contextSize = 4096, int maxTokens = 8}) =>
      ModelParams.defaults().copyWith(
        modelPath: modelPath,
        contextSize: contextSize,
        maxTokens: maxTokens,
      );

  Future<NativeLlamaSession> openSession() async {
    final session = NativeLlamaSession(libraryPath: libraryPath);
    addTearDown(session.dispose);
    await session.open(libraryPath);
    return session;
  }

  Future<NativeLlamaSession> loadedSession({int contextSize = 4096}) async {
    final session = await openSession();
    await session.load(params(contextSize: contextSize));
    return session;
  }

  GenerationRequest request({
    String prompt = 'hello',
    int maxTokens = 8,
    int requestId = 1,
  }) => GenerationRequest.create(
    requestId: requestId,
    prompt: prompt,
    params: params(maxTokens: maxTokens),
  );

  Future<List<GenerationStep>> drain(NativeLlamaSession session) async {
    final steps = <GenerationStep>[];
    while (true) {
      final step = await session.next();
      if (step == null) {
        break;
      }
      steps.add(step);
      if (step.done) {
        break;
      }
    }
    return steps;
  }

  test('scripted tokens produce their pieces and end on EOG', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();
    fake.setTokenizeResult(1);
    fake.setTokens([10, 11, 12]);
    fake.setPieces(['Hel', 'lo', ' world']);

    session.begin(request());
    final steps = await drain(session);

    expect(steps.map((step) => step.text).join(), 'Hello world');
    expect(steps.map((step) => step.text), ['Hel', 'lo', ' world', '']);
    expect(steps.last.done, isTrue);
    expect(steps.last.text, isEmpty, reason: 'EOG emits no extra text');
    expect(steps.where((step) => step.done), hasLength(1));
    expect(steps.last.metrics?.generatedTokenCount, 3);
    expect(steps.last.metrics?.promptTokenCount, 1);
    expect(fake.sampleCalls, 4, reason: 'three tokens plus the EOG sample');
    expect(fake.batchNodes, 1, reason: 'only the prompt is prefilled');
    expect(await session.next(), isNull, reason: 'a finished stream stays end');
  });

  test('a UTF-8 code point split across tokens is emitted once', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();
    fake.setTokenizeResult(1);
    fake.setTokens([10, 11]);
    fake.setPieceBytes(10, [0xE2, 0x82]);
    fake.setPieceBytes(11, [0xAC]);

    session.begin(request());
    final steps = await drain(session);

    expect(steps, hasLength(3));
    expect(steps[0].text, isEmpty, reason: 'the first two bytes are partial');
    expect(steps[1].text, '€');
    expect(steps.concatenatedText, isNot(contains('\uFFFD')));
    expect(steps.concatenatedText, '€');
    expect(steps.last.done, isTrue);
    expect(steps.last.metrics?.generatedTokenCount, 2);
  });

  test(
    'maxTokens caps the stream even when more tokens are scripted',
    () async {
      if (skipReason != null) {
        markTestSkipped(skipReason!);
        return;
      }
      final session = await loadedSession();
      fake.setTokenizeResult(1);
      fake.setTokens([10, 11, 12, 13, 14]);
      fake.setPieces(['a', 'b', 'c', 'd', 'e']);

      session.begin(request(maxTokens: 2));
      final steps = await drain(session);

      expect(steps.map((step) => step.text), ['a', 'b']);
      expect(steps.last.done, isTrue);
      expect(steps.last.metrics?.generatedTokenCount, 2);
      expect(fake.sampleCalls, 2);
      expect(await session.next(), isNull);
    },
  );

  test('a prompt longer than the context keeps its newest tokens', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession(contextSize: 64);
    fake.setTokenizeResult(200);

    session.begin(request(maxTokens: 8));
    final step = await session.next();

    expect(step, isNotNull);
    expect(fake.totalBatchTokens, 56);
    expect(fake.firstBatchPos, 0);
    expect(fake.lastBatchPos, 55);
    expect(step?.metrics?.promptTokenCount, 56);
  });

  test(
    'prefill is split into nBatch-sized chunks with one logits tail',
    () async {
      if (skipReason != null) {
        markTestSkipped(skipReason!);
        return;
      }
      final session = await loadedSession(contextSize: 2048);
      fake.setTokenizeResult(1200);

      session.begin(request(maxTokens: 8));
      final first = await session.next();
      expect(first, isNotNull);
      expect(first?.done, isFalse);
      expect(first?.text, isEmpty);
      expect(fake.batchNodes, 1);

      final second = await session.next();
      expect(second, isNotNull);
      expect(second?.done, isFalse);
      expect(fake.batchNodes, 2);

      final third = await session.next();
      expect(third, isNotNull);
      expect(third?.done, isTrue, reason: 'the scripted sampler returns EOG');
      expect(fake.batchNodes, 3);
      expect(fake.maxBatchTokens, 512);
      expect(fake.totalBatchTokens, 1200);
      expect(fake.firstBatchPos, 0);
      expect(fake.lastBatchPos, 1199);
      expect(fake.logitsCount, 1, reason: 'only the final prompt token asks');
      expect(fake.logitsLastOnly, isTrue);
    },
  );

  test('cancel before the first next frees the generation', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();
    fake.setTokenizeResult(1);

    session.begin(request());
    await session.cancel();

    expect(await session.next(), isNull);
    expect(fake.samplerFreeCount, 1);
    expect(await session.next(), isNull);
    expect(fake.samplerFreeCount, 1, reason: 'buffers are freed once');
  });

  test('cancel mid-generation stops before the next token', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();
    fake.setTokenizeResult(1);
    fake.setTokens([10, 11, 12]);
    fake.setPieces(['a', 'b', 'c']);

    session.begin(request());
    final first = await session.next();
    expect(first?.text, 'a');
    await session.cancel();

    expect(await session.next(), isNull);
    expect(fake.samplerFreeCount, 1);
    expect(fake.sampleCalls, 1, reason: 'no token is sampled after cancel');
  });

  for (final code in [1, 2, -1]) {
    test('decode result $code surfaces as a nativeError', () async {
      if (skipReason != null) {
        markTestSkipped(skipReason!);
        return;
      }
      final session = await loadedSession();
      fake.setTokenizeResult(4);
      fake.setDecodeResult(code);

      session.begin(request());

      await expectLater(
        session.next(),
        throwsA(
          isA<InferenceFailureException>()
              .having(
                (exception) => exception.failure.code,
                'code',
                InferenceFailureCode.nativeError,
              )
              .having(
                (exception) => exception.failure.details,
                'details',
                contains('$code'),
              )
              .having(
                (exception) => exception.failure.message,
                'message',
                code == -1 ? contains('--context-size') : isNotEmpty,
              ),
        ),
      );
    });
  }

  test('metrics come from perf, counts from the session', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();
    fake.setTokenizeResult(4);
    fake.setTokens([10, 11, 12]);
    fake.setPieces(['a', 'b', 'c']);

    session.begin(request(maxTokens: 3));
    fake.setPerf(
      promptEvalMs: 1.5,
      evalMs: 250.0,
      promptTokens: 4,
      generatedTokens: 2,
    );
    final steps = await drain(session);
    final finalMetrics = steps.last.metrics;

    expect(finalMetrics, isNotNull);
    expect(finalMetrics?.promptEvalMs, 2, reason: '1.5 ms rounds up');
    expect(finalMetrics?.evalMs, 250);
    expect(finalMetrics?.promptTokenCount, 4);
    expect(finalMetrics?.generatedTokenCount, 3);
    expect(finalMetrics?.tokensPerSecond, 12.0);
    expect(finalMetrics?.promptTokensPerSecond, 2000.0);
  });

  test('every begin clears memory and replaces the sampler chain', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();
    fake.setTokenizeResult(1);
    final resetsAfterLoad = fake.perfResetCount;

    session.begin(request());
    expect(fake.memoryClearCount, 1);
    expect(fake.samplerInitCount, 1);
    expect(fake.perfResetCount, resetsAfterLoad + 1);

    session.begin(request(requestId: 2));

    expect(fake.memoryClearCount, 2);
    expect(fake.samplerInitCount, 2);
    expect(fake.perfResetCount, resetsAfterLoad + 2);
    expect(fake.samplerFreeCount, 1, reason: 'the first chain is released');
  });

  test('a prompt that tokenizes to zero tokens is invalidParams', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await loadedSession();
    fake.setTokenizeResult(0);

    expect(
      () => session.begin(request()),
      throwsA(
        isA<InferenceFailureException>().having(
          (exception) => exception.failure.code,
          'code',
          InferenceFailureCode.invalidParams,
        ),
      ),
    );
  });

  test('begin without a loaded model is engineUnavailable', () async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final session = await openSession();

    expect(
      () => session.begin(request()),
      throwsA(
        isA<InferenceFailureException>().having(
          (exception) => exception.failure.code,
          'code',
          InferenceFailureCode.engineUnavailable,
        ),
      ),
    );
  });
}

extension on List<GenerationStep> {
  String get concatenatedText => map((step) => step.text).join();
}
