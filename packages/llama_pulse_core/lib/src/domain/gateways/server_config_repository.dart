import '../entities/server_config.dart';

/// Persistence for [ServerConfig] across app launches.
abstract interface class ServerConfigRepository {
  /// Reads the stored configuration, falling back to defaults when it is
  /// missing or unusable.
  Future<ServerConfig> load();

  /// Replaces the stored configuration, rejecting invalid values.
  Future<void> save(ServerConfig config);
}
