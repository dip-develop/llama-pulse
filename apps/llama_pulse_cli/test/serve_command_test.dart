import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_cli/llama_pulse_cli.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

import 'support/fake_server_controller.dart';

List<Map<String, Object?>> _lines(String text) => text
    .split('\n')
    .where((line) => line.isNotEmpty)
    .map((line) => jsonDecode(line) as Map<String, Object?>)
    .toList();

void main() {
  late Directory tempDirectory;
  late File modelFile;
  late FakeServerController controller;
  late InMemoryConfigStore store;
  late StreamController<ProcessSignal> signals;
  late StringBuffer out;
  late StringBuffer err;
  late LlamaPulseCommandRunner runner;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('llamapulse_serve_');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    modelFile = File('${tempDirectory.path}/model.gguf')
      ..writeAsStringSync('model');
    controller = FakeServerController();
    store = InMemoryConfigStore();
    signals = StreamController<ProcessSignal>.broadcast();
    out = StringBuffer();
    err = StringBuffer();
    runner = LlamaPulseCommandRunner(
      CliServices(
        paths: AppPaths(configDirectory: tempDirectory.path),
        configStore: store,
        out: out,
        err: err,
        interrupts: signals.stream,
        serverControllerFactory: () => controller,
      ),
    );
  });

  tearDown(() async {
    await signals.close();
  });

  List<String> serveArgs({bool json = true, String? modelPath}) => [
    'serve',
    if (json) '--json',
    '--model-path',
    modelPath ?? modelFile.path,
  ];

  Future<int> runWithSignal(
    List<String> args,
    ProcessSignal signal, {
    void Function()? onRunning,
  }) async {
    final subscription = controller.states.listen((state) {
      if (state.phase == ServerPhase.running) {
        onRunning?.call();
        signals.add(signal);
      }
    });
    try {
      return await runner.run(args);
    } finally {
      await subscription.cancel();
    }
  }

  test('emits starting, ready, stopping and stopped in order', () async {
    final code = await runWithSignal(serveArgs(), ProcessSignal.sigint);

    expect(code, ExitCodes.interrupted);
    expect(controller.startCalls, 1);
    expect(controller.stopCalls, 1);
    expect(controller.startConfig?.modelPath, modelFile.path);

    final events = _lines(out.toString());
    expect(events.map((event) => event['type']), [
      'starting',
      'ready',
      'stopping',
      'stopped',
    ]);
    expect(events[0]['schemaVersion'], 1);
    expect(events[0]['supervisorPid'], 1234);
    expect(events[0]['modelPath'], modelFile.path);
    expect(events[0]['host'], '127.0.0.1');
    expect(events[0]['port'], 8080);
    expect(events[0]['binaryPath'], '/opt/llama.cpp/llama-server');
    expect(events[0]['binaryVersion'], '0.8.0');
    expect(events[1]['serverPid'], 4321);
    expect(events[1]['baseUrl'], 'http://127.0.0.1:8080/v1');
    expect(events[1]['startupMs'], isA<int>());
    expect(events[2]['reason'], 'sigint');
    expect(events[3]['exitCode'], 0);
  });

  test('SIGTERM stops the server and exits 0', () async {
    final code = await runWithSignal(serveArgs(), ProcessSignal.sigterm);

    expect(code, ExitCodes.ok);
    expect(controller.stopCalls, 1);
    final events = _lines(out.toString());
    expect(events.map((event) => event['type']), contains('stopping'));
    expect(
      events.firstWhere((event) => event['type'] == 'stopping')['reason'],
      'sigterm',
    );
  });

  test('refuses to start when a recorded server answers /health', () async {
    await CliServices(
      paths: AppPaths(configDirectory: tempDirectory.path),
      configStore: store,
      out: out,
      err: err,
    ).serverStateRepository.save(
      ServerState(
        (b) => b
          ..phase = ServerPhase.running
          ..health = ServerHealth.ok
          ..supervisorPid = 11
          ..serverPid = 12
          ..host = '127.0.0.1'
          ..port = 8080
          ..modelPath = modelFile.path
          ..binaryPath = ''
          ..updatedAtEpochMs = 0,
      ),
    );

    final code = await runner.run(serveArgs());

    expect(code, ExitCodes.failure);
    expect(
      err.toString(),
      contains('a server is already recorded; run llamapulse stop'),
    );
    expect(controller.startCalls, 0);
    expect(out.toString(), isEmpty);
  });

  test('a stale state document does not block a start', () async {
    controller = FakeServerController(
      probeResult: const ServerProbeResult(
        ok: false,
        latencyMs: 0,
        message: 'unreachable',
      ),
    );
    runner = LlamaPulseCommandRunner(
      CliServices(
        paths: AppPaths(configDirectory: tempDirectory.path),
        configStore: store,
        out: out,
        err: err,
        interrupts: signals.stream,
        serverControllerFactory: () => controller,
      ),
    );
    await CliServices(
      paths: AppPaths(configDirectory: tempDirectory.path),
      configStore: store,
      out: out,
      err: err,
    ).serverStateRepository.save(
      ServerState(
        (b) => b
          ..phase = ServerPhase.running
          ..health = ServerHealth.ok
          ..supervisorPid = 11
          ..serverPid = 12
          ..host = '127.0.0.1'
          ..port = 8080
          ..modelPath = modelFile.path
          ..binaryPath = ''
          ..updatedAtEpochMs = 0,
      ),
    );

    final code = await runWithSignal(serveArgs(), ProcessSignal.sigint);

    expect(code, ExitCodes.interrupted);
    expect(controller.startCalls, 1);
  });

  test('missing model exits 3 without starting', () async {
    final code = await runner.run(
      serveArgs(modelPath: '${tempDirectory.path}/missing.gguf'),
    );

    expect(code, ExitCodes.notFound);
    expect(err.toString(), contains('model file not found'));
    expect(controller.startCalls, 0);
  });

  test('a blank model exits 2 with a validation message', () async {
    final code = await runner.run(['serve', '--model-path', '']);

    expect(code, ExitCodes.usage);
    expect(err.toString(), contains('error:'));
    expect(controller.startCalls, 0);
  });

  test('missing binary exits 1 before starting', () async {
    controller = FakeServerController(
      locateFailure: ServerException(
        ServerFailure(
          (b) => b
            ..code = ServerFailureCode.binaryNotFound
            ..message = 'llama-server not found',
        ),
      ),
    );
    runner = LlamaPulseCommandRunner(
      CliServices(
        paths: AppPaths(configDirectory: tempDirectory.path),
        configStore: store,
        out: out,
        err: err,
        interrupts: signals.stream,
        serverControllerFactory: () => controller,
      ),
    );

    final code = await runner.run(serveArgs());

    expect(code, ExitCodes.failure);
    expect(err.toString(), contains('binaryNotFound'));
    expect(controller.startCalls, 0);
  });

  test('a startup failure emits failed and exits 1', () async {
    controller = FakeServerController(
      startFailure: ServerException(
        ServerFailure(
          (b) => b
            ..code = ServerFailureCode.startupTimeout
            ..message = 'llama-server did not become ready within 10s'
            ..details = 'stderr: timeout',
        ),
      ),
    );
    runner = LlamaPulseCommandRunner(
      CliServices(
        paths: AppPaths(configDirectory: tempDirectory.path),
        configStore: store,
        out: out,
        err: err,
        interrupts: signals.stream,
        serverControllerFactory: () => controller,
      ),
    );

    final code = await runner.run(serveArgs());

    expect(code, ExitCodes.failure);
    final events = _lines(out.toString());
    final failed = events.lastWhere((event) => event['type'] == 'failed');
    expect(
      (failed['failure']! as Map<String, Object?>)['code'],
      'startupTimeout',
    );
    expect(failed['lastExitCode'], isNull);
  });

  test('an unexpected child exit emits failed and exits 1', () async {
    final subscription = controller.states.listen((state) {
      if (state.phase == ServerPhase.running) {
        Future<void>.microtask(
          () => controller.emitFailure(
            ServerFailure(
              (b) => b
                ..code = ServerFailureCode.processExited
                ..message = 'llama-server exited unexpectedly',
            ),
            lastExitCode: 7,
          ),
        );
      }
    });
    addTearDown(subscription.cancel);

    final code = await runner.run(serveArgs());

    expect(code, ExitCodes.failure);
    final failed = _lines(out.toString()).last;
    expect(failed['type'], 'failed');
    expect(failed['lastExitCode'], 7);
  });

  test(
    'human mode puts child stdout on stdout and diagnostics on stderr',
    () async {
      final code = await runWithSignal(
        serveArgs(json: false),
        ProcessSignal.sigint,
        onRunning: () {
          controller.emitLog('child line');
          controller.emitLog(
            'supervisor line',
            stream: ServerLogStream.supervisor,
          );
          controller.emitLog('child error', stream: ServerLogStream.stderr);
        },
      );

      expect(code, ExitCodes.interrupted);
      expect(out.toString(), 'child line\n');
      expect(err.toString(), contains('supervisor line'));
      expect(err.toString(), contains('child error'));
    },
  );

  test('json mode routes every log line through the object stream', () async {
    final code = await runWithSignal(
      serveArgs(),
      ProcessSignal.sigint,
      onRunning: () {
        controller.emitLog('child line');
        controller.emitMetrics(
          ServerMetrics.empty(DateTime.now().millisecondsSinceEpoch),
        );
      },
    );

    expect(code, ExitCodes.interrupted);
    final events = _lines(out.toString());
    final log = events.firstWhere((event) => event['type'] == 'log');
    expect(log['stream'], 'stdout');
    expect(log['line'], 'child line');
    final metrics = events.firstWhere((event) => event['type'] == 'metrics');
    expect(metrics['metrics'], isA<Map<String, Object?>>());
    expect(out.toString(), isNot(contains('supervisor line')));
  });
}
