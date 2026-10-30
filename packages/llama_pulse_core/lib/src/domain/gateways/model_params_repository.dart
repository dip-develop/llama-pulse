import '../entities/model_params.dart';

/// Persistence for [ModelParams] across app launches.
abstract interface class ModelParamsRepository {
  /// Reads the stored parameters.
  Future<ModelParams> load();

  /// Replaces the stored parameters.
  Future<void> save(ModelParams params);
}
