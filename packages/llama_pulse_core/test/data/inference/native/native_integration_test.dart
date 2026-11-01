import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:llama_pulse_core/src/data/inference/native/llama_library.dart';
import 'package:llama_pulse_core/src/data/inference/native/native_llama_session.dart';
import 'package:test/test.dart';

const String _skipReason = 'set LLAMA_PULSE_LIB and LLAMA_PULSE_MODEL';

String? _read(String name) {
  final String? value = Platform.environment[name];
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value;
}

void main() {
  final String? libraryPath = _read('LLAMA_PULSE_LIB');
  final String? modelPath = _read('LLAMA_PULSE_MODEL');
  final String? skipReason = libraryPath == null || modelPath == null
      ? _skipReason
      : null;

  test(
    'generates, cancels and reloads against the pinned native library',
    () async {
      final LlamaLibrary library = await LlamaLibrary.open(libraryPath!);
      expect(library.isUsable, isTrue, reason: '${library.failure}');
      expect(library.version, LlamaVersionPin.version);

      final NativeLlamaSession session = NativeLlamaSession(
        libraryPath: libraryPath,
      );
      addTearDown(session.dispose);
      await session.open(libraryPath);

      final ModelParams params = ModelParams.defaults().copyWith(
        modelPath: modelPath,
        contextSize: 512,
        threads: 2,
        gpuLayers: 0,
        maxTokens: 8,
      );
      await session.load(params);
      expect(session.contextSize, isNotNull);
      expect(session.contextSize, greaterThan(0));

      session.begin(
        GenerationRequest.create(requestId: 1, prompt: 'Hello', params: params),
      );

      final List<GenerationStep> steps = <GenerationStep>[];
      final Stopwatch elapsed = Stopwatch()..start();
      var generated = 0;
      while (generated < 8 && elapsed.elapsed < const Duration(seconds: 15)) {
        final GenerationStep? step = await session.next();
        if (step == null) {
          break;
        }
        steps.add(step);
        generated = step.metrics?.generatedTokenCount ?? generated;
        if (step.done) {
          break;
        }
      }

      final String text = steps.map((step) => step.text).join();
      final int terminalCount = steps.where((step) => step.done).length;
      expect(terminalCount, 1, reason: 'exactly one terminal done step');
      if (text.isEmpty) {
        expect(
          steps.last.done,
          isTrue,
          reason: 'a model that emits EOG immediately still terminates',
        );
      } else {
        expect(text, isNotEmpty);
      }

      var previousGenerated = 0;
      var sawMetrics = false;
      for (final GenerationStep step in steps) {
        final GenerationMetrics? metrics = step.metrics;
        if (metrics == null) {
          continue;
        }
        sawMetrics = true;
        expect(
          metrics.generatedTokenCount,
          greaterThanOrEqualTo(previousGenerated),
        );
        previousGenerated = metrics.generatedTokenCount;
        expect(metrics.promptTokenCount, greaterThan(0));
      }
      expect(sawMetrics, isTrue);

      session.begin(
        GenerationRequest.create(requestId: 2, prompt: 'Hello', params: params),
      );
      await session.next();
      await expectLater(session.cancel(), completes);
      expect(await session.next(), isNull);

      await session.unload();
      await session.load(params);
      expect(session.contextSize, isNotNull);
      expect(session.contextSize, greaterThan(0));
    },
    skip: skipReason,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
