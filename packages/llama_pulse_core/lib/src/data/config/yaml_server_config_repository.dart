import 'package:built_value/serializer.dart';

import '../../domain/entities/server_config.dart';
import '../../domain/entities/server_failure.dart';
import '../../domain/entities/server_failure_code.dart';
import '../../domain/exceptions/server_exception.dart';
import '../../domain/gateways/config_store.dart';
import '../../domain/gateways/server_config_repository.dart';
import '../../domain/server_config_validator.dart';
import 'config_names.dart';

/// Loads and saves [ServerConfig] in the `server.yaml` document.
///
/// Loading is forgiving: a missing, stale or malformed document falls back to
/// [ServerConfig.defaults] instead of throwing. Saving validates first and
/// refuses to write invalid configuration.
final class YamlServerConfigRepository implements ServerConfigRepository {
  /// Creates a repository backed by [store].
  factory YamlServerConfigRepository({
    required ConfigStore store,
    required Serializers serializers,
    ServerConfigValidator validator = const ServerConfigValidator(),
  }) => YamlServerConfigRepository._(store, serializers, validator);

  YamlServerConfigRepository._(this._store, this._serializers, this._validator);

  final ConfigStore _store;
  final Serializers _serializers;
  final ServerConfigValidator _validator;

  /// Reads the stored configuration, falling back to defaults.
  @override
  Future<ServerConfig> load() async {
    try {
      final document = await _store.read(ConfigNames.server);
      if (document == null) {
        return ServerConfig.defaults();
      }
      if (document['schemaVersion'] != ServerConfig.schemaVersion) {
        return ServerConfig.defaults();
      }
      final rawConfig = document['server'];
      if (rawConfig is! Map<String, Object?>) {
        return ServerConfig.defaults();
      }
      final config = _serializers.deserializeWith(
        ServerConfig.serializer,
        rawConfig,
      );
      if (config == null || _validator.validate(config).isNotEmpty) {
        return ServerConfig.defaults();
      }
      return config;
    } catch (_) {
      return ServerConfig.defaults();
    }
  }

  /// Returns the `server.yaml` document that stores [config].
  ///
  /// The shape is fixed here so that [save] and callers that preview the
  /// document cannot drift apart.
  Map<String, Object?> toDocument(ServerConfig config) {
    final serialized = _serializers.serializeWith(
      ServerConfig.serializer,
      config,
    );
    if (serialized is! Map<String, Object?>) {
      throw StateError('ServerConfig did not serialize to a map');
    }
    return {'schemaVersion': ServerConfig.schemaVersion, 'server': serialized};
  }

  /// Validates and writes [config], throwing [ServerException] and writing
  /// nothing when validation fails.
  @override
  Future<void> save(ServerConfig config) async {
    final violations = _validator.validate(config);
    if (violations.isNotEmpty) {
      throw ServerException(
        ServerFailure(
          (b) => b
            ..code = ServerFailureCode.invalidConfig
            ..message = 'server configuration is invalid'
            ..details = violations.join('\n'),
        ),
      );
    }
    await _store.write(ConfigNames.server, toDocument(config));
  }
}
