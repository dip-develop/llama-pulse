// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<RuntimeState> _$runtimeStateSerializer = _$RuntimeStateSerializer();

class _$RuntimeStateSerializer implements StructuredSerializer<RuntimeState> {
  @override
  final Iterable<Type> types = const [RuntimeState, _$RuntimeState];
  @override
  final String wireName = 'RuntimeState';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RuntimeState object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'loading',
      serializers.serialize(
        object.loading,
        specifiedType: const FullType(bool),
      ),
      'busy',
      serializers.serialize(object.busy, specifiedType: const FullType(bool)),
      'supports',
      serializers.serialize(
        object.supports,
        specifiedType: const FullType(BuiltList, const [
          const FullType(BackendSupport),
        ]),
      ),
      'offeredBackends',
      serializers.serialize(
        object.offeredBackends,
        specifiedType: const FullType(BuiltList, const [
          const FullType(RuntimeBackend),
        ]),
      ),
      'installed',
      serializers.serialize(
        object.installed,
        specifiedType: const FullType(BuiltList, const [
          const FullType(RuntimeInstallRef),
        ]),
      ),
      'progressReceived',
      serializers.serialize(
        object.progressReceived,
        specifiedType: const FullType(int),
      ),
      'progressTotal',
      serializers.serialize(
        object.progressTotal,
        specifiedType: const FullType(int),
      ),
      'bytesPerSecond',
      serializers.serialize(
        object.bytesPerSecond,
        specifiedType: const FullType(double),
      ),
    ];
    Object? value;
    value = object.hardwareSummary;
    if (value != null) {
      result
        ..add('hardwareSummary')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.platform;
    if (value != null) {
      result
        ..add('platform')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(RuntimePlatform),
          ),
        );
    }
    value = object.recommendedBackend;
    if (value != null) {
      result
        ..add('recommendedBackend')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(RuntimeBackend),
          ),
        );
    }
    value = object.recommendationReason;
    if (value != null) {
      result
        ..add('recommendationReason')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.selectedTag;
    if (value != null) {
      result
        ..add('selectedTag')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.selectedBackend;
    if (value != null) {
      result
        ..add('selectedBackend')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(RuntimeBackend),
          ),
        );
    }
    value = object.selectedVersion;
    if (value != null) {
      result
        ..add('selectedVersion')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.gateVerdict;
    if (value != null) {
      result
        ..add('gateVerdict')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(RuntimeGateVerdict),
          ),
        );
    }
    value = object.gateReason;
    if (value != null) {
      result
        ..add('gateReason')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.installingBackend;
    if (value != null) {
      result
        ..add('installingBackend')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(RuntimeBackend),
          ),
        );
    }
    value = object.errorMessage;
    if (value != null) {
      result
        ..add('errorMessage')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.noticeMessage;
    if (value != null) {
      result
        ..add('noticeMessage')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    return result;
  }

  @override
  RuntimeState deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RuntimeStateBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'loading':
          result.loading =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'busy':
          result.busy =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'hardwareSummary':
          result.hardwareSummary = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'platform':
          result.platform = serializers.deserialize(
            value,
            specifiedType: const FullType(RuntimePlatform),
          ) as RuntimePlatform?;
          break;
        case 'supports':
          result.supports.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(BackendSupport),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'recommendedBackend':
          result.recommendedBackend = serializers.deserialize(
            value,
            specifiedType: const FullType(RuntimeBackend),
          ) as RuntimeBackend?;
          break;
        case 'recommendationReason':
          result.recommendationReason = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'offeredBackends':
          result.offeredBackends.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(RuntimeBackend),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'installed':
          result.installed.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(RuntimeInstallRef),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'selectedTag':
          result.selectedTag = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'selectedBackend':
          result.selectedBackend = serializers.deserialize(
            value,
            specifiedType: const FullType(RuntimeBackend),
          ) as RuntimeBackend?;
          break;
        case 'selectedVersion':
          result.selectedVersion = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'gateVerdict':
          result.gateVerdict = serializers.deserialize(
            value,
            specifiedType: const FullType(RuntimeGateVerdict),
          ) as RuntimeGateVerdict?;
          break;
        case 'gateReason':
          result.gateReason = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'installingBackend':
          result.installingBackend = serializers.deserialize(
            value,
            specifiedType: const FullType(RuntimeBackend),
          ) as RuntimeBackend?;
          break;
        case 'progressReceived':
          result.progressReceived =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'progressTotal':
          result.progressTotal =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'bytesPerSecond':
          result.bytesPerSecond =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(double),
                  )!
                  as double;
          break;
        case 'errorMessage':
          result.errorMessage = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'noticeMessage':
          result.noticeMessage = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
      }
    }

    return result.build();
  }
}

class _$RuntimeState extends RuntimeState {
  @override
  final bool loading;
  @override
  final bool busy;
  @override
  final String? hardwareSummary;
  @override
  final RuntimePlatform? platform;
  @override
  final BuiltList<BackendSupport> supports;
  @override
  final RuntimeBackend? recommendedBackend;
  @override
  final String? recommendationReason;
  @override
  final BuiltList<RuntimeBackend> offeredBackends;
  @override
  final BuiltList<RuntimeInstallRef> installed;
  @override
  final String? selectedTag;
  @override
  final RuntimeBackend? selectedBackend;
  @override
  final String? selectedVersion;
  @override
  final RuntimeGateVerdict? gateVerdict;
  @override
  final String? gateReason;
  @override
  final RuntimeBackend? installingBackend;
  @override
  final int progressReceived;
  @override
  final int progressTotal;
  @override
  final double bytesPerSecond;
  @override
  final String? errorMessage;
  @override
  final String? noticeMessage;

  factory _$RuntimeState([void Function(RuntimeStateBuilder)? updates]) =>
      (RuntimeStateBuilder()..update(updates))._build();

  _$RuntimeState._({
    required this.loading,
    required this.busy,
    this.hardwareSummary,
    this.platform,
    required this.supports,
    this.recommendedBackend,
    this.recommendationReason,
    required this.offeredBackends,
    required this.installed,
    this.selectedTag,
    this.selectedBackend,
    this.selectedVersion,
    this.gateVerdict,
    this.gateReason,
    this.installingBackend,
    required this.progressReceived,
    required this.progressTotal,
    required this.bytesPerSecond,
    this.errorMessage,
    this.noticeMessage,
  }) : super._();
  @override
  RuntimeState rebuild(void Function(RuntimeStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RuntimeStateBuilder toBuilder() => RuntimeStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RuntimeState &&
        loading == other.loading &&
        busy == other.busy &&
        hardwareSummary == other.hardwareSummary &&
        platform == other.platform &&
        supports == other.supports &&
        recommendedBackend == other.recommendedBackend &&
        recommendationReason == other.recommendationReason &&
        offeredBackends == other.offeredBackends &&
        installed == other.installed &&
        selectedTag == other.selectedTag &&
        selectedBackend == other.selectedBackend &&
        selectedVersion == other.selectedVersion &&
        gateVerdict == other.gateVerdict &&
        gateReason == other.gateReason &&
        installingBackend == other.installingBackend &&
        progressReceived == other.progressReceived &&
        progressTotal == other.progressTotal &&
        bytesPerSecond == other.bytesPerSecond &&
        errorMessage == other.errorMessage &&
        noticeMessage == other.noticeMessage;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, loading.hashCode);
    _$hash = $jc(_$hash, busy.hashCode);
    _$hash = $jc(_$hash, hardwareSummary.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, supports.hashCode);
    _$hash = $jc(_$hash, recommendedBackend.hashCode);
    _$hash = $jc(_$hash, recommendationReason.hashCode);
    _$hash = $jc(_$hash, offeredBackends.hashCode);
    _$hash = $jc(_$hash, installed.hashCode);
    _$hash = $jc(_$hash, selectedTag.hashCode);
    _$hash = $jc(_$hash, selectedBackend.hashCode);
    _$hash = $jc(_$hash, selectedVersion.hashCode);
    _$hash = $jc(_$hash, gateVerdict.hashCode);
    _$hash = $jc(_$hash, gateReason.hashCode);
    _$hash = $jc(_$hash, installingBackend.hashCode);
    _$hash = $jc(_$hash, progressReceived.hashCode);
    _$hash = $jc(_$hash, progressTotal.hashCode);
    _$hash = $jc(_$hash, bytesPerSecond.hashCode);
    _$hash = $jc(_$hash, errorMessage.hashCode);
    _$hash = $jc(_$hash, noticeMessage.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RuntimeState')
          ..add('loading', loading)
          ..add('busy', busy)
          ..add('hardwareSummary', hardwareSummary)
          ..add('platform', platform)
          ..add('supports', supports)
          ..add('recommendedBackend', recommendedBackend)
          ..add('recommendationReason', recommendationReason)
          ..add('offeredBackends', offeredBackends)
          ..add('installed', installed)
          ..add('selectedTag', selectedTag)
          ..add('selectedBackend', selectedBackend)
          ..add('selectedVersion', selectedVersion)
          ..add('gateVerdict', gateVerdict)
          ..add('gateReason', gateReason)
          ..add('installingBackend', installingBackend)
          ..add('progressReceived', progressReceived)
          ..add('progressTotal', progressTotal)
          ..add('bytesPerSecond', bytesPerSecond)
          ..add('errorMessage', errorMessage)
          ..add('noticeMessage', noticeMessage))
        .toString();
  }
}

class RuntimeStateBuilder
    implements Builder<RuntimeState, RuntimeStateBuilder> {
  _$RuntimeState? _$v;

  bool? _loading;
  bool? get loading => _$this._loading;
  set loading(bool? loading) => _$this._loading = loading;

  bool? _busy;
  bool? get busy => _$this._busy;
  set busy(bool? busy) => _$this._busy = busy;

  String? _hardwareSummary;
  String? get hardwareSummary => _$this._hardwareSummary;
  set hardwareSummary(String? hardwareSummary) =>
      _$this._hardwareSummary = hardwareSummary;

  RuntimePlatform? _platform;
  RuntimePlatform? get platform => _$this._platform;
  set platform(RuntimePlatform? platform) => _$this._platform = platform;

  ListBuilder<BackendSupport>? _supports;
  ListBuilder<BackendSupport> get supports =>
      _$this._supports ??= ListBuilder<BackendSupport>();
  set supports(ListBuilder<BackendSupport>? supports) =>
      _$this._supports = supports;

  RuntimeBackend? _recommendedBackend;
  RuntimeBackend? get recommendedBackend => _$this._recommendedBackend;
  set recommendedBackend(RuntimeBackend? recommendedBackend) =>
      _$this._recommendedBackend = recommendedBackend;

  String? _recommendationReason;
  String? get recommendationReason => _$this._recommendationReason;
  set recommendationReason(String? recommendationReason) =>
      _$this._recommendationReason = recommendationReason;

  ListBuilder<RuntimeBackend>? _offeredBackends;
  ListBuilder<RuntimeBackend> get offeredBackends =>
      _$this._offeredBackends ??= ListBuilder<RuntimeBackend>();
  set offeredBackends(ListBuilder<RuntimeBackend>? offeredBackends) =>
      _$this._offeredBackends = offeredBackends;

  ListBuilder<RuntimeInstallRef>? _installed;
  ListBuilder<RuntimeInstallRef> get installed =>
      _$this._installed ??= ListBuilder<RuntimeInstallRef>();
  set installed(ListBuilder<RuntimeInstallRef>? installed) =>
      _$this._installed = installed;

  String? _selectedTag;
  String? get selectedTag => _$this._selectedTag;
  set selectedTag(String? selectedTag) => _$this._selectedTag = selectedTag;

  RuntimeBackend? _selectedBackend;
  RuntimeBackend? get selectedBackend => _$this._selectedBackend;
  set selectedBackend(RuntimeBackend? selectedBackend) =>
      _$this._selectedBackend = selectedBackend;

  String? _selectedVersion;
  String? get selectedVersion => _$this._selectedVersion;
  set selectedVersion(String? selectedVersion) =>
      _$this._selectedVersion = selectedVersion;

  RuntimeGateVerdict? _gateVerdict;
  RuntimeGateVerdict? get gateVerdict => _$this._gateVerdict;
  set gateVerdict(RuntimeGateVerdict? gateVerdict) =>
      _$this._gateVerdict = gateVerdict;

  String? _gateReason;
  String? get gateReason => _$this._gateReason;
  set gateReason(String? gateReason) => _$this._gateReason = gateReason;

  RuntimeBackend? _installingBackend;
  RuntimeBackend? get installingBackend => _$this._installingBackend;
  set installingBackend(RuntimeBackend? installingBackend) =>
      _$this._installingBackend = installingBackend;

  int? _progressReceived;
  int? get progressReceived => _$this._progressReceived;
  set progressReceived(int? progressReceived) =>
      _$this._progressReceived = progressReceived;

  int? _progressTotal;
  int? get progressTotal => _$this._progressTotal;
  set progressTotal(int? progressTotal) =>
      _$this._progressTotal = progressTotal;

  double? _bytesPerSecond;
  double? get bytesPerSecond => _$this._bytesPerSecond;
  set bytesPerSecond(double? bytesPerSecond) =>
      _$this._bytesPerSecond = bytesPerSecond;

  String? _errorMessage;
  String? get errorMessage => _$this._errorMessage;
  set errorMessage(String? errorMessage) => _$this._errorMessage = errorMessage;

  String? _noticeMessage;
  String? get noticeMessage => _$this._noticeMessage;
  set noticeMessage(String? noticeMessage) =>
      _$this._noticeMessage = noticeMessage;

  RuntimeStateBuilder();

  RuntimeStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _loading = $v.loading;
      _busy = $v.busy;
      _hardwareSummary = $v.hardwareSummary;
      _platform = $v.platform;
      _supports = $v.supports.toBuilder();
      _recommendedBackend = $v.recommendedBackend;
      _recommendationReason = $v.recommendationReason;
      _offeredBackends = $v.offeredBackends.toBuilder();
      _installed = $v.installed.toBuilder();
      _selectedTag = $v.selectedTag;
      _selectedBackend = $v.selectedBackend;
      _selectedVersion = $v.selectedVersion;
      _gateVerdict = $v.gateVerdict;
      _gateReason = $v.gateReason;
      _installingBackend = $v.installingBackend;
      _progressReceived = $v.progressReceived;
      _progressTotal = $v.progressTotal;
      _bytesPerSecond = $v.bytesPerSecond;
      _errorMessage = $v.errorMessage;
      _noticeMessage = $v.noticeMessage;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RuntimeState other) {
    _$v = other as _$RuntimeState;
  }

  @override
  void update(void Function(RuntimeStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RuntimeState build() => _build();

  _$RuntimeState _build() {
    _$RuntimeState _$result;
    try {
      _$result =
          _$v ??
          _$RuntimeState._(
            loading: BuiltValueNullFieldError.checkNotNull(
              loading,
              r'RuntimeState',
              'loading',
            ),
            busy: BuiltValueNullFieldError.checkNotNull(
              busy,
              r'RuntimeState',
              'busy',
            ),
            hardwareSummary: hardwareSummary,
            platform: platform,
            supports: supports.build(),
            recommendedBackend: recommendedBackend,
            recommendationReason: recommendationReason,
            offeredBackends: offeredBackends.build(),
            installed: installed.build(),
            selectedTag: selectedTag,
            selectedBackend: selectedBackend,
            selectedVersion: selectedVersion,
            gateVerdict: gateVerdict,
            gateReason: gateReason,
            installingBackend: installingBackend,
            progressReceived: BuiltValueNullFieldError.checkNotNull(
              progressReceived,
              r'RuntimeState',
              'progressReceived',
            ),
            progressTotal: BuiltValueNullFieldError.checkNotNull(
              progressTotal,
              r'RuntimeState',
              'progressTotal',
            ),
            bytesPerSecond: BuiltValueNullFieldError.checkNotNull(
              bytesPerSecond,
              r'RuntimeState',
              'bytesPerSecond',
            ),
            errorMessage: errorMessage,
            noticeMessage: noticeMessage,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'supports';
        supports.build();

        _$failedField = 'offeredBackends';
        offeredBackends.build();
        _$failedField = 'installed';
        installed.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'RuntimeState',
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
