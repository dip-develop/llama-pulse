// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_log_stream.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ServerLogStream _$stdout = const ServerLogStream._('stdout');
const ServerLogStream _$stderr = const ServerLogStream._('stderr');
const ServerLogStream _$supervisor = const ServerLogStream._('supervisor');

ServerLogStream _$valueOf(String name) {
  switch (name) {
    case 'stdout':
      return _$stdout;
    case 'stderr':
      return _$stderr;
    case 'supervisor':
      return _$supervisor;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ServerLogStream> _$values = BuiltSet<ServerLogStream>(
  const <ServerLogStream>[_$stdout, _$stderr, _$supervisor],
);

Serializer<ServerLogStream> _$serverLogStreamSerializer =
    _$ServerLogStreamSerializer();

class _$ServerLogStreamSerializer
    implements PrimitiveSerializer<ServerLogStream> {
  @override
  final Iterable<Type> types = const <Type>[ServerLogStream];
  @override
  final String wireName = 'ServerLogStream';

  @override
  Object serialize(
    Serializers serializers,
    ServerLogStream object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  ServerLogStream deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ServerLogStream.valueOf(serialized as String);
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
