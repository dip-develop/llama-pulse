import 'dart:async';

import 'package:llama_pulse_core/llama_pulse_core.dart';

/// A [LlamaEngine] whose generation stream the test drives event by event.
///
/// One controller is created per [generate] call; the helpers emit on the most
/// recent one so tests read like a script.
final class ScriptedLlamaEngine implements LlamaEngine {
  /// Parameters passed to [load], in call order.
  final List<ModelParams> loadedParams = [];

  /// Requests passed to [generate], in call order.
  final List<GenerationRequest> generatedRequests = [];

  /// Request identifiers passed to [cancel], in call order.
  final List<int> cancelledRequestIds = [];

  final List<StreamController<GenerationEvent>> _controllers = [];

  /// When false, [load] throws [loadFailure] instead of succeeding.
  bool loadSucceeds = true;

  /// Thrown by [load] when [loadSucceeds] is false.
  InferenceFailure loadFailure = InferenceFailure(
    (b) => b
      ..code = InferenceFailureCode.modelNotFound
      ..message = 'model file not found',
  );

  /// Number of times [unload] was called.
  int unloadCalls = 0;

  /// Number of times [dispose] was called.
  int disposeCalls = 0;

  /// Controller for the most recent [generate] call, if any.
  StreamController<GenerationEvent>? get controller =>
      _controllers.isEmpty ? null : _controllers.last;

  /// Identifier of the most recent [generate] request, if any.
  int? get lastRequestId =>
      generatedRequests.isEmpty ? null : generatedRequests.last.requestId;

  /// Waits until [generate] has been called at least [count] times.
  Future<void> waitForGenerate([int count = 1]) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (generatedRequests.length >= count) {
        return;
      }
      await Future<void>.delayed(Duration.zero);
    }
    throw StateError('generate was not called $count times');
  }

  @override
  Future<void> load(ModelParams params) async {
    loadedParams.add(params);
    if (!loadSucceeds) {
      throw InferenceFailureException(loadFailure);
    }
  }

  @override
  Stream<GenerationEvent> generate(GenerationRequest request) {
    generatedRequests.add(request);
    final StreamController<GenerationEvent> controller =
        StreamController<GenerationEvent>();
    _controllers.add(controller);
    return controller.stream;
  }

  /// Emits a token event on the active request.
  void emitToken(String text) {
    controller?.add(GenerationEvent.token(_requireRequestId(), text));
  }

  /// Emits a metrics event on the active request.
  void emitMetrics(GenerationMetrics metrics) {
    controller?.add(GenerationEvent.metrics(_requireRequestId(), metrics));
  }

  /// Emits the successful terminal event on the active request.
  void complete([GenerationMetrics? metrics]) {
    controller?.add(
      GenerationEvent.completed(_requireRequestId(), metrics ?? zeroMetrics),
    );
  }

  /// Emits the cancelled terminal event on the active request.
  void cancelled() {
    controller?.add(GenerationEvent.cancelled(_requireRequestId()));
  }

  /// Emits the failed terminal event on the active request.
  void failed(InferenceFailure failure) {
    controller?.add(GenerationEvent.failed(_requireRequestId(), failure));
  }

  /// Fails the active request stream with [error].
  void streamError(Object error) {
    controller?.addError(error);
  }

  /// Closes the active request stream without a terminal event.
  Future<void> closeStream() async {
    await controller?.close();
  }

  int _requireRequestId() {
    final int? requestId = lastRequestId;
    if (requestId == null) {
      throw StateError('generate has not been called');
    }
    return requestId;
  }

  /// Metrics with zeroed timings, used when a test does not care about them.
  static final GenerationMetrics zeroMetrics = GenerationMetrics(
    (b) => b
      ..promptTokenCount = 0
      ..generatedTokenCount = 0
      ..promptEvalMs = 0
      ..evalMs = 0,
  );

  @override
  Future<void> cancel(int requestId) async {
    cancelledRequestIds.add(requestId);
  }

  @override
  Future<void> unload() async {
    unloadCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
