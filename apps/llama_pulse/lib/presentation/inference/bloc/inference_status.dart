import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'inference_status.g.dart';

/// Lifecycle of the inference workspace.
class InferenceStatus extends EnumClass {
  /// Nothing is loaded and no generation has run.
  static const InferenceStatus initial = _$initial;

  /// The engine is loading the configured model.
  static const InferenceStatus loadingModel = _$loadingModel;

  /// A model is loaded and ready for a prompt.
  static const InferenceStatus modelReady = _$modelReady;

  /// Tokens are being generated.
  static const InferenceStatus generating = _$generating;

  /// The user cancelled and the engine has not acknowledged it yet.
  static const InferenceStatus cancelling = _$cancelling;

  /// The last action failed; see the state failure.
  static const InferenceStatus failure = _$failure;

  const InferenceStatus._(super.name);

  /// All statuses, in lifecycle order.
  static BuiltSet<InferenceStatus> get values => _$values;

  /// Looks up a status by its wire name.
  static InferenceStatus valueOf(String name) => _$valueOf(name);

  static Serializer<InferenceStatus> get serializer =>
      _$inferenceStatusSerializer;
}
