// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generation_event_kind.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const GenerationEventKind _$started = const GenerationEventKind._('started');
const GenerationEventKind _$token = const GenerationEventKind._('token');
const GenerationEventKind _$metrics = const GenerationEventKind._('metrics');
const GenerationEventKind _$completed = const GenerationEventKind._(
  'completed',
);
const GenerationEventKind _$cancelled = const GenerationEventKind._(
  'cancelled',
);
const GenerationEventKind _$failed = const GenerationEventKind._('failed');

GenerationEventKind _$valueOf(String name) {
  switch (name) {
    case 'started':
      return _$started;
    case 'token':
      return _$token;
    case 'metrics':
      return _$metrics;
    case 'completed':
      return _$completed;
    case 'cancelled':
      return _$cancelled;
    case 'failed':
      return _$failed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<GenerationEventKind> _$values = BuiltSet<GenerationEventKind>(
  const <GenerationEventKind>[
    _$started,
    _$token,
    _$metrics,
    _$completed,
    _$cancelled,
    _$failed,
  ],
);

Serializer<GenerationEventKind> _$generationEventKindSerializer =
    _$GenerationEventKindSerializer();

class _$GenerationEventKindSerializer
    implements PrimitiveSerializer<GenerationEventKind> {
  @override
  final Iterable<Type> types = const <Type>[GenerationEventKind];
  @override
  final String wireName = 'GenerationEventKind';

  @override
  Object serialize(
    Serializers serializers,
    GenerationEventKind object, {
    FullType specifiedType = FullType.unspecified,
  }) => object.name;

  @override
  GenerationEventKind deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) => GenerationEventKind.valueOf(serialized as String);
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
