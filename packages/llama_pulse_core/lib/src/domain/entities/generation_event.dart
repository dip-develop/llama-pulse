import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'generation_event_kind.dart';
import 'generation_metrics.dart';
import 'inference_failure.dart';

part 'generation_event.g.dart';

/// One message in the inference event stream.
///
/// A single class with a [kind] is used instead of five subclasses because the
/// stream crosses an isolate boundary and is persisted as YAML/JSON: one wire
/// type keeps both contracts stable and avoids polymorphic serializers.
abstract class GenerationEvent
    implements Built<GenerationEvent, GenerationEventBuilder> {
  /// Discriminator describing which fields are meaningful.
  GenerationEventKind get kind;

  /// Identifier of the request this event belongs to.
  int get requestId;

  /// Text chunk for token events, empty otherwise.
  String get text;

  /// Final metrics, set on metrics and completed events.
  GenerationMetrics? get metrics;

  /// Failure payload, set on failed events.
  InferenceFailure? get failure;

  factory GenerationEvent([void Function(GenerationEventBuilder)? updates]) =
      _$GenerationEvent;

  /// Builds an event signalling that the request started.
  factory GenerationEvent.started(int requestId) => GenerationEvent(
    (b) => b
      ..kind = GenerationEventKind.started
      ..requestId = requestId
      ..text = '',
  );

  /// Builds an event carrying the next [text] chunk.
  factory GenerationEvent.token(int requestId, String text) => GenerationEvent(
    (b) => b
      ..kind = GenerationEventKind.token
      ..requestId = requestId
      ..text = text,
  );

  /// Builds an event carrying interim [metrics].
  factory GenerationEvent.metrics(int requestId, GenerationMetrics metrics) =>
      GenerationEvent(
        (b) => b
          ..kind = GenerationEventKind.metrics
          ..requestId = requestId
          ..text = ''
          ..metrics.replace(metrics),
      );

  /// Builds an event signalling successful completion with final [metrics].
  factory GenerationEvent.completed(int requestId, GenerationMetrics metrics) =>
      GenerationEvent(
        (b) => b
          ..kind = GenerationEventKind.completed
          ..requestId = requestId
          ..text = ''
          ..metrics.replace(metrics),
      );

  /// Builds an event signalling that the user cancelled the request.
  factory GenerationEvent.cancelled(int requestId) => GenerationEvent(
    (b) => b
      ..kind = GenerationEventKind.cancelled
      ..requestId = requestId
      ..text = '',
  );

  /// Builds an event carrying [failure] details.
  factory GenerationEvent.failed(int requestId, InferenceFailure failure) =>
      GenerationEvent(
        (b) => b
          ..kind = GenerationEventKind.failed
          ..requestId = requestId
          ..text = ''
          ..failure.replace(failure),
      );

  GenerationEvent._();

  static Serializer<GenerationEvent> get serializer =>
      _$generationEventSerializer;
}
