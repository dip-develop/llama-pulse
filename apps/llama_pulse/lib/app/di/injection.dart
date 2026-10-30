import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../presentation/inference/bloc/inference_bloc.dart';
import '../../../presentation/server/bloc/server_bloc.dart';
import 'injection.config.dart';

/// Service locator shared by the whole app.
final GetIt getIt = GetIt.instance;

/// Whether the stub engine is opted into at compile time.
///
/// The flag is a `bool.fromEnvironment`, so a release build can never silently
/// emit synthetic tokens: it requires `--dart-define` at build time.
const bool _stubEngineEnabled = bool.fromEnvironment('LLAMAPULSE_STUB_ENGINE');

/// Whether the synthetic server controller is opted into at compile time.
const bool _stubServerEnabled = bool.fromEnvironment('LLAMAPULSE_STUB_SERVER');

/// Registers every dependency the app needs.
///
/// Core types are wired by hand: `injectable` only generates code for this
/// package, while `llama_pulse_core` deliberately stays DI-framework free.
///
/// An explicit [engine] always wins; otherwise [useStubEngine] (or the
/// compile-time flag) selects the synthetic [WorkerLlamaEngine].
///
/// Likewise an explicit [serverController] wins; otherwise [useStubServer] (or
/// the compile-time flag) selects [StubServerController], and a production
/// build registers [LlamaServerSupervisor].
@InjectableInit()
Future<void> configureDependencies({
  LlamaEngine? engine,
  ServerController? serverController,
  ConfigStore? configStore,
  AppPaths? paths,
  bool? useStubEngine,
  bool? useStubServer,
}) async {
  final AppPaths resolvedPaths = paths ?? AppPaths.resolve();
  getIt
    ..registerSingleton<AppPaths>(resolvedPaths)
    ..registerSingleton<Serializers>(serializers)
    ..registerFactory<ConfigStore>(
      () =>
          configStore ??
          YamlFileConfigStore(directory: resolvedPaths.configDirectory),
    )
    ..registerLazySingleton<ModelParamsValidator>(ModelParamsValidator.new)
    ..registerLazySingleton<ModelParamsRepository>(
      () => YamlModelParamsRepository(
        store: getIt<ConfigStore>(),
        serializers: getIt<Serializers>(),
        validator: getIt<ModelParamsValidator>(),
      ),
    )
    ..registerLazySingleton<ModelFileScanner>(ModelFileScanner.new)
    ..registerLazySingleton<LoadModelParams>(
      () => LoadModelParams(getIt<ModelParamsRepository>()),
    )
    ..registerLazySingleton<SaveModelParams>(
      () => SaveModelParams(
        getIt<ModelParamsRepository>(),
        getIt<ModelParamsValidator>(),
      ),
    )
    ..registerLazySingleton<ListModels>(
      () => ListModels(getIt<ModelFileScanner>()),
    )
    ..registerLazySingleton<InspectModel>(
      () => InspectModel(getIt<ModelFileScanner>()),
    )
    ..registerLazySingleton<ServerConfigValidator>(ServerConfigValidator.new)
    ..registerLazySingleton<ServerConfigRepository>(
      () => YamlServerConfigRepository(
        store: getIt<ConfigStore>(),
        serializers: getIt<Serializers>(),
        validator: getIt<ServerConfigValidator>(),
      ),
    )
    ..registerLazySingleton<ServerStateRepository>(
      () => YamlServerStateRepository(
        store: getIt<ConfigStore>(),
        serializers: getIt<Serializers>(),
      ),
    )
    ..registerLazySingleton<ServerLogStore>(
      () => ServerLogStore(filePath: resolvedPaths.serverLogFile),
    );
  if (engine != null) {
    getIt.registerLazySingleton<LlamaEngine>(() => engine);
  } else if (useStubEngine ?? _stubEngineEnabled) {
    getIt.registerLazySingleton<LlamaEngine>(
      () => WorkerLlamaEngine(useStubSession: true),
    );
  }
  if (serverController != null) {
    getIt.registerLazySingleton<ServerController>(() => serverController);
  } else if (useStubServer ?? _stubServerEnabled) {
    getIt.registerLazySingleton<ServerController>(StubServerController.new);
  } else {
    getIt.registerLazySingleton<ServerController>(
      () => LlamaServerSupervisor.production(
        paths: resolvedPaths,
        configStore: getIt<ConfigStore>(),
      ),
    );
  }
  getIt
    ..registerFactory<InferenceBloc>(
      () => InferenceBloc(
        getIt<LoadModelParams>(),
        getIt<SaveModelParams>(),
        getIt<ModelParamsValidator>(),
        getIt.isRegistered<LlamaEngine>() ? getIt<LlamaEngine>() : null,
      ),
    )
    ..registerFactory<ServerBloc>(
      () => ServerBloc(
        getIt<ServerConfigRepository>(),
        getIt<ServerConfigValidator>(),
        getIt<ServerController>(),
      ),
    )
    ..init();
}
