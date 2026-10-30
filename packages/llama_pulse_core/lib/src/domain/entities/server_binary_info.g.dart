// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_binary_info.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ServerBinaryInfo> _$serverBinaryInfoSerializer =
    _$ServerBinaryInfoSerializer();

class _$ServerBinaryInfoSerializer
    implements StructuredSerializer<ServerBinaryInfo> {
  @override
  final Iterable<Type> types = const [ServerBinaryInfo, _$ServerBinaryInfo];
  @override
  final String wireName = 'ServerBinaryInfo';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    ServerBinaryInfo object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'path',
      serializers.serialize(object.path, specifiedType: const FullType(String)),
      'version',
      serializers.serialize(
        object.version,
        specifiedType: const FullType(String),
      ),
      'supported',
      serializers.serialize(
        object.supported,
        specifiedType: const FullType(bool),
      ),
      'rawOutput',
      serializers.serialize(
        object.rawOutput,
        specifiedType: const FullType(String),
      ),
    ];
    Object? value;
    value = object.buildNumber;
    if (value != null) {
      result
        ..add('buildNumber')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.commit;
    if (value != null) {
      result
        ..add('commit')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.warning;
    if (value != null) {
      result
        ..add('warning')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    return result;
  }

  @override
  ServerBinaryInfo deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ServerBinaryInfoBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'path':
          result.path =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'version':
          result.version =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'buildNumber':
          result.buildNumber = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'commit':
          result.commit = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'supported':
          result.supported =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'warning':
          result.warning = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'rawOutput':
          result.rawOutput =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
      }
    }

    return result.build();
  }
}

class _$ServerBinaryInfo extends ServerBinaryInfo {
  @override
  final String path;
  @override
  final String version;
  @override
  final int? buildNumber;
  @override
  final String? commit;
  @override
  final bool supported;
  @override
  final String? warning;
  @override
  final String rawOutput;

  factory _$ServerBinaryInfo([
    void Function(ServerBinaryInfoBuilder)? updates,
  ]) => (ServerBinaryInfoBuilder()..update(updates))._build();

  _$ServerBinaryInfo._({
    required this.path,
    required this.version,
    this.buildNumber,
    this.commit,
    required this.supported,
    this.warning,
    required this.rawOutput,
  }) : super._();
  @override
  ServerBinaryInfo rebuild(void Function(ServerBinaryInfoBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ServerBinaryInfoBuilder toBuilder() =>
      ServerBinaryInfoBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ServerBinaryInfo &&
        path == other.path &&
        version == other.version &&
        buildNumber == other.buildNumber &&
        commit == other.commit &&
        supported == other.supported &&
        warning == other.warning &&
        rawOutput == other.rawOutput;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, path.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, buildNumber.hashCode);
    _$hash = $jc(_$hash, commit.hashCode);
    _$hash = $jc(_$hash, supported.hashCode);
    _$hash = $jc(_$hash, warning.hashCode);
    _$hash = $jc(_$hash, rawOutput.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ServerBinaryInfo')
          ..add('path', path)
          ..add('version', version)
          ..add('buildNumber', buildNumber)
          ..add('commit', commit)
          ..add('supported', supported)
          ..add('warning', warning)
          ..add('rawOutput', rawOutput))
        .toString();
  }
}

class ServerBinaryInfoBuilder
    implements Builder<ServerBinaryInfo, ServerBinaryInfoBuilder> {
  _$ServerBinaryInfo? _$v;

  String? _path;
  String? get path => _$this._path;
  set path(String? path) => _$this._path = path;

  String? _version;
  String? get version => _$this._version;
  set version(String? version) => _$this._version = version;

  int? _buildNumber;
  int? get buildNumber => _$this._buildNumber;
  set buildNumber(int? buildNumber) => _$this._buildNumber = buildNumber;

  String? _commit;
  String? get commit => _$this._commit;
  set commit(String? commit) => _$this._commit = commit;

  bool? _supported;
  bool? get supported => _$this._supported;
  set supported(bool? supported) => _$this._supported = supported;

  String? _warning;
  String? get warning => _$this._warning;
  set warning(String? warning) => _$this._warning = warning;

  String? _rawOutput;
  String? get rawOutput => _$this._rawOutput;
  set rawOutput(String? rawOutput) => _$this._rawOutput = rawOutput;

  ServerBinaryInfoBuilder();

  ServerBinaryInfoBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _path = $v.path;
      _version = $v.version;
      _buildNumber = $v.buildNumber;
      _commit = $v.commit;
      _supported = $v.supported;
      _warning = $v.warning;
      _rawOutput = $v.rawOutput;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ServerBinaryInfo other) {
    _$v = other as _$ServerBinaryInfo;
  }

  @override
  void update(void Function(ServerBinaryInfoBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ServerBinaryInfo build() => _build();

  _$ServerBinaryInfo _build() {
    final _$result =
        _$v ??
        _$ServerBinaryInfo._(
          path: BuiltValueNullFieldError.checkNotNull(
            path,
            r'ServerBinaryInfo',
            'path',
          ),
          version: BuiltValueNullFieldError.checkNotNull(
            version,
            r'ServerBinaryInfo',
            'version',
          ),
          buildNumber: buildNumber,
          commit: commit,
          supported: BuiltValueNullFieldError.checkNotNull(
            supported,
            r'ServerBinaryInfo',
            'supported',
          ),
          warning: warning,
          rawOutput: BuiltValueNullFieldError.checkNotNull(
            rawOutput,
            r'ServerBinaryInfo',
            'rawOutput',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
