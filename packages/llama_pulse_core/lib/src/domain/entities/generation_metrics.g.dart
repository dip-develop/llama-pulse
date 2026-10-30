// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generation_metrics.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<GenerationMetrics> _$generationMetricsSerializer =
    _$GenerationMetricsSerializer();

class _$GenerationMetricsSerializer
    implements StructuredSerializer<GenerationMetrics> {
  @override
  final Iterable<Type> types = const [GenerationMetrics, _$GenerationMetrics];
  @override
  final String wireName = 'GenerationMetrics';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    GenerationMetrics object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'promptTokenCount',
      serializers.serialize(
        object.promptTokenCount,
        specifiedType: const FullType(int),
      ),
      'generatedTokenCount',
      serializers.serialize(
        object.generatedTokenCount,
        specifiedType: const FullType(int),
      ),
      'promptEvalMs',
      serializers.serialize(
        object.promptEvalMs,
        specifiedType: const FullType(int),
      ),
      'evalMs',
      serializers.serialize(object.evalMs, specifiedType: const FullType(int)),
    ];

    return result;
  }

  @override
  GenerationMetrics deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GenerationMetricsBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'promptTokenCount':
          result.promptTokenCount =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'generatedTokenCount':
          result.generatedTokenCount =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'promptEvalMs':
          result.promptEvalMs =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'evalMs':
          result.evalMs =
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

class _$GenerationMetrics extends GenerationMetrics {
  @override
  final int promptTokenCount;
  @override
  final int generatedTokenCount;
  @override
  final int promptEvalMs;
  @override
  final int evalMs;

  factory _$GenerationMetrics([
    void Function(GenerationMetricsBuilder)? updates,
  ]) => (GenerationMetricsBuilder()..update(updates))._build();

  _$GenerationMetrics._({
    required this.promptTokenCount,
    required this.generatedTokenCount,
    required this.promptEvalMs,
    required this.evalMs,
  }) : super._();
  @override
  GenerationMetrics rebuild(void Function(GenerationMetricsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GenerationMetricsBuilder toBuilder() =>
      GenerationMetricsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GenerationMetrics &&
        promptTokenCount == other.promptTokenCount &&
        generatedTokenCount == other.generatedTokenCount &&
        promptEvalMs == other.promptEvalMs &&
        evalMs == other.evalMs;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, promptTokenCount.hashCode);
    _$hash = $jc(_$hash, generatedTokenCount.hashCode);
    _$hash = $jc(_$hash, promptEvalMs.hashCode);
    _$hash = $jc(_$hash, evalMs.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GenerationMetrics')
          ..add('promptTokenCount', promptTokenCount)
          ..add('generatedTokenCount', generatedTokenCount)
          ..add('promptEvalMs', promptEvalMs)
          ..add('evalMs', evalMs))
        .toString();
  }
}

class GenerationMetricsBuilder
    implements Builder<GenerationMetrics, GenerationMetricsBuilder> {
  _$GenerationMetrics? _$v;

  int? _promptTokenCount;
  int? get promptTokenCount => _$this._promptTokenCount;
  set promptTokenCount(int? promptTokenCount) =>
      _$this._promptTokenCount = promptTokenCount;

  int? _generatedTokenCount;
  int? get generatedTokenCount => _$this._generatedTokenCount;
  set generatedTokenCount(int? generatedTokenCount) =>
      _$this._generatedTokenCount = generatedTokenCount;

  int? _promptEvalMs;
  int? get promptEvalMs => _$this._promptEvalMs;
  set promptEvalMs(int? promptEvalMs) => _$this._promptEvalMs = promptEvalMs;

  int? _evalMs;
  int? get evalMs => _$this._evalMs;
  set evalMs(int? evalMs) => _$this._evalMs = evalMs;

  GenerationMetricsBuilder();

  GenerationMetricsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _promptTokenCount = $v.promptTokenCount;
      _generatedTokenCount = $v.generatedTokenCount;
      _promptEvalMs = $v.promptEvalMs;
      _evalMs = $v.evalMs;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GenerationMetrics other) {
    _$v = other as _$GenerationMetrics;
  }

  @override
  void update(void Function(GenerationMetricsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GenerationMetrics build() => _build();

  _$GenerationMetrics _build() {
    final _$result =
        _$v ??
        _$GenerationMetrics._(
          promptTokenCount: BuiltValueNullFieldError.checkNotNull(
            promptTokenCount,
            r'GenerationMetrics',
            'promptTokenCount',
          ),
          generatedTokenCount: BuiltValueNullFieldError.checkNotNull(
            generatedTokenCount,
            r'GenerationMetrics',
            'generatedTokenCount',
          ),
          promptEvalMs: BuiltValueNullFieldError.checkNotNull(
            promptEvalMs,
            r'GenerationMetrics',
            'promptEvalMs',
          ),
          evalMs: BuiltValueNullFieldError.checkNotNull(
            evalMs,
            r'GenerationMetrics',
            'evalMs',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
