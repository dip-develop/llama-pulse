import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'model_params.dart';

part 'generation_request.g.dart';

/// A single prompt submitted to the inference engine.
abstract class GenerationRequest
    implements Built<GenerationRequest, GenerationRequestBuilder> {
  /// Monotonic identifier used to correlate events with this request.
  int get requestId;

  /// Prompt text sent to the model.
  String get prompt;

  /// Parameters applied to this request.
  ModelParams get params;

  /// Whether the engine emits token events instead of one final block.
  bool get stream;

  factory GenerationRequest([
    void Function(GenerationRequestBuilder)? updates,
  ]) = _$GenerationRequest;

  /// Builds a request; [stream] defaults to token-by-token output.
  factory GenerationRequest.create({
    required int requestId,
    required String prompt,
    required ModelParams params,
    bool stream = true,
  }) => GenerationRequest(
    (b) => b
      ..requestId = requestId
      ..prompt = prompt
      ..params.replace(params)
      ..stream = stream,
  );

  GenerationRequest._();

  static Serializer<GenerationRequest> get serializer =>
      _$generationRequestSerializer;
}
