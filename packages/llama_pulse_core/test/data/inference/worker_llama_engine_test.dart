import 'dart:async';
import 'dart:isolate';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void _fastEntryPoint(WorkerConfig config) =>
    _runWorker(config, const Duration(milliseconds: 1));

void _slowEntryPoint(WorkerConfig config) =>
    _runWorker(config, const Duration(milliseconds: 200));

void _crashingEntryPoint(WorkerConfig config) {
  throw StateError('worker crashed on purpose');
}

void _runWorker(WorkerConfig config, Duration tokenDelay) {
  final port = ReceivePort();
  config.mainPort.send(WorkerReady(responsePort: port.sendPort));
  unawaited(_serve(config, port, tokenDelay));
}

Future<void> _serve(
  WorkerConfig config,
  ReceivePort port,
  Duration tokenDelay,
) async {
  final session = StubLlamaSession(tokenDelay: tokenDelay);
  await session.open('');
  final loop = WorkerLoop(session: session, send: config.mainPort.send);
  port.listen((Object? message) {
    if (message is! WorkerRequest) {
      return;
    }
    final disposing = message.kind == WorkerRequestKind.dispose;
    loop.handle(message);
    if (disposing) {
      unawaited(loop.dispose().whenComplete(port.close));
    }
  });
}

ModelParams _params({int maxTokens = 8}) => ModelParams.defaults().copyWith(
  modelPath: 'models/tiny.gguf',
  maxTokens: maxTokens,
);

GenerationRequest _request(
  String prompt, {
  required int requestId,
  int maxTokens = 8,
}) => GenerationRequest.create(
  requestId: requestId,
  prompt: prompt,
  params: _params(maxTokens: maxTokens),
);

Future<String> _stubText(String prompt, {int maxTokens = 8}) async {
  final session = StubLlamaSession(tokenDelay: Duration.zero);
  await session.open('libllama.so');
  await session.load(_params(maxTokens: maxTokens));
  session.begin(_request(prompt, requestId: 1, maxTokens: maxTokens));
  final buffer = StringBuffer();
  while (true) {
    final step = await session.next();
    if (step == null || step.done) {
      break;
    }
    buffer.write(step.text);
  }
  return buffer.toString();
}

Future<List<GenerationEvent>> _collect(Stream<GenerationEvent> stream) =>
    stream.toList().timeout(const Duration(seconds: 10));

void main() {
  test('load then generate ends with a completed terminal', () async {
    final engine = WorkerLlamaEngine(entryPoint: _fastEntryPoint);
    addTearDown(engine.dispose);
    await engine.load(_params());
    const prompt = 'hello';
    final events = await _collect(
      engine.generate(_request(prompt, requestId: 10)),
    );
    expect(events.first.kind, GenerationEventKind.started);
    expect(events.first.requestId, 10);
    expect(events.last.kind, GenerationEventKind.completed);
    expect(events.last.metrics, isNotNull);
    expect(events.every((event) => event.requestId == 10), isTrue);
    final text = events
        .where((event) => event.kind == GenerationEventKind.token)
        .map((event) => event.text)
        .join();
    expect(text, await _stubText(prompt));
  });

  test('cancel mid-stream ends with cancelled and closes', () async {
    final engine = WorkerLlamaEngine(entryPoint: _slowEntryPoint);
    addTearDown(engine.dispose);
    await engine.load(_params());
    final events = <GenerationEvent>[];
    final done = Completer<void>();
    engine
        .generate(_request('hello', requestId: 11))
        .listen(events.add, onDone: done.complete);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await engine.cancel(11);
    await done.future.timeout(const Duration(seconds: 5));
    expect(events.last.kind, GenerationEventKind.cancelled);
    expect(events.last.requestId, 11);
  });

  test('a second generate while busy fails with engineBusy', () async {
    final engine = WorkerLlamaEngine(entryPoint: _slowEntryPoint);
    addTearDown(engine.dispose);
    await engine.load(_params());
    final first = _collect(engine.generate(_request('hello', requestId: 20)));
    final second = await _collect(
      engine.generate(_request('bye', requestId: 21)),
    );
    expect(second.last.kind, GenerationEventKind.failed);
    expect(second.last.failure!.code, InferenceFailureCode.engineBusy);
    await engine.cancel(20);
    final firstEvents = await first;
    expect(firstEvents.last.kind, GenerationEventKind.cancelled);
  });

  test('a slow worker hits the request timeout', () async {
    final engine = WorkerLlamaEngine(
      entryPoint: _slowEntryPoint,
      requestTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(engine.dispose);
    await engine.load(_params());
    final events = await _collect(
      engine.generate(_request('hello', requestId: 30)),
    );
    expect(events.first.kind, GenerationEventKind.started);
    expect(events.last.kind, GenerationEventKind.failed);
    expect(events.last.failure!.code, InferenceFailureCode.nativeError);
    expect(events.last.failure!.message, contains('timed out'));
  });

  test('dispose is idempotent', () async {
    final engine = WorkerLlamaEngine(entryPoint: _fastEntryPoint);
    await engine.load(_params());
    await engine.dispose();
    await engine.dispose();
    await expectLater(
      engine.load(_params()),
      throwsA(isA<InferenceFailureException>()),
    );
  });

  test('a crashing worker fails load and is reported as a failure', () async {
    final engine = WorkerLlamaEngine(entryPoint: _crashingEntryPoint);
    addTearDown(engine.dispose);
    await expectLater(
      engine.load(_params()),
      throwsA(
        isA<InferenceFailureException>().having(
          (exception) => exception.failure.code,
          'failure.code',
          InferenceFailureCode.nativeError,
        ),
      ),
    );
    // A failed start is not cached, so the next call tries again.
    await expectLater(
      engine.load(_params()),
      throwsA(isA<InferenceFailureException>()),
    );
  });
}
