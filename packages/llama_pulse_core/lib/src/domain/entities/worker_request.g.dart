// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<WorkerRequest> _$workerRequestSerializer =
    _$WorkerRequestSerializer();

class _$WorkerRequestSerializer implements StructuredSerializer<WorkerRequest> {
  @override
  final Iterable<Type> types = const [WorkerRequest, _$WorkerRequest];
  @override
  final String wireName = 'WorkerRequest';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    WorkerRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'kind',
      serializers.serialize(
        object.kind,
        specifiedType: const FullType(WorkerRequestKind),
      ),
      'requestId',
      serializers.serialize(
        object.requestId,
        specifiedType: const FullType(int),
      ),
    ];
    Object? value;
    value = object.targetRequestId;
    if (value != null) {
      result
        ..add('targetRequestId')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.params;
    if (value != null) {
      result
        ..add('params')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(ModelParams),
          ),
        );
    }
    value = object.prompt;
    if (value != null) {
      result
        ..add('prompt')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.maxTokens;
    if (value != null) {
      result
        ..add('maxTokens')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    return result;
  }

  @override
  WorkerRequest deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = WorkerRequestBuilder();

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
                    specifiedType: const FullType(WorkerRequestKind),
                  )!
                  as WorkerRequestKind;
          break;
        case 'requestId':
          result.requestId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'targetRequestId':
          result.targetRequestId = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'params':
          result.params.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(ModelParams),
                )!
                as ModelParams,
          );
          break;
        case 'prompt':
          result.prompt = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'maxTokens':
          result.maxTokens = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
      }
    }

    return result.build();
  }
}

class _$WorkerRequest extends WorkerRequest {
  @override
  final WorkerRequestKind kind;
  @override
  final int requestId;
  @override
  final int? targetRequestId;
  @override
  final ModelParams? params;
  @override
  final String? prompt;
  @override
  final int? maxTokens;

  factory _$WorkerRequest([void Function(WorkerRequestBuilder)? updates]) =>
      (WorkerRequestBuilder()..update(updates))._build();

  _$WorkerRequest._({
    required this.kind,
    required this.requestId,
    this.targetRequestId,
    this.params,
    this.prompt,
    this.maxTokens,
  }) : super._();
  @override
  WorkerRequest rebuild(void Function(WorkerRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  WorkerRequestBuilder toBuilder() => WorkerRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is WorkerRequest &&
        kind == other.kind &&
        requestId == other.requestId &&
        targetRequestId == other.targetRequestId &&
        params == other.params &&
        prompt == other.prompt &&
        maxTokens == other.maxTokens;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, requestId.hashCode);
    _$hash = $jc(_$hash, targetRequestId.hashCode);
    _$hash = $jc(_$hash, params.hashCode);
    _$hash = $jc(_$hash, prompt.hashCode);
    _$hash = $jc(_$hash, maxTokens.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'WorkerRequest')
          ..add('kind', kind)
          ..add('requestId', requestId)
          ..add('targetRequestId', targetRequestId)
          ..add('params', params)
          ..add('prompt', prompt)
          ..add('maxTokens', maxTokens))
        .toString();
  }
}

class WorkerRequestBuilder
    implements Builder<WorkerRequest, WorkerRequestBuilder> {
  _$WorkerRequest? _$v;

  WorkerRequestKind? _kind;
  WorkerRequestKind? get kind => _$this._kind;
  set kind(WorkerRequestKind? kind) => _$this._kind = kind;

  int? _requestId;
  int? get requestId => _$this._requestId;
  set requestId(int? requestId) => _$this._requestId = requestId;

  int? _targetRequestId;
  int? get targetRequestId => _$this._targetRequestId;
  set targetRequestId(int? targetRequestId) =>
      _$this._targetRequestId = targetRequestId;

  ModelParamsBuilder? _params;
  ModelParamsBuilder get params => _$this._params ??= ModelParamsBuilder();
  set params(ModelParamsBuilder? params) => _$this._params = params;

  String? _prompt;
  String? get prompt => _$this._prompt;
  set prompt(String? prompt) => _$this._prompt = prompt;

  int? _maxTokens;
  int? get maxTokens => _$this._maxTokens;
  set maxTokens(int? maxTokens) => _$this._maxTokens = maxTokens;

  WorkerRequestBuilder();

  WorkerRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _requestId = $v.requestId;
      _targetRequestId = $v.targetRequestId;
      _params = $v.params?.toBuilder();
      _prompt = $v.prompt;
      _maxTokens = $v.maxTokens;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(WorkerRequest other) {
    _$v = other as _$WorkerRequest;
  }

  @override
  void update(void Function(WorkerRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  WorkerRequest build() => _build();

  _$WorkerRequest _build() {
    _$WorkerRequest _$result;
    try {
      _$result =
          _$v ??
          _$WorkerRequest._(
            kind: BuiltValueNullFieldError.checkNotNull(
              kind,
              r'WorkerRequest',
              'kind',
            ),
            requestId: BuiltValueNullFieldError.checkNotNull(
              requestId,
              r'WorkerRequest',
              'requestId',
            ),
            targetRequestId: targetRequestId,
            params: _params?.build(),
            prompt: prompt,
            maxTokens: maxTokens,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'params';
        _params?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'WorkerRequest',
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
