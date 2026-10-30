import 'dart:async';

import '../../domain/entities/generation_metrics.dart';
import '../../domain/entities/generation_request.dart';
import '../../domain/entities/inference_failure.dart';
import '../../domain/entities/inference_failure_code.dart';
import '../../domain/entities/worker_request.dart';
import '../../domain/entities/worker_request_kind.dart';
import '../../domain/entities/worker_response.dart';
import '../../domain/exceptions/inference_failure_exception.dart';
import '../../domain/gateways/llama_session.dart';

/// Runs the worker side of the inference protocol on top of a [LlamaSession].
///
/// The loop never throws: every failure becomes a `.failure` response, so a
/// misbehaving request cannot tear down the isolate.
final class WorkerLoop {
  /// Creates a loop that answers through [send].
  WorkerLoop({
    required LlamaSession session,
    required void Function(WorkerResponse) send,
  }) : _session = session, // ignore: prefer_initializing_formals
       _send = send; // ignore: prefer_initializing_formals

  static const _tokenBatchChars = 256;
  static const _tokenBatchMs = 16;
  static const _metricsMs = 250;

  final LlamaSession _session;
  final void Function(WorkerResponse) _send;

  Future<void> _pending = Future<void>.value();
  Future<void>? _generation;
  Future<void>? _cancellation;
  int? _generationRequestId;
  bool _cancelRequested = false;
  bool _loaded = false;
  bool _closing = false;
  bool _disposed = false;

  /// Completes when the queued control requests and any generation are done.
  Future<void> get idle async {
    await _pending;
    final cancellation = _cancellation;
    if (cancellation != null) {
      await cancellation;
    }
    final generation = _generation;
    if (generation != null) {
      await generation;
    }
  }

  /// Handles one request.
  ///
  /// `cancel` is fire-and-forget: it produces no response of its own, the
  /// cancelled generation ends with a `.cancelled` response instead.
  void handle(WorkerRequest request) {
    if (_closing) {
      return;
    }
    try {
      switch (request.kind) {
        case WorkerRequestKind.ping:
          _send(WorkerResponse.pong(request.requestId));
        case WorkerRequestKind.load:
          _enqueue(request.requestId, () => _load(request));
        case WorkerRequestKind.generate:
          _generate(request);
        case WorkerRequestKind.cancel:
          _queueCancel(request);
        case WorkerRequestKind.unload:
          _enqueue(request.requestId, () => _unload(request));
        case WorkerRequestKind.dispose:
          _closing = true;
          _enqueue(request.requestId, () => _disposeWorker(request));
      }
    } catch (error) {
      _sendFailure(request.requestId, _failureFrom(error));
    }
  }

  /// Waits for the queued work and releases the session.
  Future<void> dispose() async {
    await idle;
    if (_disposed) {
      return;
    }
    _disposed = true;
    _closing = true;
    _loaded = false;
    await _session.dispose();
  }

  void _enqueue(int requestId, Future<void> Function() operation) {
    _pending = _runAfter(_pending, requestId, operation);
  }

  Future<void> _runAfter(
    Future<void> previous,
    int requestId,
    Future<void> Function() operation,
  ) async {
    await previous;
    try {
      await operation();
    } catch (error) {
      _sendFailure(requestId, _failureFrom(error));
    }
  }

  Future<void> _load(WorkerRequest request) async {
    if (_generation != null) {
      _sendFailure(request.requestId, _busy());
      return;
    }
    final params = request.params;
    if (params == null) {
      _sendFailure(
        request.requestId,
        _invalidParams('The load request carried no parameters.'),
      );
      return;
    }
    await _session.load(params);
    _loaded = true;
    _send(WorkerResponse.loaded(request.requestId));
  }

  Future<void> _unload(WorkerRequest request) async {
    if (_generation != null) {
      _sendFailure(request.requestId, _busy());
      return;
    }
    await _session.unload();
    _loaded = false;
    _send(WorkerResponse.unloaded(request.requestId));
  }

  Future<void> _disposeWorker(WorkerRequest request) async {
    final generation = _generation;
    if (generation != null) {
      await generation;
    }
    // A cancel may still be awaiting the session; disposing underneath it would
    // overlap cancel() and dispose(). This snapshot is final because handling a
    // dispose request sets `_closing`, which drops every later cancel.
    final cancellation = _cancellation;
    if (cancellation != null) {
      await cancellation;
    }
    try {
      await _session.dispose();
      _send(WorkerResponse.disposed(request.requestId));
    } catch (error) {
      _sendFailure(request.requestId, _failureFrom(error));
    } finally {
      _loaded = false;
      _disposed = true;
    }
  }

  void _generate(WorkerRequest request) {
    if (_generation != null) {
      _sendFailure(request.requestId, _busy());
      return;
    }
    if (!_loaded) {
      _sendFailure(request.requestId, _unavailable());
      return;
    }
    _generationRequestId = request.requestId;
    _cancelRequested = false;
    _generation = _trackGeneration(_runGeneration(request));
  }

  Future<void> _trackGeneration(Future<void> task) async {
    try {
      await task;
    } catch (_) {
      // The loop must not leave an unhandled error behind.
    } finally {
      _generation = null;
      _generationRequestId = null;
      _cancelRequested = false;
    }
  }

  void _queueCancel(WorkerRequest request) {
    final previous = _cancellation;
    // Chain instead of overwriting: a second cancel that arrives while the
    // session is still cancelling must still be observed.
    final next = previous == null
        ? _cancel(request)
        : previous.then((_) => _cancel(request));
    _cancellation = next;
  }

  Future<void> _cancel(WorkerRequest request) async {
    if (request.targetRequestId != _generationRequestId) {
      return;
    }
    _cancelRequested = true;
    try {
      await _session.cancel();
    } catch (_) {
      // Cancellation is best effort; the session ends generation on its own.
    }
  }

  Future<void> _runGeneration(WorkerRequest request) async {
    final requestId = request.requestId;
    final buffer = StringBuffer();
    final metricsWatch = Stopwatch()..start();
    final batchWatch = Stopwatch()..start();
    var metricsMarkMs = 0;
    var terminalSent = false;
    GenerationMetrics? latestMetrics;

    void flushText() {
      if (buffer.isEmpty) {
        return;
      }
      final text = buffer.toString();
      buffer.clear();
      batchWatch.reset();
      _send(WorkerResponse.tokenBatch(requestId, text));
    }

    void emitMetrics() {
      final metrics = latestMetrics;
      if (metrics == null) {
        return;
      }
      metricsMarkMs = metricsWatch.elapsedMilliseconds;
      _send(WorkerResponse.metrics(requestId, metrics));
    }

    void finish(WorkerResponse terminal) {
      if (terminalSent) {
        return;
      }
      terminalSent = true;
      flushText();
      emitMetrics();
      _send(terminal);
    }

    try {
      final params = request.params;
      if (params == null) {
        _sendFailure(
          requestId,
          _invalidParams('The generate request carried no parameters.'),
        );
        return;
      }
      _session.begin(
        GenerationRequest.create(
          requestId: requestId,
          prompt: request.prompt ?? '',
          params: params,
        ),
      );
      while (true) {
        final step = await _session.next();
        if (_cancelRequested) {
          finish(WorkerResponse.cancelled(requestId));
          return;
        }
        if (step == null) {
          // The session only stops early when it was cancelled.
          finish(WorkerResponse.cancelled(requestId));
          return;
        }
        if (step.text.isNotEmpty) {
          buffer.write(step.text);
        }
        final stepMetrics = step.metrics;
        if (stepMetrics != null) {
          latestMetrics = stepMetrics;
        }
        if (buffer.length >= _tokenBatchChars ||
            batchWatch.elapsedMilliseconds >= _tokenBatchMs) {
          flushText();
        }
        if (metricsWatch.elapsedMilliseconds - metricsMarkMs >= _metricsMs) {
          emitMetrics();
        }
        if (step.done) {
          finish(WorkerResponse.completed(requestId));
          return;
        }
        // Yielding lets a cancel request reach the loop between steps.
        await Future<void>.delayed(Duration.zero);
      }
    } catch (error) {
      finish(WorkerResponse.failure(requestId, _failureFrom(error)));
    }
  }

  void _sendFailure(int requestId, InferenceFailure failure) {
    _send(WorkerResponse.failure(requestId, failure));
  }

  InferenceFailure _failureFrom(Object error) {
    if (error is InferenceFailureException) {
      return error.failure;
    }
    return InferenceFailure(
      (b) => b
        ..code = InferenceFailureCode.unknown
        ..message = 'The inference worker failed unexpectedly.'
        ..details = error.toString(),
    );
  }

  InferenceFailure _busy() => InferenceFailure(
    (b) => b
      ..code = InferenceFailureCode.engineBusy
      ..message = 'The engine is already running a request.',
  );

  InferenceFailure _unavailable() => InferenceFailure(
    (b) => b
      ..code = InferenceFailureCode.engineUnavailable
      ..message = 'No model is loaded.',
  );

  InferenceFailure _invalidParams(String message) => InferenceFailure(
    (b) => b
      ..code = InferenceFailureCode.invalidParams
      ..message = message,
  );
}
