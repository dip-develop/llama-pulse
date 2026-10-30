import 'dart:async';

import 'package:llama_pulse_core/llama_pulse_core.dart';

/// A deterministic [LlamaEngine] for CLI tests.
///
/// Each [generate] emits `started`, the configured [tokens], then `completed`.
/// Cancellation is cooperative and only observed when [honourCancel] is true.
final class ScriptedLlamaEngine implements LlamaEngine {
  /// Creates an engine emitting [tokens] with the given metric values.
  ScriptedLlamaEngine({
    this.tokens = const ['Hello', ' world'],
    this.promptTokenCount = 5,
    this.promptEvalMs = 10,
    this.evalMs = 20,
    this.tokenInterval = Duration.zero,
    this.honourCancel = true,
    this.repeatTokens = false,
    this.loadFailure,
    this.generateFailure,
    this.completionMetrics,
  });

  /// Token text emitted per run.
  final List<String> tokens;

  /// Prompt token count reported in the metrics.
  final int promptTokenCount;

  /// Prompt evaluation time reported in the metrics.
  final int promptEvalMs;

  /// Generation time reported in the metrics.
  final int evalMs;

  /// Delay between tokens.
  final Duration tokenInterval;

  /// Whether [cancel] makes the active generation emit `cancelled`.
  final bool honourCancel;

  /// Whether the token list repeats forever; useful for interrupt tests.
  final bool repeatTokens;

  /// Failure thrown by [load], when set.
  final InferenceFailure? loadFailure;

  /// Failure emitted by [generate], when set.
  final InferenceFailure? generateFailure;

  /// Metrics override for the `completed` event.
  final GenerationMetrics? completionMetrics;

  /// Number of [load] calls.
  int loadCalls = 0;

  /// Number of [generate] calls.
  int generateCalls = 0;

  /// Number of [cancel] calls.
  int cancelCalls = 0;

  /// Number of [unload] calls.
  int unloadCalls = 0;

  /// Number of [dispose] calls.
  int disposeCalls = 0;

  /// Request ids passed to [cancel], in order.
  final List<int> cancelledRequestIds = [];

  /// Requests passed to [generate], in order.
  final List<GenerationRequest> generateRequests = [];

  /// Params passed to the last successful [load].
  ModelParams? loadedParams;

  final Set<int> _cancelled = {};

  @override
  Future<void> load(ModelParams params) async {
    loadCalls++;
    final failure = loadFailure;
    if (failure != null) {
      throw InferenceFailureException(failure);
    }
    loadedParams = params;
  }

  @override
  Stream<GenerationEvent> generate(GenerationRequest request) async* {
    generateCalls++;
    generateRequests.add(request);
    final requestId = request.requestId;
    yield GenerationEvent.started(requestId);

    final failure = generateFailure;
    if (failure != null) {
      yield GenerationEvent.failed(requestId, failure);
      return;
    }

    var index = 0;
    while (repeatTokens || index < tokens.length) {
      if (tokenInterval > Duration.zero) {
        await Future<void>.delayed(tokenInterval);
      }
      if (honourCancel && _cancelled.contains(requestId)) {
        yield GenerationEvent.cancelled(requestId);
        return;
      }
      yield GenerationEvent.token(requestId, tokens[index % tokens.length]);
      index++;
    }

    if (honourCancel && _cancelled.contains(requestId)) {
      yield GenerationEvent.cancelled(requestId);
      return;
    }
    yield GenerationEvent.completed(requestId, completionMetrics ?? _metrics());
  }

  @override
  Future<void> cancel(int requestId) async {
    cancelCalls++;
    cancelledRequestIds.add(requestId);
    _cancelled.add(requestId);
  }

  @override
  Future<void> unload() async {
    unloadCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  GenerationMetrics _metrics() => GenerationMetrics(
    (b) => b
      ..promptTokenCount = promptTokenCount
      ..generatedTokenCount = tokens.length
      ..promptEvalMs = promptEvalMs
      ..evalMs = evalMs,
  );
}
