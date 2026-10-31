import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'server_phase.g.dart';

/// Lifecycle phase of the supervised server.
class ServerPhase extends EnumClass {
  /// No process is running.
  static const ServerPhase stopped = _$stopped;

  /// The process was spawned and the server has not answered yet.
  static const ServerPhase starting = _$starting;

  /// The server answers requests.
  static const ServerPhase running = _$running;

  /// The process is shutting down.
  static const ServerPhase stopping = _$stopping;

  /// The last operation failed; see the state's failure.
  static const ServerPhase failed = _$failed;

  const ServerPhase._(super.name);

  /// All phases, in lifecycle order.
  static BuiltSet<ServerPhase> get values => _$values;

  /// Looks up a phase by its wire name.
  static ServerPhase valueOf(String name) => _$valueOf(name);

  static Serializer<ServerPhase> get serializer => _$serverPhaseSerializer;
}
