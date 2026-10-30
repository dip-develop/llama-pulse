// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_response_kind.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const WorkerResponseKind _$loaded = const WorkerResponseKind._('loaded');
const WorkerResponseKind _$unloaded = const WorkerResponseKind._('unloaded');
const WorkerResponseKind _$tokenBatch = const WorkerResponseKind._(
  'tokenBatch',
);
const WorkerResponseKind _$metrics = const WorkerResponseKind._('metrics');
const WorkerResponseKind _$completed = const WorkerResponseKind._('completed');
const WorkerResponseKind _$cancelled = const WorkerResponseKind._('cancelled');
const WorkerResponseKind _$failure = const WorkerResponseKind._('failure');
const WorkerResponseKind _$pong = const WorkerResponseKind._('pong');
const WorkerResponseKind _$disposed = const WorkerResponseKind._('disposed');

WorkerResponseKind _$valueOf(String name) {
  switch (name) {
    case 'loaded':
      return _$loaded;
    case 'unloaded':
      return _$unloaded;
    case 'tokenBatch':
      return _$tokenBatch;
    case 'metrics':
      return _$metrics;
    case 'completed':
      return _$completed;
    case 'cancelled':
      return _$cancelled;
    case 'failure':
      return _$failure;
    case 'pong':
      return _$pong;
    case 'disposed':
      return _$disposed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<WorkerResponseKind> _$values = BuiltSet<WorkerResponseKind>(
  const <WorkerResponseKind>[
    _$loaded,
    _$unloaded,
    _$tokenBatch,
    _$metrics,
    _$completed,
    _$cancelled,
    _$failure,
    _$pong,
    _$disposed,
  ],
);

Serializer<WorkerResponseKind> _$workerResponseKindSerializer =
    _$WorkerResponseKindSerializer();

class _$WorkerResponseKindSerializer
    implements PrimitiveSerializer<WorkerResponseKind> {
  @override
  final Iterable<Type> types = const <Type>[WorkerResponseKind];
  @override
  final String wireName = 'WorkerResponseKind';

  @override
  Object serialize(
    Serializers serializers,
    WorkerResponseKind object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  WorkerResponseKind deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => WorkerResponseKind.valueOf(serialized as String);
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
