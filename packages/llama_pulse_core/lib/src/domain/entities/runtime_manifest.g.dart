// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runtime_manifest.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<RuntimeManifest> _$runtimeManifestSerializer =
    _$RuntimeManifestSerializer();

class _$RuntimeManifestSerializer
    implements StructuredSerializer<RuntimeManifest> {
  @override
  final Iterable<Type> types = const [RuntimeManifest, _$RuntimeManifest];
  @override
  final String wireName = 'RuntimeManifest';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    RuntimeManifest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'tag',
      serializers.serialize(object.tag, specifiedType: const FullType(String)),
      'build',
      serializers.serialize(
        object.buildId,
        specifiedType: const FullType(String),
      ),
      'commit',
      serializers.serialize(
        object.commit,
        specifiedType: const FullType(String),
      ),
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
      'assetName',
      serializers.serialize(
        object.assetName,
        specifiedType: const FullType(String),
      ),
      'sha256',
      serializers.serialize(
        object.sha256,
        specifiedType: const FullType(String),
      ),
      'sizeBytes',
      serializers.serialize(
        object.sizeBytes,
        specifiedType: const FullType(int),
      ),
      'installedAtEpochMs',
      serializers.serialize(
        object.installedAtEpochMs,
        specifiedType: const FullType(int),
      ),
      'backendLibs',
      serializers.serialize(
        object.backendLibs,
        specifiedType: const FullType(BuiltList, const [
          const FullType(String),
        ]),
      ),
      'files',
      serializers.serialize(object.files, specifiedType: const FullType(int)),
    ];
    Object? value;
    value = object.llamaVersion;
    if (value != null) {
      result
        ..add('llamaVersion')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.buildNumber;
    if (value != null) {
      result
        ..add('buildNumber')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.requires;
    if (value != null) {
      result
        ..add('requires')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    return result;
  }

  @override
  RuntimeManifest deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RuntimeManifestBuilder();

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
        case 'build':
          result.buildId =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'commit':
          result.commit =
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
        case 'assetName':
          result.assetName =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'sha256':
          result.sha256 =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'sizeBytes':
          result.sizeBytes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'installedAtEpochMs':
          result.installedAtEpochMs =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'llamaVersion':
          result.llamaVersion = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'buildNumber':
          result.buildNumber = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'backendLibs':
          result.backendLibs.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(String),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'requires':
          result.requires = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'files':
          result.files =
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

class _$RuntimeManifest extends RuntimeManifest {
  @override
  final String tag;
  @override
  final String buildId;
  @override
  final String commit;
  @override
  final RuntimeBackend backend;
  @override
  final RuntimePlatform platform;
  @override
  final String assetName;
  @override
  final String sha256;
  @override
  final int sizeBytes;
  @override
  final int installedAtEpochMs;
  @override
  final String? llamaVersion;
  @override
  final int? buildNumber;
  @override
  final BuiltList<String> backendLibs;
  @override
  final String? requires;
  @override
  final int files;

  factory _$RuntimeManifest([void Function(RuntimeManifestBuilder)? updates]) =>
      (RuntimeManifestBuilder()..update(updates))._build();

  _$RuntimeManifest._({
    required this.tag,
    required this.buildId,
    required this.commit,
    required this.backend,
    required this.platform,
    required this.assetName,
    required this.sha256,
    required this.sizeBytes,
    required this.installedAtEpochMs,
    this.llamaVersion,
    this.buildNumber,
    required this.backendLibs,
    this.requires,
    required this.files,
  }) : super._();
  @override
  RuntimeManifest rebuild(void Function(RuntimeManifestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RuntimeManifestBuilder toBuilder() => RuntimeManifestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RuntimeManifest &&
        tag == other.tag &&
        buildId == other.buildId &&
        commit == other.commit &&
        backend == other.backend &&
        platform == other.platform &&
        assetName == other.assetName &&
        sha256 == other.sha256 &&
        sizeBytes == other.sizeBytes &&
        installedAtEpochMs == other.installedAtEpochMs &&
        llamaVersion == other.llamaVersion &&
        buildNumber == other.buildNumber &&
        backendLibs == other.backendLibs &&
        requires == other.requires &&
        files == other.files;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, tag.hashCode);
    _$hash = $jc(_$hash, buildId.hashCode);
    _$hash = $jc(_$hash, commit.hashCode);
    _$hash = $jc(_$hash, backend.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jc(_$hash, assetName.hashCode);
    _$hash = $jc(_$hash, sha256.hashCode);
    _$hash = $jc(_$hash, sizeBytes.hashCode);
    _$hash = $jc(_$hash, installedAtEpochMs.hashCode);
    _$hash = $jc(_$hash, llamaVersion.hashCode);
    _$hash = $jc(_$hash, buildNumber.hashCode);
    _$hash = $jc(_$hash, backendLibs.hashCode);
    _$hash = $jc(_$hash, requires.hashCode);
    _$hash = $jc(_$hash, files.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RuntimeManifest')
          ..add('tag', tag)
          ..add('buildId', buildId)
          ..add('commit', commit)
          ..add('backend', backend)
          ..add('platform', platform)
          ..add('assetName', assetName)
          ..add('sha256', sha256)
          ..add('sizeBytes', sizeBytes)
          ..add('installedAtEpochMs', installedAtEpochMs)
          ..add('llamaVersion', llamaVersion)
          ..add('buildNumber', buildNumber)
          ..add('backendLibs', backendLibs)
          ..add('requires', requires)
          ..add('files', files))
        .toString();
  }
}

class RuntimeManifestBuilder
    implements Builder<RuntimeManifest, RuntimeManifestBuilder> {
  _$RuntimeManifest? _$v;

  String? _tag;
  String? get tag => _$this._tag;
  set tag(String? tag) => _$this._tag = tag;

  String? _buildId;
  String? get buildId => _$this._buildId;
  set buildId(String? buildId) => _$this._buildId = buildId;

  String? _commit;
  String? get commit => _$this._commit;
  set commit(String? commit) => _$this._commit = commit;

  RuntimeBackend? _backend;
  RuntimeBackend? get backend => _$this._backend;
  set backend(RuntimeBackend? backend) => _$this._backend = backend;

  RuntimePlatform? _platform;
  RuntimePlatform? get platform => _$this._platform;
  set platform(RuntimePlatform? platform) => _$this._platform = platform;

  String? _assetName;
  String? get assetName => _$this._assetName;
  set assetName(String? assetName) => _$this._assetName = assetName;

  String? _sha256;
  String? get sha256 => _$this._sha256;
  set sha256(String? sha256) => _$this._sha256 = sha256;

  int? _sizeBytes;
  int? get sizeBytes => _$this._sizeBytes;
  set sizeBytes(int? sizeBytes) => _$this._sizeBytes = sizeBytes;

  int? _installedAtEpochMs;
  int? get installedAtEpochMs => _$this._installedAtEpochMs;
  set installedAtEpochMs(int? installedAtEpochMs) =>
      _$this._installedAtEpochMs = installedAtEpochMs;

  String? _llamaVersion;
  String? get llamaVersion => _$this._llamaVersion;
  set llamaVersion(String? llamaVersion) => _$this._llamaVersion = llamaVersion;

  int? _buildNumber;
  int? get buildNumber => _$this._buildNumber;
  set buildNumber(int? buildNumber) => _$this._buildNumber = buildNumber;

  ListBuilder<String>? _backendLibs;
  ListBuilder<String> get backendLibs =>
      _$this._backendLibs ??= ListBuilder<String>();
  set backendLibs(ListBuilder<String>? backendLibs) =>
      _$this._backendLibs = backendLibs;

  String? _requires;
  String? get requires => _$this._requires;
  set requires(String? requires) => _$this._requires = requires;

  int? _files;
  int? get files => _$this._files;
  set files(int? files) => _$this._files = files;

  RuntimeManifestBuilder();

  RuntimeManifestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _tag = $v.tag;
      _buildId = $v.buildId;
      _commit = $v.commit;
      _backend = $v.backend;
      _platform = $v.platform;
      _assetName = $v.assetName;
      _sha256 = $v.sha256;
      _sizeBytes = $v.sizeBytes;
      _installedAtEpochMs = $v.installedAtEpochMs;
      _llamaVersion = $v.llamaVersion;
      _buildNumber = $v.buildNumber;
      _backendLibs = $v.backendLibs.toBuilder();
      _requires = $v.requires;
      _files = $v.files;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RuntimeManifest other) {
    _$v = other as _$RuntimeManifest;
  }

  @override
  void update(void Function(RuntimeManifestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RuntimeManifest build() => _build();

  _$RuntimeManifest _build() {
    _$RuntimeManifest _$result;
    try {
      _$result =
          _$v ??
          _$RuntimeManifest._(
            tag: BuiltValueNullFieldError.checkNotNull(
              tag,
              r'RuntimeManifest',
              'tag',
            ),
            buildId: BuiltValueNullFieldError.checkNotNull(
              buildId,
              r'RuntimeManifest',
              'buildId',
            ),
            commit: BuiltValueNullFieldError.checkNotNull(
              commit,
              r'RuntimeManifest',
              'commit',
            ),
            backend: BuiltValueNullFieldError.checkNotNull(
              backend,
              r'RuntimeManifest',
              'backend',
            ),
            platform: BuiltValueNullFieldError.checkNotNull(
              platform,
              r'RuntimeManifest',
              'platform',
            ),
            assetName: BuiltValueNullFieldError.checkNotNull(
              assetName,
              r'RuntimeManifest',
              'assetName',
            ),
            sha256: BuiltValueNullFieldError.checkNotNull(
              sha256,
              r'RuntimeManifest',
              'sha256',
            ),
            sizeBytes: BuiltValueNullFieldError.checkNotNull(
              sizeBytes,
              r'RuntimeManifest',
              'sizeBytes',
            ),
            installedAtEpochMs: BuiltValueNullFieldError.checkNotNull(
              installedAtEpochMs,
              r'RuntimeManifest',
              'installedAtEpochMs',
            ),
            llamaVersion: llamaVersion,
            buildNumber: buildNumber,
            backendLibs: backendLibs.build(),
            requires: requires,
            files: BuiltValueNullFieldError.checkNotNull(
              files,
              r'RuntimeManifest',
              'files',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'backendLibs';
        backendLibs.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'RuntimeManifest',
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
