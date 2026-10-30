import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

ModelParams _params({
  String modelPath = 'models/tiny.gguf',
  int maxTokens = 64,
}) =>
    ModelParams.defaults().copyWith(modelPath: modelPath, maxTokens: maxTokens);

GenerationRequest _request(String prompt, {int requestId = 1}) =>
    GenerationRequest.create(
      requestId: requestId,
      prompt: prompt,
      params: _params(),
    );

Future<StubLlamaSession> _openSession() async {
  final session = StubLlamaSession(tokenDelay: Duration.zero);
  await session.open('libllama.so');
  return session;
}

Future<({String text, List<GenerationStep> steps})> _drain(
  LlamaSession session,
) async {
  final steps = <GenerationStep>[];
  final buffer = StringBuffer();
  while (true) {
    final step = await session.next();
    if (step == null) {
      break;
    }
    steps.add(step);
    buffer.write(step.text);
    if (step.done) {
      break;
    }
  }
  return (text: buffer.toString(), steps: steps);
}

Matcher _throwsFailure(InferenceFailureCode code) => throwsA(
  isA<InferenceFailureException>().having(
    (exception) => exception.failure.code,
    'failure.code',
    code,
  ),
);

void main() {
  group('StubLlamaSession protocol misuse', () {
    test('load before open fails with engineUnavailable', () async {
      final session = StubLlamaSession(tokenDelay: Duration.zero);
      await expectLater(
        session.load(_params()),
        _throwsFailure(InferenceFailureCode.engineUnavailable),
      );
    });

    test('a blank model path fails with modelNotFound', () async {
      final session = await _openSession();
      await expectLater(
        session.load(_params(modelPath: '   ')),
        _throwsFailure(InferenceFailureCode.modelNotFound),
      );
    });

    test('begin before load fails with engineUnavailable', () async {
      final session = await _openSession();
      expect(
        () => session.begin(_request('hello')),
        _throwsFailure(InferenceFailureCode.engineUnavailable),
      );
    });

    test('begin after unload fails with engineUnavailable', () async {
      final session = await _openSession();
      await session.load(_params());
      await session.unload();
      expect(
        () => session.begin(_request('hello')),
        _throwsFailure(InferenceFailureCode.engineUnavailable),
      );
    });
  });

  group('StubLlamaSession generation', () {
    test('produces the same text for the same prompt', () async {
      final first = await _openSession();
      await first.load(_params());
      first.begin(_request('hello'));
      final firstRun = await _drain(first);

      final second = await _openSession();
      await second.load(_params());
      second.begin(_request('hello'));
      final secondRun = await _drain(second);

      expect(firstRun.text, secondRun.text);
      expect(firstRun.text, isNotEmpty);
      expect(firstRun.steps.length, secondRun.steps.length);
    });

    test('different prompts produce different text', () async {
      final session = await _openSession();
      await session.load(_params());
      session.begin(_request('hello'));
      final first = await _drain(session);
      session.begin(_request('bye'));
      final second = await _drain(session);
      expect(first.text, isNot(second.text));
    });

    test('respects the maxTokens cap', () async {
      final session = await _openSession();
      await session.load(_params(maxTokens: 3));
      session.begin(_request('hello'));
      final run = await _drain(session);
      final tokenSteps = run.steps.where((step) => !step.done);
      expect(tokenSteps.length, 3);
    });

    test('cancel makes the next step null', () async {
      final session = await _openSession();
      await session.load(_params());
      session.begin(_request('hello'));
      final first = await session.next();
      expect(first, isNotNull);
      await session.cancel();
      expect(await session.next(), isNull);
    });

    test('emits done exactly once with final metrics', () async {
      final session = await _openSession();
      await session.load(_params());
      session.begin(_request('hello'));
      final run = await _drain(session);
      expect(run.steps.where((step) => step.done).length, 1);
      expect(run.steps.last.done, isTrue);
      expect(run.steps.last.text, '');
      expect(run.steps.last.metrics, isNotNull);
      expect(await session.next(), isNull);
    });

    test('metric counts increase monotonically', () async {
      final session = await _openSession();
      await session.load(_params());
      session.begin(_request('hello'));
      final run = await _drain(session);
      var previous = 0;
      for (final step in run.steps) {
        final metrics = step.metrics;
        expect(metrics, isNotNull);
        expect(metrics!.promptTokenCount, greaterThanOrEqualTo(1));
        expect(metrics.promptEvalMs, 3);
        expect(metrics.generatedTokenCount, greaterThanOrEqualTo(previous));
        previous = metrics.generatedTokenCount;
      }
      expect(previous, greaterThan(0));
    });

    test('dispose is idempotent and stops generation', () async {
      final session = await _openSession();
      await session.load(_params());
      session.begin(_request('hello'));
      await session.dispose();
      await session.dispose();
      expect(await session.next(), isNull);
    });
  });
}
