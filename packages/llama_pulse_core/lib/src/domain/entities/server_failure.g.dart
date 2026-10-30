// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_failure.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ServerFailure> _$serverFailureSerializer =
    _$ServerFailureSerializer();

class _$ServerFailureSerializer implements StructuredSerializer<ServerFailure> {
  @override
  final Iterable<Type> types = const [ServerFailure, _$ServerFailure];
  @override
  final String wireName = 'ServerFailure';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    ServerFailure object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'code',
      serializers.serialize(
        object.code,
        specifiedType: const FullType(ServerFailureCode),
      ),
      'message',
      serializers.serialize(
        object.message,
        specifiedType: const FullType(String),
      ),
    ];
    Object? value;
    value = object.details;
    if (value != null) {
      result
        ..add('details')
        ..add(
          serializers.serialize(value, specifiedType: const FullType(String)),
        );
    }
    return result;
  }

  @override
  ServerFailure deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ServerFailureBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'code':
          result.code =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(ServerFailureCode),
                  )!
                  as ServerFailureCode;
          break;
        case 'message':
          result.message =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'details':
          result.details = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String?;
          break;
      }
    }

    return result.build();
  }
}

class _$ServerFailure extends ServerFailure {
  @override
  final ServerFailureCode code;
  @override
  final String message;
  @override
  final String? details;

  factory _$ServerFailure([void Function(ServerFailureBuilder)? updates]) =>
      (ServerFailureBuilder()..update(updates))._build();

  _$ServerFailure._({required this.code, required this.message, this.details})
    : super._();
  @override
  ServerFailure rebuild(void Function(ServerFailureBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ServerFailureBuilder toBuilder() => ServerFailureBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ServerFailure &&
        code == other.code &&
        message == other.message &&
        details == other.details;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, code.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, details.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ServerFailure')
          ..add('code', code)
          ..add('message', message)
          ..add('details', details))
        .toString();
  }
}

class ServerFailureBuilder
    implements Builder<ServerFailure, ServerFailureBuilder> {
  _$ServerFailure? _$v;

  ServerFailureCode? _code;
  ServerFailureCode? get code => _$this._code;
  set code(ServerFailureCode? code) => _$this._code = code;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  String? _details;
  String? get details => _$this._details;
  set details(String? details) => _$this._details = details;

  ServerFailureBuilder();

  ServerFailureBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _code = $v.code;
      _message = $v.message;
      _details = $v.details;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ServerFailure other) {
    _$v = other as _$ServerFailure;
  }

  @override
  void update(void Function(ServerFailureBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ServerFailure build() => _build();

  _$ServerFailure _build() {
    final _$result =
        _$v ??
        _$ServerFailure._(
          code: BuiltValueNullFieldError.checkNotNull(
            code,
            r'ServerFailure',
            'code',
          ),
          message: BuiltValueNullFieldError.checkNotNull(
            message,
            r'ServerFailure',
            'message',
          ),
          details: details,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
