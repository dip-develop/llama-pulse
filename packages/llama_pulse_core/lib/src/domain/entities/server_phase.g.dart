// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_phase.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ServerPhase _$stopped = const ServerPhase._('stopped');
const ServerPhase _$starting = const ServerPhase._('starting');
const ServerPhase _$running = const ServerPhase._('running');
const ServerPhase _$stopping = const ServerPhase._('stopping');
const ServerPhase _$failed = const ServerPhase._('failed');

ServerPhase _$valueOf(String name) {
  switch (name) {
    case 'stopped':
      return _$stopped;
    case 'starting':
      return _$starting;
    case 'running':
      return _$running;
    case 'stopping':
      return _$stopping;
    case 'failed':
      return _$failed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ServerPhase> _$values = BuiltSet<ServerPhase>(
  const <ServerPhase>[_$stopped, _$starting, _$running, _$stopping, _$failed],
);

Serializer<ServerPhase> _$serverPhaseSerializer = _$ServerPhaseSerializer();

class _$ServerPhaseSerializer implements PrimitiveSerializer<ServerPhase> {
  @override
  final Iterable<Type> types = const <Type>[ServerPhase];
  @override
  final String wireName = 'ServerPhase';

  @override
  Object serialize(
    Serializers serializers,
    ServerPhase object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  ServerPhase deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ServerPhase.valueOf(serialized as String);
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
