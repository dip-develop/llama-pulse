import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'inference_failure_code.g.dart';

/// Machine-readable reason for an inference failure.
class InferenceFailureCode extends EnumClass {
  /// The native engine could not be loaded or started.
  static const InferenceFailureCode engineUnavailable = _$engineUnavailable;

  /// The configured model file is missing or unreadable.
  static const InferenceFailureCode modelNotFound = _$modelNotFound;

  /// The request parameters are outside the allowed ranges.
  static const InferenceFailureCode invalidParams = _$invalidParams;

  /// The engine is already handling another request.
  static const InferenceFailureCode engineBusy = _$engineBusy;

  /// The request was cancelled before completion.
  static const InferenceFailureCode cancelled = _$cancelled;

  /// The native layer reported an unexpected error.
  static const InferenceFailureCode nativeError = _$nativeError;

  /// The failure could not be classified.
  static const InferenceFailureCode unknown = _$unknown;

  const InferenceFailureCode._(super.name);

  /// All codes, in protocol order.
  static BuiltSet<InferenceFailureCode> get values => _$values;

  /// Looks up a code by its wire name.
  static InferenceFailureCode valueOf(String name) => _$valueOf(name);

  static Serializer<InferenceFailureCode> get serializer =>
      _$inferenceFailureCodeSerializer;
}
