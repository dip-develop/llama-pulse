// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generation_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<GenerationRequest> _$generationRequestSerializer =
    _$GenerationRequestSerializer();

class _$GenerationRequestSerializer
    implements StructuredSerializer<GenerationRequest> {
  @override
  final Iterable<Type> types = const [GenerationRequest, _$GenerationRequest];
  @override
  final String wireName = 'GenerationRequest';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    GenerationRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'requestId',
      serializers.serialize(
        object.requestId,
        specifiedType: const FullType(int),
      ),
      'prompt',
      serializers.serialize(
        object.prompt,
        specifiedType: const FullType(String),
      ),
      'params',
      serializers.serialize(
        object.params,
        specifiedType: const FullType(ModelParams),
      ),
      'stream',
      serializers.serialize(object.stream, specifiedType: const FullType(bool)),
    ];

    return result;
  }

  @override
  GenerationRequest deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GenerationRequestBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'requestId':
          result.requestId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'prompt':
          result.prompt =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
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
        case 'stream':
          result.stream =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
      }
    }

    return result.build();
  }
}

class _$GenerationRequest extends GenerationRequest {
  @override
  final int requestId;
  @override
  final String prompt;
  @override
  final ModelParams params;
  @override
  final bool stream;

  factory _$GenerationRequest([
    void Function(GenerationRequestBuilder)? updates,
  ]) => (GenerationRequestBuilder()..update(updates))._build();

  _$GenerationRequest._({
    required this.requestId,
    required this.prompt,
    required this.params,
    required this.stream,
  }) : super._();
  @override
  GenerationRequest rebuild(void Function(GenerationRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GenerationRequestBuilder toBuilder() =>
      GenerationRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GenerationRequest &&
        requestId == other.requestId &&
        prompt == other.prompt &&
        params == other.params &&
        stream == other.stream;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, requestId.hashCode);
    _$hash = $jc(_$hash, prompt.hashCode);
    _$hash = $jc(_$hash, params.hashCode);
    _$hash = $jc(_$hash, stream.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GenerationRequest')
          ..add('requestId', requestId)
          ..add('prompt', prompt)
          ..add('params', params)
          ..add('stream', stream))
        .toString();
  }
}

class GenerationRequestBuilder
    implements Builder<GenerationRequest, GenerationRequestBuilder> {
  _$GenerationRequest? _$v;

  int? _requestId;
  int? get requestId => _$this._requestId;
  set requestId(int? requestId) => _$this._requestId = requestId;

  String? _prompt;
  String? get prompt => _$this._prompt;
  set prompt(String? prompt) => _$this._prompt = prompt;

  ModelParamsBuilder? _params;
  ModelParamsBuilder get params => _$this._params ??= ModelParamsBuilder();
  set params(ModelParamsBuilder? params) => _$this._params = params;

  bool? _stream;
  bool? get stream => _$this._stream;
  set stream(bool? stream) => _$this._stream = stream;

  GenerationRequestBuilder();

  GenerationRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _requestId = $v.requestId;
      _prompt = $v.prompt;
      _params = $v.params.toBuilder();
      _stream = $v.stream;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GenerationRequest other) {
    _$v = other as _$GenerationRequest;
  }

  @override
  void update(void Function(GenerationRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GenerationRequest build() => _build();

  _$GenerationRequest _build() {
    _$GenerationRequest _$result;
    try {
      _$result =
          _$v ??
          _$GenerationRequest._(
            requestId: BuiltValueNullFieldError.checkNotNull(
              requestId,
              r'GenerationRequest',
              'requestId',
            ),
            prompt: BuiltValueNullFieldError.checkNotNull(
              prompt,
              r'GenerationRequest',
              'prompt',
            ),
            params: params.build(),
            stream: BuiltValueNullFieldError.checkNotNull(
              stream,
              r'GenerationRequest',
              'stream',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'params';
        params.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'GenerationRequest',
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
