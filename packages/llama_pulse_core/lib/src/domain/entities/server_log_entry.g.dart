// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_log_entry.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ServerLogEntry> _$serverLogEntrySerializer =
    _$ServerLogEntrySerializer();

class _$ServerLogEntrySerializer
    implements StructuredSerializer<ServerLogEntry> {
  @override
  final Iterable<Type> types = const [ServerLogEntry, _$ServerLogEntry];
  @override
  final String wireName = 'ServerLogEntry';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    ServerLogEntry object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'sequence',
      serializers.serialize(
        object.sequence,
        specifiedType: const FullType(int),
      ),
      'timestampEpochMs',
      serializers.serialize(
        object.timestampEpochMs,
        specifiedType: const FullType(int),
      ),
      'stream',
      serializers.serialize(
        object.stream,
        specifiedType: const FullType(ServerLogStream),
      ),
      'line',
      serializers.serialize(object.line, specifiedType: const FullType(String)),
    ];

    return result;
  }

  @override
  ServerLogEntry deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ServerLogEntryBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'sequence':
          result.sequence =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'timestampEpochMs':
          result.timestampEpochMs =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(int),
                  )!
                  as int;
          break;
        case 'stream':
          result.stream =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(ServerLogStream),
                  )!
                  as ServerLogStream;
          break;
        case 'line':
          result.line =
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

class _$ServerLogEntry extends ServerLogEntry {
  @override
  final int sequence;
  @override
  final int timestampEpochMs;
  @override
  final ServerLogStream stream;
  @override
  final String line;

  factory _$ServerLogEntry([void Function(ServerLogEntryBuilder)? updates]) =>
      (ServerLogEntryBuilder()..update(updates))._build();

  _$ServerLogEntry._({
    required this.sequence,
    required this.timestampEpochMs,
    required this.stream,
    required this.line,
  }) : super._();
  @override
  ServerLogEntry rebuild(void Function(ServerLogEntryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ServerLogEntryBuilder toBuilder() => ServerLogEntryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ServerLogEntry &&
        sequence == other.sequence &&
        timestampEpochMs == other.timestampEpochMs &&
        stream == other.stream &&
        line == other.line;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, sequence.hashCode);
    _$hash = $jc(_$hash, timestampEpochMs.hashCode);
    _$hash = $jc(_$hash, stream.hashCode);
    _$hash = $jc(_$hash, line.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ServerLogEntry')
          ..add('sequence', sequence)
          ..add('timestampEpochMs', timestampEpochMs)
          ..add('stream', stream)
          ..add('line', line))
        .toString();
  }
}

class ServerLogEntryBuilder
    implements Builder<ServerLogEntry, ServerLogEntryBuilder> {
  _$ServerLogEntry? _$v;

  int? _sequence;
  int? get sequence => _$this._sequence;
  set sequence(int? sequence) => _$this._sequence = sequence;

  int? _timestampEpochMs;
  int? get timestampEpochMs => _$this._timestampEpochMs;
  set timestampEpochMs(int? timestampEpochMs) =>
      _$this._timestampEpochMs = timestampEpochMs;

  ServerLogStream? _stream;
  ServerLogStream? get stream => _$this._stream;
  set stream(ServerLogStream? stream) => _$this._stream = stream;

  String? _line;
  String? get line => _$this._line;
  set line(String? line) => _$this._line = line;

  ServerLogEntryBuilder();

  ServerLogEntryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _sequence = $v.sequence;
      _timestampEpochMs = $v.timestampEpochMs;
      _stream = $v.stream;
      _line = $v.line;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ServerLogEntry other) {
    _$v = other as _$ServerLogEntry;
  }

  @override
  void update(void Function(ServerLogEntryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ServerLogEntry build() => _build();

  _$ServerLogEntry _build() {
    final _$result =
        _$v ??
        _$ServerLogEntry._(
          sequence: BuiltValueNullFieldError.checkNotNull(
            sequence,
            r'ServerLogEntry',
            'sequence',
          ),
          timestampEpochMs: BuiltValueNullFieldError.checkNotNull(
            timestampEpochMs,
            r'ServerLogEntry',
            'timestampEpochMs',
          ),
          stream: BuiltValueNullFieldError.checkNotNull(
            stream,
            r'ServerLogEntry',
            'stream',
          ),
          line: BuiltValueNullFieldError.checkNotNull(
            line,
            r'ServerLogEntry',
            'line',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
