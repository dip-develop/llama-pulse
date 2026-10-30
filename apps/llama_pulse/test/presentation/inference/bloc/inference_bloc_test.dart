import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_bloc.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_event.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_state.dart';
import 'package:llama_pulse/presentation/inference/bloc/inference_status.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

import '../../../support/scripted_llama_engine.dart';

const ModelParamsValidator _validator = ModelParamsValidator();

ModelParams _validParams() =>
    ModelParams.defaults().copyWith(modelPath: '/models/model.gguf');

ModelParams _storedParams() => _validParams().copyWith(threads: 8);

ModelParams _invalidParams() => _validParams().copyWith(contextSize: 0);

GenerationMetrics _metrics(int generatedTokenCount) => GenerationMetrics(
  (b) => b
    ..promptTokenCount = 10
    ..generatedTokenCount = generatedTokenCount
    ..promptEvalMs = 20
    ..evalMs = 100,
);

InferenceState _readyState() => InferenceState.initial().rebuild(
  (b) => b
    ..status = InferenceStatus.modelReady
    ..params.replace(_validParams())
    ..prompt = 'hello',
);

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('condition was not met');
}

Future<void> _loadReady(InferenceBloc bloc) async {
  bloc.add(InferenceParamsChanged(_validParams()));
  bloc.add(const InferencePromptChanged('hello'));
  bloc.add(const InferenceLoadRequested());
  await _waitUntil(() => bloc.state.status == InferenceStatus.modelReady);
}

void main() {
  late InMemoryConfigStore store;
  late YamlModelParamsRepository repository;
  late LoadModelParams loadParams;
  late SaveModelParams saveParams;
  late ScriptedLlamaEngine engine;

  setUp(() {
    store = InMemoryConfigStore();
    repository = YamlModelParamsRepository(
      store: store,
      serializers: serializers,
      validator: _validator,
    );
    loadParams = LoadModelParams(repository);
    saveParams = SaveModelParams(repository, _validator);
    engine = ScriptedLlamaEngine();
  });

  InferenceBloc buildBloc({LlamaEngine? forEngine}) =>
      InferenceBloc(loadParams, saveParams, _validator, forEngine);

  group('parameters', () {
    blocTest<InferenceBloc, InferenceState>(
      'starts initial and loads the stored parameters',
      setUp: () async {
        await store.write(
          ConfigNames.params,
          repository.toDocument(_storedParams()),
        );
      },
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const InferenceStarted()),
      expect: () => [
        isA<InferenceState>()
            .having((s) => s.status, 'status', InferenceStatus.initial)
            .having((s) => s.params, 'params', _storedParams()),
      ],
    );

    test('keeps a user edit made before the stored load completes', () async {
      final bloc = buildBloc();
      final ModelParams edited = _validParams().copyWith(threads: 12);
      bloc.add(InferenceParamsChanged(edited));
      await _waitUntil(() => bloc.state.params.threads == 12);

      bloc.add(const InferenceStarted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.params.threads, 12);
      await bloc.close();
    });

    blocTest<InferenceBloc, InferenceState>(
      'persists parameters on save',
      build: () => buildBloc(),
      act: (bloc) async {
        bloc.add(InferenceParamsChanged(_storedParams()));
        bloc.add(const InferenceSaveRequested());
      },
      expect: () => [
        isA<InferenceState>().having(
          (s) => s.params,
          'params',
          _storedParams(),
        ),
      ],
      verify: (bloc) async {
        expect(await store.read(ConfigNames.params), isNotNull);
        expect((await loadParams()), _storedParams());
        expect(bloc.state.failure, isNull);
      },
    );

    blocTest<InferenceBloc, InferenceState>(
      'rejects invalid parameters without persisting them',
      build: () => buildBloc(),
      act: (bloc) async {
        bloc.add(InferenceParamsChanged(_invalidParams()));
        bloc.add(const InferenceSaveRequested());
      },
      expect: () => [
        isA<InferenceState>().having(
          (s) => s.params.contextSize,
          'contextSize',
          0,
        ),
        isA<InferenceState>()
            .having(
              (s) => s.failure?.code,
              'failure code',
              InferenceFailureCode.invalidParams,
            )
            .having((s) => s.status, 'status', InferenceStatus.failure),
      ],
      verify: (bloc) async {
        expect(await store.read(ConfigNames.params), isNull);
      },
    );
  });

  group('model loading', () {
    blocTest<InferenceBloc, InferenceState>(
      'reports engineUnavailable when no engine is registered',
      build: () => buildBloc(),
      act: (bloc) async {
        bloc.add(InferenceParamsChanged(_validParams()));
        bloc.add(const InferenceLoadRequested());
      },
      expect: () => [
        isA<InferenceState>().having(
          (s) => s.params.modelPath,
          'modelPath',
          _validParams().modelPath,
        ),
        isA<InferenceState>().having(
          (s) => s.failure?.code,
          'failure code',
          InferenceFailureCode.engineUnavailable,
        ),
      ],
    );

    blocTest<InferenceBloc, InferenceState>(
      'loads the configured model and becomes ready',
      build: () => buildBloc(forEngine: engine),
      act: (bloc) async {
        bloc.add(InferenceParamsChanged(_validParams()));
        bloc.add(const InferenceLoadRequested());
      },
      expect: () => [
        isA<InferenceState>().having((s) => s.params, 'params', _validParams()),
        isA<InferenceState>().having(
          (s) => s.status,
          'status',
          InferenceStatus.loadingModel,
        ),
        isA<InferenceState>()
            .having((s) => s.status, 'status', InferenceStatus.modelReady)
            .having((s) => s.failure, 'failure', isNull),
      ],
      verify: (bloc) {
        expect(engine.loadedParams, [_validParams()]);
      },
    );

    blocTest<InferenceBloc, InferenceState>(
      'maps an engine failure to its code',
      setUp: () {
        engine.loadSucceeds = false;
      },
      build: () => buildBloc(forEngine: engine),
      act: (bloc) async {
        bloc.add(InferenceParamsChanged(_validParams()));
        bloc.add(const InferenceLoadRequested());
      },
      expect: () => [
        isA<InferenceState>().having((s) => s.params, 'params', _validParams()),
        isA<InferenceState>().having(
          (s) => s.status,
          'status',
          InferenceStatus.loadingModel,
        ),
        isA<InferenceState>()
            .having(
              (s) => s.failure?.code,
              'failure code',
              InferenceFailureCode.modelNotFound,
            )
            .having((s) => s.status, 'status', InferenceStatus.failure),
      ],
    );
  });

  group('generation', () {
    blocTest<InferenceBloc, InferenceState>(
      'reports engineUnavailable when no engine is registered',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const InferenceGenerateRequested()),
      expect: () => [
        isA<InferenceState>().having(
          (s) => s.failure?.code,
          'failure code',
          InferenceFailureCode.engineUnavailable,
        ),
      ],
    );

    blocTest<InferenceBloc, InferenceState>(
      'streams tokens, records metrics and completes',
      build: () => buildBloc(forEngine: engine),
      seed: _readyState,
      act: (bloc) async {
        bloc.add(const InferenceGenerateRequested());
        await engine.waitForGenerate();
        final Future<InferenceState> done = bloc.stream.firstWhere(
          (s) => s.status == InferenceStatus.modelReady && s.output.isNotEmpty,
        );
        engine.emitToken('Hel');
        engine.emitToken('lo');
        engine.emitMetrics(_metrics(2));
        engine.complete(_metrics(3));
        await done;
      },
      expect: () => [
        isA<InferenceState>()
            .having((s) => s.status, 'status', InferenceStatus.generating)
            .having((s) => s.activeRequestId, 'activeRequestId', 1)
            .having((s) => s.output, 'output', ''),
        isA<InferenceState>()
            .having((s) => s.output, 'output', 'Hel')
            .having(
              (s) => s.timeToFirstTokenMs,
              'timeToFirstTokenMs',
              isNotNull,
            ),
        isA<InferenceState>().having((s) => s.output, 'output', 'Hello'),
        isA<InferenceState>()
            .having((s) => s.metricsHistory.length, 'metricsHistory length', 1)
            .having(
              (s) => s.latestMetrics?.generatedTokenCount,
              'latest metric',
              2,
            ),
        isA<InferenceState>()
            .having((s) => s.status, 'status', InferenceStatus.modelReady)
            .having((s) => s.activeRequestId, 'activeRequestId', isNull)
            .having((s) => s.output, 'output', 'Hello')
            .having((s) => s.metricsHistory.length, 'metricsHistory length', 2)
            .having(
              (s) => s.latestMetrics?.generatedTokenCount,
              'latest metric',
              3,
            ),
      ],
      verify: (bloc) {
        expect(engine.generatedRequests.single.requestId, 1);
        expect(engine.generatedRequests.single.prompt, 'hello');
      },
    );

    test('rejects invalid parameters before generating', () async {
      final bloc = buildBloc(forEngine: engine);
      await _loadReady(bloc);
      bloc.add(InferenceParamsChanged(_validParams().copyWith(maxTokens: 0)));
      await _waitUntil(() => bloc.state.params.maxTokens == 0);

      bloc.add(const InferenceGenerateRequested());
      await _waitUntil(() => bloc.state.failure != null);

      expect(bloc.state.failure?.code, InferenceFailureCode.invalidParams);
      expect(bloc.state.failure?.message, contains('maxTokens'));
      expect(engine.generatedRequests, isEmpty);
      await bloc.close();
    });

    test('caps the metrics history at the 100 newest reports', () async {
      final bloc = buildBloc(forEngine: engine);
      await _loadReady(bloc);
      bloc.add(const InferenceGenerateRequested());
      await engine.waitForGenerate();
      for (var i = 0; i < 105; i++) {
        engine.emitMetrics(_metrics(i));
      }
      await _waitUntil(
        () => bloc.state.latestMetrics?.generatedTokenCount == 104,
      );

      expect(bloc.state.metricsHistory.length, 100);
      expect(bloc.state.metricsHistory.first.generatedTokenCount, 5);
      expect(bloc.state.metricsHistory.last.generatedTokenCount, 104);
      await bloc.close();
    });

    test('cancels the active request and reports the cancellation', () async {
      final bloc = buildBloc(forEngine: engine);
      await _loadReady(bloc);
      bloc.add(const InferenceGenerateRequested());
      await engine.waitForGenerate();
      engine.emitToken('par');
      await _waitUntil(() => bloc.state.output == 'par');

      bloc.add(const InferenceCancelRequested());
      await _waitUntil(() => bloc.state.status == InferenceStatus.cancelling);
      expect(engine.cancelledRequestIds, [1]);

      engine.cancelled();
      await _waitUntil(() => bloc.state.failure != null);

      expect(bloc.state.status, InferenceStatus.modelReady);
      expect(bloc.state.activeRequestId, isNull);
      expect(bloc.state.output, 'par');
      expect(bloc.state.failure?.code, InferenceFailureCode.cancelled);
      await bloc.close();
    });

    test('keeps partial text when generation fails', () async {
      final bloc = buildBloc(forEngine: engine);
      await _loadReady(bloc);
      bloc.add(const InferenceGenerateRequested());
      await engine.waitForGenerate();
      engine.emitToken('par');
      await _waitUntil(() => bloc.state.output == 'par');

      engine.failed(
        InferenceFailure(
          (b) => b
            ..code = InferenceFailureCode.nativeError
            ..message = 'decode failed',
        ),
      );
      await _waitUntil(() => bloc.state.failure != null);

      expect(bloc.state.output, 'par');
      expect(bloc.state.failure?.code, InferenceFailureCode.nativeError);
      expect(bloc.state.activeRequestId, isNull);
      await bloc.close();
    });

    test('fails when the stream closes without a terminal event', () async {
      final bloc = buildBloc(forEngine: engine);
      await _loadReady(bloc);
      bloc.add(const InferenceGenerateRequested());
      await engine.waitForGenerate();
      await engine.closeStream();
      await _waitUntil(() => bloc.state.failure != null);

      expect(bloc.state.status, InferenceStatus.failure);
      expect(bloc.state.failure?.code, InferenceFailureCode.unknown);
      await bloc.close();
    });
  });

  group('unload', () {
    test('refuses to unload while a generation is active', () async {
      final bloc = buildBloc(forEngine: engine);
      await _loadReady(bloc);
      bloc.add(const InferenceGenerateRequested());
      await engine.waitForGenerate();
      engine.emitToken('par');
      await _waitUntil(() => bloc.state.output == 'par');

      bloc.add(const InferenceUnloadRequested());
      await _waitUntil(() => bloc.state.failure != null);

      expect(engine.unloadCalls, 0);
      expect(bloc.state.failure?.code, InferenceFailureCode.engineBusy);
      expect(
        bloc.state.failure?.message,
        'cancel the running generation first',
      );
      expect(bloc.state.status, InferenceStatus.generating);
      expect(bloc.state.activeRequestId, 1);
      expect(bloc.state.output, 'par');
      await bloc.close();
    });

    test('releases the model and returns to initial', () async {
      final bloc = buildBloc(forEngine: engine);
      await _loadReady(bloc);

      bloc.add(const InferenceUnloadRequested());
      await _waitUntil(() => bloc.state.status == InferenceStatus.initial);

      expect(engine.unloadCalls, 1);
      expect(bloc.state.activeRequestId, isNull);
      expect(bloc.state.failure, isNull);
      await bloc.close();
    });
  });
}
