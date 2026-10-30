import '../entities/model_params.dart';
import '../exceptions/invalid_model_params_exception.dart';
import '../gateways/model_params_repository.dart';
import '../model_params_validator.dart';

/// Validates before writing, so every entrypoint rejects with the same
/// message ordering and the repository is never asked to store bad values.
final class SaveModelParams {
  /// Creates the use case over [repository] and [validator].
  const SaveModelParams(this._repository, this._validator);

  final ModelParamsRepository _repository;
  final ModelParamsValidator _validator;

  /// Writes [params], throwing [InvalidModelParamsException] when invalid.
  Future<void> call(ModelParams params) async {
    final violations = _validator.validate(params);
    if (violations.isNotEmpty) {
      throw InvalidModelParamsException(violations);
    }
    await _repository.save(params);
  }
}
