// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_status.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const InferenceStatus _$initial = const InferenceStatus._('initial');
const InferenceStatus _$loadingModel = const InferenceStatus._('loadingModel');
const InferenceStatus _$modelReady = const InferenceStatus._('modelReady');
const InferenceStatus _$generating = const InferenceStatus._('generating');
const InferenceStatus _$cancelling = const InferenceStatus._('cancelling');
const InferenceStatus _$failure = const InferenceStatus._('failure');

InferenceStatus _$valueOf(String name) {
  switch (name) {
    case 'initial':
      return _$initial;
    case 'loadingModel':
      return _$loadingModel;
    case 'modelReady':
      return _$modelReady;
    case 'generating':
      return _$generating;
    case 'cancelling':
      return _$cancelling;
    case 'failure':
      return _$failure;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<InferenceStatus> _$values = BuiltSet<InferenceStatus>(
  const <InferenceStatus>[
    _$initial,
    _$loadingModel,
    _$modelReady,
    _$generating,
    _$cancelling,
    _$failure,
  ],
);

Serializer<InferenceStatus> _$inferenceStatusSerializer =
    _$InferenceStatusSerializer();

class _$InferenceStatusSerializer
    implements PrimitiveSerializer<InferenceStatus> {
  @override
  final Iterable<Type> types = const <Type>[InferenceStatus];
  @override
  final String wireName = 'InferenceStatus';

  @override
  Object serialize(
    Serializers serializers,
    InferenceStatus object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  InferenceStatus deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => InferenceStatus.valueOf(serialized as String);
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
