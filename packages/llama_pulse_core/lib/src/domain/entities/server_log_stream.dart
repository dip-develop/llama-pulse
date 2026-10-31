import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'server_log_stream.g.dart';

/// Source of one line in the server log.
class ServerLogStream extends EnumClass {
  /// A line written by `llama-server` to stdout.
  static const ServerLogStream stdout = _$stdout;

  /// A line written by `llama-server` to stderr.
  static const ServerLogStream stderr = _$stderr;

  /// A line written by the supervisor itself.
  static const ServerLogStream supervisor = _$supervisor;

  const ServerLogStream._(super.name);

  /// All streams, in declaration order.
  static BuiltSet<ServerLogStream> get values => _$values;

  /// Looks up a stream by its wire name.
  static ServerLogStream valueOf(String name) => _$valueOf(name);

  static Serializer<ServerLogStream> get serializer =>
      _$serverLogStreamSerializer;
}
