import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'inference_failure_code.dart';

part 'inference_failure.g.dart';

/// Structured description of a failed inference request.
///
/// Deliberately not an exception: it is data carried across the isolate
/// boundary, not a value that is thrown.
abstract class InferenceFailure
    implements Built<InferenceFailure, InferenceFailureBuilder> {
  /// Classified reason for the failure.
  InferenceFailureCode get code;

  /// Human-readable message suitable for the UI.
  String get message;

  /// Optional engine output with technical detail.
  String? get details;

  factory InferenceFailure([void Function(InferenceFailureBuilder)? updates]) =
      _$InferenceFailure;

  InferenceFailure._();

  static Serializer<InferenceFailure> get serializer =>
      _$inferenceFailureSerializer;
}
