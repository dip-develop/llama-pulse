import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'chat_message.dart';
import 'model_params.dart';

part 'generation_request.g.dart';

/// A single prompt submitted to the inference engine.
abstract class GenerationRequest
    implements Built<GenerationRequest, GenerationRequestBuilder> {
  /// Monotonic identifier used to correlate events with this request.
  int get requestId;

  /// Prompt text sent to the model.
  ///
  /// When [messages] is empty this is the single `user` message. When it is
  /// not, it carries the final user text for callers that report or echo a
  /// prompt (the stub engine and the human output), while the native session
  /// renders [messages].
  String get prompt;

  /// Conversation sent to the model, oldest first.
  ///
  /// Empty means the request is the single user message in [prompt]; that is
  /// the shape every caller used before chat messages existed.
  BuiltList<ChatMessage> get messages;

  /// The messages actually rendered: [messages], or [prompt] as one `user`
  /// message when the list is empty.
  List<ChatMessage> get effectiveMessages => messages.isNotEmpty
      ? messages.toList(growable: false)
      : <ChatMessage>[ChatMessage.create(role: 'user', content: prompt)];

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
    List<ChatMessage> messages = const <ChatMessage>[],
  }) => GenerationRequest(
    (b) => b
      ..requestId = requestId
      ..prompt = prompt
      ..messages = BuiltList<ChatMessage>(messages).toBuilder()
      ..params.replace(params)
      ..stream = stream,
  );

  GenerationRequest._();

  static Serializer<GenerationRequest> get serializer =>
      _$generationRequestSerializer;
}
