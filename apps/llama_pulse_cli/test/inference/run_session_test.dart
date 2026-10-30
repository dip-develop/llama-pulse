import 'dart:async';
import 'dart:convert';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_cli/src/inference/run_session.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

/// An engine whose generation stream always closes without a terminal event.
final class _TruncatedEngine implements LlamaEngine {
  @override
  Stream<GenerationEvent> generate(GenerationRequest request) async* {
    yield GenerationEvent.started(request.requestId);
    yield GenerationEvent.token(request.requestId, 'partial');
  }

  @override
  Future<void> load(ModelParams params) async {}

  @override
  Future<void> cancel(int requestId) async {}

  @override
  Future<void> unload() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  test('a stream without a terminal event fails the session', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final result = await runSession(
      engine: _TruncatedEngine(),
      request: GenerationRequest.create(
        requestId: 7,
        prompt: 'hi',
        params: ModelParams.defaults(),
      ),
      out: out,
      err: err,
      mode: RunOutputMode.json,
    );

    expect(result.status, SessionStatus.failed);
    expect(result.text, 'partial');
    expect(result.failure?.code, InferenceFailureCode.unknown);
    expect(result.failure?.message, 'the engine stream ended without a result');
    expect(result.exitCode, ExitCodes.failure);

    final event = jsonDecode(out.toString().trim()) as Map<String, Object?>;
    expect(event['type'], 'failed');
    expect(event['requestId'], 7);
    expect(event['text'], 'partial');
    expect(
      (event['failure'] as Map<String, Object?>)['message'],
      'the engine stream ended without a result',
    );
  });
}
