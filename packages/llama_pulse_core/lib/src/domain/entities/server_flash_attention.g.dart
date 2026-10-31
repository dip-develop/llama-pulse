// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_flash_attention.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ServerFlashAttention _$auto = const ServerFlashAttention._('auto');
const ServerFlashAttention _$on = const ServerFlashAttention._('on');
const ServerFlashAttention _$off = const ServerFlashAttention._('off');

ServerFlashAttention _$valueOf(String name) {
  switch (name) {
    case 'auto':
      return _$auto;
    case 'on':
      return _$on;
    case 'off':
      return _$off;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ServerFlashAttention> _$values = BuiltSet<ServerFlashAttention>(
  const <ServerFlashAttention>[_$auto, _$on, _$off],
);

Serializer<ServerFlashAttention> _$serverFlashAttentionSerializer =
    _$ServerFlashAttentionSerializer();

class _$ServerFlashAttentionSerializer
    implements PrimitiveSerializer<ServerFlashAttention> {
  @override
  final Iterable<Type> types = const <Type>[ServerFlashAttention];
  @override
  final String wireName = 'ServerFlashAttention';

  @override
  Object serialize(
    Serializers serializers,
    ServerFlashAttention object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  ServerFlashAttention deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => ServerFlashAttention.valueOf(serialized as String);
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
