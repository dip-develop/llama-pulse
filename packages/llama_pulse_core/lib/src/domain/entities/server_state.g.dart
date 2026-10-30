// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ServerState> _$serverStateSerializer = _$ServerStateSerializer();

class _$ServerStateSerializer implements StructuredSerializer<ServerState> {
  @override
  final Iterable<Type> types = const [ServerState, _$ServerState];
  @override
  final String wireName = 'ServerState';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    ServerState object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'phase',
      serializers.serialize(
        object.phase,
        specifiedType: const FullType(ServerPhase),
      ),
      'health',
      serializers.serialize(
        object.health,
        specifiedType: const FullType(ServerHealth),
      ),
      'host',
      serializers.serialize(object.host, specifiedType: const FullType(String)),
      'port',
      serializers.serialize(object.port, specifiedType: const FullType(int)),
      'modelPath',
      serializers.serialize(
        object.modelPath,
        specifiedType: const FullType(String),
      ),
      'binaryPath',
      serializers.serialize(
        object.binaryPath,
        specifiedType: const FullType(String),
      ),
      'updatedAtEpochMs',
      serializers.serialize(
        object.updatedAtEpochMs,
        specifiedType: const FullType(int),
      ),
    ];
    Object? value;
    value = object.supervisorPid;
    if (value != null) {
      result
        ..add('supervisorPid')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.serverPid;
    if (value != null) {
      result
        ..add('serverPid')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.binaryVersion;
    if (value != null) {
      result
        ..add('binaryVersion')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    value = object.startedAtEpochMs;
    if (value != null) {
      result
        ..add('startedAtEpochMs')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.lastExitCode;
    if (value != null) {
      result
        ..add('lastExitCode')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.failure;
    if (value != null) {
      result
        ..add('failure')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(ServerFailure),
          ),
        );
    }
    return result;
  }

  @override
  ServerState deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ServerStateBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'phase':
          result.phase =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(ServerPhase),
                  )!
                  as ServerPhase;
          break;
        case 'health':
          result.health =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(ServerHealth),
                  )!
                  as ServerHealth;
          break;
        case 'supervisorPid':
          result.supervisorPid = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'serverPid':
          result.serverPid = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
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
        case 'modelPath':
          result.modelPath =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'binaryPath':
          result.binaryPath =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'binaryVersion':
          result.binaryVersion = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
        case 'startedAtEpochMs':
          result.startedAtEpochMs = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'updatedAtEpochMs':
          result.updatedAtEpochMs =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'lastExitCode':
          result.lastExitCode = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'failure':
          result.failure.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(ServerFailure),
                )!
                as ServerFailure,
          );
          break;
      }
    }

    return result.build();
  }
}

class _$ServerState extends ServerState {
  @override
  final ServerPhase phase;
  @override
  final ServerHealth health;
  @override
  final int? supervisorPid;
  @override
  final int? serverPid;
  @override
  final String host;
  @override
  final int port;
  @override
  final String modelPath;
  @override
  final String binaryPath;
  @override
  final String? binaryVersion;
  @override
  final int? startedAtEpochMs;
  @override
  final int updatedAtEpochMs;
  @override
  final int? lastExitCode;
  @override
  final ServerFailure? failure;

  factory _$ServerState([void Function(ServerStateBuilder)? updates]) =>
      (ServerStateBuilder()..update(updates))._build();

  _$ServerState._({
    required this.phase,
    required this.health,
    this.supervisorPid,
    this.serverPid,
    required this.host,
    required this.port,
    required this.modelPath,
    required this.binaryPath,
    this.binaryVersion,
    this.startedAtEpochMs,
    required this.updatedAtEpochMs,
    this.lastExitCode,
    this.failure,
  }) : super._();
  @override
  ServerState rebuild(void Function(ServerStateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ServerStateBuilder toBuilder() => ServerStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ServerState &&
        phase == other.phase &&
        health == other.health &&
        supervisorPid == other.supervisorPid &&
        serverPid == other.serverPid &&
        host == other.host &&
        port == other.port &&
        modelPath == other.modelPath &&
        binaryPath == other.binaryPath &&
        binaryVersion == other.binaryVersion &&
        startedAtEpochMs == other.startedAtEpochMs &&
        updatedAtEpochMs == other.updatedAtEpochMs &&
        lastExitCode == other.lastExitCode &&
        failure == other.failure;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, phase.hashCode);
    _$hash = $jc(_$hash, health.hashCode);
    _$hash = $jc(_$hash, supervisorPid.hashCode);
    _$hash = $jc(_$hash, serverPid.hashCode);
    _$hash = $jc(_$hash, host.hashCode);
    _$hash = $jc(_$hash, port.hashCode);
    _$hash = $jc(_$hash, modelPath.hashCode);
    _$hash = $jc(_$hash, binaryPath.hashCode);
    _$hash = $jc(_$hash, binaryVersion.hashCode);
    _$hash = $jc(_$hash, startedAtEpochMs.hashCode);
    _$hash = $jc(_$hash, updatedAtEpochMs.hashCode);
    _$hash = $jc(_$hash, lastExitCode.hashCode);
    _$hash = $jc(_$hash, failure.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ServerState')
          ..add('phase', phase)
          ..add('health', health)
          ..add('supervisorPid', supervisorPid)
          ..add('serverPid', serverPid)
          ..add('host', host)
          ..add('port', port)
          ..add('modelPath', modelPath)
          ..add('binaryPath', binaryPath)
          ..add('binaryVersion', binaryVersion)
          ..add('startedAtEpochMs', startedAtEpochMs)
          ..add('updatedAtEpochMs', updatedAtEpochMs)
          ..add('lastExitCode', lastExitCode)
          ..add('failure', failure))
        .toString();
  }
}

class ServerStateBuilder implements Builder<ServerState, ServerStateBuilder> {
  _$ServerState? _$v;

  ServerPhase? _phase;
  ServerPhase? get phase => _$this._phase;
  set phase(ServerPhase? phase) => _$this._phase = phase;

  ServerHealth? _health;
  ServerHealth? get health => _$this._health;
  set health(ServerHealth? health) => _$this._health = health;

  int? _supervisorPid;
  int? get supervisorPid => _$this._supervisorPid;
  set supervisorPid(int? supervisorPid) =>
      _$this._supervisorPid = supervisorPid;

  int? _serverPid;
  int? get serverPid => _$this._serverPid;
  set serverPid(int? serverPid) => _$this._serverPid = serverPid;

  String? _host;
  String? get host => _$this._host;
  set host(String? host) => _$this._host = host;

  int? _port;
  int? get port => _$this._port;
  set port(int? port) => _$this._port = port;

  String? _modelPath;
  String? get modelPath => _$this._modelPath;
  set modelPath(String? modelPath) => _$this._modelPath = modelPath;

  String? _binaryPath;
  String? get binaryPath => _$this._binaryPath;
  set binaryPath(String? binaryPath) => _$this._binaryPath = binaryPath;

  String? _binaryVersion;
  String? get binaryVersion => _$this._binaryVersion;
  set binaryVersion(String? binaryVersion) =>
      _$this._binaryVersion = binaryVersion;

  int? _startedAtEpochMs;
  int? get startedAtEpochMs => _$this._startedAtEpochMs;
  set startedAtEpochMs(int? startedAtEpochMs) =>
      _$this._startedAtEpochMs = startedAtEpochMs;

  int? _updatedAtEpochMs;
  int? get updatedAtEpochMs => _$this._updatedAtEpochMs;
  set updatedAtEpochMs(int? updatedAtEpochMs) =>
      _$this._updatedAtEpochMs = updatedAtEpochMs;

  int? _lastExitCode;
  int? get lastExitCode => _$this._lastExitCode;
  set lastExitCode(int? lastExitCode) => _$this._lastExitCode = lastExitCode;

  ServerFailureBuilder? _failure;
  ServerFailureBuilder get failure =>
      _$this._failure ??= ServerFailureBuilder();
  set failure(ServerFailureBuilder? failure) => _$this._failure = failure;

  ServerStateBuilder();

  ServerStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _phase = $v.phase;
      _health = $v.health;
      _supervisorPid = $v.supervisorPid;
      _serverPid = $v.serverPid;
      _host = $v.host;
      _port = $v.port;
      _modelPath = $v.modelPath;
      _binaryPath = $v.binaryPath;
      _binaryVersion = $v.binaryVersion;
      _startedAtEpochMs = $v.startedAtEpochMs;
      _updatedAtEpochMs = $v.updatedAtEpochMs;
      _lastExitCode = $v.lastExitCode;
      _failure = $v.failure?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ServerState other) {
    _$v = other as _$ServerState;
  }

  @override
  void update(void Function(ServerStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ServerState build() => _build();

  _$ServerState _build() {
    _$ServerState _$result;
    try {
      _$result =
          _$v ??
          _$ServerState._(
            phase: BuiltValueNullFieldError.checkNotNull(
              phase,
              r'ServerState',
              'phase',
            ),
            health: BuiltValueNullFieldError.checkNotNull(
              health,
              r'ServerState',
              'health',
            ),
            supervisorPid: supervisorPid,
            serverPid: serverPid,
            host: BuiltValueNullFieldError.checkNotNull(
              host,
              r'ServerState',
              'host',
            ),
            port: BuiltValueNullFieldError.checkNotNull(
              port,
              r'ServerState',
              'port',
            ),
            modelPath: BuiltValueNullFieldError.checkNotNull(
              modelPath,
              r'ServerState',
              'modelPath',
            ),
            binaryPath: BuiltValueNullFieldError.checkNotNull(
              binaryPath,
              r'ServerState',
              'binaryPath',
            ),
            binaryVersion: binaryVersion,
            startedAtEpochMs: startedAtEpochMs,
            updatedAtEpochMs: BuiltValueNullFieldError.checkNotNull(
              updatedAtEpochMs,
              r'ServerState',
              'updatedAtEpochMs',
            ),
            lastExitCode: lastExitCode,
            failure: _failure?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'failure';
        _failure?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ServerState',
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
