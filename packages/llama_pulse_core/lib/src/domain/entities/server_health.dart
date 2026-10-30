import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'server_health.g.dart';

/// Result of the most recent health probe against the server.
class ServerHealth extends EnumClass {
  /// No probe has run yet in this phase.
  static const ServerHealth unknown = _$unknown;

  /// The server answered and reports that it is ready.
  static const ServerHealth ok = _$ok;

  /// The server answered but is still loading the model.
  static const ServerHealth loading = _$loading;

  /// The server answers but reports a degraded state.
  static const ServerHealth degraded = _$degraded;

  /// The server did not answer.
  static const ServerHealth unreachable = _$unreachable;

  const ServerHealth._(super.name);

  /// All health values, in declaration order.
  static BuiltSet<ServerHealth> get values => _$values;

  /// Looks up a health value by its wire name.
  static ServerHealth valueOf(String name) => _$valueOf(name);

  static Serializer<ServerHealth> get serializer => _$serverHealthSerializer;
}
