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

final class _RecordingSignaller implements ProcessSignaller {
  _RecordingSignaller({this.onSend});

  final void Function(int pid, ServerKillMode mode)? onSend;
  final List<(int, ServerKillMode)> calls = <(int, ServerKillMode)>[];
  bool result = true;

  @override
  bool send(int pid, ServerKillMode mode) {
    calls.add((pid, mode));
    onSend?.call(pid, mode);
    return result;
  }
}

void main() {
  late Directory tempDirectory;
  late InMemoryConfigStore store;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'llamapulse_server_status_',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    store = InMemoryConfigStore();
    out = StringBuffer();
    err = StringBuffer();
  });

  CliServices services({
    FakeServerController? controller,
    ProcessSignaller? signaller,
    Stream<ProcessSignal>? interrupts,
    Duration stopTimeout = const Duration(milliseconds: 30),
  }) => CliServices(
    paths: AppPaths(configDirectory: tempDirectory.path),
    configStore: store,
    out: out,
    err: err,
    interrupts: interrupts,
    serverControllerFactory: controller == null ? null : () => controller,
    processSignaller: signaller ?? _RecordingSignaller(),
    stopTimeout: stopTimeout,
    stopPollInterval: const Duration(milliseconds: 5),
  );

  ServerState runningState({
    int serverPid = 124,
    int supervisorPid = 123,
    int? startedAtEpochMs,
    String modelPath = '/models/x.gguf',
  }) => ServerState(
    (b) => b
      ..phase = ServerPhase.running
      ..health = ServerHealth.ok
      ..supervisorPid = supervisorPid
      ..serverPid = serverPid
      ..host = '127.0.0.1'
      ..port = 8080
      ..modelPath = modelPath
      ..binaryPath = '/opt/llama.cpp/llama-server'
      ..binaryVersion = '0.8.0'
      ..startedAtEpochMs = startedAtEpochMs
      ..updatedAtEpochMs = 0,
  );

  test('status reports a running healthy server and exits 0', () async {
    final servicesUnderTest = services(controller: FakeServerController());
    await servicesUnderTest.serverStateRepository.save(
      runningState(
        startedAtEpochMs: DateTime.now().millisecondsSinceEpoch - 42000,
      ),
    );
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    final code = await runner.run(['status', '--json']);

    expect(code, ExitCodes.ok);
    final status = _lines(out.toString()).single;
    expect(status['schemaVersion'], 1);
    expect(status['type'], 'serverStatus');
    expect(status['running'], isTrue);
    expect(status['status'], 'running');
    expect(status['health'], 'ok');
    expect(status['pid'], 124);
    expect(status['supervisorPid'], 123);
    expect(status['host'], '127.0.0.1');
    expect(status['port'], 8080);
    expect(status['baseUrl'], 'http://127.0.0.1:8080/v1');
    expect(status['modelPath'], '/models/x.gguf');
    expect(status['uptimeSeconds'], inInclusiveRange(41, 43));
    expect(status['lastExitCode'], isNull);
    expect(status['failure'], isNull);
    final binary = status['binary']! as Map<String, Object?>;
    expect(binary['path'], '/opt/llama.cpp/llama-server');
    expect(binary['version'], '0.8.0');
    expect(binary['buildNumber'], 11960);
    expect(binary['supported'], isTrue);
    expect(binary['warning'], isNull);
  });

  test('status human output lists the spec fields in order', () async {
    final servicesUnderTest = services(controller: FakeServerController());
    await servicesUnderTest.serverStateRepository.save(
      runningState(
        startedAtEpochMs: DateTime.now().millisecondsSinceEpoch - 42000,
      ),
    );
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    expect(await runner.run(['status']), ExitCodes.ok);

    final text = out.toString();
    expect(text, contains('status: running\n'));
    expect(text, contains('pid: 124\n'));
    expect(text, contains('supervisorPid: 123\n'));
    expect(text, contains('endpoint: http://127.0.0.1:8080/v1\n'));
    expect(text, contains('model: /models/x.gguf\n'));
    expect(
      text,
      contains('binary: /opt/llama.cpp/llama-server (0.8.0, build 11960)\n'),
    );
    expect(text, contains('health: ok\n'));
    expect(text, contains('uptime: 42s\n'));
    expect(
      text.indexOf('status: running'),
      lessThan(text.indexOf('health: ok')),
    );
  });

  test('status with no state reports stopped and exits 1', () async {
    final servicesUnderTest = services(controller: FakeServerController());
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    expect(await runner.run(['status', '--json']), ExitCodes.failure);

    final status = _lines(out.toString()).single;
    expect(status['running'], isFalse);
    expect(status['status'], 'stopped');
    expect(status['health'], 'unknown');
    expect(status['pid'], isNull);
    expect(status['uptimeSeconds'], isNull);
    expect(status['binary'], isA<Map<String, Object?>>());
  });

  test('status reports stale when the server does not answer', () async {
    final servicesUnderTest = services(
      controller: FakeServerController(
        probeResult: const ServerProbeResult(
          ok: false,
          latencyMs: 0,
          message: 'unreachable',
        ),
      ),
    );
    await servicesUnderTest.serverStateRepository.save(runningState());
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    expect(await runner.run(['status', '--json']), ExitCodes.failure);

    final status = _lines(out.toString()).single;
    expect(status['running'], isFalse);
    expect(status['status'], 'stale');
    expect(status['health'], 'unreachable');
  });

  test(
    'status reports a missing binary and still exits 1 when stopped',
    () async {
      final servicesUnderTest = services(
        controller: FakeServerController(
          locateFailure: ServerException(
            ServerFailure(
              (b) => b
                ..code = ServerFailureCode.binaryNotFound
                ..message = 'llama-server not found',
            ),
          ),
        ),
      );
      final runner = LlamaPulseCommandRunner(servicesUnderTest);

      expect(await runner.run(['status']), ExitCodes.failure);

      expect(out.toString(), contains('binary: not found'));
      expect(out.toString(), contains('status: stopped'));
    },
  );

  test('stop with no recorded state prints not running and exits 0', () async {
    final servicesUnderTest = services();
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    expect(await runner.run(['stop']), ExitCodes.ok);
    expect(out.toString(), 'not running\n');
  });

  test('stop asks the supervisor to stop gracefully', () async {
    final signaller = _RecordingSignaller(
      onSend: (pid, mode) {
        if (mode == ServerKillMode.graceful) {
          unawaited(services().serverStateRepository.clear());
        }
      },
    );
    final servicesUnderTest = services(signaller: signaller);
    await servicesUnderTest.serverStateRepository.save(runningState());
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    expect(await runner.run(['stop', '--json']), ExitCodes.ok);

    expect(signaller.calls, [(123, ServerKillMode.graceful)]);
    final result = _lines(out.toString()).single;
    expect(result['type'], 'serverStop');
    expect(result['stopped'], isTrue);
    expect(result['pid'], 123);
    expect(result['forced'], isFalse);
  });

  test('stop forces a lingering process and clears the state', () async {
    late CliServices servicesUnderTest;
    final signaller = _RecordingSignaller(
      onSend: (pid, mode) {
        if (mode == ServerKillMode.force) {
          unawaited(servicesUnderTest.serverStateRepository.clear());
        }
      },
    );
    servicesUnderTest = services(signaller: signaller);
    await servicesUnderTest.serverStateRepository.save(runningState());
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    expect(await runner.run(['stop', '--json']), ExitCodes.ok);

    expect(signaller.calls, [
      (123, ServerKillMode.graceful),
      (123, ServerKillMode.force),
    ]);
    final result = _lines(out.toString()).single;
    expect(result['stopped'], isTrue);
    expect(result['forced'], isTrue);
    expect(await servicesUnderTest.serverStateRepository.load(), isNull);
  });

  test('stop --force skips the graceful phase', () async {
    final signaller = _RecordingSignaller(
      onSend: (pid, mode) =>
          unawaited(services().serverStateRepository.clear()),
    );
    final servicesUnderTest = services(signaller: signaller);
    await servicesUnderTest.serverStateRepository.save(runningState());
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    expect(await runner.run(['stop', '--force']), ExitCodes.ok);
    expect(signaller.calls, [(123, ServerKillMode.force)]);
    expect(out.toString(), 'stopped\n');
  });

  test('stop exits 1 when the process cannot be signalled', () async {
    final signaller = _RecordingSignaller()..result = false;
    final servicesUnderTest = services(signaller: signaller);
    await servicesUnderTest.serverStateRepository.save(runningState());
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    expect(await runner.run(['stop', '--json']), ExitCodes.failure);

    final result = _lines(out.toString()).single;
    expect(result['stopped'], isFalse);
    expect(result['forced'], isTrue);
    expect(err.toString(), contains('could not stop'));
  });

  test('logs prints the newest lines with the stream prefix', () async {
    final servicesUnderTest = services();
    final logStore = servicesUnderTest.serverLogStore;
    for (var i = 0; i < 5; i++) {
      logStore.append(ServerLogStream.stdout, 'line $i');
    }
    logStore.append(ServerLogStream.supervisor, 'supervisor line');
    await logStore.flush();
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    expect(await runner.run(['logs', '--lines', '2']), ExitCodes.ok);

    expect(out.toString(), '[stdout] line 4\n[supervisor] supervisor line\n');
  });

  test(
    'logs --json prints one object per line with the documented fields',
    () async {
      final servicesUnderTest = services();
      final logStore = servicesUnderTest.serverLogStore;
      logStore.append(ServerLogStream.stderr, 'first line');
      await logStore.flush();
      final runner = LlamaPulseCommandRunner(servicesUnderTest);

      expect(
        await runner.run(['logs', '--lines', '1', '--json']),
        ExitCodes.ok,
      );

      final entry = _lines(out.toString()).single;
      expect(entry.keys, [
        'schemaVersion',
        'type',
        'sequence',
        'timestampEpochMs',
        'stream',
        'line',
      ]);
      expect(entry['schemaVersion'], 1);
      expect(entry['type'], 'log');
      expect(entry['sequence'], 1);
      expect(entry['stream'], 'stderr');
      expect(entry['line'], 'first line');
      expect(entry['timestampEpochMs'], isA<int>());
    },
  );

  test('logs rejects an out-of-range line count', () async {
    final runner = LlamaPulseCommandRunner(services());

    expect(await runner.run(['logs', '--lines', '0']), ExitCodes.usage);
    expect(err.toString(), contains('--lines must be an integer in 1..1000'));
  });

  test('logs --follow prints new lines and exits 130 on interrupt', () async {
    final signals = StreamController<ProcessSignal>.broadcast();
    addTearDown(signals.close);
    final servicesUnderTest = services(interrupts: signals.stream);
    final logStore = servicesUnderTest.serverLogStore;
    logStore.append(ServerLogStream.stdout, 'first');
    await logStore.flush();
    final runner = LlamaPulseCommandRunner(servicesUnderTest);

    final running = runner.run(['logs', '--follow']);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    logStore.append(ServerLogStream.stdout, 'second');
    await logStore.flush();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    signals.add(ProcessSignal.sigint);

    expect(await running, ExitCodes.interrupted);
    expect(out.toString(), '[stdout] first\n[stdout] second\n');
  });

  test('logs on a missing file prints nothing and exits 0', () async {
    final runner = LlamaPulseCommandRunner(services());

    expect(await runner.run(['logs', '--lines', '5']), ExitCodes.ok);
    expect(out.toString(), isEmpty);
  });
}
