import 'package:built_value/serializer.dart';

import '../../domain/entities/server_state.dart';
import '../../domain/gateways/config_store.dart';
import '../../domain/gateways/server_state_repository.dart';
import 'config_names.dart';

/// Loads and saves [ServerState] in the `server-state.yaml` document.
///
/// Loading never throws: a missing, stale or malformed document reads as
/// `null`, which callers treat as "no known server".
final class YamlServerStateRepository implements ServerStateRepository {
  /// Creates a repository backed by [store].
  factory YamlServerStateRepository({
    required ConfigStore store,
    required Serializers serializers,
  }) => YamlServerStateRepository._(store, serializers);

  YamlServerStateRepository._(this._store, this._serializers);

  final ConfigStore _store;
  final Serializers _serializers;

  /// Reads the stored state, or `null` when no usable document exists.
  @override
  Future<ServerState?> load() async {
    try {
      final document = await _store.read(ConfigNames.serverState);
      if (document == null) {
        return null;
      }
      if (document['schemaVersion'] != ServerState.schemaVersion) {
        return null;
      }
      final rawState = document['state'];
      if (rawState is! Map<String, Object?>) {
        return null;
      }
      return _serializers.deserializeWith(ServerState.serializer, rawState);
    } catch (_) {
      return null;
    }
  }

  /// Returns the `server-state.yaml` document that stores [state].
  Map<String, Object?> toDocument(ServerState state) {
    final serialized = _serializers.serializeWith(
      ServerState.serializer,
      state,
    );
    if (serialized is! Map<String, Object?>) {
      throw StateError('ServerState did not serialize to a map');
    }
    return {'schemaVersion': ServerState.schemaVersion, 'state': serialized};
  }

  /// Writes [state]; the document is a reporting snapshot, so it is not
  /// validated.
  @override
  Future<void> save(ServerState state) async {
    await _store.write(ConfigNames.serverState, toDocument(state));
  }

  /// Removes the stored state.
  @override
  Future<void> clear() => _store.delete(ConfigNames.serverState);
}
