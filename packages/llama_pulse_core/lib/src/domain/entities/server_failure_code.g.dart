// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_failure_code.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ServerFailureCode _$binaryNotFound = const ServerFailureCode._(
  'binaryNotFound',
);
const ServerFailureCode _$binaryNotExecutable = const ServerFailureCode._(
  'binaryNotExecutable',
);
const ServerFailureCode _$unsupportedVersion = const ServerFailureCode._(
  'unsupportedVersion',
);
const ServerFailureCode _$portInUse = const ServerFailureCode._('portInUse');
const ServerFailureCode _$modelNotFound = const ServerFailureCode._(
  'modelNotFound',
);
const ServerFailureCode _$invalidConfig = const ServerFailureCode._(
  'invalidConfig',
);
const ServerFailureCode _$startupTimeout = const ServerFailureCode._(
  'startupTimeout',
);
const ServerFailureCode _$processExited = const ServerFailureCode._(
  'processExited',
);
const ServerFailureCode _$healthCheckFailed = const ServerFailureCode._(
  'healthCheckFailed',
);
const ServerFailureCode _$httpError = const ServerFailureCode._('httpError');
const ServerFailureCode _$stateUnreadable = const ServerFailureCode._(
  'stateUnreadable',
);
const ServerFailureCode _$unknown = const ServerFailureCode._('unknown');

ServerFailureCode _$valueOf(String name) {
  switch (name) {
    case 'binaryNotFound':
      return _$binaryNotFound;
    case 'binaryNotExecutable':
      return _$binaryNotExecutable;
    case 'unsupportedVersion':
      return _$unsupportedVersion;
    case 'portInUse':
      return _$portInUse;
    case 'modelNotFound':
      return _$modelNotFound;
    case 'invalidConfig':
      return _$invalidConfig;
    case 'startupTimeout':
      return _$startupTimeout;
    case 'processExited':
      return _$processExited;
    case 'healthCheckFailed':
      return _$healthCheckFailed;
    case 'httpError':
      return _$httpError;
    case 'stateUnreadable':
      return _$stateUnreadable;
    case 'unknown':
      return _$unknown;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ServerFailureCode> _$values = BuiltSet<ServerFailureCode>(
  const <ServerFailureCode>[
    _$binaryNotFound,
    _$binaryNotExecutable,
    _$unsupportedVersion,
    _$portInUse,
    _$modelNotFound,
    _$invalidConfig,
    _$startupTimeout,
    _$processExited,
    _$healthCheckFailed,
    _$httpError,
    _$stateUnreadable,
    _$unknown,
  ],
);

Serializer<ServerFailureCode> _$serverFailureCodeSerializer =
    _$ServerFailureCodeSerializer();

class _$ServerFailureCodeSerializer
    implements PrimitiveSerializer<ServerFailureCode> {
  @override
  final Iterable<Type> types = const <Type>[ServerFailureCode];
  @override
  final String wireName = 'ServerFailureCode';

  @override
  Object serialize(
    Serializers serializers,
    ServerFailureCode object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  ServerFailureCode deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ServerFailureCode.valueOf(serialized as String);
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
