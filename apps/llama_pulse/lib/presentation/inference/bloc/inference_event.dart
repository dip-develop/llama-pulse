import 'package:llama_pulse_core/llama_pulse_core.dart';

/// Commands accepted by the inference bloc.
///
/// Deliberately a sealed hierarchy rather than `built_value`: events are
/// transient commands that never cross the isolate boundary and are never
/// persisted or compared structurally, so they stay immutable plain classes.
sealed class InferenceEvent {
  const InferenceEvent();
}

/// Loads the stored parameters when the screen mounts.
final class InferenceStarted extends InferenceEvent {
  const InferenceStarted();
}

/// The user edited the model parameters.
final class InferenceParamsChanged extends InferenceEvent {
  const InferenceParamsChanged(this.params);

  /// New parameters, not yet persisted.
  final ModelParams params;
}

/// The user edited the prompt text.
final class InferencePromptChanged extends InferenceEvent {
  const InferencePromptChanged(this.prompt);

  /// New prompt text.
  final String prompt;
}

/// Persists the current parameters.
final class InferenceSaveRequested extends InferenceEvent {
  const InferenceSaveRequested();
}

/// Loads the configured model into the engine.
final class InferenceLoadRequested extends InferenceEvent {
  const InferenceLoadRequested();
}

/// Starts generation for the current prompt and parameters.
final class InferenceGenerateRequested extends InferenceEvent {
  const InferenceGenerateRequested();
}

/// Asks the engine to stop the running generation.
final class InferenceCancelRequested extends InferenceEvent {
  const InferenceCancelRequested();
}

/// Releases the loaded model while keeping the engine alive.
final class InferenceUnloadRequested extends InferenceEvent {
  const InferenceUnloadRequested();
}

/// Internal plumbing: one event read from the engine's generation stream.
///
/// It is part of the sealed hierarchy so the bloc can emit states from an
/// event handler, which is the only place `bloc` allows emissions. UI code
/// never adds it.
final class InferenceEngineEventReceived extends InferenceEvent {
  const InferenceEngineEventReceived(this.event);

  /// Event delivered by [LlamaEngine.generate].
  final GenerationEvent event;
}

/// Internal plumbing: the generation stream ended without a terminal event.
final class InferenceEngineStreamEnded extends InferenceEvent {
  const InferenceEngineStreamEnded(this.requestId, {this.error});

  /// Request whose stream ended.
  final int requestId;

  /// Error that broke the stream, or `null` for a clean close.
  final Object? error;
}
