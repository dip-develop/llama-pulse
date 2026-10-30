import 'package:built_value/serializer.dart';

import '../../domain/entities/model_params.dart';
import '../../domain/exceptions/invalid_model_params_exception.dart';
import '../../domain/gateways/config_store.dart';
import '../../domain/gateways/model_params_repository.dart';
import '../../domain/model_params_validator.dart';
import 'config_names.dart';

/// Loads and saves [ModelParams] in the `params.yaml` document.
///
/// Loading is forgiving: a missing, stale or malformed document falls back to
/// [ModelParams.defaults] instead of throwing. Saving validates first and
/// refuses to write invalid parameters.
final class YamlModelParamsRepository implements ModelParamsRepository {
  /// Creates a repository backed by [store].
  factory YamlModelParamsRepository({
    required ConfigStore store,
    required Serializers serializers,
    ModelParamsValidator validator = const ModelParamsValidator(),
  }) => YamlModelParamsRepository._(store, serializers, validator);

  YamlModelParamsRepository._(this._store, this._serializers, this._validator);

  final ConfigStore _store;
  final Serializers _serializers;
  final ModelParamsValidator _validator;

  /// Reads the stored parameters, falling back to defaults.
  @override
  Future<ModelParams> load() async {
    try {
      final document = await _store.read(ConfigNames.params);
      if (document == null) {
        return ModelParams.defaults();
      }
      if (document['schemaVersion'] != ModelParams.schemaVersion) {
        return ModelParams.defaults();
      }
      final rawParams = document['params'];
      if (rawParams is! Map<String, Object?>) {
        return ModelParams.defaults();
      }
      final params = _serializers.deserializeWith(
        ModelParams.serializer,
        rawParams,
      );
      if (params == null || _validator.validate(params).isNotEmpty) {
        return ModelParams.defaults();
      }
      return params;
    } catch (_) {
      return ModelParams.defaults();
    }
  }

  /// Returns the `params.yaml` document that stores [params].
  ///
  /// The shape is fixed here so that [save], which calls this method, and
  /// callers that preview a document (for example the CLI's `params get`)
  /// cannot drift apart.
  Map<String, Object?> toDocument(ModelParams params) {
    final serialized = _serializers.serializeWith(
      ModelParams.serializer,
      params,
    );
    if (serialized is! Map<String, Object?>) {
      throw StateError('ModelParams did not serialize to a map');
    }
    return {'schemaVersion': ModelParams.schemaVersion, 'params': serialized};
  }

  /// Validates and writes [params], throwing [InvalidModelParamsException] and
  /// writing nothing when validation fails.
  @override
  Future<void> save(ModelParams params) async {
    final violations = _validator.validate(params);
    if (violations.isNotEmpty) {
      throw InvalidModelParamsException(violations);
    }
    await _store.write(ConfigNames.params, toDocument(params));
  }
}
