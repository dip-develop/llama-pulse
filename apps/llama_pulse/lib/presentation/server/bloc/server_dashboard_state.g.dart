// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_dashboard_state.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ServerDashboardState> _$serverDashboardStateSerializer =
    _$ServerDashboardStateSerializer();

class _$ServerDashboardStateSerializer
    implements StructuredSerializer<ServerDashboardState> {
  @override
  final Iterable<Type> types = const [
    ServerDashboardState,
    _$ServerDashboardState,
  ];
  @override
  final String wireName = 'ServerDashboardState';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    ServerDashboardState object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'config',
      serializers.serialize(
        object.config,
        specifiedType: const FullType(ServerConfig),
      ),
      'serverState',
      serializers.serialize(
        object.serverState,
        specifiedType: const FullType(ServerState),
      ),
      'metricsHistory',
      serializers.serialize(
        object.metricsHistory,
        specifiedType: const FullType(BuiltList, const [
          const FullType(ServerMetrics),
        ]),
      ),
      'logs',
      serializers.serialize(
        object.logs,
        specifiedType: const FullType(BuiltList, const [
          const FullType(ServerLogEntry),
        ]),
      ),
      'saving',
      serializers.serialize(object.saving, specifiedType: const FullType(bool)),
      'dirty',
      serializers.serialize(object.dirty, specifiedType: const FullType(bool)),
      'testingConnection',
      serializers.serialize(
        object.testingConnection,
        specifiedType: const FullType(bool),
      ),
    ];
    Object? value;
    value = object.binaryInfo;
    if (value != null) {
      result
        ..add('binaryInfo')
        ..add(
          serializers.serialize(
            value,
            specifiedType: const FullType(ServerBinaryInfo),
          ),
        );
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
    value = object.connectionLatencyMs;
    if (value != null) {
      result
        ..add('connectionLatencyMs')
        ..add(serializers.serialize(value, specifiedType: const FullType(int)));
    }
    value = object.connectionMessage;
    if (value != null) {
      result
        ..add('connectionMessage')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    return result;
  }

  @override
  ServerDashboardState deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ServerDashboardStateBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'config':
          result.config.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(ServerConfig),
                )!
                as ServerConfig,
          );
          break;
        case 'serverState':
          result.serverState.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(ServerState),
                )!
                as ServerState,
          );
          break;
        case 'metricsHistory':
          result.metricsHistory.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(ServerMetrics),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'logs':
          result.logs.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(BuiltList, const [
                    const FullType(ServerLogEntry),
                  ]),
                )!
                as BuiltList<Object?>,
          );
          break;
        case 'binaryInfo':
          result.binaryInfo.replace(
            serializers.deserialize(
                  value,
                  specifiedType: const FullType(ServerBinaryInfo),
                )!
                as ServerBinaryInfo,
          );
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
        case 'saving':
          result.saving =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'dirty':
          result.dirty =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'testingConnection':
          result.testingConnection =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )!
                  as bool;
          break;
        case 'connectionLatencyMs':
          result.connectionLatencyMs = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int?;
          break;
        case 'connectionMessage':
          result.connectionMessage = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
      }
    }

    return result.build();
  }
}

class _$ServerDashboardState extends ServerDashboardState {
  @override
  final ServerConfig config;
  @override
  final ServerState serverState;
  @override
  final BuiltList<ServerMetrics> metricsHistory;
  @override
  final BuiltList<ServerLogEntry> logs;
  @override
  final ServerBinaryInfo? binaryInfo;
  @override
  final ServerFailure? failure;
  @override
  final bool saving;
  @override
  final bool dirty;
  @override
  final bool testingConnection;
  @override
  final int? connectionLatencyMs;
  @override
  final String? connectionMessage;

  factory _$ServerDashboardState([
    void Function(ServerDashboardStateBuilder)? updates,
  ]) => (ServerDashboardStateBuilder()..update(updates))._build();

  _$ServerDashboardState._({
    required this.config,
    required this.serverState,
    required this.metricsHistory,
    required this.logs,
    this.binaryInfo,
    this.failure,
    required this.saving,
    required this.dirty,
    required this.testingConnection,
    this.connectionLatencyMs,
    this.connectionMessage,
  }) : super._();
  @override
  ServerDashboardState rebuild(
    void Function(ServerDashboardStateBuilder) updates,
  ) => (toBuilder()..update(updates)).build();

  @override
  ServerDashboardStateBuilder toBuilder() =>
      ServerDashboardStateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ServerDashboardState &&
        config == other.config &&
        serverState == other.serverState &&
        metricsHistory == other.metricsHistory &&
        logs == other.logs &&
        binaryInfo == other.binaryInfo &&
        failure == other.failure &&
        saving == other.saving &&
        dirty == other.dirty &&
        testingConnection == other.testingConnection &&
        connectionLatencyMs == other.connectionLatencyMs &&
        connectionMessage == other.connectionMessage;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, config.hashCode);
    _$hash = $jc(_$hash, serverState.hashCode);
    _$hash = $jc(_$hash, metricsHistory.hashCode);
    _$hash = $jc(_$hash, logs.hashCode);
    _$hash = $jc(_$hash, binaryInfo.hashCode);
    _$hash = $jc(_$hash, failure.hashCode);
    _$hash = $jc(_$hash, saving.hashCode);
    _$hash = $jc(_$hash, dirty.hashCode);
    _$hash = $jc(_$hash, testingConnection.hashCode);
    _$hash = $jc(_$hash, connectionLatencyMs.hashCode);
    _$hash = $jc(_$hash, connectionMessage.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ServerDashboardState')
          ..add('config', config)
          ..add('serverState', serverState)
          ..add('metricsHistory', metricsHistory)
          ..add('logs', logs)
          ..add('binaryInfo', binaryInfo)
          ..add('failure', failure)
          ..add('saving', saving)
          ..add('dirty', dirty)
          ..add('testingConnection', testingConnection)
          ..add('connectionLatencyMs', connectionLatencyMs)
          ..add('connectionMessage', connectionMessage))
        .toString();
  }
}

class ServerDashboardStateBuilder
    implements Builder<ServerDashboardState, ServerDashboardStateBuilder> {
  _$ServerDashboardState? _$v;

  ServerConfigBuilder? _config;
  ServerConfigBuilder get config => _$this._config ??= ServerConfigBuilder();
  set config(ServerConfigBuilder? config) => _$this._config = config;

  ServerStateBuilder? _serverState;
  ServerStateBuilder get serverState =>
      _$this._serverState ??= ServerStateBuilder();
  set serverState(ServerStateBuilder? serverState) =>
      _$this._serverState = serverState;

  ListBuilder<ServerMetrics>? _metricsHistory;
  ListBuilder<ServerMetrics> get metricsHistory =>
      _$this._metricsHistory ??= ListBuilder<ServerMetrics>();
  set metricsHistory(ListBuilder<ServerMetrics>? metricsHistory) =>
      _$this._metricsHistory = metricsHistory;

  ListBuilder<ServerLogEntry>? _logs;
  ListBuilder<ServerLogEntry> get logs =>
      _$this._logs ??= ListBuilder<ServerLogEntry>();
  set logs(ListBuilder<ServerLogEntry>? logs) => _$this._logs = logs;

  ServerBinaryInfoBuilder? _binaryInfo;
  ServerBinaryInfoBuilder get binaryInfo =>
      _$this._binaryInfo ??= ServerBinaryInfoBuilder();
  set binaryInfo(ServerBinaryInfoBuilder? binaryInfo) =>
      _$this._binaryInfo = binaryInfo;

  ServerFailureBuilder? _failure;
  ServerFailureBuilder get failure =>
      _$this._failure ??= ServerFailureBuilder();
  set failure(ServerFailureBuilder? failure) => _$this._failure = failure;

  bool? _saving;
  bool? get saving => _$this._saving;
  set saving(bool? saving) => _$this._saving = saving;

  bool? _dirty;
  bool? get dirty => _$this._dirty;
  set dirty(bool? dirty) => _$this._dirty = dirty;

  bool? _testingConnection;
  bool? get testingConnection => _$this._testingConnection;
  set testingConnection(bool? testingConnection) =>
      _$this._testingConnection = testingConnection;

  int? _connectionLatencyMs;
  int? get connectionLatencyMs => _$this._connectionLatencyMs;
  set connectionLatencyMs(int? connectionLatencyMs) =>
      _$this._connectionLatencyMs = connectionLatencyMs;

  String? _connectionMessage;
  String? get connectionMessage => _$this._connectionMessage;
  set connectionMessage(String? connectionMessage) =>
      _$this._connectionMessage = connectionMessage;

  ServerDashboardStateBuilder();

  ServerDashboardStateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _config = $v.config.toBuilder();
      _serverState = $v.serverState.toBuilder();
      _metricsHistory = $v.metricsHistory.toBuilder();
      _logs = $v.logs.toBuilder();
      _binaryInfo = $v.binaryInfo?.toBuilder();
      _failure = $v.failure?.toBuilder();
      _saving = $v.saving;
      _dirty = $v.dirty;
      _testingConnection = $v.testingConnection;
      _connectionLatencyMs = $v.connectionLatencyMs;
      _connectionMessage = $v.connectionMessage;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ServerDashboardState other) {
    _$v = other as _$ServerDashboardState;
  }

  @override
  void update(void Function(ServerDashboardStateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ServerDashboardState build() => _build();

  _$ServerDashboardState _build() {
    _$ServerDashboardState _$result;
    try {
      _$result =
          _$v ??
          _$ServerDashboardState._(
            config: config.build(),
            serverState: serverState.build(),
            metricsHistory: metricsHistory.build(),
            logs: logs.build(),
            binaryInfo: _binaryInfo?.build(),
            failure: _failure?.build(),
            saving: BuiltValueNullFieldError.checkNotNull(
              saving,
              r'ServerDashboardState',
              'saving',
            ),
            dirty: BuiltValueNullFieldError.checkNotNull(
              dirty,
              r'ServerDashboardState',
              'dirty',
            ),
            testingConnection: BuiltValueNullFieldError.checkNotNull(
              testingConnection,
              r'ServerDashboardState',
              'testingConnection',
            ),
            connectionLatencyMs: connectionLatencyMs,
            connectionMessage: connectionMessage,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'config';
        config.build();
        _$failedField = 'serverState';
        serverState.build();
        _$failedField = 'metricsHistory';
        metricsHistory.build();
        _$failedField = 'logs';
        logs.build();
        _$failedField = 'binaryInfo';
        _binaryInfo?.build();
        _$failedField = 'failure';
        _failure?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
          r'ServerDashboardState',
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
