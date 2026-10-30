import '../entities/generation_event.dart';
import '../entities/generation_request.dart';
import '../entities/model_params.dart';

/// Runs llama.cpp inference inside a worker isolate.
///
/// Implementations run off the calling isolate, so nothing here may block the
/// caller. [generate] emits exactly one terminal event (`completed`,
/// `cancelled` or `failed`) and then closes the stream.
abstract interface class LlamaEngine {
  /// Loads [params], replacing any previously loaded model.
  Future<void> load(ModelParams params);

  /// Starts generation for [request].
  Stream<GenerationEvent> generate(GenerationRequest request);

  /// Cooperatively cancels the request identified by [requestId].
  Future<void> cancel(int requestId);

  /// Releases native resources held by the engine.
  Future<void> dispose();
}
