// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<InferenceState> _$inferenceStateSerializer =
    _$InferenceStateSerializer();

class _$InferenceStateSerializer
    implements StructuredSerializer<InferenceState> {
  @override
  final Iterable<Type> types = const [InferenceState, _$InferenceState];
  @override
  final String wireName = 'InferenceState';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    InferenceState object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'status',
      serializers.serialize(
        object.status,
        specifiedType: const FullType(InferenceStatus),
      ),
      'params',
      serializers.serialize(
        object.params,
        specifiedType: const FullType(ModelParams),
      ),
      'prompt',
      serializers.serialize(
        object.prompt,
        specifiedType: const FullType(String),
      ),
      'outputChunks',
      serializers.serialize(
        object.outputChunks,
        specifiedType: const FullType(BuiltList, const [
          const FullType(String),
        ]),
      ),
      'metricsHistory',
      serializers.serialize(
        object.metricsHistory,
        specifiedType: const FullType(BuiltList, const [
          const FullType(GenerationMetrics),
        ]),
      ),
    ];
    Object? value;
    value = object.activeRequestId;
    if (value != null) {
      result
        ..add('activeRequestId')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
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
    value = object.timeToFirstTokenMs;
    if (value != null) {
      result
        ..add('timeToFirstTokenMs')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    return result;
  }

  @override
  InferenceState deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = InferenceStateBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'status':
          result.status =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(InferenceStatus),
                  )!
                  as InferenceStatus;
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
          result.prompt =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'outputChunks':
          result.outputChunks.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(String),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'metricsHistory':
          result.metricsHistory.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(GenerationMetrics),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'activeRequestId':
          result.activeRequestId = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
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
        case 'timeToFirstTokenMs':
          result.timeToFirstTokenMs = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
      }
    }

    return result.build();
  }
}

class _$InferenceState extends InferenceState {
  @override
  final InferenceStatus status;
  @override
  final ModelParams params;
  @override
  final String prompt;
  @override
  final BuiltList<String> outputChunks;
  @override
  final BuiltList<GenerationMetrics> metricsHistory;
  @override
  final int? activeRequestId;
  @override
  final InferenceFailure? failure;
  @override
  final int? timeToFirstTokenMs;

  factory _$InferenceState([void Function(InferenceStateBuilder)? updates]) =>
      (InferenceStateBuilder()..update(updates))._build();

  _$InferenceState._({
    required this.status,
    required this.params,
    required this.prompt,
    required this.outputChunks,
    required this.metricsHistory,
    this.activeRequestId,
    this.failure,
    this.timeToFirstTokenMs,
  }) : super._();
  @override
  InferenceState rebuild(void Function(InferenceStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  InferenceStateBuilder toBuilder() => InferenceStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is InferenceState &&
        status == other.status &&
        params == other.params &&
        prompt == other.prompt &&
        outputChunks == other.outputChunks &&
        metricsHistory == other.metricsHistory &&
        activeRequestId == other.activeRequestId &&
        failure == other.failure &&
        timeToFirstTokenMs == other.timeToFirstTokenMs;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, params.hashCode);
    _$hash = $jc(_$hash, prompt.hashCode);
    _$hash = $jc(_$hash, outputChunks.hashCode);
    _$hash = $jc(_$hash, metricsHistory.hashCode);
    _$hash = $jc(_$hash, activeRequestId.hashCode);
    _$hash = $jc(_$hash, failure.hashCode);
    _$hash = $jc(_$hash, timeToFirstTokenMs.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'InferenceState')
          ..add('status', status)
          ..add('params', params)
          ..add('prompt', prompt)
          ..add('outputChunks', outputChunks)
          ..add('metricsHistory', metricsHistory)
          ..add('activeRequestId', activeRequestId)
          ..add('failure', failure)
          ..add('timeToFirstTokenMs', timeToFirstTokenMs))
        .toString();
  }
}

class InferenceStateBuilder
    implements Builder<InferenceState, InferenceStateBuilder> {
  _$InferenceState? _$v;

  InferenceStatus? _status;
  InferenceStatus? get status => _$this._status;
  set status(InferenceStatus? status) => _$this._status = status;

  ModelParamsBuilder? _params;
  ModelParamsBuilder get params => _$this._params ??= ModelParamsBuilder();
  set params(ModelParamsBuilder? params) => _$this._params = params;

  String? _prompt;
  String? get prompt => _$this._prompt;
  set prompt(String? prompt) => _$this._prompt = prompt;

  ListBuilder<String>? _outputChunks;
  ListBuilder<String> get outputChunks =>
      _$this._outputChunks ??= ListBuilder<String>();
  set outputChunks(ListBuilder<String>? outputChunks) =>
      _$this._outputChunks = outputChunks;

  ListBuilder<GenerationMetrics>? _metricsHistory;
  ListBuilder<GenerationMetrics> get metricsHistory =>
      _$this._metricsHistory ??= ListBuilder<GenerationMetrics>();
  set metricsHistory(ListBuilder<GenerationMetrics>? metricsHistory) =>
      _$this._metricsHistory = metricsHistory;

  int? _activeRequestId;
  int? get activeRequestId => _$this._activeRequestId;
  set activeRequestId(int? activeRequestId) =>
      _$this._activeRequestId = activeRequestId;

  InferenceFailureBuilder? _failure;
  InferenceFailureBuilder get failure =>
      _$this._failure ??= InferenceFailureBuilder();
  set failure(InferenceFailureBuilder? failure) => _$this._failure = failure;

  int? _timeToFirstTokenMs;
  int? get timeToFirstTokenMs => _$this._timeToFirstTokenMs;
  set timeToFirstTokenMs(int? timeToFirstTokenMs) =>
      _$this._timeToFirstTokenMs = timeToFirstTokenMs;

  InferenceStateBuilder();

  InferenceStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _status = $v.status;
      _params = $v.params.toBuilder();
      _prompt = $v.prompt;
      _outputChunks = $v.outputChunks.toBuilder();
      _metricsHistory = $v.metricsHistory.toBuilder();
      _activeRequestId = $v.activeRequestId;
      _failure = $v.failure?.toBuilder();
      _timeToFirstTokenMs = $v.timeToFirstTokenMs;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(InferenceState other) {
    _$v = other as _$InferenceState;
  }

  @override
  void update(void Function(InferenceStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  InferenceState build() => _build();

  _$InferenceState _build() {
    _$InferenceState _$result;
    try {
      _$result =
          _$v ??
          _$InferenceState._(
            status: BuiltValueNullFieldError.checkNotNull(
              status,
              r'InferenceState',
              'status',
            ),
            params: params.build(),
            prompt: BuiltValueNullFieldError.checkNotNull(
              prompt,
              r'InferenceState',
              'prompt',
            ),
            outputChunks: outputChunks.build(),
            metricsHistory: metricsHistory.build(),
            activeRequestId: activeRequestId,
            failure: _failure?.build(),
            timeToFirstTokenMs: timeToFirstTokenMs,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'params';
        params.build();

        _$failedField = 'outputChunks';
        outputChunks.build();
        _$failedField = 'metricsHistory';
        metricsHistory.build();

        _$failedField = 'failure';
        _failure?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'InferenceState',
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
