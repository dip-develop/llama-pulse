import 'dart:async';
import 'dart:isolate';

import '../../domain/entities/inference_failure.dart';
import '../../domain/entities/inference_failure_code.dart';
import '../../domain/entities/worker_request.dart';
import '../../domain/entities/worker_response.dart';
import 'worker_config.dart';
import 'worker_entrypoint.dart';

/// Owns the worker isolate and its message ports on the spawning side.
///
/// [start] spawns the isolate and waits for [WorkerReady]; [send] is only valid
/// afterwards and throws a [StateError] before it. Responses and crash
/// notifications are exposed as broadcast streams, so a consumer that needs a
/// message must subscribe before sending the request.
final class WorkerTransport {
  /// Creates a transport that spawns [entryPoint], or [llamaWorkerMain] when
  /// none is given.
  ///
  /// [useStubSession] is forwarded to the worker in [WorkerConfig] and selects
  /// the session implementation inside the worker.
  WorkerTransport({
    void Function(WorkerConfig)? entryPoint,
    this.handshakeTimeout = const Duration(seconds: 10),
    this.useStubSession = false,
  }) : _entryPoint = entryPoint ?? llamaWorkerMain;

  /// How long [start] waits for the worker's [WorkerReady] handshake.
  final Duration handshakeTimeout;

  /// Whether the worker should run the deterministic stub session.
  final bool useStubSession;

  static const _exitGrace = Duration(seconds: 2);

  final void Function(WorkerConfig) _entryPoint;
  final _responses = StreamController<WorkerResponse>.broadcast();
  final _failures = StreamController<InferenceFailure>.broadcast();
  Completer<void> _exitSignal = Completer<void>();

  Isolate? _isolate;
  ReceivePort? _port;
  SendPort? _workerPort;
  Completer<SendPort?>? _handshake;
  Future<void>? _starting;
  Future<void>? _closing;
  bool _closeRequested = false;
  bool _closed = false;
  bool _exitReported = false;

  /// Responses received from the worker.
  Stream<WorkerResponse> get responses => _responses.stream;

  /// Crashes and unexpected exits of the worker.
  Stream<InferenceFailure> get failures => _failures.stream;

  /// Whether the isolate is spawned and its response port is known.
  bool get isRunning => !_closed && _workerPort != null;

  /// Spawns the worker and waits for its handshake; idempotent.
  Future<void> start() async {
    if (_closed) {
      throw StateError('The worker transport is closed.');
    }
    await (_starting ??= _start());
  }

  /// Sends [request] to the worker.
  void send(WorkerRequest request) {
    final port = _workerPort;
    if (port == null || _closed) {
      throw StateError('The worker transport is not running.');
    }
    port.send(request);
  }

  /// Stops the worker; idempotent.
  ///
  /// The isolate is killed only when it does not exit on its own within two
  /// seconds, which is the only place a kill is allowed.
  Future<void> close() => _closing ??= _close();

  Future<void> _start() async {
    // A transport aborted after a handshake timeout can be started again; the
    // exit completer is single-use, so reset it together with the exit flag.
    if (_exitSignal.isCompleted) {
      _exitSignal = Completer<void>();
    }
    _exitReported = false;

    final port = ReceivePort();
    _port = port;
    final handshake = Completer<SendPort?>();
    _handshake = handshake;
    port.listen(_onMessage);

    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _entryPoint,
        WorkerConfig(mainPort: port.sendPort, useStubSession: useStubSession),
        debugName: 'llamapulse-worker',
        errorsAreFatal: false,
        onError: port.sendPort,
        onExit: port.sendPort,
      );
    } catch (_) {
      _starting = null;
      port.close();
      _port = null;
      _handshake = null;
      rethrow;
    }
    _isolate = isolate;

    // `close()` may have been requested while `Isolate.spawn` was awaiting; it
    // cannot see the isolate yet, so the spawned worker is killed here instead
    // of leaking.
    if (_closeRequested) {
      isolate.kill(priority: Isolate.immediate);
      _isolate = null;
      _handshake = null;
      _port?.close();
      _port = null;
      _starting = null;
      throw StateError('The inference worker was closed before it started.');
    }

    final SendPort? responsePort;
    try {
      responsePort = await handshake.future.timeout(handshakeTimeout);
    } on TimeoutException {
      _starting = null;
      await _abortStart();
      throw StateError(
        'The inference worker did not start within '
        '${handshakeTimeout.inMilliseconds} ms.',
      );
    }
    if (responsePort == null) {
      _starting = null;
      await _abortStart();
      throw StateError('The inference worker was closed before it started.');
    }
    _workerPort = responsePort;
  }

  Future<void> _close() async {
    _closeRequested = true;
    final handshake = _handshake;
    if (handshake != null && !handshake.isCompleted) {
      handshake.complete(null);
    }
    // Wait for an in-flight spawn so a worker that appears late is killed by
    // `_start` instead of outliving this close.
    final starting = _starting;
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        // The start already reported its own failure.
      }
    }
    final isolate = _isolate;
    if (isolate != null) {
      try {
        await _exitSignal.future.timeout(_exitGrace);
      } on TimeoutException {
        isolate.kill(priority: Isolate.immediate);
      }
    }
    _isolate = null;
    _workerPort = null;
    _handshake = null;
    _closed = true;
    _port?.close();
    _port = null;
    await _responses.close();
    await _failures.close();
  }

  Future<void> _abortStart() async {
    final isolate = _isolate;
    _starting = null;
    _isolate = null;
    _workerPort = null;
    _handshake = null;
    isolate?.kill(priority: Isolate.immediate);
    _port?.close();
    _port = null;
  }

  void _onMessage(Object? message) {
    if (message is WorkerReady) {
      final handshake = _handshake;
      if (handshake != null && !handshake.isCompleted) {
        handshake.complete(message.responsePort);
      }
      return;
    }
    if (message is WorkerResponse) {
      if (!_responses.isClosed) {
        _responses.add(message);
      }
      return;
    }
    if (message is List<Object?>) {
      _reportCrash(
        message.isEmpty ? null : message.first,
        message.length > 1 ? message[1] : null,
      );
      _abortHandshake();
      return;
    }
    _reportExit();
    _abortHandshake();
  }

  void _abortHandshake() {
    final handshake = _handshake;
    if (handshake != null && !handshake.isCompleted) {
      handshake.complete(null);
    }
  }

  void _reportCrash(Object? error, Object? stack) {
    if (_closeRequested || _failures.isClosed) {
      return;
    }
    _failures.add(
      InferenceFailure(
        (b) => b
          ..code = InferenceFailureCode.nativeError
          ..message = '${error ?? 'The inference worker failed.'}'
          ..details = stack?.toString(),
      ),
    );
  }

  void _reportExit() {
    if (!_exitSignal.isCompleted) {
      _exitSignal.complete();
    }
    _port?.close();
    _port = null;
    if (_exitReported) {
      return;
    }
    _exitReported = true;
    _workerPort = null;
    if (_closeRequested || _failures.isClosed) {
      return;
    }
    _failures.add(
      InferenceFailure(
        (b) => b
          ..code = InferenceFailureCode.nativeError
          ..message = 'The inference worker exited unexpectedly.'
          ..details = 'workerExited',
      ),
    );
  }
}
