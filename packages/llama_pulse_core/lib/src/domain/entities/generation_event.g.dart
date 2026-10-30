// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generation_event.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<GenerationEvent> _$generationEventSerializer =
    _$GenerationEventSerializer();

class _$GenerationEventSerializer
    implements StructuredSerializer<GenerationEvent> {
  @override
  final Iterable<Type> types = const [GenerationEvent, _$GenerationEvent];
  @override
  final String wireName = 'GenerationEvent';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    GenerationEvent object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'kind',
      serializers.serialize(
        object.kind,
        specifiedType: const FullType(GenerationEventKind),
      ),
      'requestId',
      serializers.serialize(
        object.requestId,
        specifiedType: const FullType(int),
      ),
      'text',
      serializers.serialize(object.text, specifiedType: const FullType(String)),
    ];
    Object? value;
    value = object.metrics;
    if (value != null) {
      result
        ..add('metrics')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(GenerationMetrics),
          ),
        );
    }
    value = object.failure;
    if (value != null) {
      result
        ..add('failure')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(InferenceFailure),
          ),
        );
    }
    return result;
  }

  @override
  GenerationEvent deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GenerationEventBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'kind':
          result.kind =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(GenerationEventKind),
                  )!
                  as GenerationEventKind;
          break;
        case 'requestId':
          result.requestId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'text':
          result.text =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'metrics':
          result.metrics.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(GenerationMetrics),
                )!
                as GenerationMetrics,
          );
          break;
        case 'failure':
          result.failure.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(InferenceFailure),
                )!
                as InferenceFailure,
          );
          break;
      }
    }

    return result.build();
  }
}

class _$GenerationEvent extends GenerationEvent {
  @override
  final GenerationEventKind kind;
  @override
  final int requestId;
  @override
  final String text;
  @override
  final GenerationMetrics? metrics;
  @override
  final InferenceFailure? failure;

  factory _$GenerationEvent([void Function(GenerationEventBuilder)? updates]) =>
      (GenerationEventBuilder()..update(updates))._build();

  _$GenerationEvent._({
    required this.kind,
    required this.requestId,
    required this.text,
    this.metrics,
    this.failure,
  }) : super._();
  @override
  GenerationEvent rebuild(void Function(GenerationEventBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GenerationEventBuilder toBuilder() => GenerationEventBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GenerationEvent &&
        kind == other.kind &&
        requestId == other.requestId &&
        text == other.text &&
        metrics == other.metrics &&
        failure == other.failure;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, requestId.hashCode);
    _$hash = $jc(_$hash, text.hashCode);
    _$hash = $jc(_$hash, metrics.hashCode);
    _$hash = $jc(_$hash, failure.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GenerationEvent')
          ..add('kind', kind)
          ..add('requestId', requestId)
          ..add('text', text)
          ..add('metrics', metrics)
          ..add('failure', failure))
        .toString();
  }
}

class GenerationEventBuilder
    implements Builder<GenerationEvent, GenerationEventBuilder> {
  _$GenerationEvent? _$v;

  GenerationEventKind? _kind;
  GenerationEventKind? get kind => _$this._kind;
  set kind(GenerationEventKind? kind) => _$this._kind = kind;

  int? _requestId;
  int? get requestId => _$this._requestId;
  set requestId(int? requestId) => _$this._requestId = requestId;

  String? _text;
  String? get text => _$this._text;
  set text(String? text) => _$this._text = text;

  GenerationMetricsBuilder? _metrics;
  GenerationMetricsBuilder get metrics =>
      _$this._metrics ??= GenerationMetricsBuilder();
  set metrics(GenerationMetricsBuilder? metrics) => _$this._metrics = metrics;

  InferenceFailureBuilder? _failure;
  InferenceFailureBuilder get failure =>
      _$this._failure ??= InferenceFailureBuilder();
  set failure(InferenceFailureBuilder? failure) => _$this._failure = failure;

  GenerationEventBuilder();

  GenerationEventBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _requestId = $v.requestId;
      _text = $v.text;
      _metrics = $v.metrics?.toBuilder();
      _failure = $v.failure?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GenerationEvent other) {
    _$v = other as _$GenerationEvent;
  }

  @override
  void update(void Function(GenerationEventBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GenerationEvent build() => _build();

  _$GenerationEvent _build() {
    _$GenerationEvent _$result;
    try {
      _$result =
          _$v ??
          _$GenerationEvent._(
            kind: BuiltValueNullFieldError.checkNotNull(
              kind,
              r'GenerationEvent',
              'kind',
            ),
            requestId: BuiltValueNullFieldError.checkNotNull(
              requestId,
              r'GenerationEvent',
              'requestId',
            ),
            text: BuiltValueNullFieldError.checkNotNull(
              text,
              r'GenerationEvent',
              'text',
            ),
            metrics: _metrics?.build(),
            failure: _failure?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'metrics';
        _metrics?.build();
        _$failedField = 'failure';
        _failure?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'GenerationEvent',
          _$failedField,
          e.toString(),
        );
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
