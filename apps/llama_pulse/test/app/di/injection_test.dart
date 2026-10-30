import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/app/di/injection.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_bloc.dart';
import 'package:llama_pulse/presentation/server/bloc/server_bloc.dart';
import 'package:llama_pulse/presentation/server/bloc/server_event.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../support/fake_llama_engine.dart';
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
    final InferenceBloc bloc = getIt<InferenceBloc>();
    expect(bloc, isA<InferenceBloc>());
    await bloc.close();
  });

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

  test('does not register an engine when none is supplied', () async {
    await getIt.reset();
    await configureDependencies(
      paths: AppPaths(configDirectory: tempDir.path),
      configStore: InMemoryConfigStore(),
    );

    expect(getIt.isRegistered<LlamaEngine>(), isFalse);
    expect(() => getIt<LlamaEngine>(), throwsA(isA<StateError>()));

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

    expect(getIt<LlamaEngine>(), isA<WorkerLlamaEngine>());
    // The worker is spawned lazily, so disposing before any call is safe and
    // leaves no isolate behind for the next test.
    await getIt<LlamaEngine>().dispose();
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
}
