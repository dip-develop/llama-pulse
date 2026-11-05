import 'package:built_collection/built_collection.dart';
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

  /// Chat template selection for the native session.
  ///
  /// Null uses the model's built-in template. The literal `none` disables
  /// templating, and any other value names a built-in template passed to
  /// `llama_model_chat_template`.
  String? get chatTemplate;

  /// Default `system` message prepended to chat requests.
  ///
  /// Null means no system message. Persisted in `params.yaml`; the CLI's
  /// `run --system` is a per-run override and does not read this value.
  String? get systemPrompt;

  /// Whether the native session wraps the prompt in a chat template.
  ///
  /// Null means true; false forces the raw prompt.
  bool? get useChatTemplate;

  /// Catalog parameter values keyed by catalog id.
  ///
  /// Typed fields win over this map; see `ParameterValues.valueForModel`.
  BuiltMap<String, String> get params;

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
      ..maxTokens = 256
      ..chatTemplate = null
      ..systemPrompt = null
      ..useChatTemplate = null
      ..params = MapBuilder<String, String>(),
  );

  ModelParams._();

  static Serializer<ModelParams> get serializer => _$modelParamsSerializer;

  /// Returns a copy with the given fields replaced.
  ///
  /// Omitting [chatTemplate], [systemPrompt] or [useChatTemplate] keeps the
  /// current value; pass an explicit null to clear it: no system prompt for
  /// [systemPrompt], the model default for [useChatTemplate].
  ModelParams copyWith({
    String? modelPath,
    int? contextSize,
    int? gpuLayers,
    int? threads,
    double? temperature,
    double? topP,
    int? topK,
    int? maxTokens,
    Object? chatTemplate = _unset,
    Object? systemPrompt = _unset,
    Object? useChatTemplate = _unset,
    BuiltMap<String, String>? params,
  }) => rebuild(
    (b) => b
      ..modelPath = modelPath ?? this.modelPath
      ..contextSize = contextSize ?? this.contextSize
      ..gpuLayers = gpuLayers ?? this.gpuLayers
      ..threads = threads ?? this.threads
      ..temperature = temperature ?? this.temperature
      ..topP = topP ?? this.topP
      ..topK = topK ?? this.topK
      ..maxTokens = maxTokens ?? this.maxTokens
      ..chatTemplate = identical(chatTemplate, _unset)
          ? this.chatTemplate
          : chatTemplate as String?
      ..systemPrompt = identical(systemPrompt, _unset)
          ? this.systemPrompt
          : systemPrompt as String?
      ..useChatTemplate = identical(useChatTemplate, _unset)
          ? this.useChatTemplate
          : useChatTemplate as bool?
      ..params.replace(params ?? this.params),
  );

  static const Object _unset = Object();
}
