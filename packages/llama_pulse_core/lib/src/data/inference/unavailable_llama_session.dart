import '../../domain/entities/generation_request.dart';
import '../../domain/entities/inference_failure.dart';
import '../../domain/entities/inference_failure_code.dart';
import '../../domain/entities/model_params.dart';
import '../../domain/exceptions/inference_failure_exception.dart';
import '../../domain/gateways/llama_session.dart';

/// Placeholder [LlamaSession] used when the worker is not in stub mode.
///
/// The native llama.cpp session replaces this in the next PR; until then every
/// `load` reports `engineUnavailable` instead of producing synthetic output.
final class UnavailableLlamaSession implements LlamaSession {
  /// Creates the placeholder session.
  const UnavailableLlamaSession();

  static const _message = 'the native llama.cpp session is not implemented yet';

  @override
  Future<void> open(String libraryPath) async {}

  @override
  Future<void> load(ModelParams params) async {
    throw InferenceFailureException(
      _failure(InferenceFailureCode.engineUnavailable, _message),
    );
  }

  @override
  void begin(GenerationRequest request) {}

  @override
  Future<GenerationStep?> next() async => null;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> unload() async {}

  @override
  Future<void> dispose() async {}

  InferenceFailure _failure(InferenceFailureCode code, String message) =>
      InferenceFailure(
        (b) => b
          ..code = code
          ..message = message,
      );
}
