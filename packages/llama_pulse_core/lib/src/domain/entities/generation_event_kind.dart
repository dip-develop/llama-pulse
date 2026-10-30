import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'generation_event_kind.g.dart';

/// Kind discriminator carried by every generation event.
class GenerationEventKind extends EnumClass {
  /// The request was accepted and started.
  static const GenerationEventKind started = _$started;

  /// A chunk of generated text is available.
  static const GenerationEventKind token = _$token;

  /// Final token and timing metrics are available.
  static const GenerationEventKind metrics = _$metrics;

  /// The request finished successfully.
  static const GenerationEventKind completed = _$completed;

  /// The request was cancelled by the user.
  static const GenerationEventKind cancelled = _$cancelled;

  /// The request failed; see the event failure.
  static const GenerationEventKind failed = _$failed;

  const GenerationEventKind._(super.name);

  /// All kinds, in protocol order.
  static BuiltSet<GenerationEventKind> get values => _$values;

  /// Looks up a kind by its wire name.
  static GenerationEventKind valueOf(String name) => _$valueOf(name);

  static Serializer<GenerationEventKind> get serializer =>
      _$generationEventKindSerializer;
}
