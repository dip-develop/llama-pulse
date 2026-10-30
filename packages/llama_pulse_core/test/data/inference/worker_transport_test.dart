import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

final String _readyMarker =
    '${Directory.systemTemp.path}/llama_pulse_handshake_$pid';

void _crashingEntryPoint(WorkerConfig config) {
  throw StateError('worker crashed on purpose');
}

void _exitingEntryPoint(WorkerConfig config) {
  final port = ReceivePort();
  config.mainPort.send(WorkerReady(responsePort: port.sendPort));
  // Closing the only port lets the isolate exit right after the handshake.
  port.close();
}

/// Sends [WorkerReady] only when [_readyMarker] exists, so one transport can
/// time out and then start successfully against the same entry point.
void _conditionalEntryPoint(WorkerConfig config) {
  final port = ReceivePort();
  port.listen((Object? message) => port.close());
  if (File(_readyMarker).existsSync()) {
    config.mainPort.send(WorkerReady(responsePort: port.sendPort));
  }
}

void _deleteReadyMarker() {
  final marker = File(_readyMarker);
  if (marker.existsSync()) {
    marker.deleteSync();
  }
}

Future<void> _shutdown(WorkerTransport transport) async {
  if (transport.isRunning) {
    transport.send(WorkerRequest.dispose(-99));
  }
  await transport.close();
}

void main() {
  test('spawns a worker and completes the handshake', () async {
    final transport = WorkerTransport();
    addTearDown(transport.close);
    expect(transport.isRunning, isFalse);
    await transport.start();
    await transport.start();
    expect(transport.isRunning, isTrue);

    final pong = transport.responses
        .firstWhere((response) => response.kind == WorkerResponseKind.pong)
        .timeout(const Duration(seconds: 5));
    transport.send(WorkerRequest.ping(-1));
    expect((await pong).requestId, -1);
    await _shutdown(transport);
  });

  test('close is idempotent', () async {
    final transport = WorkerTransport();
    await transport.start();
    final first = transport.close();
    final second = transport.close();
    await first;
    await second;
    expect(transport.isRunning, isFalse);
    expect(() => transport.send(WorkerRequest.ping(-1)), throwsStateError);
  });

  test('send before start throws', () {
    final transport = WorkerTransport();
    expect(() => transport.send(WorkerRequest.ping(-1)), throwsStateError);
  });

  test('a crashing entry point fails the handshake', () async {
    final transport = WorkerTransport(
      entryPoint: _crashingEntryPoint,
      handshakeTimeout: const Duration(milliseconds: 200),
    );
    addTearDown(transport.close);
    await expectLater(transport.start(), throwsA(isA<StateError>()));
    expect(transport.isRunning, isFalse);
  });

  test('an unexpected exit emits a failure', () async {
    final transport = WorkerTransport(entryPoint: _exitingEntryPoint);
    addTearDown(transport.close);
    final failure = transport.failures.first.timeout(
      const Duration(seconds: 5),
    );
    await transport.start();
    final reported = await failure;
    expect(reported.code, InferenceFailureCode.nativeError);
    expect(reported.message, contains('exited'));
    expect(transport.isRunning, isFalse);
  });

  test('a handshake timeout fails start and close completes', () async {
    _deleteReadyMarker();
    final transport = WorkerTransport(
      entryPoint: _conditionalEntryPoint,
      handshakeTimeout: const Duration(milliseconds: 50),
    );
    addTearDown(_deleteReadyMarker);
    await expectLater(transport.start(), throwsA(isA<StateError>()));
    expect(transport.isRunning, isFalse);
    await transport.close();
    expect(transport.isRunning, isFalse);
  });

  test('the transport is reusable after a handshake timeout', () async {
    _deleteReadyMarker();
    addTearDown(_deleteReadyMarker);
    final transport = WorkerTransport(
      entryPoint: _conditionalEntryPoint,
      handshakeTimeout: const Duration(milliseconds: 50),
    );
    addTearDown(transport.close);

    await expectLater(transport.start(), throwsA(isA<StateError>()));
    expect(transport.isRunning, isFalse);

    File(_readyMarker).writeAsStringSync('ready');
    await transport.start();
    expect(transport.isRunning, isTrue);
    await _shutdown(transport);
    expect(transport.isRunning, isFalse);
  });

  test('close while the spawn is in flight does not leak the worker', () async {
    _deleteReadyMarker();
    addTearDown(_deleteReadyMarker);
    final transport = WorkerTransport(entryPoint: _conditionalEntryPoint);
    final starting = transport.start();
    final closing = transport.close();

    await expectLater(starting, throwsA(isA<StateError>()));
    await closing;
    expect(transport.isRunning, isFalse);
    expect(() => transport.send(WorkerRequest.ping(-1)), throwsStateError);
  });
}
