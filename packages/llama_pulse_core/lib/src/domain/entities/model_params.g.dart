// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_params.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ModelParams> _$modelParamsSerializer = _$ModelParamsSerializer();

class _$ModelParamsSerializer implements StructuredSerializer<ModelParams> {
  @override
  final Iterable<Type> types = const [ModelParams, _$ModelParams];
  @override
  final String wireName = 'ModelParams';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    ModelParams object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'modelPath',
      serializers.serialize(
        object.modelPath,
        specifiedType: const FullType(String),
      ),
      'contextSize',
      serializers.serialize(
        object.contextSize,
        specifiedType: const FullType(int),
      ),
      'gpuLayers',
      serializers.serialize(
        object.gpuLayers,
        specifiedType: const FullType(int),
      ),
      'threads',
      serializers.serialize(object.threads, specifiedType: const FullType(int)),
      'temperature',
      serializers.serialize(
        object.temperature,
        specifiedType: const FullType(double),
      ),
      'topP',
      serializers.serialize(object.topP, specifiedType: const FullType(double)),
      'topK',
      serializers.serialize(object.topK, specifiedType: const FullType(int)),
      'maxTokens',
      serializers.serialize(
        object.maxTokens,
        specifiedType: const FullType(int),
      ),
    ];

    return result;
  }

  @override
  ModelParams deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ModelParamsBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'modelPath':
          result.modelPath =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'contextSize':
          result.contextSize =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'gpuLayers':
          result.gpuLayers =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'threads':
          result.threads =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'temperature':
          result.temperature =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(double),
                  )!
                  as double;
          break;
        case 'topP':
          result.topP =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(double),
                  )!
                  as double;
          break;
        case 'topK':
          result.topK =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'maxTokens':
          result.maxTokens =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
      }
    }

    return result.build();
  }
}

class _$ModelParams extends ModelParams {
  @override
  final String modelPath;
  @override
  final int contextSize;
  @override
  final int gpuLayers;
  @override
  final int threads;
  @override
  final double temperature;
  @override
  final double topP;
  @override
  final int topK;
  @override
  final int maxTokens;

  factory _$ModelParams([void Function(ModelParamsBuilder)? updates]) =>
      (ModelParamsBuilder()..update(updates))._build();

  _$ModelParams._({
    required this.modelPath,
    required this.contextSize,
    required this.gpuLayers,
    required this.threads,
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.maxTokens,
  }) : super._();
  @override
  ModelParams rebuild(void Function(ModelParamsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ModelParamsBuilder toBuilder() => ModelParamsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ModelParams &&
        modelPath == other.modelPath &&
        contextSize == other.contextSize &&
        gpuLayers == other.gpuLayers &&
        threads == other.threads &&
        temperature == other.temperature &&
        topP == other.topP &&
        topK == other.topK &&
        maxTokens == other.maxTokens;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, modelPath.hashCode);
    _$hash = $jc(_$hash, contextSize.hashCode);
    _$hash = $jc(_$hash, gpuLayers.hashCode);
    _$hash = $jc(_$hash, threads.hashCode);
    _$hash = $jc(_$hash, temperature.hashCode);
    _$hash = $jc(_$hash, topP.hashCode);
    _$hash = $jc(_$hash, topK.hashCode);
    _$hash = $jc(_$hash, maxTokens.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ModelParams')
          ..add('modelPath', modelPath)
          ..add('contextSize', contextSize)
          ..add('gpuLayers', gpuLayers)
          ..add('threads', threads)
          ..add('temperature', temperature)
          ..add('topP', topP)
          ..add('topK', topK)
          ..add('maxTokens', maxTokens))
        .toString();
  }
}

class ModelParamsBuilder implements Builder<ModelParams, ModelParamsBuilder> {
  _$ModelParams? _$v;

  String? _modelPath;
  String? get modelPath => _$this._modelPath;
  set modelPath(String? modelPath) => _$this._modelPath = modelPath;

  int? _contextSize;
  int? get contextSize => _$this._contextSize;
  set contextSize(int? contextSize) => _$this._contextSize = contextSize;

  int? _gpuLayers;
  int? get gpuLayers => _$this._gpuLayers;
  set gpuLayers(int? gpuLayers) => _$this._gpuLayers = gpuLayers;

  int? _threads;
  int? get threads => _$this._threads;
  set threads(int? threads) => _$this._threads = threads;

  double? _temperature;
  double? get temperature => _$this._temperature;
  set temperature(double? temperature) => _$this._temperature = temperature;

  double? _topP;
  double? get topP => _$this._topP;
  set topP(double? topP) => _$this._topP = topP;

  int? _topK;
  int? get topK => _$this._topK;
  set topK(int? topK) => _$this._topK = topK;

  int? _maxTokens;
  int? get maxTokens => _$this._maxTokens;
  set maxTokens(int? maxTokens) => _$this._maxTokens = maxTokens;

  ModelParamsBuilder();

  ModelParamsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _modelPath = $v.modelPath;
      _contextSize = $v.contextSize;
      _gpuLayers = $v.gpuLayers;
      _threads = $v.threads;
      _temperature = $v.temperature;
      _topP = $v.topP;
      _topK = $v.topK;
      _maxTokens = $v.maxTokens;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ModelParams other) {
    _$v = other as _$ModelParams;
  }

  @override
  void update(void Function(ModelParamsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ModelParams build() => _build();

  _$ModelParams _build() {
    final _$result =
        _$v ??
        _$ModelParams._(
          modelPath: BuiltValueNullFieldError.checkNotNull(
            modelPath,
            r'ModelParams',
            'modelPath',
          ),
          contextSize: BuiltValueNullFieldError.checkNotNull(
            contextSize,
            r'ModelParams',
            'contextSize',
          ),
          gpuLayers: BuiltValueNullFieldError.checkNotNull(
            gpuLayers,
            r'ModelParams',
            'gpuLayers',
          ),
          threads: BuiltValueNullFieldError.checkNotNull(
            threads,
            r'ModelParams',
            'threads',
          ),
          temperature: BuiltValueNullFieldError.checkNotNull(
            temperature,
            r'ModelParams',
            'temperature',
          ),
          topP: BuiltValueNullFieldError.checkNotNull(
            topP,
            r'ModelParams',
            'topP',
          ),
          topK: BuiltValueNullFieldError.checkNotNull(
            topK,
            r'ModelParams',
            'topK',
          ),
          maxTokens: BuiltValueNullFieldError.checkNotNull(
            maxTokens,
            r'ModelParams',
            'maxTokens',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
