import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/app/app.dart';
import 'package:llama_pulse/app/bootstrap.dart';
import 'package:llama_pulse/app/di/injection.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_bloc.dart';
import 'package:llama_pulse/presentation/runtime/bloc/runtime_bloc.dart';
import 'package:llama_pulse/presentation/server/bloc/server_bloc.dart';
import 'package:llama_pulse/presentation/server/bloc/server_event.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../support/fake_llama_engine.dart';
import '../../support/fake_runtime.dart';
import '../../support/fake_server_controller.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('llama_pulse_di_test');
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
      engine: FakeLlamaEngine(),
    );
  });

  tearDown(() async {
    if (getIt.isRegistered<LlamaEngine>()) {
      await getIt<LlamaEngine>().dispose();
    }
    await getIt.reset();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('registers the app dependencies', () async {
    expect(getIt<AppPaths>().configDirectory, tempDir.path);
    expect(getIt<ConfigStore>(), isA<InMemoryConfigStore>());
    expect(getIt<ModelParamsRepository>(), isA<YamlModelParamsRepository>());
    expect(getIt<LlamaEngine>(), isA<FakeLlamaEngine>());
    expect(getIt.isRegistered<ModelParamsValidator>(), isTrue);
    expect(getIt.isRegistered<ModelFileScanner>(), isTrue);
    expect(getIt.isRegistered<LoadModelParams>(), isTrue);
    expect(getIt.isRegistered<SaveModelParams>(), isTrue);
    expect(getIt.isRegistered<ListModels>(), isTrue);
    expect(getIt.isRegistered<InspectModel>(), isTrue);
    expect(getIt.isRegistered<InferenceBloc>(), isTrue);
    expect(getIt<ServerConfigValidator>(), isA<ServerConfigValidator>());
    expect(getIt<ServerConfigRepository>(), isA<YamlServerConfigRepository>());
    expect(getIt<ServerStateRepository>(), isA<YamlServerStateRepository>());
    expect(getIt<ServerLogStore>(), isA<ServerLogStore>());
    expect(getIt.isRegistered<ServerController>(), isTrue);
    expect(getIt.isRegistered<ServerBloc>(), isTrue);
    expect(getIt<RuntimeStore>(), isA<YamlRuntimeStore>());
    expect(getIt<RuntimeProbe>(), isA<DartRuntimeProbe>());
    expect(getIt<RuntimeInstallService>(), isA<RuntimeInstaller>());
    expect(getIt.isRegistered<RuntimeBloc>(), isTrue);
    final InferenceBloc bloc = getIt<InferenceBloc>();
    expect(bloc, isA<InferenceBloc>());
    await bloc.close();
    await getIt<RuntimeBloc>().close();
  });

  test(
    'runtime overrides replace the probe, the store and the installer',
    () async {
      await getIt.reset();
      final FakeRuntimeStore store = FakeRuntimeStore();
      final RuntimeRelease release = testRuntimeRelease();
      final FakeRuntimeInstallService installer = FakeRuntimeInstallService(
        release: release,
        store: store,
      );
      await configureDependencies(
        paths: AppPaths(configDirectory: tempDir.path),
        configStore: InMemoryConfigStore(),
        engine: FakeLlamaEngine(),
        runtimeProbe: FakeRuntimeProbe(),
        runtimeStore: store,
        runtimeRelease: release,
        runtimeInstallService: installer,
      );

      expect(getIt<RuntimeStore>(), same(store));
      expect(getIt<RuntimeProbe>(), isA<FakeRuntimeProbe>());
      expect(getIt<RuntimeInstallService>(), same(installer));

      final RuntimeBloc bloc = getIt<RuntimeBloc>();
      await bloc.close();
    },
  );

  test('loads defaults from an empty store', () async {
    final ModelParams params = await getIt<LoadModelParams>()();

    expect(params, ModelParams.defaults());
  });

  test('round-trips saved parameters through the store', () async {
    final ModelParams saved = ModelParams.defaults().copyWith(
      modelPath: '/models/a.gguf',
      threads: 8,
      maxTokens: 512,
    );

    await getIt<SaveModelParams>()(saved);
    final ModelParams reloaded = await getIt<LoadModelParams>()();

    expect(reloaded, saved);
  });

  test('registers the native worker engine by default', () async {
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
    );

    final LlamaEngine engine = getIt<LlamaEngine>();
    expect(engine, isA<WorkerLlamaEngine>());
    expect((engine as WorkerLlamaEngine).useStubSession, isFalse);
    // Registration is side-effect free: dispose before any call spawns nothing.
    await engine.dispose();

    final InferenceBloc bloc = getIt<InferenceBloc>();
    expect(bloc, isA<InferenceBloc>());
    await bloc.close();
  });

  test('registers the worker stub engine on request', () async {
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
      useStubEngine: true,
    );

    final LlamaEngine engine = getIt<LlamaEngine>();
    expect(engine, isA<WorkerLlamaEngine>());
    expect((engine as WorkerLlamaEngine).useStubSession, isTrue);
    // The worker is spawned lazily, so disposing before any call is safe and
    // leaves no isolate behind for the next test.
    await engine.dispose();
    await getIt.reset();
  });

  test('an explicit engine wins over the stub flag', () async {
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
      engine: FakeLlamaEngine(),
      useStubEngine: true,
    );

    expect(getIt<LlamaEngine>(), isA<FakeLlamaEngine>());
  });

  test('registers the production supervisor by default', () async {
    expect(tempDir.listSync(), isEmpty);
    final ServerController controller = getIt<ServerController>();

    expect(controller, isA<LlamaServerSupervisor>());
    expect(controller.state.phase, ServerPhase.stopped);
    // Construction and disposal touch no process and no file; dispose is
    // idempotent.
    await controller.dispose();
    await controller.dispose();
    expect(tempDir.listSync(), isEmpty);
  });

  test('registers the stub server on request', () async {
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
      useStubServer: true,
    );

    final ServerController controller = getIt<ServerController>();
    expect(controller, isA<StubServerController>());
    await controller.dispose();
  });

  test('an explicit server controller wins over the stub flag', () async {
    final FakeServerController fake = FakeServerController();
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
      serverController: fake,
      useStubServer: true,
    );

    expect(getIt<ServerController>(), same(fake));
    await fake.dispose();
  });

  test('ServerBloc resolves over the injected controller', () async {
    final FakeServerController fake = FakeServerController();
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
      engine: FakeLlamaEngine(),
      serverController: fake,
    );

    final ServerBloc bloc = getIt<ServerBloc>();
    expect(bloc.state.serverState, fake.state);
    bloc.add(const ServerDashboardStarted());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await bloc.close();

    expect(fake.disposeCalls, 0);
    await fake.dispose();
  });

  test('disposeAppDependencies disposes the registered controller', () async {
    final FakeServerController fake = FakeServerController();
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
      serverController: fake,
    );

    await disposeAppDependencies();

    expect(fake.disposeCalls, 1);
  });

  test('disposeAppDependencies is safe when already disposed', () async {
    final FakeServerController fake = FakeServerController();
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
      serverController: fake,
    );

    await fake.dispose();
    await expectLater(disposeAppDependencies(), completes);

    // And safe once the registrations are gone, as in a second exit request.
    await getIt.reset();
    await expectLater(disposeAppDependencies(), completes);
  });

  test('bootstrap forwards the compile-time demo flags to the app', () {
    final LlamaPulseApp app = buildRootApp();

    expect(app.demoEngine, stubEngineEnabled);
    expect(app.demoServer, stubServerEnabled);
    // Tests run without `--dart-define`, so the release-safe defaults hold.
    expect(stubServerEnabled, isFalse);
  });

  test('the signal guard follows the platform', () {
    expect(supportsTerminationSignals, !Platform.isWindows);
  });

  test('handleTerminationSignal disposes once and is re-entry safe', () async {
    final FakeServerController fake = FakeServerController();
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
      serverController: fake,
    );
    final List<int> exitCodes = <int>[];

    await handleTerminationSignal(
      ProcessSignal.sigterm,
      exitProcess: exitCodes.add,
    );

    expect(exitCodes, <int>[0]);
    expect(fake.disposeCalls, 1);

    // A second signal exits immediately instead of disposing again.
    await handleTerminationSignal(
      ProcessSignal.sigint,
      exitProcess: exitCodes.add,
    );

    expect(exitCodes, <int>[0, 130]);
    expect(fake.disposeCalls, 1);
  });
}
