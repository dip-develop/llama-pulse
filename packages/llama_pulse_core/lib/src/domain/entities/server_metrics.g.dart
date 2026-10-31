// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_metrics.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ServerMetrics> _$serverMetricsSerializer =
    _$ServerMetricsSerializer();

class _$ServerMetricsSerializer implements StructuredSerializer<ServerMetrics> {
  @override
  final Iterable<Type> types = const [ServerMetrics, _$ServerMetrics];
  @override
  final String wireName = 'ServerMetrics';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    ServerMetrics object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'promptTokensTotal',
      serializers.serialize(
        object.promptTokensTotal,
        specifiedType: const FullType(int),
      ),
      'promptTokensCachedTotal',
      serializers.serialize(
        object.promptTokensCachedTotal,
        specifiedType: const FullType(int),
      ),
      'tokensPredictedTotal',
      serializers.serialize(
        object.tokensPredictedTotal,
        specifiedType: const FullType(int),
      ),
      'nDecodeTotal',
      serializers.serialize(
        object.nDecodeTotal,
        specifiedType: const FullType(int),
      ),
      'nTokensMax',
      serializers.serialize(
        object.nTokensMax,
        specifiedType: const FullType(int),
      ),
      'requestsProcessing',
      serializers.serialize(
        object.requestsProcessing,
        specifiedType: const FullType(int),
      ),
      'requestsDeferred',
      serializers.serialize(
        object.requestsDeferred,
        specifiedType: const FullType(int),
      ),
      'nBusySlotsPerDecode',
      serializers.serialize(
        object.nBusySlotsPerDecode,
        specifiedType: const FullType(int),
      ),
      'promptSecondsTotal',
      serializers.serialize(
        object.promptSecondsTotal,
        specifiedType: const FullType(double),
      ),
      'tokensPredictedSecondsTotal',
      serializers.serialize(
        object.tokensPredictedSecondsTotal,
        specifiedType: const FullType(double),
      ),
      'tokensPerSecond',
      serializers.serialize(
        object.tokensPerSecond,
        specifiedType: const FullType(double),
      ),
      'promptTokensPerSecond',
      serializers.serialize(
        object.promptTokensPerSecond,
        specifiedType: const FullType(double),
      ),
      'activeSlots',
      serializers.serialize(
        object.activeSlots,
        specifiedType: const FullType(int),
      ),
      'totalSlots',
      serializers.serialize(
        object.totalSlots,
        specifiedType: const FullType(int),
      ),
      'capturedAtEpochMs',
      serializers.serialize(
        object.capturedAtEpochMs,
        specifiedType: const FullType(int),
      ),
    ];
    Object? value;
    value = object.uptimeSeconds;
    if (value != null) {
      result
        ..add('uptimeSeconds')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.contextUsageRatio;
    if (value != null) {
      result
        ..add('contextUsageRatio')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(double)),
        );
    }
    return result;
  }

  @override
  ServerMetrics deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ServerMetricsBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'promptTokensTotal':
          result.promptTokensTotal =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'promptTokensCachedTotal':
          result.promptTokensCachedTotal =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'tokensPredictedTotal':
          result.tokensPredictedTotal =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'nDecodeTotal':
          result.nDecodeTotal =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'nTokensMax':
          result.nTokensMax =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'requestsProcessing':
          result.requestsProcessing =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'requestsDeferred':
          result.requestsDeferred =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'nBusySlotsPerDecode':
          result.nBusySlotsPerDecode =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'promptSecondsTotal':
          result.promptSecondsTotal =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(double),
                  )!
                  as double;
          break;
        case 'tokensPredictedSecondsTotal':
          result.tokensPredictedSecondsTotal =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(double),
                  )!
                  as double;
          break;
        case 'tokensPerSecond':
          result.tokensPerSecond =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(double),
                  )!
                  as double;
          break;
        case 'promptTokensPerSecond':
          result.promptTokensPerSecond =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(double),
                  )!
                  as double;
          break;
        case 'activeSlots':
          result.activeSlots =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'totalSlots':
          result.totalSlots =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'uptimeSeconds':
          result.uptimeSeconds = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'contextUsageRatio':
          result.contextUsageRatio = serializers.deserialize(
            value,
            specifiedType: const FullType(double),
          ) as double?;
          break;
        case 'capturedAtEpochMs':
          result.capturedAtEpochMs =
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

class _$ServerMetrics extends ServerMetrics {
  @override
  final int promptTokensTotal;
  @override
  final int promptTokensCachedTotal;
  @override
  final int tokensPredictedTotal;
  @override
  final int nDecodeTotal;
  @override
  final int nTokensMax;
  @override
  final int requestsProcessing;
  @override
  final int requestsDeferred;
  @override
  final int nBusySlotsPerDecode;
  @override
  final double promptSecondsTotal;
  @override
  final double tokensPredictedSecondsTotal;
  @override
  final double tokensPerSecond;
  @override
  final double promptTokensPerSecond;
  @override
  final int activeSlots;
  @override
  final int totalSlots;
  @override
  final int? uptimeSeconds;
  @override
  final double? contextUsageRatio;
  @override
  final int capturedAtEpochMs;

  factory _$ServerMetrics([void Function(ServerMetricsBuilder)? updates]) =>
      (ServerMetricsBuilder()..update(updates))._build();

  _$ServerMetrics._({
    required this.promptTokensTotal,
    required this.promptTokensCachedTotal,
    required this.tokensPredictedTotal,
    required this.nDecodeTotal,
    required this.nTokensMax,
    required this.requestsProcessing,
    required this.requestsDeferred,
    required this.nBusySlotsPerDecode,
    required this.promptSecondsTotal,
    required this.tokensPredictedSecondsTotal,
    required this.tokensPerSecond,
    required this.promptTokensPerSecond,
    required this.activeSlots,
    required this.totalSlots,
    this.uptimeSeconds,
    this.contextUsageRatio,
    required this.capturedAtEpochMs,
  }) : super._();
  @override
  ServerMetrics rebuild(void Function(ServerMetricsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ServerMetricsBuilder toBuilder() => ServerMetricsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ServerMetrics &&
        promptTokensTotal == other.promptTokensTotal &&
        promptTokensCachedTotal == other.promptTokensCachedTotal &&
        tokensPredictedTotal == other.tokensPredictedTotal &&
        nDecodeTotal == other.nDecodeTotal &&
        nTokensMax == other.nTokensMax &&
        requestsProcessing == other.requestsProcessing &&
        requestsDeferred == other.requestsDeferred &&
        nBusySlotsPerDecode == other.nBusySlotsPerDecode &&
        promptSecondsTotal == other.promptSecondsTotal &&
        tokensPredictedSecondsTotal == other.tokensPredictedSecondsTotal &&
        tokensPerSecond == other.tokensPerSecond &&
        promptTokensPerSecond == other.promptTokensPerSecond &&
        activeSlots == other.activeSlots &&
        totalSlots == other.totalSlots &&
        uptimeSeconds == other.uptimeSeconds &&
        contextUsageRatio == other.contextUsageRatio &&
        capturedAtEpochMs == other.capturedAtEpochMs;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, promptTokensTotal.hashCode);
    _$hash = $jc(_$hash, promptTokensCachedTotal.hashCode);
    _$hash = $jc(_$hash, tokensPredictedTotal.hashCode);
    _$hash = $jc(_$hash, nDecodeTotal.hashCode);
    _$hash = $jc(_$hash, nTokensMax.hashCode);
    _$hash = $jc(_$hash, requestsProcessing.hashCode);
    _$hash = $jc(_$hash, requestsDeferred.hashCode);
    _$hash = $jc(_$hash, nBusySlotsPerDecode.hashCode);
    _$hash = $jc(_$hash, promptSecondsTotal.hashCode);
    _$hash = $jc(_$hash, tokensPredictedSecondsTotal.hashCode);
    _$hash = $jc(_$hash, tokensPerSecond.hashCode);
    _$hash = $jc(_$hash, promptTokensPerSecond.hashCode);
    _$hash = $jc(_$hash, activeSlots.hashCode);
    _$hash = $jc(_$hash, totalSlots.hashCode);
    _$hash = $jc(_$hash, uptimeSeconds.hashCode);
    _$hash = $jc(_$hash, contextUsageRatio.hashCode);
    _$hash = $jc(_$hash, capturedAtEpochMs.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ServerMetrics')
          ..add('promptTokensTotal', promptTokensTotal)
          ..add('promptTokensCachedTotal', promptTokensCachedTotal)
          ..add('tokensPredictedTotal', tokensPredictedTotal)
          ..add('nDecodeTotal', nDecodeTotal)
          ..add('nTokensMax', nTokensMax)
          ..add('requestsProcessing', requestsProcessing)
          ..add('requestsDeferred', requestsDeferred)
          ..add('nBusySlotsPerDecode', nBusySlotsPerDecode)
          ..add('promptSecondsTotal', promptSecondsTotal)
          ..add('tokensPredictedSecondsTotal', tokensPredictedSecondsTotal)
          ..add('tokensPerSecond', tokensPerSecond)
          ..add('promptTokensPerSecond', promptTokensPerSecond)
          ..add('activeSlots', activeSlots)
          ..add('totalSlots', totalSlots)
          ..add('uptimeSeconds', uptimeSeconds)
          ..add('contextUsageRatio', contextUsageRatio)
          ..add('capturedAtEpochMs', capturedAtEpochMs))
        .toString();
  }
}

class ServerMetricsBuilder
    implements Builder<ServerMetrics, ServerMetricsBuilder> {
  _$ServerMetrics? _$v;

  int? _promptTokensTotal;
  int? get promptTokensTotal => _$this._promptTokensTotal;
  set promptTokensTotal(int? promptTokensTotal) =>
      _$this._promptTokensTotal = promptTokensTotal;

  int? _promptTokensCachedTotal;
  int? get promptTokensCachedTotal => _$this._promptTokensCachedTotal;
  set promptTokensCachedTotal(int? promptTokensCachedTotal) =>
      _$this._promptTokensCachedTotal = promptTokensCachedTotal;

  int? _tokensPredictedTotal;
  int? get tokensPredictedTotal => _$this._tokensPredictedTotal;
  set tokensPredictedTotal(int? tokensPredictedTotal) =>
      _$this._tokensPredictedTotal = tokensPredictedTotal;

  int? _nDecodeTotal;
  int? get nDecodeTotal => _$this._nDecodeTotal;
  set nDecodeTotal(int? nDecodeTotal) => _$this._nDecodeTotal = nDecodeTotal;

  int? _nTokensMax;
  int? get nTokensMax => _$this._nTokensMax;
  set nTokensMax(int? nTokensMax) => _$this._nTokensMax = nTokensMax;

  int? _requestsProcessing;
  int? get requestsProcessing => _$this._requestsProcessing;
  set requestsProcessing(int? requestsProcessing) =>
      _$this._requestsProcessing = requestsProcessing;

  int? _requestsDeferred;
  int? get requestsDeferred => _$this._requestsDeferred;
  set requestsDeferred(int? requestsDeferred) =>
      _$this._requestsDeferred = requestsDeferred;

  int? _nBusySlotsPerDecode;
  int? get nBusySlotsPerDecode => _$this._nBusySlotsPerDecode;
  set nBusySlotsPerDecode(int? nBusySlotsPerDecode) =>
      _$this._nBusySlotsPerDecode = nBusySlotsPerDecode;

  double? _promptSecondsTotal;
  double? get promptSecondsTotal => _$this._promptSecondsTotal;
  set promptSecondsTotal(double? promptSecondsTotal) =>
      _$this._promptSecondsTotal = promptSecondsTotal;

  double? _tokensPredictedSecondsTotal;
  double? get tokensPredictedSecondsTotal =>
      _$this._tokensPredictedSecondsTotal;
  set tokensPredictedSecondsTotal(double? tokensPredictedSecondsTotal) =>
      _$this._tokensPredictedSecondsTotal = tokensPredictedSecondsTotal;

  double? _tokensPerSecond;
  double? get tokensPerSecond => _$this._tokensPerSecond;
  set tokensPerSecond(double? tokensPerSecond) =>
      _$this._tokensPerSecond = tokensPerSecond;

  double? _promptTokensPerSecond;
  double? get promptTokensPerSecond => _$this._promptTokensPerSecond;
  set promptTokensPerSecond(double? promptTokensPerSecond) =>
      _$this._promptTokensPerSecond = promptTokensPerSecond;

  int? _activeSlots;
  int? get activeSlots => _$this._activeSlots;
  set activeSlots(int? activeSlots) => _$this._activeSlots = activeSlots;

  int? _totalSlots;
  int? get totalSlots => _$this._totalSlots;
  set totalSlots(int? totalSlots) => _$this._totalSlots = totalSlots;

  int? _uptimeSeconds;
  int? get uptimeSeconds => _$this._uptimeSeconds;
  set uptimeSeconds(int? uptimeSeconds) =>
      _$this._uptimeSeconds = uptimeSeconds;

  double? _contextUsageRatio;
  double? get contextUsageRatio => _$this._contextUsageRatio;
  set contextUsageRatio(double? contextUsageRatio) =>
      _$this._contextUsageRatio = contextUsageRatio;

  int? _capturedAtEpochMs;
  int? get capturedAtEpochMs => _$this._capturedAtEpochMs;
  set capturedAtEpochMs(int? capturedAtEpochMs) =>
      _$this._capturedAtEpochMs = capturedAtEpochMs;

  ServerMetricsBuilder();

  ServerMetricsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _promptTokensTotal = $v.promptTokensTotal;
      _promptTokensCachedTotal = $v.promptTokensCachedTotal;
      _tokensPredictedTotal = $v.tokensPredictedTotal;
      _nDecodeTotal = $v.nDecodeTotal;
      _nTokensMax = $v.nTokensMax;
      _requestsProcessing = $v.requestsProcessing;
      _requestsDeferred = $v.requestsDeferred;
      _nBusySlotsPerDecode = $v.nBusySlotsPerDecode;
      _promptSecondsTotal = $v.promptSecondsTotal;
      _tokensPredictedSecondsTotal = $v.tokensPredictedSecondsTotal;
      _tokensPerSecond = $v.tokensPerSecond;
      _promptTokensPerSecond = $v.promptTokensPerSecond;
      _activeSlots = $v.activeSlots;
      _totalSlots = $v.totalSlots;
      _uptimeSeconds = $v.uptimeSeconds;
      _contextUsageRatio = $v.contextUsageRatio;
      _capturedAtEpochMs = $v.capturedAtEpochMs;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ServerMetrics other) {
    _$v = other as _$ServerMetrics;
  }

  @override
  void update(void Function(ServerMetricsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ServerMetrics build() => _build();

  _$ServerMetrics _build() {
    final _$result =
        _$v ??
        _$ServerMetrics._(
          promptTokensTotal: BuiltValueNullFieldError.checkNotNull(
            promptTokensTotal,
            r'ServerMetrics',
            'promptTokensTotal',
          ),
          promptTokensCachedTotal: BuiltValueNullFieldError.checkNotNull(
            promptTokensCachedTotal,
            r'ServerMetrics',
            'promptTokensCachedTotal',
          ),
          tokensPredictedTotal: BuiltValueNullFieldError.checkNotNull(
            tokensPredictedTotal,
            r'ServerMetrics',
            'tokensPredictedTotal',
          ),
          nDecodeTotal: BuiltValueNullFieldError.checkNotNull(
            nDecodeTotal,
            r'ServerMetrics',
            'nDecodeTotal',
          ),
          nTokensMax: BuiltValueNullFieldError.checkNotNull(
            nTokensMax,
            r'ServerMetrics',
            'nTokensMax',
          ),
          requestsProcessing: BuiltValueNullFieldError.checkNotNull(
            requestsProcessing,
            r'ServerMetrics',
            'requestsProcessing',
          ),
          requestsDeferred: BuiltValueNullFieldError.checkNotNull(
            requestsDeferred,
            r'ServerMetrics',
            'requestsDeferred',
          ),
          nBusySlotsPerDecode: BuiltValueNullFieldError.checkNotNull(
            nBusySlotsPerDecode,
            r'ServerMetrics',
            'nBusySlotsPerDecode',
          ),
          promptSecondsTotal: BuiltValueNullFieldError.checkNotNull(
            promptSecondsTotal,
            r'ServerMetrics',
            'promptSecondsTotal',
          ),
          tokensPredictedSecondsTotal: BuiltValueNullFieldError.checkNotNull(
            tokensPredictedSecondsTotal,
            r'ServerMetrics',
            'tokensPredictedSecondsTotal',
          ),
          tokensPerSecond: BuiltValueNullFieldError.checkNotNull(
            tokensPerSecond,
            r'ServerMetrics',
            'tokensPerSecond',
          ),
          promptTokensPerSecond: BuiltValueNullFieldError.checkNotNull(
            promptTokensPerSecond,
            r'ServerMetrics',
            'promptTokensPerSecond',
          ),
          activeSlots: BuiltValueNullFieldError.checkNotNull(
            activeSlots,
            r'ServerMetrics',
            'activeSlots',
          ),
          totalSlots: BuiltValueNullFieldError.checkNotNull(
            totalSlots,
            r'ServerMetrics',
            'totalSlots',
          ),
          uptimeSeconds: uptimeSeconds,
          contextUsageRatio: contextUsageRatio,
          capturedAtEpochMs: BuiltValueNullFieldError.checkNotNull(
            capturedAtEpochMs,
            r'ServerMetrics',
            'capturedAtEpochMs',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
