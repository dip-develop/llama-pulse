import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'model_params.g.dart';

/// Sampling and runtime parameters for one generation request.
abstract class ModelParams implements Built<ModelParams, ModelParamsBuilder> {
  /// Version of the YAML document schema that stores these parameters.
  static const int schemaVersion = 1;

  /// Path to the model file, as configured by the user.
  String get modelPath;

  /// Context window size in tokens.
  int get contextSize;

  /// Number of layers offloaded to the GPU.
  int get gpuLayers;

  /// Worker threads used for evaluation.
  int get threads;

  /// Sampling temperature.
  double get temperature;

  /// Nucleus sampling probability mass.
  double get topP;

  /// Top-k sampling cutoff.
  int get topK;

  /// Upper bound on generated tokens.
  int get maxTokens;

  factory ModelParams([void Function(ModelParamsBuilder)? updates]) =
      _$ModelParams;

  /// Returns the parameters used when no user configuration exists yet.
  factory ModelParams.defaults() => ModelParams(
    (b) => b
      ..modelPath = ''
      ..contextSize = 2048
      ..gpuLayers = 0
      ..threads = 4
      ..temperature = 0.8
      ..topP = 0.95
      ..topK = 40
      ..maxTokens = 256,
  );

  ModelParams._();

  static Serializer<ModelParams> get serializer => _$modelParamsSerializer;

  /// Returns a copy with the given fields replaced.
  ModelParams copyWith({
    String? modelPath,
    int? contextSize,
    int? gpuLayers,
    int? threads,
    double? temperature,
    double? topP,
    int? topK,
    int? maxTokens,
  }) => rebuild(
    (b) => b
      ..modelPath = modelPath ?? this.modelPath
      ..contextSize = contextSize ?? this.contextSize
      ..gpuLayers = gpuLayers ?? this.gpuLayers
      ..threads = threads ?? this.threads
      ..temperature = temperature ?? this.temperature
      ..topP = topP ?? this.topP
      ..topK = topK ?? this.topK
      ..maxTokens = maxTokens ?? this.maxTokens,
  );
}
