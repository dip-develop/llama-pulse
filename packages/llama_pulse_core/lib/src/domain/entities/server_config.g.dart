// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_config.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ServerConfig> _$serverConfigSerializer = _$ServerConfigSerializer();

class _$ServerConfigSerializer implements StructuredSerializer<ServerConfig> {
  @override
  final Iterable<Type> types = const [ServerConfig, _$ServerConfig];
  @override
  final String wireName = 'ServerConfig';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    ServerConfig object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'modelPath',
      serializers.serialize(
        object.modelPath,
        specifiedType: const FullType(String),
      ),
      'host',
      serializers.serialize(object.host, specifiedType: const FullType(String)),
      'port',
      serializers.serialize(object.port, specifiedType: const FullType(int)),
      'contextSize',
      serializers.serialize(
        object.contextSize,
        specifiedType: const FullType(int),
      ),
      'threads',
      serializers.serialize(object.threads, specifiedType: const FullType(int)),
      'gpuLayers',
      serializers.serialize(
        object.gpuLayers,
        specifiedType: const FullType(int),
      ),
      'parallelSlots',
      serializers.serialize(
        object.parallelSlots,
        specifiedType: const FullType(int),
      ),
      'modelAlias',
      serializers.serialize(
        object.modelAlias,
        specifiedType: const FullType(String),
      ),
      'apiKey',
      serializers.serialize(
        object.apiKey,
        specifiedType: const FullType(String),
      ),
      'flashAttention',
      serializers.serialize(
        object.flashAttention,
        specifiedType: const FullType(ServerFlashAttention),
      ),
      'mlock',
      serializers.serialize(object.mlock, specifiedType: const FullType(bool)),
      'mmap',
      serializers.serialize(object.mmap, specifiedType: const FullType(bool)),
      'extraArgs',
      serializers.serialize(
        object.extraArgs,
        specifiedType: const FullType(BuiltList, const [
          const FullType(String),
        ]),
      ),
      'binaryPath',
      serializers.serialize(
        object.binaryPath,
        specifiedType: const FullType(String),
      ),
      'startupTimeoutSeconds',
      serializers.serialize(
        object.startupTimeoutSeconds,
        specifiedType: const FullType(int),
      ),
    ];

    return result;
  }

  @override
  ServerConfig deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ServerConfigBuilder();

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
        case 'host':
          result.host =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'port':
          result.port =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'contextSize':
          result.contextSize =
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
        case 'gpuLayers':
          result.gpuLayers =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'parallelSlots':
          result.parallelSlots =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'modelAlias':
          result.modelAlias =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'apiKey':
          result.apiKey =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'flashAttention':
          result.flashAttention =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(ServerFlashAttention),
                  )!
                  as ServerFlashAttention;
          break;
        case 'mlock':
          result.mlock =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'mmap':
          result.mmap =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'extraArgs':
          result.extraArgs.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(String),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'binaryPath':
          result.binaryPath =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'startupTimeoutSeconds':
          result.startupTimeoutSeconds =
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

class _$ServerConfig extends ServerConfig {
  @override
  final String modelPath;
  @override
  final String host;
  @override
  final int port;
  @override
  final int contextSize;
  @override
  final int threads;
  @override
  final int gpuLayers;
  @override
  final int parallelSlots;
  @override
  final String modelAlias;
  @override
  final String apiKey;
  @override
  final ServerFlashAttention flashAttention;
  @override
  final bool mlock;
  @override
  final bool mmap;
  @override
  final BuiltList<String> extraArgs;
  @override
  final String binaryPath;
  @override
  final int startupTimeoutSeconds;

  factory _$ServerConfig([void Function(ServerConfigBuilder)? updates]) =>
      (ServerConfigBuilder()..update(updates))._build();

  _$ServerConfig._({
    required this.modelPath,
    required this.host,
    required this.port,
    required this.contextSize,
    required this.threads,
    required this.gpuLayers,
    required this.parallelSlots,
    required this.modelAlias,
    required this.apiKey,
    required this.flashAttention,
    required this.mlock,
    required this.mmap,
    required this.extraArgs,
    required this.binaryPath,
    required this.startupTimeoutSeconds,
  }) : super._();
  @override
  ServerConfig rebuild(void Function(ServerConfigBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ServerConfigBuilder toBuilder() => ServerConfigBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ServerConfig &&
        modelPath == other.modelPath &&
        host == other.host &&
        port == other.port &&
        contextSize == other.contextSize &&
        threads == other.threads &&
        gpuLayers == other.gpuLayers &&
        parallelSlots == other.parallelSlots &&
        modelAlias == other.modelAlias &&
        apiKey == other.apiKey &&
        flashAttention == other.flashAttention &&
        mlock == other.mlock &&
        mmap == other.mmap &&
        extraArgs == other.extraArgs &&
        binaryPath == other.binaryPath &&
        startupTimeoutSeconds == other.startupTimeoutSeconds;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, modelPath.hashCode);
    _$hash = $jc(_$hash, host.hashCode);
    _$hash = $jc(_$hash, port.hashCode);
    _$hash = $jc(_$hash, contextSize.hashCode);
    _$hash = $jc(_$hash, threads.hashCode);
    _$hash = $jc(_$hash, gpuLayers.hashCode);
    _$hash = $jc(_$hash, parallelSlots.hashCode);
    _$hash = $jc(_$hash, modelAlias.hashCode);
    _$hash = $jc(_$hash, apiKey.hashCode);
    _$hash = $jc(_$hash, flashAttention.hashCode);
    _$hash = $jc(_$hash, mlock.hashCode);
    _$hash = $jc(_$hash, mmap.hashCode);
    _$hash = $jc(_$hash, extraArgs.hashCode);
    _$hash = $jc(_$hash, binaryPath.hashCode);
    _$hash = $jc(_$hash, startupTimeoutSeconds.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ServerConfig')
          ..add('modelPath', modelPath)
          ..add('host', host)
          ..add('port', port)
          ..add('contextSize', contextSize)
          ..add('threads', threads)
          ..add('gpuLayers', gpuLayers)
          ..add('parallelSlots', parallelSlots)
          ..add('modelAlias', modelAlias)
          ..add('apiKey', apiKey)
          ..add('flashAttention', flashAttention)
          ..add('mlock', mlock)
          ..add('mmap', mmap)
          ..add('extraArgs', extraArgs)
          ..add('binaryPath', binaryPath)
          ..add('startupTimeoutSeconds', startupTimeoutSeconds))
        .toString();
  }
}

class ServerConfigBuilder
    implements Builder<ServerConfig, ServerConfigBuilder> {
  _$ServerConfig? _$v;

  String? _modelPath;
  String? get modelPath => _$this._modelPath;
  set modelPath(String? modelPath) => _$this._modelPath = modelPath;

  String? _host;
  String? get host => _$this._host;
  set host(String? host) => _$this._host = host;

  int? _port;
  int? get port => _$this._port;
  set port(int? port) => _$this._port = port;

  int? _contextSize;
  int? get contextSize => _$this._contextSize;
  set contextSize(int? contextSize) => _$this._contextSize = contextSize;

  int? _threads;
  int? get threads => _$this._threads;
  set threads(int? threads) => _$this._threads = threads;

  int? _gpuLayers;
  int? get gpuLayers => _$this._gpuLayers;
  set gpuLayers(int? gpuLayers) => _$this._gpuLayers = gpuLayers;

  int? _parallelSlots;
  int? get parallelSlots => _$this._parallelSlots;
  set parallelSlots(int? parallelSlots) =>
      _$this._parallelSlots = parallelSlots;

  String? _modelAlias;
  String? get modelAlias => _$this._modelAlias;
  set modelAlias(String? modelAlias) => _$this._modelAlias = modelAlias;

  String? _apiKey;
  String? get apiKey => _$this._apiKey;
  set apiKey(String? apiKey) => _$this._apiKey = apiKey;

  ServerFlashAttention? _flashAttention;
  ServerFlashAttention? get flashAttention => _$this._flashAttention;
  set flashAttention(ServerFlashAttention? flashAttention) =>
      _$this._flashAttention = flashAttention;

  bool? _mlock;
  bool? get mlock => _$this._mlock;
  set mlock(bool? mlock) => _$this._mlock = mlock;

  bool? _mmap;
  bool? get mmap => _$this._mmap;
  set mmap(bool? mmap) => _$this._mmap = mmap;

  ListBuilder<String>? _extraArgs;
  ListBuilder<String> get extraArgs =>
      _$this._extraArgs ??= ListBuilder<String>();
  set extraArgs(ListBuilder<String>? extraArgs) =>
      _$this._extraArgs = extraArgs;

  String? _binaryPath;
  String? get binaryPath => _$this._binaryPath;
  set binaryPath(String? binaryPath) => _$this._binaryPath = binaryPath;

  int? _startupTimeoutSeconds;
  int? get startupTimeoutSeconds => _$this._startupTimeoutSeconds;
  set startupTimeoutSeconds(int? startupTimeoutSeconds) =>
      _$this._startupTimeoutSeconds = startupTimeoutSeconds;

  ServerConfigBuilder();

  ServerConfigBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _modelPath = $v.modelPath;
      _host = $v.host;
      _port = $v.port;
      _contextSize = $v.contextSize;
      _threads = $v.threads;
      _gpuLayers = $v.gpuLayers;
      _parallelSlots = $v.parallelSlots;
      _modelAlias = $v.modelAlias;
      _apiKey = $v.apiKey;
      _flashAttention = $v.flashAttention;
      _mlock = $v.mlock;
      _mmap = $v.mmap;
      _extraArgs = $v.extraArgs.toBuilder();
      _binaryPath = $v.binaryPath;
      _startupTimeoutSeconds = $v.startupTimeoutSeconds;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ServerConfig other) {
    _$v = other as _$ServerConfig;
  }

  @override
  void update(void Function(ServerConfigBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ServerConfig build() => _build();

  _$ServerConfig _build() {
    _$ServerConfig _$result;
    try {
      _$result =
          _$v ??
          _$ServerConfig._(
            modelPath: BuiltValueNullFieldError.checkNotNull(
              modelPath,
              r'ServerConfig',
              'modelPath',
            ),
            host: BuiltValueNullFieldError.checkNotNull(
              host,
              r'ServerConfig',
              'host',
            ),
            port: BuiltValueNullFieldError.checkNotNull(
              port,
              r'ServerConfig',
              'port',
            ),
            contextSize: BuiltValueNullFieldError.checkNotNull(
              contextSize,
              r'ServerConfig',
              'contextSize',
            ),
            threads: BuiltValueNullFieldError.checkNotNull(
              threads,
              r'ServerConfig',
              'threads',
            ),
            gpuLayers: BuiltValueNullFieldError.checkNotNull(
              gpuLayers,
              r'ServerConfig',
              'gpuLayers',
            ),
            parallelSlots: BuiltValueNullFieldError.checkNotNull(
              parallelSlots,
              r'ServerConfig',
              'parallelSlots',
            ),
            modelAlias: BuiltValueNullFieldError.checkNotNull(
              modelAlias,
              r'ServerConfig',
              'modelAlias',
            ),
            apiKey: BuiltValueNullFieldError.checkNotNull(
              apiKey,
              r'ServerConfig',
              'apiKey',
            ),
            flashAttention: BuiltValueNullFieldError.checkNotNull(
              flashAttention,
              r'ServerConfig',
              'flashAttention',
            ),
            mlock: BuiltValueNullFieldError.checkNotNull(
              mlock,
              r'ServerConfig',
              'mlock',
            ),
            mmap: BuiltValueNullFieldError.checkNotNull(
              mmap,
              r'ServerConfig',
              'mmap',
            ),
            extraArgs: extraArgs.build(),
            binaryPath: BuiltValueNullFieldError.checkNotNull(
              binaryPath,
              r'ServerConfig',
              'binaryPath',
            ),
            startupTimeoutSeconds: BuiltValueNullFieldError.checkNotNull(
              startupTimeoutSeconds,
              r'ServerConfig',
              'startupTimeoutSeconds',
            ),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'extraArgs';
        extraArgs.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ServerConfig',
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
