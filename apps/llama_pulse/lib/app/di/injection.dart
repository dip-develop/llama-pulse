import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../presentation/inference/bloc/inference_bloc.dart';
import 'injection.config.dart';

/// Service locator shared by the whole app.
final GetIt getIt = GetIt.instance;

/// Registers every dependency the app needs.
///
/// Core types are wired by hand: `injectable` only generates code for this
/// package, while `llama_pulse_core` deliberately stays DI-framework free.
@InjectableInit()
Future<void> configureDependencies({
  LlamaEngine? engine,
  ConfigStore? configStore,
  AppPaths? paths,
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
    );
  if (engine != null) {
    getIt.registerLazySingleton<LlamaEngine>(() => engine);
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
    ..init();
}
