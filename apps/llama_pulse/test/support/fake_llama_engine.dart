import 'package:llama_pulse_core/llama_pulse_core.dart';

/// A [LlamaEngine] that records calls and emits no generation events.
final class FakeLlamaEngine implements LlamaEngine {
  /// Parameters passed to [load], in call order.
  final List<ModelParams> loadedParams = [];

  /// Requests passed to [generate], in call order.
  final List<GenerationRequest> generatedRequests = [];

  /// Request identifiers passed to [cancel], in call order.
  final List<int> cancelledRequestIds = [];

  /// Number of times [dispose] was called.
  int disposeCalls = 0;

  @override
  Future<void> load(ModelParams params) async {
    loadedParams.add(params);
  }

  @override
  Stream<GenerationEvent> generate(GenerationRequest request) {
    generatedRequests.add(request);
    return Stream<GenerationEvent>.empty();
  }

  @override
  Future<void> cancel(int requestId) async {
    cancelledRequestIds.add(requestId);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
