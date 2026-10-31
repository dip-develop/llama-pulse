import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

import '../../support/server_fakes.dart';

ServerConfig _config({
  String modelPath = '/models/missing.gguf',
  int parallelSlots = 3,
}) => ServerConfig(
  (b) => b
    ..modelPath = modelPath
    ..host = '127.0.0.1'
    ..port = 18080
    ..contextSize = 4096
    ..threads = 4
    ..gpuLayers = 0
    ..parallelSlots = parallelSlots
    ..modelAlias = 'stub'
    ..apiKey = ''
    ..flashAttention = ServerFlashAttention.auto
    ..mlock = false
    ..mmap = true
    ..binaryPath = ''
    ..startupTimeoutSeconds = 10,
);

void main() {
  late StubServerController controller;
  var now = 0;

  setUp(() {
    now = 0;
    controller = StubServerController(
      clock: () => now,
      delay: (duration) async {
        now += duration.inMilliseconds;
      },
    );
  });

  tearDown(() async {
    await controller.dispose();
  });

  test(
    'moves through starting and running without touching the model',
    () async {
      final phases = <ServerPhase>[];
      final states = <ServerState>[];
      final subscription = controller.states.listen((state) {
        phases.add(state.phase);
        states.add(state);
      });
      addTearDown(subscription.cancel);

      await controller.start(_config());
      await pumpEventQueue();

      expect(phases, [ServerPhase.starting, ServerPhase.running]);
      expect(controller.state.phase, ServerPhase.running);
      expect(controller.state.health, ServerHealth.ok);
      expect(controller.state.serverPid, isNull);
      expect(controller.state.host, '127.0.0.1');
      expect(controller.state.port, 18080);
      expect(states.first.health, ServerHealth.loading);
    },
  );

  test('emits deterministic synthetic metrics every tick', () async {
    final fast = StubServerController(
      tuning: const SupervisorTuning(
        monitorInterval: Duration(milliseconds: 5),
      ),
      clock: () => now,
      delay: (duration) async {
        now += duration.inMilliseconds;
      },
    );
    addTearDown(fast.dispose);
    await fast.start(_config(parallelSlots: 3));

    final sample = await fast.metrics.first;

    expect(sample.totalSlots, 3);
    expect(sample.activeSlots, 1);
    expect(sample.tokensPerSecond, 32.0);
    expect(sample.promptTokensPerSecond, 96.0);
    expect(sample.promptTokensTotal, 0);
    expect(sample.capturedAtEpochMs, now);
  });

  test('emits synthetic log lines', () async {
    final fast = StubServerController(
      tuning: const SupervisorTuning(
        monitorInterval: Duration(milliseconds: 5),
      ),
      clock: () => now,
      delay: (duration) async {
        now += duration.inMilliseconds;
      },
    );
    addTearDown(fast.dispose);
    await fast.start(_config());

    final entry = await fast.logs.first;

    expect(entry.line, isNotEmpty);
    expect(entry.stream, ServerLogStream.stdout);
    expect(entry.sequence, greaterThan(0));
  });

  test('stop publishes stopping then stopped and cancels timers', () async {
    await controller.start(_config());
    final phases = <ServerPhase>[];
    final subscription = controller.states.listen(
      (state) => phases.add(state.phase),
    );
    addTearDown(subscription.cancel);

    await controller.stop();
    await pumpEventQueue();

    expect(phases, [ServerPhase.stopping, ServerPhase.stopped]);
    expect(controller.state.phase, ServerPhase.stopped);
  });

  test('stop before start is a no-op', () async {
    await controller.stop();

    expect(controller.state.phase, ServerPhase.stopped);
  });

  test('testConnection answers ok with a fixed latency', () async {
    final result = await controller.testConnection(_config());

    expect(result.ok, isTrue);
    expect(result.latencyMs, 12);
    expect(result.message, 'ok');
  });

  test('locateBinary describes the fake executable', () async {
    final info = await controller.locateBinary(_config());

    expect(info.path, '/stub/llama-server');
    expect(info.version, '0.8.0');
    expect(info.buildNumber, 11960);
    expect(info.supported, isTrue);
  });

  test('persists states when a repository is provided', () async {
    final repository = FakeStateRepository();
    final persisting = StubServerController(
      stateRepository: repository,
      clock: () => now,
      delay: (duration) async {
        now += duration.inMilliseconds;
      },
    );
    addTearDown(persisting.dispose);

    await persisting.start(_config());
    await pumpEventQueue();

    expect(repository.saved.map((state) => state.phase), [
      ServerPhase.starting,
      ServerPhase.running,
    ]);
  });

  test('dispose is idempotent and closes the streams', () async {
    await controller.start(_config());

    await controller.dispose();
    await controller.dispose();
    final rest = await controller.states.toList();

    expect(controller.state.phase, ServerPhase.stopped);
    expect(rest, isEmpty);
  });
}
