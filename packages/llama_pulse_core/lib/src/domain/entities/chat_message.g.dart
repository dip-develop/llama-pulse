// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ChatMessage> _$chatMessageSerializer = _$ChatMessageSerializer();

class _$ChatMessageSerializer implements StructuredSerializer<ChatMessage> {
  @override
  final Iterable<Type> types = const [ChatMessage, _$ChatMessage];
  @override
  final String wireName = 'ChatMessage';

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    ChatMessage object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = <Object?>[
      'role',
      serializers.serialize(object.role, specifiedType: const FullType(String)),
      'content',
      serializers.serialize(
        object.content,
        specifiedType: const FullType(String),
      ),
    ];

    return result;
  }

  @override
  ChatMessage deserialize(
    Serializers serializers,
    Iterable<Object?> serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ChatMessageBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current! as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'role':
          result.role =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )!
                  as String;
          break;
        case 'content':
          result.content =
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

class _$ChatMessage extends ChatMessage {
  @override
  final String role;
  @override
  final String content;

  factory _$ChatMessage([void Function(ChatMessageBuilder)? updates]) =>
      (ChatMessageBuilder()..update(updates))._build();

  _$ChatMessage._({required this.role, required this.content}) : super._();
  @override
  ChatMessage rebuild(void Function(ChatMessageBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ChatMessageBuilder toBuilder() => ChatMessageBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ChatMessage &&
        role == other.role &&
        content == other.content;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jc(_$hash, content.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ChatMessage')
          ..add('role', role)
          ..add('content', content))
        .toString();
  }
}

class ChatMessageBuilder implements Builder<ChatMessage, ChatMessageBuilder> {
  _$ChatMessage? _$v;

  String? _role;
  String? get role => _$this._role;
  set role(String? role) => _$this._role = role;

  String? _content;
  String? get content => _$this._content;
  set content(String? content) => _$this._content = content;

  ChatMessageBuilder();

  ChatMessageBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _role = $v.role;
      _content = $v.content;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ChatMessage other) {
    _$v = other as _$ChatMessage;
  }

  @override
  void update(void Function(ChatMessageBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ChatMessage build() => _build();

  _$ChatMessage _build() {
    final _$result =
        _$v ??
        _$ChatMessage._(
          role: BuiltValueNullFieldError.checkNotNull(
            role,
            r'ChatMessage',
            'role',
          ),
          content: BuiltValueNullFieldError.checkNotNull(
            content,
            r'ChatMessage',
            'content',
          ),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
