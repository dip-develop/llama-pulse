import 'package:built_value/serializer.dart';

import '../../domain/runtime/runtime_backend.dart';
import '../../domain/runtime/runtime_platform.dart';

/// Serializes [RuntimeBackend] by its stable [RuntimeBackend.id].
///
/// The backend and platform enums predate built_value's `EnumClass`; registered
/// primitive serializers keep the generated entity serializers working without
/// changing the enums the rest of the core uses.
final class RuntimeBackendSerializer
    implements PrimitiveSerializer<RuntimeBackend> {
  /// Creates the serializer.
  const RuntimeBackendSerializer();

  @override
  Iterable<Type> get types => const <Type>[RuntimeBackend];

  @override
  String get wireName => 'RuntimeBackend';

  @override
  Object serialize(
    Serializers serializers,
    RuntimeBackend object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.id;

  @override
  RuntimeBackend deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    if (serialized is RuntimeBackend) {
      return serialized;
    }
    if (serialized is! String) {
      throw StateError('RuntimeBackend must serialize as a string');
    }
    final backend = RuntimeBackend.fromId(serialized);
    if (backend == null) {
      throw StateError('Unknown runtime backend "$serialized"');
    }
    return backend;
  }
}

/// Serializes [RuntimePlatform] by its stable [RuntimePlatform.id].
final class RuntimePlatformSerializer
    implements PrimitiveSerializer<RuntimePlatform> {
  /// Creates the serializer.
  const RuntimePlatformSerializer();

  @override
  Iterable<Type> get types => const <Type>[RuntimePlatform];

  @override
  String get wireName => 'RuntimePlatform';

  @override
  Object serialize(
    Serializers serializers,
    RuntimePlatform object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.id;

  @override
  RuntimePlatform deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    if (serialized is RuntimePlatform) {
      return serialized;
    }
    if (serialized is! String) {
      throw StateError('RuntimePlatform must serialize as a string');
    }
    final platform = RuntimePlatform.fromId(serialized);
    if (platform == null) {
      throw StateError('Unknown runtime platform "$serialized"');
    }
    return platform;
  }
}
