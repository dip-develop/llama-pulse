// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime_install_ref.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<RuntimeInstallRef> _$runtimeInstallRefSerializer =
    _$RuntimeInstallRefSerializer();

class _$RuntimeInstallRefSerializer
    implements StructuredSerializer<RuntimeInstallRef> {
  @override
  final Iterable<Type> types = const [RuntimeInstallRef, _$RuntimeInstallRef];
  @override
  final String wireName = 'RuntimeInstallRef';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RuntimeInstallRef object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'tag',
      serializers.serialize(object.tag, specifiedType: const FullType(String)),
      'backend',
      serializers.serialize(
        object.backend,
        specifiedType: const FullType(RuntimeBackend),
      ),
      'platform',
      serializers.serialize(
        object.platform,
        specifiedType: const FullType(RuntimePlatform),
      ),
      'installedAtEpochMs',
      serializers.serialize(
        object.installedAtEpochMs,
        specifiedType: const FullType(int),
      ),
      'sizeBytes',
      serializers.serialize(
        object.sizeBytes,
        specifiedType: const FullType(int),
      ),
    ];

    return result;
  }

  @override
  RuntimeInstallRef deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RuntimeInstallRefBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'tag':
          result.tag =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'backend':
          result.backend =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(RuntimeBackend),
                  )!
                  as RuntimeBackend;
          break;
        case 'platform':
          result.platform =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(RuntimePlatform),
                  )!
                  as RuntimePlatform;
          break;
        case 'installedAtEpochMs':
          result.installedAtEpochMs =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'sizeBytes':
          result.sizeBytes =
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

class _$RuntimeInstallRef extends RuntimeInstallRef {
  @override
  final String tag;
  @override
  final RuntimeBackend backend;
  @override
  final RuntimePlatform platform;
  @override
  final int installedAtEpochMs;
  @override
  final int sizeBytes;

  factory _$RuntimeInstallRef([
    void Function(RuntimeInstallRefBuilder)? updates,
  ]) => (RuntimeInstallRefBuilder()..update(updates))._build();

  _$RuntimeInstallRef._({
    required this.tag,
    required this.backend,
    required this.platform,
    required this.installedAtEpochMs,
    required this.sizeBytes,
  }) : super._();
  @override
  RuntimeInstallRef rebuild(void Function(RuntimeInstallRefBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RuntimeInstallRefBuilder toBuilder() =>
      RuntimeInstallRefBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RuntimeInstallRef &&
        tag == other.tag &&
        backend == other.backend &&
        platform == other.platform &&
        installedAtEpochMs == other.installedAtEpochMs &&
        sizeBytes == other.sizeBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, tag.hashCode);
    _$hash = $jc(_$hash, backend.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, installedAtEpochMs.hashCode);
    _$hash = $jc(_$hash, sizeBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RuntimeInstallRef')
          ..add('tag', tag)
          ..add('backend', backend)
          ..add('platform', platform)
          ..add('installedAtEpochMs', installedAtEpochMs)
          ..add('sizeBytes', sizeBytes))
        .toString();
  }
}

class RuntimeInstallRefBuilder
    implements Builder<RuntimeInstallRef, RuntimeInstallRefBuilder> {
  _$RuntimeInstallRef? _$v;

  String? _tag;
  String? get tag => _$this._tag;
  set tag(String? tag) => _$this._tag = tag;

  RuntimeBackend? _backend;
  RuntimeBackend? get backend => _$this._backend;
  set backend(RuntimeBackend? backend) => _$this._backend = backend;

  RuntimePlatform? _platform;
  RuntimePlatform? get platform => _$this._platform;
  set platform(RuntimePlatform? platform) => _$this._platform = platform;

  int? _installedAtEpochMs;
  int? get installedAtEpochMs => _$this._installedAtEpochMs;
  set installedAtEpochMs(int? installedAtEpochMs) =>
      _$this._installedAtEpochMs = installedAtEpochMs;

  int? _sizeBytes;
  int? get sizeBytes => _$this._sizeBytes;
  set sizeBytes(int? sizeBytes) => _$this._sizeBytes = sizeBytes;

  RuntimeInstallRefBuilder();

  RuntimeInstallRefBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _tag = $v.tag;
      _backend = $v.backend;
      _platform = $v.platform;
      _installedAtEpochMs = $v.installedAtEpochMs;
      _sizeBytes = $v.sizeBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RuntimeInstallRef other) {
    _$v = other as _$RuntimeInstallRef;
  }

  @override
  void update(void Function(RuntimeInstallRefBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RuntimeInstallRef build() => _build();

  _$RuntimeInstallRef _build() {
    final _$result =
        _$v ??
        _$RuntimeInstallRef._(
          tag: BuiltValueNullFieldError.checkNotNull(
            tag,
            r'RuntimeInstallRef',
            'tag',
          ),
          backend: BuiltValueNullFieldError.checkNotNull(
            backend,
            r'RuntimeInstallRef',
            'backend',
          ),
          platform: BuiltValueNullFieldError.checkNotNull(
            platform,
            r'RuntimeInstallRef',
            'platform',
          ),
          installedAtEpochMs: BuiltValueNullFieldError.checkNotNull(
            installedAtEpochMs,
            r'RuntimeInstallRef',
            'installedAtEpochMs',
          ),
          sizeBytes: BuiltValueNullFieldError.checkNotNull(
            sizeBytes,
            r'RuntimeInstallRef',
            'sizeBytes',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
