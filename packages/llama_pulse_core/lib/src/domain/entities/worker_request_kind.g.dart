// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_request_kind.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const WorkerRequestKind _$load = const WorkerRequestKind._('load');
const WorkerRequestKind _$generate = const WorkerRequestKind._('generate');
const WorkerRequestKind _$cancel = const WorkerRequestKind._('cancel');
const WorkerRequestKind _$unload = const WorkerRequestKind._('unload');
const WorkerRequestKind _$dispose = const WorkerRequestKind._('dispose');
const WorkerRequestKind _$ping = const WorkerRequestKind._('ping');

WorkerRequestKind _$valueOf(String name) {
  switch (name) {
    case 'load':
      return _$load;
    case 'generate':
      return _$generate;
    case 'cancel':
      return _$cancel;
    case 'unload':
      return _$unload;
    case 'dispose':
      return _$dispose;
    case 'ping':
      return _$ping;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<WorkerRequestKind> _$values = BuiltSet<WorkerRequestKind>(
  const <WorkerRequestKind>[
    _$load,
    _$generate,
    _$cancel,
    _$unload,
    _$dispose,
    _$ping,
  ],
);

Serializer<WorkerRequestKind> _$workerRequestKindSerializer =
    _$WorkerRequestKindSerializer();

class _$WorkerRequestKindSerializer
    implements PrimitiveSerializer<WorkerRequestKind> {
  @override
  final Iterable<Type> types = const <Type>[WorkerRequestKind];
  @override
  final String wireName = 'WorkerRequestKind';

  @override
  Object serialize(
    Serializers serializers,
    WorkerRequestKind object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  WorkerRequestKind deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => WorkerRequestKind.valueOf(serialized as String);
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
