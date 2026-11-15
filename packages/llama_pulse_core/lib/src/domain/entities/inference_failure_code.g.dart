// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_failure_code.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const InferenceFailureCode _$engineUnavailable = const InferenceFailureCode._(
  'engineUnavailable',
);
const InferenceFailureCode _$modelNotFound = const InferenceFailureCode._(
  'modelNotFound',
);
const InferenceFailureCode _$invalidParams = const InferenceFailureCode._(
  'invalidParams',
);
const InferenceFailureCode _$engineBusy = const InferenceFailureCode._(
  'engineBusy',
);
const InferenceFailureCode _$cancelled = const InferenceFailureCode._(
  'cancelled',
);
const InferenceFailureCode _$nativeError = const InferenceFailureCode._(
  'nativeError',
);
const InferenceFailureCode _$libraryNotFound = const InferenceFailureCode._(
  'libraryNotFound',
);
const InferenceFailureCode _$libraryVersionMismatch =
    const InferenceFailureCode._('libraryVersionMismatch');
const InferenceFailureCode _$paramsLoadFailed = const InferenceFailureCode._(
  'paramsLoadFailed',
);
const InferenceFailureCode _$paramsSaveFailed = const InferenceFailureCode._(
  'paramsSaveFailed',
);
const InferenceFailureCode _$modelPathRequired = const InferenceFailureCode._(
  'modelPathRequired',
);
const InferenceFailureCode _$modelLoadFailed = const InferenceFailureCode._(
  'modelLoadFailed',
);
const InferenceFailureCode _$promptRequired = const InferenceFailureCode._(
  'promptRequired',
);
const InferenceFailureCode _$modelNotReady = const InferenceFailureCode._(
  'modelNotReady',
);
const InferenceFailureCode _$cancelFailed = const InferenceFailureCode._(
  'cancelFailed',
);
const InferenceFailureCode _$unloadFailed = const InferenceFailureCode._(
  'unloadFailed',
);
const InferenceFailureCode _$streamEnded = const InferenceFailureCode._(
  'streamEnded',
);
const InferenceFailureCode _$unknown = const InferenceFailureCode._('unknown');

InferenceFailureCode _$valueOf(String name) {
  switch (name) {
    case 'engineUnavailable':
      return _$engineUnavailable;
    case 'modelNotFound':
      return _$modelNotFound;
    case 'invalidParams':
      return _$invalidParams;
    case 'engineBusy':
      return _$engineBusy;
    case 'cancelled':
      return _$cancelled;
    case 'nativeError':
      return _$nativeError;
    case 'libraryNotFound':
      return _$libraryNotFound;
    case 'libraryVersionMismatch':
      return _$libraryVersionMismatch;
    case 'paramsLoadFailed':
      return _$paramsLoadFailed;
    case 'paramsSaveFailed':
      return _$paramsSaveFailed;
    case 'modelPathRequired':
      return _$modelPathRequired;
    case 'modelLoadFailed':
      return _$modelLoadFailed;
    case 'promptRequired':
      return _$promptRequired;
    case 'modelNotReady':
      return _$modelNotReady;
    case 'cancelFailed':
      return _$cancelFailed;
    case 'unloadFailed':
      return _$unloadFailed;
    case 'streamEnded':
      return _$streamEnded;
    case 'unknown':
      return _$unknown;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<InferenceFailureCode> _$values = BuiltSet<InferenceFailureCode>(
  const <InferenceFailureCode>[
    _$engineUnavailable,
    _$modelNotFound,
    _$invalidParams,
    _$engineBusy,
    _$cancelled,
    _$nativeError,
    _$libraryNotFound,
    _$libraryVersionMismatch,
    _$paramsLoadFailed,
    _$paramsSaveFailed,
    _$modelPathRequired,
    _$modelLoadFailed,
    _$promptRequired,
    _$modelNotReady,
    _$cancelFailed,
    _$unloadFailed,
    _$streamEnded,
    _$unknown,
  ],
);

Serializer<InferenceFailureCode> _$inferenceFailureCodeSerializer =
    _$InferenceFailureCodeSerializer();

class _$InferenceFailureCodeSerializer
    implements PrimitiveSerializer<InferenceFailureCode> {
  @override
  final Iterable<Type> types = const <Type>[InferenceFailureCode];
  @override
  final String wireName = 'InferenceFailureCode';

  @override
  Object serialize(
    Serializers serializers,
    InferenceFailureCode object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  InferenceFailureCode deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => InferenceFailureCode.valueOf(serialized as String);
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
