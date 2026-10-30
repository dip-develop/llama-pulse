// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_failure.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<InferenceFailure> _$inferenceFailureSerializer =
    _$InferenceFailureSerializer();

class _$InferenceFailureSerializer
    implements StructuredSerializer<InferenceFailure> {
  @override
  final Iterable<Type> types = const [InferenceFailure, _$InferenceFailure];
  @override
  final String wireName = 'InferenceFailure';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    InferenceFailure object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'code',
      serializers.serialize(
        object.code,
        specifiedType: const FullType(InferenceFailureCode),
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
  InferenceFailure deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = InferenceFailureBuilder();

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
                    specifiedType: const FullType(InferenceFailureCode),
                  )!
                  as InferenceFailureCode;
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

class _$InferenceFailure extends InferenceFailure {
  @override
  final InferenceFailureCode code;
  @override
  final String message;
  @override
  final String? details;

  factory _$InferenceFailure([
    void Function(InferenceFailureBuilder)? updates,
  ]) => (InferenceFailureBuilder()..update(updates))._build();

  _$InferenceFailure._({
    required this.code,
    required this.message,
    this.details,
  }) : super._();
  @override
  InferenceFailure rebuild(void Function(InferenceFailureBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  InferenceFailureBuilder toBuilder() =>
      InferenceFailureBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is InferenceFailure &&
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
    return (newBuiltValueToStringHelper(r'InferenceFailure')
          ..add('code', code)
          ..add('message', message)
          ..add('details', details))
        .toString();
  }
}

class InferenceFailureBuilder
    implements Builder<InferenceFailure, InferenceFailureBuilder> {
  _$InferenceFailure? _$v;

  InferenceFailureCode? _code;
  InferenceFailureCode? get code => _$this._code;
  set code(InferenceFailureCode? code) => _$this._code = code;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  String? _details;
  String? get details => _$this._details;
  set details(String? details) => _$this._details = details;

  InferenceFailureBuilder();

  InferenceFailureBuilder get _$this {
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
  void replace(InferenceFailure other) {
    _$v = other as _$InferenceFailure;
  }

  @override
  void update(void Function(InferenceFailureBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  InferenceFailure build() => _build();

  _$InferenceFailure _build() {
    final _$result =
        _$v ??
        _$InferenceFailure._(
          code: BuiltValueNullFieldError.checkNotNull(
            code,
            r'InferenceFailure',
            'code',
          ),
          message: BuiltValueNullFieldError.checkNotNull(
            message,
            r'InferenceFailure',
            'message',
          ),
          details: details,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
