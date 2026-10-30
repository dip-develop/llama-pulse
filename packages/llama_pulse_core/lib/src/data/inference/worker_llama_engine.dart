import 'dart:async';

import '../../domain/entities/generation_event.dart';
import '../../domain/entities/generation_metrics.dart';
import '../../domain/entities/generation_request.dart';
import '../../domain/entities/inference_failure.dart';
import '../../domain/entities/inference_failure_code.dart';
import '../../domain/entities/model_params.dart';
import '../../domain/entities/worker_request.dart';
import '../../domain/entities/worker_response.dart';
import '../../domain/entities/worker_response_kind.dart';
import '../../domain/exceptions/inference_failure_exception.dart';
import '../../domain/gateways/llama_engine.dart';
import 'worker_config.dart';
import 'worker_transport.dart';

/// [LlamaEngine] backed by a long-lived worker isolate.
///
/// Nothing happens in the constructor: the worker is spawned lazily by the
/// first [load], [unload] or [generate], and a failed start is retried on the
/// next call.
final class WorkerLlamaEngine implements LlamaEngine {
  /// Creates an engine that spawns [entryPoint], or the production worker when
  /// none is given.
  WorkerLlamaEngine({
    this.loadTimeout = const Duration(seconds: 30),
    this.requestTimeout = const Duration(minutes: 5),
    void Function(WorkerConfig)? entryPoint,
  }) : _entryPoint = entryPoint; // ignore: prefer_initializing_formals

  /// Upper bound for loading or unloading a model.
  final Duration loadTimeout;

  /// Upper bound for one generation, measured from [generate] to its terminal.
  final Duration requestTimeout;

  final void Function(WorkerConfig)? _entryPoint;
  final _controls = <int, _PendingControl>{};
  final _channels = <int, _GenerationChannel>{};

  static final _zeroMetrics = GenerationMetrics(
    (b) => b
      ..promptTokenCount = 0
      ..generatedTokenCount = 0
      ..promptEvalMs = 0
      ..evalMs = 0,
  );

  WorkerTransport? _transport;
  StreamSubscription<WorkerResponse>? _responseSubscription;
  StreamSubscription<InferenceFailure>? _failureSubscription;
  Future<WorkerTransport>? _starting;
  Future<void>? _disposing;
  // Control ids are negative and decrease so they never collide with the
  // caller-owned, non-negative generation ids.
  int _nextControlRequestId = -1;

  /// Loads [params], spawning the worker on first use.
  @override
  Future<void> load(ModelParams params) async {
    _ensureNotDisposed();
    final transport = await _started();
    final requestId = _controlId();
    final completer = Completer<void>();
    _controls[requestId] = _PendingControl(
      expectedKind: WorkerResponseKind.loaded,
      completer: completer,
    );
    try {
      transport.send(WorkerRequest.load(requestId, params));
      await completer.future.timeout(loadTimeout);
    } on TimeoutException {
      throw InferenceFailureException(
        _timedOut('Loading the model', loadTimeout),
      );
    } finally {
      _controls.remove(requestId);
    }
  }

  /// Releases the loaded model, keeping the worker alive.
  @override
  Future<void> unload() async {
    _ensureNotDisposed();
    final transport = await _started();
    final requestId = _controlId();
    final completer = Completer<void>();
    _controls[requestId] = _PendingControl(
      expectedKind: WorkerResponseKind.unloaded,
      completer: completer,
    );
    try {
      transport.send(WorkerRequest.unload(requestId));
      await completer.future.timeout(loadTimeout);
    } on TimeoutException {
      throw InferenceFailureException(
        _timedOut('Unloading the model', loadTimeout),
      );
    } finally {
      _controls.remove(requestId);
    }
  }

  /// Starts generation for [request].
  ///
  /// Caller ids must be non-negative and unique while a request is in flight;
  /// responses for any other id are ignored. The returned stream emits
  /// [GenerationEvent.started] immediately, then tokens and metrics, then
  /// exactly one terminal event, and never a stream error.
  @override
  Stream<GenerationEvent> generate(GenerationRequest request) {
    final controller = StreamController<GenerationEvent>();
    final channel = _GenerationChannel(
      requestId: request.requestId,
      controller: controller,
    );
    _channels[request.requestId] = channel;
    channel.emit(GenerationEvent.started(request.requestId));
    if (_disposing != null) {
      _finishChannel(
        channel,
        GenerationEvent.failed(
          request.requestId,
          _failure(
            InferenceFailureCode.engineUnavailable,
            'The inference engine was disposed.',
          ),
        ),
      );
      return controller.stream;
    }
    channel.timeout = Timer(
      requestTimeout,
      () => _failChannel(channel, _timedOut('The inference request')),
    );
    unawaited(_startGeneration(channel, request));
    return controller.stream;
  }

  /// Sends a fire-and-forget cancel request for [requestId].
  @override
  Future<void> cancel(int requestId) async {
    final transport = _transport;
    if (transport == null || !transport.isRunning) {
      return;
    }
    try {
      transport.send(WorkerRequest.cancel(_controlId(), requestId));
    } on StateError {
      // The worker exited between the check and the send.
    }
  }

  /// Shuts the worker down; idempotent.
  @override
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    final pendingStart = _starting;
    var transport = _transport;
    if (transport == null && pendingStart != null) {
      try {
        transport = await pendingStart;
      } on InferenceFailureException {
        transport = null;
      }
    }
    _starting = null;
    _transport = null;
    if (transport != null) {
      if (transport.isRunning) {
        try {
          transport.send(WorkerRequest.dispose(_controlId()));
        } on StateError {
          // The worker already exited; closing the transport is enough.
        }
      }
      await transport.close();
    }
    await _responseSubscription?.cancel();
    await _failureSubscription?.cancel();
    _responseSubscription = null;
    _failureSubscription = null;
    for (final control in _controls.values.toList()) {
      control.completer.completeError(
        InferenceFailureException(
          _failure(
            InferenceFailureCode.engineUnavailable,
            'The inference engine was disposed.',
          ),
        ),
      );
    }
    _controls.clear();
    for (final channel in _channels.values.toList()) {
      _finishChannel(
        channel,
        GenerationEvent.failed(
          channel.requestId,
          _failure(
            InferenceFailureCode.cancelled,
            'The inference engine was disposed.',
          ),
        ),
      );
    }
  }

  Future<void> _startGeneration(
    _GenerationChannel channel,
    GenerationRequest request,
  ) async {
    try {
      final transport = await _started();
      transport.send(WorkerRequest.generate(request));
    } catch (error) {
      _finishChannel(
        channel,
        GenerationEvent.failed(channel.requestId, _failureFrom(error)),
      );
    }
  }

  Future<WorkerTransport> _started() async {
    final existing = _transport;
    if (existing != null && existing.isRunning) {
      return existing;
    }
    final starting = _starting;
    if (starting != null) {
      return starting;
    }
    final future = _startTransport();
    _starting = future;
    try {
      return await future.timeout(loadTimeout);
    } on TimeoutException {
      throw InferenceFailureException(
        _timedOut('Starting the inference worker', loadTimeout),
      );
    } finally {
      if (identical(_starting, future)) {
        _starting = null;
      }
    }
  }

  Future<WorkerTransport> _startTransport() async {
    final previousResponses = _responseSubscription;
    final previousFailures = _failureSubscription;
    if (previousResponses != null) {
      await previousResponses.cancel();
    }
    if (previousFailures != null) {
      await previousFailures.cancel();
    }
    final transport = WorkerTransport(entryPoint: _entryPoint);
    try {
      await transport.start();
    } catch (error) {
      await transport.close();
      if (error is InferenceFailureException) {
        rethrow;
      }
      throw InferenceFailureException(_failureFrom(error));
    }
    _responseSubscription = transport.responses.listen(_onResponse);
    _failureSubscription = transport.failures.listen(_failAll);
    _transport = transport;
    return transport;
  }

  void _onResponse(WorkerResponse response) {
    switch (response.kind) {
      case WorkerResponseKind.loaded:
      case WorkerResponseKind.unloaded:
        _completeControl(response);
      case WorkerResponseKind.failure:
        _handleFailureResponse(response);
      case WorkerResponseKind.tokenBatch:
        _channels[response.requestId]?.emit(
          GenerationEvent.token(response.requestId, response.text),
        );
      case WorkerResponseKind.metrics:
        final channel = _channels[response.requestId];
        final metrics = response.metrics;
        if (channel != null && metrics != null) {
          channel.latestMetrics = metrics;
          channel.emit(GenerationEvent.metrics(response.requestId, metrics));
        }
      case WorkerResponseKind.completed:
        final channel = _channels[response.requestId];
        if (channel != null) {
          _finishChannel(
            channel,
            GenerationEvent.completed(
              response.requestId,
              channel.latestMetrics ?? _zeroMetrics,
            ),
          );
        }
      case WorkerResponseKind.cancelled:
        final channel = _channels[response.requestId];
        if (channel != null) {
          _finishChannel(
            channel,
            GenerationEvent.cancelled(response.requestId),
          );
        }
      case WorkerResponseKind.pong:
      case WorkerResponseKind.disposed:
        break;
    }
  }

  void _completeControl(WorkerResponse response) {
    final control = _controls.remove(response.requestId);
    if (control == null || control.expectedKind != response.kind) {
      return;
    }
    control.completer.complete();
  }

  void _handleFailureResponse(WorkerResponse response) {
    final failure = response.failure;
    if (failure == null) {
      return;
    }
    final control = _controls.remove(response.requestId);
    if (control != null) {
      control.completer.completeError(InferenceFailureException(failure));
      return;
    }
    final channel = _channels[response.requestId];
    if (channel != null) {
      _finishChannel(
        channel,
        GenerationEvent.failed(response.requestId, failure),
      );
    }
  }

  void _failAll(InferenceFailure failure) {
    final controls = _controls.values.toList();
    _controls.clear();
    for (final control in controls) {
      control.completer.completeError(InferenceFailureException(failure));
    }
    final channels = _channels.values.toList();
    for (final channel in channels) {
      _finishChannel(
        channel,
        GenerationEvent.failed(channel.requestId, failure),
      );
    }
  }

  void _failChannel(_GenerationChannel channel, InferenceFailure failure) {
    _finishChannel(channel, GenerationEvent.failed(channel.requestId, failure));
    cancel(channel.requestId);
  }

  void _finishChannel(_GenerationChannel channel, GenerationEvent terminal) {
    _channels.remove(channel.requestId);
    channel.finish(terminal);
  }

  void _ensureNotDisposed() {
    if (_disposing != null) {
      throw InferenceFailureException(
        _failure(
          InferenceFailureCode.engineUnavailable,
          'The inference engine was disposed.',
        ),
      );
    }
  }

  int _controlId() => _nextControlRequestId--;

  InferenceFailure _timedOut(String action, [Duration? limit]) {
    final bound = limit ?? requestTimeout;
    return _failure(
      InferenceFailureCode.nativeError,
      '$action timed out after ${bound.inMilliseconds} ms.',
    );
  }

  InferenceFailure _failureFrom(Object error) {
    if (error is InferenceFailureException) {
      return error.failure;
    }
    if (error is TimeoutException) {
      return _timedOut('The inference request');
    }
    return _failure(
      InferenceFailureCode.nativeError,
      'The inference engine failed.',
      details: error.toString(),
    );
  }

  InferenceFailure _failure(
    InferenceFailureCode code,
    String message, {
    String? details,
  }) => InferenceFailure(
    (b) => b
      ..code = code
      ..message = message
      ..details = details,
  );
}

final class _PendingControl {
  _PendingControl({required this.expectedKind, required this.completer});

  final WorkerResponseKind expectedKind;
  final Completer<void> completer;
}

final class _GenerationChannel {
  _GenerationChannel({required this.requestId, required this.controller});

  final int requestId;
  final StreamController<GenerationEvent> controller;
  GenerationMetrics? latestMetrics;
  Timer? timeout;
  bool _done = false;

  void emit(GenerationEvent event) {
    if (_done) {
      return;
    }
    controller.add(event);
  }

  void finish(GenerationEvent terminal) {
    if (_done) {
      return;
    }
    _done = true;
    timeout?.cancel();
    controller.add(terminal);
    unawaited(controller.close());
  }
}
