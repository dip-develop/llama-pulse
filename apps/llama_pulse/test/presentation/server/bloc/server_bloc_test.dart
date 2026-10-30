import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/presentation/server/bloc/server_bloc.dart';
import 'package:llama_pulse/presentation/server/bloc/server_dashboard_state.dart';
import 'package:llama_pulse/presentation/server/bloc/server_event.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../support/fake_server_controller.dart';
import '../../../support/fake_server_state_repository.dart';

const ServerConfigValidator _validator = ServerConfigValidator();

ServerConfig _validConfig() =>
    ServerConfig.defaults().copyWith(modelPath: '/models/model.gguf');

ServerConfig _storedConfig() => _validConfig().copyWith(port: 9090, threads: 8);

ServerState _state(ServerPhase phase) => ServerState(
  (b) => b
    ..phase = phase
    ..health = ServerHealth.ok
    ..host = '127.0.0.1'
    ..port = 8080
    ..modelPath = '/models/model.gguf'
    ..binaryPath = '/opt/llama-server'
    ..updatedAtEpochMs = 0,
);

ServerMetrics _metrics(int capturedAtEpochMs) =>
    ServerMetrics.empty(capturedAtEpochMs);

ServerLogEntry _logEntry(int sequence) => ServerLogEntry(
  (b) => b
    ..sequence = sequence
    ..timestampEpochMs = sequence
    ..stream = ServerLogStream.supervisor
    ..line = 'line $sequence',
);

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 400; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('condition was not met');
}

void main() {
  late InMemoryConfigStore store;
  late YamlServerConfigRepository repository;
  late FakeServerController controller;
  late FakeServerStateRepository stateRepository;

  setUp(() {
    store = InMemoryConfigStore();
    repository = YamlServerConfigRepository(
      store: store,
      serializers: serializers,
      validator: _validator,
    );
    controller = FakeServerController();
    stateRepository = FakeServerStateRepository();
  });

  ServerBloc buildBloc() =>
      ServerBloc(repository, _validator, controller, stateRepository);

  Future<ServerBloc> startedBloc() async {
    final ServerBloc bloc = buildBloc();
    bloc.add(const ServerDashboardStarted());
    await _waitUntil(() => bloc.state.binaryInfo != null);
    return bloc;
  }

  test('starts from the controller state', () async {
    controller = FakeServerController(state: _state(ServerPhase.running));
    final ServerBloc bloc = buildBloc();

    expect(bloc.state.serverState, _state(ServerPhase.running));
    expect(bloc.state.config, ServerConfig.defaults());
    expect(bloc.state.metricsHistory, isEmpty);
    expect(bloc.state.logs, isEmpty);
    expect(bloc.state.phase, ServerPhase.running);
    expect(bloc.state.canStop, isTrue);
    expect(bloc.state.canStart, isFalse);
    expect(bloc.state.endpoint, 'http://127.0.0.1:8080/v1');
    await bloc.close();
  });

  test('Started loads the stored config and locates the binary', () async {
    await store.write(
      ConfigNames.server,
      repository.toDocument(_storedConfig()),
    );
    final ServerBloc bloc = await startedBloc();

    expect(bloc.state.config, _storedConfig());
    expect(bloc.state.binaryInfo?.path, '/opt/llama-server');
    expect(bloc.state.binaryInfo?.supported, isTrue);
    expect(bloc.state.dirty, isFalse);
    expect(bloc.state.failure, isNull);
    expect(controller.locateBinaryCalls, 1);
    expect(controller.startedConfigs, isEmpty);
    await bloc.close();
  });

  test('Started falls back to defaults and reports a load failure', () async {
    final ServerBloc bloc = ServerBloc(
      _ThrowingConfigRepository(),
      _validator,
      controller,
      stateRepository,
    );
    bloc.add(const ServerDashboardStarted());
    await _waitUntil(() => bloc.state.binaryInfo != null);

    expect(bloc.state.config, ServerConfig.defaults());
    expect(bloc.state.failure?.code, ServerFailureCode.unknown);
    expect(bloc.state.failure?.message, contains('Could not load'));
    await bloc.close();
  });

  test('Started surfaces a binary failure without aborting', () async {
    controller.binaryError = ServerException(
      ServerFailure(
        (b) => b
          ..code = ServerFailureCode.binaryNotFound
          ..message = 'llama-server not found',
      ),
    );
    final ServerBloc bloc = buildBloc();
    bloc.add(const ServerDashboardStarted());
    await _waitUntil(() => bloc.state.failure != null);

    expect(bloc.state.failure?.code, ServerFailureCode.binaryNotFound);
    expect(bloc.state.binaryInfo, isNull);
    controller.emitState(_state(ServerPhase.running));
    await _waitUntil(() => bloc.state.phase == ServerPhase.running);
    await bloc.close();
  });

  test('Started subscribes to the controller streams once', () async {
    final ServerBloc bloc = await startedBloc();
    bloc.add(const ServerDashboardStarted());
    await Future<void>.delayed(Duration.zero);

    controller.emitState(_state(ServerPhase.running));
    await _waitUntil(() => bloc.state.phase == ServerPhase.running);
    controller.emitMetrics(_metrics(7));
    await _waitUntil(() => bloc.state.latestMetrics != null);
    controller.emitLog(_logEntry(1));
    await _waitUntil(() => bloc.state.logs.isNotEmpty);

    expect(bloc.state.latestMetrics?.capturedAtEpochMs, 7);
    expect(bloc.state.logs.single.line, 'line 1');
    await bloc.close();
  });

  test('ConfigChanged marks the state dirty without writing', () async {
    final ServerBloc bloc = await startedBloc();
    bloc.add(ServerConfigChanged(_storedConfig()));
    await _waitUntil(() => bloc.state.dirty);

    expect(bloc.state.config, _storedConfig());
    expect(await store.read(ConfigNames.server), isNull);
    await bloc.close();
  });

  test('SaveRequested validates and persists the config', () async {
    final ServerBloc bloc = await startedBloc();
    final Future<ServerDashboardState> saved = bloc.stream.firstWhere(
      (s) => !s.dirty && !s.saving && s.failure == null,
    );
    bloc.add(ServerConfigChanged(_storedConfig()));
    bloc.add(const ServerSaveRequested());
    await saved;

    expect(await repository.load(), _storedConfig());
    expect(bloc.state.dirty, isFalse);
    expect(bloc.state.saving, isFalse);
    expect(bloc.state.failure, isNull);
    await bloc.close();
  });

  test('SaveRequested rejects an invalid port without writing', () async {
    final ServerBloc bloc = await startedBloc();
    bloc.add(ServerConfigChanged(_storedConfig().copyWith(port: 0)));
    bloc.add(const ServerSaveRequested());
    await _waitUntil(() => bloc.state.failure != null);

    expect(bloc.state.failure?.code, ServerFailureCode.invalidConfig);
    expect(bloc.state.failure?.message, contains('port'));
    expect(await store.read(ConfigNames.server), isNull);
    await bloc.close();
  });

  test('ReloadRequested discards edits and clears the dirty flag', () async {
    await store.write(
      ConfigNames.server,
      repository.toDocument(_storedConfig()),
    );
    final ServerBloc bloc = await startedBloc();
    bloc.add(ServerConfigChanged(_validConfig().copyWith(threads: 2)));
    await _waitUntil(() => bloc.state.dirty);

    bloc.add(const ServerReloadRequested());
    await _waitUntil(() => !bloc.state.dirty);

    expect(bloc.state.config, _storedConfig());
    await bloc.close();
  });

  test('StartRequested delegates with the current config', () async {
    final ServerBloc bloc = await startedBloc();
    bloc.add(ServerConfigChanged(_validConfig()));
    bloc.add(const ServerStartRequested());
    await _waitUntil(() => controller.startedConfigs.isNotEmpty);

    expect(controller.startedConfigs.single, _validConfig());
    expect(bloc.state.failure, isNull);
    await bloc.close();
  });

  test('StartRequested rejects an incomplete config', () async {
    final ServerBloc bloc = await startedBloc();
    bloc.add(const ServerStartRequested());
    await _waitUntil(() => bloc.state.failure != null);

    expect(bloc.state.failure?.code, ServerFailureCode.invalidConfig);
    expect(bloc.state.failure?.message, contains('modelPath'));
    expect(controller.startedConfigs, isEmpty);
    await bloc.close();
  });

  test('StartRequested surfaces a ServerException as a failure', () async {
    controller.startFailure = ServerException(
      ServerFailure(
        (b) => b
          ..code = ServerFailureCode.portInUse
          ..message = 'port is busy'
          ..details = 'bind failed',
      ),
    );
    final ServerBloc bloc = await startedBloc();
    bloc.add(ServerConfigChanged(_validConfig()));
    bloc.add(const ServerStartRequested());
    await _waitUntil(() => bloc.state.failure != null);

    expect(bloc.state.failure?.code, ServerFailureCode.portInUse);
    expect(bloc.state.failure?.message, 'port is busy');
    expect(bloc.state.failure?.details, 'bind failed');
    expect(controller.startedConfigs.single, _validConfig());
    await bloc.close();
  });

  test('StopRequested delegates to the controller', () async {
    controller = FakeServerController(state: _state(ServerPhase.running));
    final ServerBloc bloc = await startedBloc();
    bloc.add(const ServerStopRequested());
    await _waitUntil(() => controller.stopCalls == 1);

    expect(controller.stopCalls, 1);
    await bloc.close();
  });

  test('Started seeds a server started outside the app', () async {
    final ServerState recorded = _state(ServerPhase.running).rebuild(
      (b) => b
        ..supervisorPid = 4242
        ..serverPid = 4243
        ..startedAtEpochMs = 1,
    );
    stateRepository.recorded = recorded;
    final ServerBloc bloc = await startedBloc();
    await _waitUntil(() => bloc.state.externalRun);

    expect(bloc.state.serverState, recorded);
    expect(bloc.state.phase, ServerPhase.running);
    expect(bloc.state.canStart, isFalse);
    expect(bloc.state.canStop, isTrue);
    await bloc.close();
  });

  test('StopRequested never stops an externally started server', () async {
    stateRepository.recorded = _state(ServerPhase.running);
    final ServerBloc bloc = await startedBloc();
    await _waitUntil(() => bloc.state.externalRun);

    bloc.add(const ServerStopRequested());
    await _waitUntil(() => bloc.state.failure != null);

    expect(controller.stopCalls, 0);
    expect(bloc.state.failure?.message, contains('llamapulse stop'));
    expect(bloc.state.phase, ServerPhase.running);
    expect(bloc.state.externalRun, isTrue);
    await bloc.close();
  });

  test(
    'a successful local start clears the external run and failure',
    () async {
      stateRepository.recorded = _state(ServerPhase.running);
      final ServerBloc bloc = await startedBloc();
      await _waitUntil(() => bloc.state.externalRun);
      bloc.add(const ServerStopRequested());
      await _waitUntil(() => bloc.state.failure != null);

      bloc.add(ServerConfigChanged(_validConfig()));
      bloc.add(const ServerStartRequested());
      await _waitUntil(() => controller.startedConfigs.isNotEmpty);
      await _waitUntil(
        () => bloc.state.failure == null && !bloc.state.externalRun,
      );

      expect(controller.startedConfigs.single, _validConfig());
      expect(bloc.state.failure, isNull);
      expect(bloc.state.externalRun, isFalse);
      await bloc.close();
    },
  );

  test('StartRequested does not block controller state events', () async {
    final Completer<void> gate = Completer<void>();
    controller.startGate = gate;
    final ServerBloc bloc = await startedBloc();
    bloc.add(ServerConfigChanged(_validConfig()));
    bloc.add(const ServerStartRequested());
    await _waitUntil(() => controller.startedConfigs.isNotEmpty);

    // The start is still in flight, yet the transition reaches the state.
    controller.emitState(_state(ServerPhase.starting));
    await _waitUntil(() => bloc.state.phase == ServerPhase.starting);
    expect(bloc.state.failure, isNull);

    gate.complete();
    for (var turn = 0; turn < 5; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(bloc.state.failure, isNull);
    expect(bloc.state.phase, ServerPhase.starting);
    await bloc.close();
  });

  test('TestConnectionRequested records latency and toggles testing', () async {
    await store.write(
      ConfigNames.server,
      repository.toDocument(_validConfig()),
    );
    controller.probeResult = const ServerProbeResult(
      ok: true,
      latencyMs: 42,
      message: 'ok',
    );
    final ServerBloc bloc = await startedBloc();
    final Future<ServerDashboardState> testing = bloc.stream.firstWhere(
      (s) => s.testingConnection,
    );
    final Future<ServerDashboardState> done = bloc.stream.firstWhere(
      (s) => !s.testingConnection && s.connectionMessage != null,
    );

    bloc.add(ServerConfigChanged(_validConfig()));
    bloc.add(const ServerTestConnectionRequested());

    expect((await testing).testingConnection, isTrue);
    await _waitUntil(() => controller.probedConfigs.isNotEmpty);
    expect(controller.probedConfigs.single, _validConfig());
    final ServerDashboardState result = await done;
    expect(result.testingConnection, isFalse);
    expect(result.connectionLatencyMs, 42);
    expect(result.connectionMessage, 'ok');
    await bloc.close();
  });

  test('caps the metrics history at the 120 newest samples', () async {
    final ServerBloc bloc = await startedBloc();
    for (var i = 0; i < 125; i++) {
      controller.emitMetrics(_metrics(i));
    }
    await _waitUntil(() => bloc.state.latestMetrics?.capturedAtEpochMs == 124);

    expect(bloc.state.metricsHistory.length, ServerBloc.maxMetricsHistory);
    expect(bloc.state.metricsHistory.first.capturedAtEpochMs, 5);
    expect(bloc.state.metricsHistory.last.capturedAtEpochMs, 124);
    await bloc.close();
  });

  test('caps the logs at the 1000 newest lines', () async {
    final ServerBloc bloc = await startedBloc();
    for (var i = 1; i <= 1005; i++) {
      controller.emitLog(_logEntry(i));
    }
    await _waitUntil(
      () => bloc.state.logs.isNotEmpty && bloc.state.logs.last.sequence == 1005,
    );

    expect(bloc.state.logs.length, ServerBloc.maxLogs);
    expect(bloc.state.logs.first.sequence, 6);
    expect(bloc.state.logs.last.sequence, 1005);
    await bloc.close();
  });

  test('ServerLogsCleared empties the log pane', () async {
    final ServerBloc bloc = await startedBloc();
    controller.emitLog(_logEntry(1));
    await _waitUntil(() => bloc.state.logs.isNotEmpty);

    bloc.add(const ServerLogsCleared());
    await _waitUntil(() => bloc.state.logs.isEmpty);

    expect(bloc.state.logs, isEmpty);
    await bloc.close();
  });

  test('StreamEnded sets a failure unless the server is stopped', () async {
    final ServerBloc stoppedBloc = await startedBloc();
    await controller.closeStates();
    for (var turn = 0; turn < 20; turn++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(stoppedBloc.state.phase, ServerPhase.stopped);
    expect(stoppedBloc.state.failure, isNull);
    await stoppedBloc.close();

    controller = FakeServerController(state: _state(ServerPhase.running));
    final ServerBloc runningBloc = await startedBloc();
    await controller.closeStates();
    await _waitUntil(() => runningBloc.state.failure != null);

    expect(runningBloc.state.failure?.code, ServerFailureCode.unknown);
    expect(
      runningBloc.state.failure?.message,
      'the server controller closed its stream',
    );
    await runningBloc.close();
  });

  test(
    'close cancels subscriptions but never disposes the controller',
    () async {
      final ServerBloc bloc = await startedBloc();
      await bloc.close();

      expect(controller.disposeCalls, 0);
      controller.emitState(_state(ServerPhase.running));
      controller.emitMetrics(_metrics(1));
      expect(bloc.isClosed, isTrue);
    },
  );
}

final class _ThrowingConfigRepository implements ServerConfigRepository {
  @override
  Future<ServerConfig> load() async => throw StateError('store is broken');

  @override
  Future<void> save(ServerConfig config) async {}
}
