import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'generation_metrics.g.dart';

/// Token counts and timings reported for one request.
abstract class GenerationMetrics
    implements Built<GenerationMetrics, GenerationMetricsBuilder> {
  /// Number of tokens in the prompt.
  int get promptTokenCount;

  /// Number of tokens produced by the model.
  int get generatedTokenCount;

  /// Milliseconds spent evaluating the prompt.
  int get promptEvalMs;

  /// Milliseconds spent generating the response.
  int get evalMs;

  /// Generated tokens per second, or zero when no time was measured.
  double get tokensPerSecond =>
      evalMs <= 0 ? 0 : generatedTokenCount * 1000 / evalMs;

  /// Prompt tokens per second, or zero when no time was measured.
  double get promptTokensPerSecond =>
      promptEvalMs <= 0 ? 0 : promptTokenCount * 1000 / promptEvalMs;

  factory GenerationMetrics([
    void Function(GenerationMetricsBuilder)? updates,
  ]) = _$GenerationMetrics;

  GenerationMetrics._();

  static Serializer<GenerationMetrics> get serializer =>
      _$generationMetricsSerializer;
}
