import 'dart:async';
import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../support/server_fakes.dart';

const _tuning = SupervisorTuning(
  healthPollInterval: Duration(milliseconds: 5),
  shutdownGrace: Duration(milliseconds: 10),
  stopPollInterval: Duration(milliseconds: 5),
  monitorInterval: Duration(milliseconds: 10),
  metricsInterval: Duration(milliseconds: 10),
  httpTimeout: Duration(milliseconds: 50),
  maxLogTail: 5,
);

const _healthy = ServerHttpResponse(statusCode: 200, body: '{"status":"ok"}');

const _metricsTuning = SupervisorTuning(
  healthPollInterval: Duration(milliseconds: 5),
  shutdownGrace: Duration(milliseconds: 10),
  stopPollInterval: Duration(milliseconds: 5),
  monitorInterval: Duration(hours: 1),
  metricsInterval: Duration(milliseconds: 5),
  httpTimeout: Duration(milliseconds: 50),
  maxLogTail: 5,
);

/// A monitor returning one canned sample, or throwing the configured error.
final class _FakeMonitor extends ServerMonitor {
  _FakeMonitor({this.value, this.error}) : super(httpClient: FakeHttpClient());

  final ServerMetrics? value;
  final Object? error;
  int calls = 0;

  @override
  Future<ServerMetrics> sample(
    ServerConfig config, {
    int? startedAtEpochMs,
  }) async {
    calls++;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return value ?? ServerMetrics.empty(startedAtEpochMs ?? 0);
  }
}

ServerBinaryInfo _binary({int? buildNumber = 11960}) => ServerBinaryInfo(
  (b) => b
    ..path = '/opt/llama-server'
    ..version = buildNumber == null ? 'unknown' : 'b$buildNumber'
    ..buildNumber = buildNumber
    ..supported = true
    ..rawOutput = 'llama-server',
);

ServerConfig _config(
  String modelPath, {
  String host = '127.0.0.1',
  int port = 18080,
  int parallelSlots = 2,
  int startupTimeoutSeconds = 10,
  bool mlock = false,
  String apiKey = '',
}) => ServerConfig(
  (b) => b
    ..modelPath = modelPath
    ..host = host
    ..port = port
    ..contextSize = 4096
    ..threads = 4
    ..gpuLayers = 0
    ..parallelSlots = parallelSlots
    ..modelAlias = 'llama-pulse'
    ..apiKey = apiKey
    ..flashAttention = ServerFlashAttention.auto
    ..mlock = mlock
    ..mmap = true
    ..binaryPath = ''
    ..startupTimeoutSeconds = startupTimeoutSeconds,
);

void main() {
  late Directory directory;
  late String modelPath;
  late ServerLogStore logStore;
  late FakeLauncher launcher;
  late FakeHttpClient httpClient;
  late FakePortProbe portProbe;
  late FakeBinaryLocator binaryLocator;
  late FakeStateRepository stateRepository;
  late FakeServerProcess process;
  LlamaServerSupervisor? supervisor;
  var now = 0;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'llama_pulse_supervisor_',
    );
    now = 0;
    modelPath = p.join(directory.path, 'model.gguf');
    await File(modelPath).writeAsString('gguf');
    logStore = ServerLogStore(
      filePath: p.join(directory.path, 'server.log'),
      capacity: 200,
    );
    launcher = FakeLauncher();
    httpClient = FakeHttpClient();
    portProbe = FakePortProbe();
    binaryLocator = FakeBinaryLocator()..info = _binary();
    stateRepository = FakeStateRepository();
    process = FakeServerProcess()..exitOnGraceful = true;
    launcher.process = process;
    supervisor = null;
  });

  tearDown(() async {
    await supervisor?.dispose();
    await process.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  LlamaServerSupervisor create({
    SupervisorTuning tuning = _tuning,
    ServerMonitor? monitor,
  }) {
    final created = LlamaServerSupervisor(
      launcher: launcher,
      httpClient: httpClient,
      portProbe: portProbe,
      binaryLocator: binaryLocator,
      stateRepository: stateRepository,
      logStore: logStore,
      validator: const ServerConfigValidator(),
      monitor: monitor,
      tuning: tuning,
      clock: () => now,
      delay: (duration) async {
        now += duration.inMilliseconds;
      },
    );
    supervisor = created;
    return created;
  }

  Future<void> waitUntil(bool Function() condition) async {
    for (var attempt = 0; attempt < 1000 && !condition(); attempt++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(condition(), isTrue);
  }

  void answerHealthy() {
    httpClient.addResponse('/health', _healthy);
    httpClient.addResponse(
      '/props',
      const ServerHttpResponse(statusCode: 200, body: '{}'),
    );
  }

  Future<void> startHealthy(LlamaServerSupervisor created) async {
    answerHealthy();
    await created.start(_config(modelPath));
  }

  Matcher throwsServerFailure(ServerFailureCode code) => throwsA(
    isA<ServerException>().having(
      (error) => error.failure.code,
      'failure.code',
      code,
    ),
  );

  test('starts the child, waits for health and publishes running', () async {
    final created = create();
    final states = <ServerState>[];
    final subscription = created.states.listen(states.add);
    addTearDown(subscription.cancel);

    await startHealthy(created);
    await pumpEventQueue();

    expect(states.first.phase, ServerPhase.starting);
    expect(
      states.any(
        (state) =>
            state.phase == ServerPhase.starting && state.serverPid == null,
      ),
      isTrue,
    );
    expect(
      states.any(
        (state) =>
            state.phase == ServerPhase.starting &&
            state.serverPid == process.pid,
      ),
      isTrue,
    );
    expect(states.last.phase, ServerPhase.running);

    final state = created.state;
    expect(state.phase, ServerPhase.running);
    expect(state.health, ServerHealth.ok);
    expect(state.serverPid, process.pid);
    expect(state.supervisorPid, pid);
    expect(state.host, '127.0.0.1');
    expect(state.port, 18080);
    expect(state.modelPath, modelPath);
    expect(state.binaryPath, '/opt/llama-server');
    expect(state.binaryVersion, 'b11960');
    expect(state.startedAtEpochMs, 0);
    expect(state.lastExitCode, isNull);

    expect(launcher.executable, '/opt/llama-server');
    expect(
      launcher.arguments,
      containsAllInOrder(<String>[
        '-m',
        modelPath,
        '--host',
        '127.0.0.1',
        '--port',
        '18080',
        '--metrics',
        '--slots',
      ]),
    );
    expect(launcher.arguments, containsAllInOrder(<String>['-lm', 'mmap']));
    expect(stateRepository.saved.map((entry) => entry.phase), [
      ServerPhase.starting,
      ServerPhase.starting,
      ServerPhase.running,
    ]);
  });

  test('uses the legacy load flags for builds before 10875', () async {
    binaryLocator.info = _binary(buildNumber: 5000);
    final created = create();

    answerHealthy();
    await created.start(_config(modelPath, mlock: true));

    expect(launcher.arguments, contains('--mlock'));
    expect(launcher.arguments, isNot(contains('-lm')));
  });

  test('uses load mode when the build number is unknown', () async {
    binaryLocator.info = _binary(buildNumber: null);
    final created = create();

    answerHealthy();
    await created.start(_config(modelPath));

    expect(launcher.arguments, contains('-lm'));
  });

  test('rejects an invalid configuration before launching', () async {
    final created = create();

    await expectLater(
      created.start(_config('')),
      throwsServerFailure(ServerFailureCode.invalidConfig),
    );
    expect(launcher.calls, 0);
  });

  test('reports a binary locator failure and does not launch', () async {
    binaryLocator.error = ServerException(
      ServerFailure(
        (b) => b
          ..code = ServerFailureCode.binaryNotFound
          ..message = 'llama-server not found',
      ),
    );
    final created = create();

    await expectLater(
      created.start(_config(modelPath)),
      throwsServerFailure(ServerFailureCode.binaryNotFound),
    );
    expect(launcher.calls, 0);
  });

  test('reports a missing model file and does not launch', () async {
    final created = create();
    final missing = p.join(directory.path, 'missing.gguf');

    await expectLater(
      created.start(_config(missing)),
      throwsServerFailure(ServerFailureCode.modelNotFound),
    );
    expect(launcher.calls, 0);
  });

  test('reports a busy port and does not launch', () async {
    portProbe.available = false;
    final created = create();

    await expectLater(
      created.start(_config(modelPath)),
      throwsA(
        isA<ServerException>()
            .having(
              (error) => error.failure.code,
              'failure.code',
              ServerFailureCode.portInUse,
            )
            .having(
              (error) => error.failure.message,
              'failure.message',
              contains('127.0.0.1:18080'),
            ),
      ),
    );
    expect(launcher.calls, 0);
  });

  test('fails when the child exits before it is ready', () async {
    httpClient.addResponse('/health', Exception('connection refused'));

    // The delay is the only hook that runs after the output listeners are
    // attached, so the child exits from inside it.
    final failing = LlamaServerSupervisor(
      launcher: launcher,
      httpClient: httpClient,
      portProbe: portProbe,
      binaryLocator: binaryLocator,
      stateRepository: stateRepository,
      logStore: logStore,
      validator: const ServerConfigValidator(),
      tuning: _tuning,
      clock: () => now,
      delay: (duration) async {
        now += duration.inMilliseconds;
        if (!process.hasExited) {
          process.writeStderr('error: failed to load model');
          await Future<void>.delayed(Duration.zero);
          process.exit(3);
        }
      },
    );
    supervisor = failing;

    await expectLater(
      failing.start(_config(modelPath)),
      throwsServerFailure(ServerFailureCode.processExited),
    );

    expect(failing.state.phase, ServerPhase.failed);
    expect(failing.state.lastExitCode, 3);
    expect(failing.state.serverPid, isNull);
    expect(failing.state.failure?.message, contains('exit code 3'));
    expect(failing.state.failure?.details, contains('failed to load model'));
  });

  test('reports portInUse when stderr reports a bind failure', () async {
    httpClient.addResponse('/health', Exception('connection refused'));
    final failing = LlamaServerSupervisor(
      launcher: launcher,
      httpClient: httpClient,
      portProbe: portProbe,
      binaryLocator: binaryLocator,
      stateRepository: stateRepository,
      logStore: logStore,
      validator: const ServerConfigValidator(),
      tuning: _tuning,
      clock: () => now,
      delay: (duration) async {
        now += duration.inMilliseconds;
        if (!process.hasExited) {
          process.writeStderr('error: address already in use');
          await Future<void>.delayed(Duration.zero);
          process.exit(1);
        }
      },
    );
    supervisor = failing;

    await expectLater(
      failing.start(_config(modelPath)),
      throwsServerFailure(ServerFailureCode.portInUse),
    );

    expect(failing.state.failure?.code, ServerFailureCode.portInUse);
    expect(failing.state.failure?.message, contains('127.0.0.1:18080'));
  });

  test(
    'kills the child gracefully then forcibly on a readiness timeout',
    () async {
      httpClient.addResponse('/health', Exception('connection refused'));
      process
        ..exitOnGraceful = false
        ..exitOnForce = true;
      final created = create();

      await expectLater(
        created.start(_config(modelPath)),
        throwsServerFailure(ServerFailureCode.startupTimeout),
      );

      expect(process.kills, [ServerKillMode.graceful, ServerKillMode.force]);
      expect(created.state.phase, ServerPhase.failed);
      expect(created.state.health, ServerHealth.unreachable);
      expect(created.state.serverPid, isNull);
      expect(created.state.failure?.code, ServerFailureCode.startupTimeout);
    },
  );

  test('keeps polling while health answers 503 and starts on ok', () async {
    httpClient.addResponse(
      '/health',
      const ServerHttpResponse(statusCode: 503, body: '{"status":"loading"}'),
    );
    httpClient.addResponse('/health', _healthy);
    httpClient.addResponse(
      '/props',
      const ServerHttpResponse(statusCode: 200, body: '{}'),
    );
    final created = create();

    await created.start(_config(modelPath));

    expect(created.state.phase, ServerPhase.running);
    expect(created.state.health, ServerHealth.ok);
    expect(httpClient.paths.where((path) => path == '/health').length, 2);
  });

  test('marks a running server failed when the child exits', () async {
    final created = create();
    await startHealthy(created);

    final failed = created.states.firstWhere(
      (state) => state.phase == ServerPhase.failed,
    );
    process.exit(7);
    final state = await failed;

    expect(state.lastExitCode, 7);
    expect(state.serverPid, isNull);
    expect(state.failure?.code, ServerFailureCode.processExited);
    expect(created.state.phase, ServerPhase.failed);
    expect(created.state.failure?.message, contains('exit code 7'));
  });

  test('stops gracefully and keeps the exit code', () async {
    process
      ..exitOnGraceful = true
      ..exitCodeValue = 0;
    final created = create();
    await startHealthy(created);

    final states = <ServerState>[];
    final subscription = created.states.listen(states.add);
    addTearDown(subscription.cancel);

    await created.stop();
    await pumpEventQueue();

    expect(process.kills, [ServerKillMode.graceful]);
    expect(states.map((state) => state.phase), [
      ServerPhase.stopping,
      ServerPhase.stopped,
    ]);
    expect(created.state.phase, ServerPhase.stopped);
    expect(created.state.serverPid, isNull);
    expect(created.state.supervisorPid, isNull);
    expect(created.state.lastExitCode, 0);
    expect(stateRepository.saved.last.phase, ServerPhase.stopped);
    expect(stateRepository.saved.last.serverPid, isNull);
    expect(stateRepository.saved.last.supervisorPid, isNull);
  });

  test('escalates to a force kill when graceful stop hangs', () async {
    process
      ..exitOnGraceful = false
      ..exitOnForce = true;
    final created = create();
    await startHealthy(created);

    await created.stop();

    expect(process.kills, [ServerKillMode.graceful, ServerKillMode.force]);
    expect(created.state.phase, ServerPhase.stopped);
  });

  test('stop when nothing runs is a no-op', () async {
    final created = create();
    final states = <ServerState>[];
    final subscription = created.states.listen(states.add);
    addTearDown(subscription.cancel);

    await created.stop();
    await pumpEventQueue();

    expect(states, isEmpty);
    expect(created.state.phase, ServerPhase.stopped);
  });

  test('rejects a second start while running', () async {
    final created = create();
    await startHealthy(created);

    await expectLater(
      created.start(_config(modelPath)),
      throwsA(
        isA<ServerException>()
            .having(
              (error) => error.failure.code,
              'failure.code',
              ServerFailureCode.invalidConfig,
            )
            .having(
              (error) => error.failure.message,
              'failure.message',
              contains('already running'),
            ),
      ),
    );
    expect(launcher.calls, 1);
  });

  test('rejects a second start while starting', () async {
    launcher.gate = Completer<void>();
    final created = create();

    final first = created.start(_config(modelPath));
    await pumpEventQueue();

    await expectLater(
      created.start(_config(modelPath)),
      throwsServerFailure(ServerFailureCode.invalidConfig),
    );

    launcher.gate?.complete();
    answerHealthy();
    await first;
  });

  test('samples metrics while running', () async {
    final monitor = _FakeMonitor(value: ServerMetrics.empty(1234));
    final created = create(monitor: monitor, tuning: _metricsTuning);
    final samples = <ServerMetrics>[];
    final subscription = created.metrics.listen(samples.add);
    addTearDown(subscription.cancel);

    final sampled = created.metrics.first;
    await startHealthy(created);
    final metrics = await sampled.timeout(const Duration(seconds: 1));

    expect(metrics.capturedAtEpochMs, 1234);
    expect(monitor.calls, greaterThanOrEqualTo(1));
    expect(created.state.phase, ServerPhase.running);
  });

  test('a failing metrics sample degrades health but keeps running', () async {
    final monitor = _FakeMonitor(
      error: ServerException(
        ServerFailure(
          (b) => b
            ..code = ServerFailureCode.httpError
            ..message = 'metrics unavailable',
        ),
      ),
    );
    final created = create(monitor: monitor, tuning: _metricsTuning);
    final degraded = created.states.firstWhere(
      (state) => state.health == ServerHealth.degraded,
    );

    await startHealthy(created);
    await degraded.timeout(const Duration(seconds: 1));

    expect(created.state.phase, ServerPhase.running);
    expect(created.state.health, ServerHealth.degraded);
  });

  test('a stale exit watcher cannot poison the next run', () async {
    final processA = process..exitOnGraceful = false;
    final created = create();
    await startHealthy(created);

    // Stop A while its process never exits: the supervisor keeps it for a
    // later signal, which leaves the old exit watcher pending.
    await expectLater(
      created.stop(),
      throwsServerFailure(ServerFailureCode.processExited),
    );
    expect(created.state.phase, ServerPhase.failed);

    final processB = FakeServerProcess(pid: 9876)..exitOnGraceful = true;
    addTearDown(processB.close);
    launcher.process = processB;
    await startHealthy(created);
    expect(created.state.phase, ServerPhase.running);
    expect(created.state.serverPid, processB.pid);

    processA.exit(9);
    await pumpEventQueue();

    expect(created.state.phase, ServerPhase.running);
    expect(created.state.serverPid, processB.pid);
    expect(processB.hasExited, isFalse);
    expect(processB.kills, isEmpty);

    await created.stop();
    expect(processB.kills, [ServerKillMode.graceful]);
    expect(processB.hasExited, isTrue);
  });

  test('stop during a launch before the spawn leaves no process', () async {
    launcher.gate = Completer<void>();
    process.exitOnGraceful = true;
    final created = create();
    final states = <ServerState>[];
    final subscription = created.states.listen(states.add);
    addTearDown(subscription.cancel);

    final starting = created.start(_config(modelPath));
    await waitUntil(() => launcher.calls == 1);
    final stopping = created.stop();
    await pumpEventQueue();
    launcher.gate?.complete();
    await starting;
    await stopping;

    expect(states.any((state) => state.phase == ServerPhase.running), isFalse);
    expect(created.state.phase, ServerPhase.stopped);
    expect(created.state.serverPid, isNull);
    expect(process.kills, isNotEmpty);
  });

  test('stop while waiting for readiness never publishes running', () async {
    final health = Completer<ServerHttpResponse>();
    httpClient.addResponse('/health', health.future);
    process.exitOnGraceful = true;
    final created = create();
    final states = <ServerState>[];
    final subscription = created.states.listen(states.add);
    addTearDown(subscription.cancel);

    final starting = created.start(_config(modelPath));
    await waitUntil(() => httpClient.paths.contains('/health'));
    final stopping = created.stop();
    await pumpEventQueue();
    health.complete(_healthy);
    await starting;
    await stopping;

    expect(states.any((state) => state.phase == ServerPhase.running), isFalse);
    expect(created.state.phase, ServerPhase.stopped);
    expect(created.state.serverPid, isNull);
    expect(process.kills, contains(ServerKillMode.graceful));
  });

  test('dispose during a start terminates the child and completes', () async {
    final health = Completer<ServerHttpResponse>();
    httpClient.addResponse('/health', health.future);
    process.exitOnGraceful = true;
    final created = create();

    final starting = created.start(_config(modelPath));
    await waitUntil(() => httpClient.paths.contains('/health'));
    final disposing = created.dispose();
    await pumpEventQueue();
    health.complete(_healthy);
    await starting;
    await disposing;

    expect(created.state.phase, ServerPhase.stopped);
    expect(created.state.serverPid, isNull);
    expect(process.kills, contains(ServerKillMode.graceful));
    expect(httpClient.closed, isTrue);
  });

  test(
    'stop fails when the child survives SIGKILL and keeps its pid',
    () async {
      process.exitOnGraceful = false;
      final created = create();
      await startHealthy(created);

      await expectLater(
        created.stop(),
        throwsA(
          isA<ServerException>()
              .having(
                (error) => error.failure.code,
                'failure.code',
                ServerFailureCode.processExited,
              )
              .having(
                (error) => error.failure.message,
                'failure.message',
                contains('did not exit after SIGKILL'),
              ),
        ),
      );

      expect(created.state.phase, ServerPhase.failed);
      expect(created.state.serverPid, process.pid);
      expect(created.state.supervisorPid, isNull);
    },
  );

  test('redacts the api key from logs and failure details', () async {
    httpClient.addResponse('/health', _healthy);
    httpClient.addResponse(
      '/props',
      const ServerHttpResponse(statusCode: 200, body: '{}'),
    );
    final created = create();
    await created.start(_config(modelPath, apiKey: 'secret-key'));

    process.writeStdout('request with secret-key accepted');
    await pumpEventQueue();

    expect(logStore.recent.last.line, contains('***'));
    expect(logStore.recent.last.line, isNot(contains('secret-key')));

    final failed = created.states.firstWhere(
      (state) => state.phase == ServerPhase.failed,
    );
    process.exit(1);
    final state = await failed;

    expect(state.failure?.details, contains('***'));
    expect(state.failure?.details, isNot(contains('secret-key')));
  });

  test('testConnection requires a status ok body', () async {
    httpClient.addResponse(
      '/health',
      const ServerHttpResponse(statusCode: 200, body: '{"error":"ok"}'),
    );
    final created = create();

    final result = await created.testConnection(_config(modelPath));

    expect(result.ok, isFalse);
    expect(result.message, 'HTTP 200');
  });

  test('testConnection tolerates whitespace around status', () async {
    httpClient.addResponse(
      '/health',
      const ServerHttpResponse(statusCode: 200, body: '{ "status" : "ok" }'),
    );
    final created = create();

    final result = await created.testConnection(_config(modelPath));

    expect(result.ok, isTrue);
    expect(result.message, 'ok');
  });

  test('testConnection sends the api key and reports ok', () async {
    httpClient.addResponse('/health', _healthy);
    httpClient.addResponse(
      '/v1/models',
      const ServerHttpResponse(statusCode: 200, body: '{"data":[]}'),
    );
    final created = create();

    final result = await created.testConnection(
      _config(modelPath, apiKey: 'secret'),
    );

    expect(result.ok, isTrue);
    expect(result.message, 'ok');
    expect(result.latencyMs, greaterThanOrEqualTo(0));
    final models = httpClient.requests.firstWhere(
      (request) => request.uri.path == '/v1/models',
    );
    expect(models.headers['Authorization'], 'Bearer secret');
  });

  test('testConnection reports unauthorized', () async {
    httpClient.addResponse(
      '/health',
      const ServerHttpResponse(statusCode: 401, body: ''),
    );
    final created = create();

    final result = await created.testConnection(_config(modelPath));

    expect(result.ok, isFalse);
    expect(result.message, 'unauthorized');
  });

  test('testConnection never throws on a refused connection', () async {
    final created = create();

    final result = await created.testConnection(_config(modelPath));

    expect(result.ok, isFalse);
    expect(result.message, 'unreachable');
  });

  test('a failing state repository does not abort the start', () async {
    stateRepository.saveError = StateError('disk full');
    final created = create();

    await startHealthy(created);
    await pumpEventQueue();

    expect(created.state.phase, ServerPhase.running);
    final entries = logStore.recent;
    expect(
      entries.any(
        (entry) =>
            entry.stream == ServerLogStream.supervisor &&
            entry.line.contains('could not write server state'),
      ),
      isTrue,
    );
  });

  test('locateBinary delegates to the locator', () async {
    final created = create();

    final info = await created.locateBinary(_config(modelPath));

    expect(info.path, '/opt/llama-server');
    expect(binaryLocator.configs, hasLength(1));
  });

  test('dispose stops the server and is idempotent', () async {
    process.exitOnGraceful = true;
    final created = create();
    await startHealthy(created);

    await created.dispose();
    await created.dispose();

    expect(created.state.phase, ServerPhase.stopped);
    expect(process.kills, contains(ServerKillMode.graceful));
    expect(httpClient.closed, isTrue);
  });
}
