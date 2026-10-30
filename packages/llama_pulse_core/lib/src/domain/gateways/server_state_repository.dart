import '../entities/server_state.dart';

/// Persistence for the supervisor's [ServerState].
///
/// The document is shared by the supervisor, the CLI and the app, so a caller
/// can report on a server it did not start.
abstract interface class ServerStateRepository {
  /// Reads the stored state, or `null` when no usable document exists.
  Future<ServerState?> load();

  /// Replaces the stored state.
  Future<void> save(ServerState state);

  /// Removes the stored state.
  Future<void> clear();
}
