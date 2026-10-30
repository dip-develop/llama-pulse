import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Version of the line-oriented inference output schema.
///
/// Deliberately separate from [ModelParams.schemaVersion]: the configuration
/// document and the streaming protocol evolve independently.
const int outputSchemaVersion = 1;

/// Rounds [value] to two decimal places.
double roundToTwoDecimals(double value) => (value * 100).round() / 100;

/// Encodes the `started` event.
Map<String, Object?> encodeStarted(int requestId) => {
  'schemaVersion': outputSchemaVersion,
  'type': 'started',
  'requestId': requestId,
};

/// Encodes a `token` event carrying one chunk of generated [text].
Map<String, Object?> encodeToken(int requestId, String text) => {
  'schemaVersion': outputSchemaVersion,
  'type': 'token',
  'requestId': requestId,
  'text': text,
};

/// Encodes a `metrics` event carrying interim [metrics].
Map<String, Object?> encodeMetrics(int requestId, GenerationMetrics metrics) =>
    {
      'schemaVersion': outputSchemaVersion,
      'type': 'metrics',
      'requestId': requestId,
      'metrics': encodeMetricsObject(metrics),
    };

/// Encodes a `completed` event with the full [text] and final [metrics].
Map<String, Object?> encodeCompleted(
  int requestId,
  String text,
  GenerationMetrics metrics,
) => {
  'schemaVersion': outputSchemaVersion,
  'type': 'completed',
  'requestId': requestId,
  'text': text,
  'metrics': encodeMetricsObject(metrics),
};

/// Encodes a `cancelled` event with the partial [text] produced so far.
Map<String, Object?> encodeCancelled(int requestId, String text) => {
  'schemaVersion': outputSchemaVersion,
  'type': 'cancelled',
  'requestId': requestId,
  'text': text,
};

/// Encodes a `failed` event with the partial [text] and [failure] details.
Map<String, Object?> encodeFailed(
  int requestId,
  String text,
  InferenceFailure failure,
) => {
  'schemaVersion': outputSchemaVersion,
  'type': 'failed',
  'requestId': requestId,
  'text': text,
  'failure': encodeFailureObject(failure),
};

/// Encodes [metrics] as the nested metrics object.
Map<String, Object?> encodeMetricsObject(GenerationMetrics metrics) => {
  'promptTokenCount': metrics.promptTokenCount,
  'generatedTokenCount': metrics.generatedTokenCount,
  'promptEvalMs': metrics.promptEvalMs,
  'evalMs': metrics.evalMs,
  'tokensPerSecond': roundToTwoDecimals(metrics.tokensPerSecond),
  'promptTokensPerSecond': roundToTwoDecimals(metrics.promptTokensPerSecond),
};

/// Encodes [failure] as the nested failure object.
Map<String, Object?> encodeFailureObject(InferenceFailure failure) => {
  'code': failure.code.name,
  'message': failure.message,
  'details': failure.details,
};
