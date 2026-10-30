import 'dart:async';
import 'dart:isolate';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void _crashingEntryPoint(WorkerConfig config) {
  throw StateError('worker crashed on purpose');
}

void _exitingEntryPoint(WorkerConfig config) {
  final port = ReceivePort();
  config.mainPort.send(WorkerReady(responsePort: port.sendPort));
  // Closing the only port lets the isolate exit right after the handshake.
  port.close();
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
}
