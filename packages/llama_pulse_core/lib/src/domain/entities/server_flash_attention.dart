import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'server_flash_attention.g.dart';

/// Flash-attention mode passed to `llama-server` as `-fa`.
class ServerFlashAttention extends EnumClass {
  /// Let `llama-server` decide for the loaded model.
  static const ServerFlashAttention auto = _$auto;

  /// Force flash attention on.
  static const ServerFlashAttention on = _$on;

  /// Force flash attention off.
  static const ServerFlashAttention off = _$off;

  const ServerFlashAttention._(super.name);

  /// All modes, in declaration order.
  static BuiltSet<ServerFlashAttention> get values => _$values;

  /// Looks up a mode by its wire name.
  static ServerFlashAttention valueOf(String name) => _$valueOf(name);

  static Serializer<ServerFlashAttention> get serializer =>
      _$serverFlashAttentionSerializer;
}
