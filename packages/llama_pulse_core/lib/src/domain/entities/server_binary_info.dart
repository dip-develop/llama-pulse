import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'server_binary_info.g.dart';

/// What the supervisor learned by running `llama-server --version`.
abstract class ServerBinaryInfo
    implements Built<ServerBinaryInfo, ServerBinaryInfoBuilder> {
  /// Absolute path to the executable.
  String get path;

  /// Version string reported by the executable.
  String get version;

  /// Build number reported by the executable, when present.
  int? get buildNumber;

  /// Source commit reported by the executable, when present.
  String? get commit;

  /// Whether this version is known to expose the flags LlamaPulse passes.
  bool get supported;

  /// Why the version is not supported, when [supported] is false.
  String? get warning;

  /// First lines of the executable's version output.
  String get rawOutput;

  factory ServerBinaryInfo([void Function(ServerBinaryInfoBuilder)? updates]) =
      _$ServerBinaryInfo;

  ServerBinaryInfo._();

  static Serializer<ServerBinaryInfo> get serializer =>
      _$serverBinaryInfoSerializer;
}
