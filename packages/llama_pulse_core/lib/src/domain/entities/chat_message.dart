import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'chat_message.g.dart';

/// One message in a chat prompt, rendered by the model's chat template.
abstract class ChatMessage implements Built<ChatMessage, ChatMessageBuilder> {
  /// The `system` template role.
  static const String roleSystem = 'system';

  /// The `user` template role.
  static const String roleUser = 'user';

  /// The `assistant` template role.
  static const String roleAssistant = 'assistant';

  /// The `tool` template role.
  static const String roleTool = 'tool';

  /// Roles the llama.cpp chat template machinery understands.
  static const List<String> knownRoles = <String>[
    roleSystem,
    roleUser,
    roleAssistant,
    roleTool,
  ];

  /// Template role, for example `system`, `user` or `assistant`.
  String get role;

  /// Message text.
  String get content;

  /// Whether [role] is one of [knownRoles].
  bool get hasKnownRole => knownRoles.contains(role);

  factory ChatMessage([void Function(ChatMessageBuilder)? updates]) =
      _$ChatMessage;

  /// Creates one message.
  factory ChatMessage.create({required String role, required String content}) =>
      ChatMessage(
        (b) => b
          ..role = role
          ..content = content,
      );

  ChatMessage._();

  static Serializer<ChatMessage> get serializer => _$chatMessageSerializer;
}
