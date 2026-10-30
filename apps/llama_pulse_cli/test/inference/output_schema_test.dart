import 'package:llama_pulse_cli/src/inference/output_schema.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

GenerationMetrics _metrics({
  int promptTokenCount = 12,
  int generatedTokenCount = 21,
  int promptEvalMs = 34,
  int evalMs = 56,
}) => GenerationMetrics(
  (b) => b
    ..promptTokenCount = promptTokenCount
    ..generatedTokenCount = generatedTokenCount
    ..promptEvalMs = promptEvalMs
    ..evalMs = evalMs,
);

InferenceFailure _failure({String? details}) => InferenceFailure(
  (b) => b
    ..code = InferenceFailureCode.nativeError
    ..message = 'boom'
    ..details = details,
);

void main() {
  test('output schema version is stable', () {
    expect(outputSchemaVersion, 1);
  });

  test('started has exactly the common keys', () {
    final event = encodeStarted(7);
    expect(event.keys.toList(), ['schemaVersion', 'type', 'requestId']);
    expect(event['schemaVersion'], 1);
    expect(event['type'], 'started');
    expect(event['requestId'], 7);
  });

  test('token carries only text on top of the common keys', () {
    final event = encodeToken(3, 'hello');
    expect(event.keys.toList(), ['schemaVersion', 'type', 'requestId', 'text']);
    expect(event['type'], 'token');
    expect(event['requestId'], 3);
    expect(event['text'], 'hello');
  });

  test('metrics carries the nested metrics object in a stable order', () {
    final event = encodeMetrics(1, _metrics());
    expect(event.keys.toList(), [
      'schemaVersion',
      'type',
      'requestId',
      'metrics',
    ]);
    final metrics = event['metrics'] as Map<String, Object?>;
    expect(metrics.keys.toList(), [
      'promptTokenCount',
      'generatedTokenCount',
      'promptEvalMs',
      'evalMs',
      'tokensPerSecond',
      'promptTokensPerSecond',
    ]);
    expect(metrics['promptTokenCount'], 12);
    expect(metrics['promptTokenCount'], isA<int>());
    expect(metrics['generatedTokenCount'], 21);
    expect(metrics['promptEvalMs'], 34);
    expect(metrics['evalMs'], 56);
    expect(metrics['tokensPerSecond'], 375.0);
    expect(metrics['tokensPerSecond'], isA<double>());
    expect(metrics['promptTokensPerSecond'], 352.94);
    expect(metrics['promptTokensPerSecond'], isA<double>());
  });

  test('completed carries the full text and metrics', () {
    final event = encodeCompleted(2, 'full output', _metrics());
    expect(event.keys.toList(), [
      'schemaVersion',
      'type',
      'requestId',
      'text',
      'metrics',
    ]);
    expect(event['type'], 'completed');
    expect(event['text'], 'full output');
    expect(event['metrics'], isA<Map<String, Object?>>());
  });

  test('cancelled carries only the partial text', () {
    final event = encodeCancelled(4, 'par');
    expect(event.keys.toList(), ['schemaVersion', 'type', 'requestId', 'text']);
    expect(event['type'], 'cancelled');
    expect(event['text'], 'par');
    expect(event.containsKey('metrics'), isFalse);
    expect(event.containsKey('failure'), isFalse);
  });

  test('failed carries the partial text and a failure with null details', () {
    final event = encodeFailed(5, 'par', _failure());
    expect(event.keys.toList(), [
      'schemaVersion',
      'type',
      'requestId',
      'text',
      'failure',
    ]);
    expect(event['type'], 'failed');
    expect(event['text'], 'par');
    final failure = event['failure'] as Map<String, Object?>;
    expect(failure.keys.toList(), ['code', 'message', 'details']);
    expect(failure['code'], 'nativeError');
    expect(failure['message'], 'boom');
    expect(failure['details'], isNull);
  });

  test('failed keeps non-null details', () {
    final event = encodeFailed(5, '', _failure(details: 'stack'));
    final failure = event['failure'] as Map<String, Object?>;
    expect(failure['details'], 'stack');
  });

  test('metrics rounding uses two decimals', () {
    final metrics = _metrics(
      promptTokenCount: 1,
      generatedTokenCount: 1,
      promptEvalMs: 3,
      evalMs: 7,
    );
    final encoded = encodeMetricsObject(metrics);
    expect(encoded['tokensPerSecond'], 142.86);
    expect(encoded['promptTokensPerSecond'], 333.33);
  });

  test('zero timings produce zero rates', () {
    final metrics = _metrics(
      promptTokenCount: 0,
      generatedTokenCount: 0,
      promptEvalMs: 0,
      evalMs: 0,
    );
    final encoded = encodeMetricsObject(metrics);
    expect(encoded['tokensPerSecond'], 0.0);
    expect(encoded['promptTokensPerSecond'], 0.0);
  });
}
