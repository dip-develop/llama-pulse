import '../entities/generation_metrics.dart';
import '../entities/generation_request.dart';
import '../entities/model_params.dart';

/// One step produced by a [LlamaSession].
///
/// A plain class because it is produced on demand, never persisted and never
/// compared structurally.
final class GenerationStep {
  /// Creates a step; [done] marks normal completion.
  const GenerationStep({this.text = '', this.metrics, this.done = false});

  /// Token text produced by this step, empty when [done].
  final String text;

  /// Cumulative metrics observed so far.
  final GenerationMetrics? metrics;

  /// Whether generation finished normally.
  final bool done;
}

/// The engine session that runs inside the worker isolate.
///
/// [open] prepares the native library; the stub implementation ignores it.
/// [next] returns `null` when the request was cancelled, and a step with
/// [GenerationStep.done] set means normal completion with final metrics.
/// Implementations never throw for native failures: they surface them through
/// [InferenceFailureException], which the worker maps to a failure response.
/// Stubs throw it for protocol misuse (load before open, generate before load).
abstract interface class LlamaSession {
  /// Prepares the native library at [libraryPath].
  Future<void> open(String libraryPath);

  /// Loads [params], replacing any previously loaded model.
  Future<void> load(ModelParams params);

  /// Starts generation for [request].
  void begin(GenerationRequest request);

  /// Returns the next step, or `null` when cancelled or finished.
  Future<GenerationStep?> next();

  /// Requests cooperative cancellation of the running generation.
  Future<void> cancel();

  /// Releases the loaded model but keeps the session usable.
  Future<void> unload();

  /// Releases every resource held by the session.
  Future<void> dispose();
}
