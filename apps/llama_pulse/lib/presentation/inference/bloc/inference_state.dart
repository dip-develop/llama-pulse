import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import 'inference_status.dart';

part 'inference_state.g.dart';

/// Immutable snapshot rendered by the inference screen.
abstract class InferenceState
    implements Built<InferenceState, InferenceStateBuilder> {
  /// Current lifecycle position.
  InferenceStatus get status;

  /// Parameters shown in the form and used for the next request.
  ModelParams get params;

  /// Prompt text in the editor.
  String get prompt;

  /// Generated text chunks for the active or last request.
  BuiltList<String> get outputChunks;

  /// Metrics reported for the active or last request, newest last.
  BuiltList<GenerationMetrics> get metricsHistory;

  /// Request the engine is working on, or `null` when idle.
  int? get activeRequestId;

  /// Details of the last failure, or `null` when the last action succeeded.
  InferenceFailure? get failure;

  /// Milliseconds from generation start to the first token, once seen.
  int? get timeToFirstTokenMs;

  /// Generated text, assembled from [outputChunks].
  String get output => outputChunks.join();

  /// Metrics from the most recent report, or `null` when none arrived.
  GenerationMetrics? get latestMetrics =>
      metricsHistory.isEmpty ? null : metricsHistory.last;

  /// Whether the engine is loading, generating or cancelling.
  bool get isBusy =>
      status == InferenceStatus.loadingModel ||
      status == InferenceStatus.generating ||
      status == InferenceStatus.cancelling;

  factory InferenceState([void Function(InferenceStateBuilder)? updates]) =
      _$InferenceState;

  /// The state shown before anything has been loaded.
  factory InferenceState.initial() => InferenceState(
    (b) => b
      ..status = InferenceStatus.initial
      ..params.replace(ModelParams.defaults())
      ..prompt = ''
      ..outputChunks = ListBuilder<String>()
      ..metricsHistory = ListBuilder<GenerationMetrics>(),
  );

  InferenceState._();

  static Serializer<InferenceState> get serializer =>
      _$inferenceStateSerializer;
}
