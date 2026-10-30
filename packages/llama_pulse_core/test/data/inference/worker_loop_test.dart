import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

ModelParams _params({int maxTokens = 8}) => ModelParams.defaults().copyWith(
  modelPath: 'models/tiny.gguf',
  maxTokens: maxTokens,
);

GenerationRequest _request(
  String prompt, {
  int requestId = 1,
  int maxTokens = 8,
}) => GenerationRequest.create(
  requestId: requestId,
  prompt: prompt,
  params: _params(maxTokens: maxTokens),
);

Future<({String text, int tokens})> _stubOutput(
  String prompt, {
  int maxTokens = 8,
}) async {
  final session = StubLlamaSession(tokenDelay: Duration.zero);
  await session.open('libllama.so');
  await session.load(_params(maxTokens: maxTokens));
  session.begin(_request(prompt, maxTokens: maxTokens));
  final buffer = StringBuffer();
  var tokens = 0;
  while (true) {
    final step = await session.next();
    if (step == null || step.done) {
      break;
    }
    buffer.write(step.text);
    tokens++;
  }
  return (text: buffer.toString(), tokens: tokens);
}

final class _Harness {
  _Harness({LlamaSession? session})
    : session = session ?? StubLlamaSession(tokenDelay: Duration.zero);

  final LlamaSession session;
  final responses = <WorkerResponse>[];
  final sentAtMs = <int>[];
  final stopwatch = Stopwatch()..start();
  late final WorkerLoop loop = WorkerLoop(session: session, send: _record);

  void _record(WorkerResponse response) {
    responses.add(response);
    sentAtMs.add(stopwatch.elapsedMilliseconds);
  }

  List<WorkerResponse> ofKind(WorkerResponseKind kind) =>
      responses.where((response) => response.kind == kind).toList();

  Future<void> load({int maxTokens = 8}) async {
    loop.handle(WorkerRequest.load(-1, _params(maxTokens: maxTokens)));
    await loop.idle;
  }
}

Future<_Harness> _loaded({Duration tokenDelay = Duration.zero}) async {
  final session = StubLlamaSession(tokenDelay: tokenDelay);
  await session.open('libllama.so');
  final harness = _Harness(session: session);
  await harness.load();
  harness.responses.clear();
  harness.sentAtMs.clear();
  harness.stopwatch.reset();
  return harness;
}

bool _isTerminal(WorkerResponse response) =>
    response.kind == WorkerResponseKind.completed ||
    response.kind == WorkerResponseKind.cancelled ||
    response.kind == WorkerResponseKind.failure;

void main() {
  test('ping answers with pong', () async {
    final harness = _Harness();
    harness.loop.handle(WorkerRequest.ping(-1));
    await harness.loop.idle;
    final pong = harness.responses.single;
    expect(pong.kind, WorkerResponseKind.pong);
    expect(pong.requestId, -1);
  });

  group('load', () {
    test('success answers loaded', () async {
      final session = StubLlamaSession(tokenDelay: Duration.zero);
      await session.open('libllama.so');
      final harness = _Harness(session: session);
      await harness.load();
      final loaded = harness.responses.single;
      expect(loaded.kind, WorkerResponseKind.loaded);
      expect(loaded.requestId, -1);
    });

    test('a session failure is mapped to a failure response', () async {
      // The stub refuses to load a model before open().
      final harness = _Harness(
        session: StubLlamaSession(tokenDelay: Duration.zero),
      );
      harness.loop.handle(WorkerRequest.load(-1, _params()));
      await harness.loop.idle;
      final failure = harness.responses.single;
      expect(failure.kind, WorkerResponseKind.failure);
      expect(failure.failure!.code, InferenceFailureCode.engineUnavailable);
    });

    test('generate before load fails with engineUnavailable', () async {
      final harness = _Harness();
      harness.loop.handle(WorkerRequest.generate(_request('hello')));
      await harness.loop.idle;
      final failure = harness.responses.single;
      expect(failure.kind, WorkerResponseKind.failure);
      expect(failure.failure!.code, InferenceFailureCode.engineUnavailable);
    });
  });

  group('generate', () {
    test('batches coalesce into the full text', () async {
      final harness = await _loaded(
        tokenDelay: const Duration(milliseconds: 5),
      );
      const prompt = 'hello';
      harness.loop.handle(
        WorkerRequest.generate(_request(prompt, requestId: 3, maxTokens: 8)),
      );
      await harness.loop.idle;
      final batches = harness.ofKind(WorkerResponseKind.tokenBatch);
      final expected = await _stubOutput(prompt);
      expect(batches.map((response) => response.text).join(), expected.text);
      expect(batches, isNotEmpty);
      expect(batches.length, lessThanOrEqualTo(expected.tokens));
      expect(batches.every((response) => response.requestId == 3), isTrue);
    });

    test('ends with metrics and exactly one completed terminal', () async {
      final harness = await _loaded();
      harness.loop.handle(WorkerRequest.generate(_request('hello')));
      await harness.loop.idle;
      final terminals = harness.responses.where(_isTerminal).toList();
      expect(terminals, hasLength(1));
      expect(terminals.single.kind, WorkerResponseKind.completed);
      expect(harness.responses.last.kind, WorkerResponseKind.completed);
      expect(
        harness.responses[harness.responses.length - 2].kind,
        WorkerResponseKind.metrics,
      );
      expect(harness.responses.last.metrics, isNull);
    });

    test('a second generate while busy fails with engineBusy', () async {
      final harness = await _loaded(
        tokenDelay: const Duration(milliseconds: 20),
      );
      harness.loop.handle(
        WorkerRequest.generate(_request('hello', requestId: 7, maxTokens: 40)),
      );
      harness.loop.handle(
        WorkerRequest.generate(_request('bye', requestId: 8, maxTokens: 40)),
      );
      harness.loop.handle(WorkerRequest.cancel(-3, 7));
      await harness.loop.idle;
      final failure = harness.ofKind(WorkerResponseKind.failure).single;
      expect(failure.requestId, 8);
      expect(failure.failure!.code, InferenceFailureCode.engineBusy);
      expect(harness.ofKind(WorkerResponseKind.cancelled).single.requestId, 7);
    });

    test('cancel before completion ends with cancelled', () async {
      final harness = await _loaded(
        tokenDelay: const Duration(milliseconds: 20),
      );
      harness.loop.handle(
        WorkerRequest.generate(_request('hello', requestId: 4, maxTokens: 40)),
      );
      harness.loop.handle(WorkerRequest.cancel(-3, 4));
      await harness.loop.idle;
      expect(harness.responses.last.kind, WorkerResponseKind.cancelled);
      expect(harness.responses.last.requestId, 4);
      expect(harness.ofKind(WorkerResponseKind.completed), isEmpty);
    });

    test('cancel for another request is ignored', () async {
      final harness = await _loaded();
      harness.loop.handle(WorkerRequest.cancel(-3, 99));
      await harness.loop.idle;
      expect(harness.responses, isEmpty);
    });

    test('interim metrics respect the 250 ms interval', () async {
      final harness = await _loaded(
        tokenDelay: const Duration(milliseconds: 60),
      );
      harness.loop.handle(
        WorkerRequest.generate(_request('hello', requestId: 5, maxTokens: 6)),
      );
      await harness.loop.idle;
      final metrics = harness.ofKind(WorkerResponseKind.metrics);
      // One final marker plus at least one interim sample on a ~360 ms run.
      expect(metrics.length, greaterThanOrEqualTo(2));
      expect(metrics.length, lessThanOrEqualTo(4));
      final marks = <int>[
        for (var index = 0; index < harness.responses.length; index++)
          if (harness.responses[index].kind == WorkerResponseKind.metrics)
            harness.sentAtMs[index],
      ];
      for (var index = 1; index < marks.length - 1; index++) {
        expect(marks[index] - marks[index - 1], greaterThanOrEqualTo(200));
      }
    });
  });

  group('unload', () {
    test('answers unloaded and blocks later generates', () async {
      final harness = await _loaded();
      harness.loop.handle(WorkerRequest.unload(-2));
      await harness.loop.idle;
      expect(harness.responses.single.kind, WorkerResponseKind.unloaded);
      harness.responses.clear();
      harness.loop.handle(WorkerRequest.generate(_request('hello')));
      await harness.loop.idle;
      expect(
        harness.responses.single.failure!.code,
        InferenceFailureCode.engineUnavailable,
      );
    });

    test('unload while generating fails with engineBusy', () async {
      final harness = await _loaded(
        tokenDelay: const Duration(milliseconds: 20),
      );
      harness.loop.handle(
        WorkerRequest.generate(_request('hello', requestId: 6, maxTokens: 40)),
      );
      harness.loop.handle(WorkerRequest.unload(-2));
      harness.loop.handle(WorkerRequest.cancel(-3, 6));
      await harness.loop.idle;
      final failure = harness.ofKind(WorkerResponseKind.failure).single;
      expect(failure.requestId, -2);
      expect(failure.failure!.code, InferenceFailureCode.engineBusy);
      expect(harness.ofKind(WorkerResponseKind.unloaded), isEmpty);
    });
  });

  test('dispose answers disposed and ignores later requests', () async {
    final harness = await _loaded();
    harness.loop.handle(WorkerRequest.dispose(-9));
    await harness.loop.idle;
    expect(harness.responses.single.kind, WorkerResponseKind.disposed);
    expect(harness.responses.single.requestId, -9);
    harness.loop.handle(WorkerRequest.ping(-10));
    await harness.loop.idle;
    expect(harness.responses, hasLength(1));
  });
}
