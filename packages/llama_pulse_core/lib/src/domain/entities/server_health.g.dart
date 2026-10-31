// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_health.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ServerHealth _$unknown = const ServerHealth._('unknown');
const ServerHealth _$ok = const ServerHealth._('ok');
const ServerHealth _$loading = const ServerHealth._('loading');
const ServerHealth _$degraded = const ServerHealth._('degraded');
const ServerHealth _$unreachable = const ServerHealth._('unreachable');

ServerHealth _$valueOf(String name) {
  switch (name) {
    case 'unknown':
      return _$unknown;
    case 'ok':
      return _$ok;
    case 'loading':
      return _$loading;
    case 'degraded':
      return _$degraded;
    case 'unreachable':
      return _$unreachable;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ServerHealth> _$values = BuiltSet<ServerHealth>(
  const <ServerHealth>[_$unknown, _$ok, _$loading, _$degraded, _$unreachable],
);

Serializer<ServerHealth> _$serverHealthSerializer = _$ServerHealthSerializer();

class _$ServerHealthSerializer implements PrimitiveSerializer<ServerHealth> {
  @override
  final Iterable<Type> types = const <Type>[ServerHealth];
  @override
  final String wireName = 'ServerHealth';

  @override
  Object serialize(
    Serializers serializers,
    ServerHealth object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  ServerHealth deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ServerHealth.valueOf(serialized as String);
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
