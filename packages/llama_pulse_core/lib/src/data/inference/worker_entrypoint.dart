import 'dart:async';
import 'dart:isolate';

import '../../domain/entities/worker_request.dart';
import '../../domain/entities/worker_request_kind.dart';
import 'stub_llama_session.dart';
import 'worker_config.dart';
import 'worker_loop.dart';

/// Entry point of the inference worker isolate.
///
/// The pragma keeps the symbol alive in ahead-of-time builds where nothing
/// references it directly; [Isolate.spawn] resolves it by value at runtime.
@pragma('vm:entry-point')
void llamaWorkerMain(WorkerConfig config) {
  final port = ReceivePort();
  config.mainPort.send(WorkerReady(responsePort: port.sendPort));
  unawaited(_serve(config, port));
}

Future<void> _serve(WorkerConfig config, ReceivePort port) async {
  // The next change replaces the stub with the native session, which opens the
  // library named by LLAMA_PULSE_LIB; the stub ignores the path.
  final session = StubLlamaSession();
  await session.open('');
  final loop = WorkerLoop(session: session, send: config.mainPort.send);
  port.listen((Object? message) {
    if (message is! WorkerRequest) {
      return;
    }
    final disposing = message.kind == WorkerRequestKind.dispose;
    loop.handle(message);
    if (disposing) {
      // Closing the port after the `.disposed` response lets the isolate exit.
      unawaited(loop.dispose().whenComplete(port.close));
    }
  });
}
