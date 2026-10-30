// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<WorkerResponse> _$workerResponseSerializer =
    _$WorkerResponseSerializer();

class _$WorkerResponseSerializer
    implements StructuredSerializer<WorkerResponse> {
  @override
  final Iterable<Type> types = const [WorkerResponse, _$WorkerResponse];
  @override
  final String wireName = 'WorkerResponse';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    WorkerResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'kind',
      serializers.serialize(
        object.kind,
        specifiedType: const FullType(WorkerResponseKind),
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
  WorkerResponse deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = WorkerResponseBuilder();

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
                    specifiedType: const FullType(WorkerResponseKind),
                  )!
                  as WorkerResponseKind;
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

class _$WorkerResponse extends WorkerResponse {
  @override
  final WorkerResponseKind kind;
  @override
  final int requestId;
  @override
  final String text;
  @override
  final GenerationMetrics? metrics;
  @override
  final InferenceFailure? failure;

  factory _$WorkerResponse([void Function(WorkerResponseBuilder)? updates]) =>
      (WorkerResponseBuilder()..update(updates))._build();

  _$WorkerResponse._({
    required this.kind,
    required this.requestId,
    required this.text,
    this.metrics,
    this.failure,
  }) : super._();
  @override
  WorkerResponse rebuild(void Function(WorkerResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  WorkerResponseBuilder toBuilder() => WorkerResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is WorkerResponse &&
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
    return (newBuiltValueToStringHelper(r'WorkerResponse')
          ..add('kind', kind)
          ..add('requestId', requestId)
          ..add('text', text)
          ..add('metrics', metrics)
          ..add('failure', failure))
        .toString();
  }
}

class WorkerResponseBuilder
    implements Builder<WorkerResponse, WorkerResponseBuilder> {
  _$WorkerResponse? _$v;

  WorkerResponseKind? _kind;
  WorkerResponseKind? get kind => _$this._kind;
  set kind(WorkerResponseKind? kind) => _$this._kind = kind;

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

  WorkerResponseBuilder();

  WorkerResponseBuilder get _$this {
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
  void replace(WorkerResponse other) {
    _$v = other as _$WorkerResponse;
  }

  @override
  void update(void Function(WorkerResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  WorkerResponse build() => _build();

  _$WorkerResponse _build() {
    _$WorkerResponse _$result;
    try {
      _$result =
          _$v ??
          _$WorkerResponse._(
            kind: BuiltValueNullFieldError.checkNotNull(
              kind,
              r'WorkerResponse',
              'kind',
            ),
            requestId: BuiltValueNullFieldError.checkNotNull(
              requestId,
              r'WorkerResponse',
              'requestId',
            ),
            text: BuiltValueNullFieldError.checkNotNull(
              text,
              r'WorkerResponse',
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
          r'WorkerResponse',
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
