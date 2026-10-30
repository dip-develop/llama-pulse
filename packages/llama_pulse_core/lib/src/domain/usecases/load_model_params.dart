import '../entities/model_params.dart';
import '../gateways/model_params_repository.dart';

/// Loads the persisted parameters, falling back to defaults when none exist.
final class LoadModelParams {
  /// Creates the use case over [repository].
  const LoadModelParams(this._repository);

  final ModelParamsRepository _repository;

  /// Returns the stored parameters.
  Future<ModelParams> call() => _repository.load();
}
