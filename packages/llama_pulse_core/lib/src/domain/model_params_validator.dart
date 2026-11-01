import 'entities/model_params.dart';
import 'limits.dart';

/// Validates [ModelParams] field by field against [ModelParamLimits].
final class ModelParamsValidator {
  const ModelParamsValidator();

  /// Returns one message per violated field, in field declaration order.
  ///
  /// An empty list means the value is valid. A blank [ModelParams.modelPath]
  /// is accepted as "not configured"; only a whitespace-only path is rejected.
  List<String> validate(ModelParams params) {
    final violations = <String>[];

    if (params.modelPath.isNotEmpty && params.modelPath.trim().isEmpty) {
      violations.add('modelPath must not be blank');
    }
    _checkInt(
      violations,
      'contextSize',
      params.contextSize,
      ModelParamLimits.minContextSize,
      ModelParamLimits.maxContextSize,
    );
    _checkInt(
      violations,
      'gpuLayers',
      params.gpuLayers,
      ModelParamLimits.minGpuLayers,
      ModelParamLimits.maxGpuLayers,
    );
    _checkInt(
      violations,
      'threads',
      params.threads,
      ModelParamLimits.minThreads,
      ModelParamLimits.maxThreads,
    );
    _checkDouble(
      violations,
      'temperature',
      params.temperature,
      ModelParamLimits.minTemperature,
      ModelParamLimits.maxTemperature,
    );
    _checkDouble(
      violations,
      'topP',
      params.topP,
      ModelParamLimits.minTopP,
      ModelParamLimits.maxTopP,
    );
    _checkInt(
      violations,
      'topK',
      params.topK,
      ModelParamLimits.minTopK,
      ModelParamLimits.maxTopK,
    );
    _checkInt(
      violations,
      'maxTokens',
      params.maxTokens,
      ModelParamLimits.minMaxTokens,
      ModelParamLimits.maxMaxTokens,
    );
    _checkChatTemplate(violations, params.chatTemplate);

    return violations;
  }

  void _checkChatTemplate(List<String> violations, String? value) {
    if (value == null || value == 'none') {
      return;
    }
    if (value.isEmpty || value.length > 64) {
      violations.add('chatTemplate must be 1..64 characters');
    }
    if (value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
      violations.add('chatTemplate must not contain control characters');
    }
  }

  void _checkInt(
    List<String> violations,
    String field,
    int value,
    int min,
    int max,
  ) {
    if (value < min || value > max) {
      violations.add('$field must be in $min..$max');
    }
  }

  void _checkDouble(
    List<String> violations,
    String field,
    double value,
    double min,
    double max,
  ) {
    if (!(value >= min && value <= max)) {
      violations.add('$field must be in $min..$max');
    }
  }
}
