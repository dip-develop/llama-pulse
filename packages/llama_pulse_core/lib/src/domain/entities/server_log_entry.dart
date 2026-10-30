import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'server_log_stream.dart';

part 'server_log_entry.g.dart';

/// One line of supervisor or `llama-server` output.
abstract class ServerLogEntry
    implements Built<ServerLogEntry, ServerLogEntryBuilder> {
  /// Monotonic position of the line in the log, starting at one.
  int get sequence;

  /// When the line was captured, as milliseconds since the Unix epoch.
  int get timestampEpochMs;

  /// Where the line came from.
  ServerLogStream get stream;

  /// The line, without its trailing line break.
  String get line;

  factory ServerLogEntry([void Function(ServerLogEntryBuilder)? updates]) =
      _$ServerLogEntry;

  ServerLogEntry._();

  static Serializer<ServerLogEntry> get serializer =>
      _$serverLogEntrySerializer;
}
