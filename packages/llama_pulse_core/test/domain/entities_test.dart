import 'package:built_value/serializer.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

/// Serializes and deserializes [value], asserting equality at both ends.
T roundTrip<T>(Serializer<T> serializer, T value) {
  final serialized = serializers.serializeWith(serializer, value);
  expect(serialized, isNotNull);
  final deserialized = serializers.deserializeWith(serializer, serialized);
  expect(deserialized, value);
  return deserialized as T;
}

GenerationMetrics metrics({
  int promptTokens = 0,
  int generatedTokens = 0,
  int promptEvalMs = 0,
  int evalMs = 0,
}) => GenerationMetrics(
  (b) => b
    ..promptTokenCount = promptTokens
    ..generatedTokenCount = generatedTokens
    ..promptEvalMs = promptEvalMs
    ..evalMs = evalMs,
);

void main() {
  group('ModelParams', () {
    test('defaults match the documented values', () {
      final params = ModelParams.defaults();
      expect(params.modelPath, '');
      expect(params.contextSize, 2048);
      expect(params.gpuLayers, 0);
      expect(params.threads, 4);
      expect(params.temperature, 0.8);
      expect(params.topP, 0.95);
      expect(params.topK, 40);
      expect(params.maxTokens, 256);
      expect(ModelParams.schemaVersion, 1);
    });

    test('copyWith changes only the given field', () {
      final params = ModelParams.defaults().copyWith(threads: 8);
      expect(params.threads, 8);
      expect(params.contextSize, 2048);
      expect(params.temperature, 0.8);
      expect(params.maxTokens, 256);
    });

    test('round-trips through the serializers', () {
      final params = ModelParams.defaults().copyWith(
        modelPath: 'models/tiny.gguf',
        temperature: 0.0,
        topP: 0.5,
      );
      expect(roundTrip(ModelParams.serializer, params), params);
    });
  });

  group('GenerationRequest', () {
    test('streams by default', () {
      final request = GenerationRequest.create(
        requestId: 7,
        prompt: 'hello',
        params: ModelParams.defaults(),
      );
      expect(request.stream, isTrue);
    });

    test('round-trips through the serializers', () {
      final request = GenerationRequest.create(
        requestId: 7,
        prompt: 'hello',
        params: ModelParams.defaults(),
        stream: false,
      );
      expect(roundTrip(GenerationRequest.serializer, request), request);
    });
  });

  group('GenerationMetrics', () {
    test('tokensPerSecond is zero without measured time', () {
      expect(metrics(generatedTokens: 10).tokensPerSecond, 0);
    });

    test('tokensPerSecond divides generated tokens by eval time', () {
      expect(metrics(generatedTokens: 10, evalMs: 500).tokensPerSecond, 20.0);
    });

    test('promptTokensPerSecond is zero without measured prompt time', () {
      expect(metrics(promptTokens: 10).promptTokensPerSecond, 0);
    });

    test('promptTokensPerSecond divides prompt tokens by prompt time', () {
      expect(
        metrics(promptTokens: 10, promptEvalMs: 100).promptTokensPerSecond,
        100.0,
      );
    });

    test('zero prompt eval time does not throw', () {
      final m = metrics(generatedTokens: 10, promptTokens: 10);
      expect(m.promptEvalMs, 0);
      expect(m.promptTokensPerSecond, 0);
      expect(m.tokensPerSecond, 0);
    });

    test('round-trips through the serializers', () {
      final m = metrics(
        promptTokens: 12,
        generatedTokens: 34,
        promptEvalMs: 56,
        evalMs: 78,
      );
      expect(roundTrip(GenerationMetrics.serializer, m), m);
    });
  });

  group('GenerationEvent', () {
    test('token event serializes kind as a plain string', () {
      final event = GenerationEvent.token(3, 'hi');
      final serialized = serializers.serializeWith(
        GenerationEvent.serializer,
        event,
      );
      final map = serialized! as Map<String, Object?>;
      expect(map['kind'], 'token');
      expect(map['text'], 'hi');
    });

    test('round-trips a failed event with its failure', () {
      final event = GenerationEvent.failed(
        4,
        InferenceFailure(
          (b) => b
            ..code = InferenceFailureCode.modelNotFound
            ..message = 'missing model'
            ..details = 'no such file',
        ),
      );
      expect(roundTrip(GenerationEvent.serializer, event), event);
    });

    test('named factories set the matching kind', () {
      final m = metrics(generatedTokens: 1, evalMs: 10);
      final failure = InferenceFailure(
        (b) => b
          ..code = InferenceFailureCode.unknown
          ..message = 'boom',
      );

      expect(GenerationEvent.started(1).kind, GenerationEventKind.started);
      expect(GenerationEvent.token(1, 'x').kind, GenerationEventKind.token);
      expect(GenerationEvent.metrics(1, m).kind, GenerationEventKind.metrics);
      expect(
        GenerationEvent.completed(1, m).kind,
        GenerationEventKind.completed,
      );
      expect(GenerationEvent.cancelled(1).kind, GenerationEventKind.cancelled);
      expect(
        GenerationEvent.failed(1, failure).kind,
        GenerationEventKind.failed,
      );
    });
  });

  group('InferenceFailure', () {
    test('round-trips through the serializers', () {
      final failure = InferenceFailure(
        (b) => b
          ..code = InferenceFailureCode.nativeError
          ..message = 'engine crashed'
          ..details = null,
      );
      expect(roundTrip(InferenceFailure.serializer, failure), failure);
    });
  });

  group('ModelFileInfo', () {
    test('sizeMiB converts bytes', () {
      final empty = ModelFileInfo(
        (b) => b
          ..path = '/models/a.gguf'
          ..fileName = 'a.gguf'
          ..sizeBytes = 0
          ..modifiedAtEpochMs = 0,
      );
      expect(empty.sizeMiB, 0.0);

      final oneMiB = empty.rebuild((b) => b..sizeBytes = 1048576);
      expect(oneMiB.sizeMiB, 1.0);

      final fractional = empty.rebuild((b) => b..sizeBytes = 1572864);
      expect(fractional.sizeMiB, 1.5);
    });

    test('round-trips through the serializers', () {
      final info = ModelFileInfo(
        (b) => b
          ..path = '/models/a.gguf'
          ..fileName = 'a.gguf'
          ..sizeBytes = 1572864
          ..modifiedAtEpochMs = 1700000000000,
      );
      expect(roundTrip(ModelFileInfo.serializer, info), info);
    });
  });

  group('enums', () {
    test('GenerationEventKind round-trips by name', () {
      for (final kind in GenerationEventKind.values) {
        expect(
          serializers.serializeWith(GenerationEventKind.serializer, kind),
          kind.name,
        );
        expect(
          serializers.deserializeWith(
            GenerationEventKind.serializer,
            kind.name,
          ),
          kind,
        );
        expect(GenerationEventKind.valueOf(kind.name), kind);
      }
    });

    test('InferenceFailureCode round-trips by name', () {
      for (final code in InferenceFailureCode.values) {
        expect(
          serializers.serializeWith(InferenceFailureCode.serializer, code),
          code.name,
        );
        expect(
          serializers.deserializeWith(
            InferenceFailureCode.serializer,
            code.name,
          ),
          code,
        );
        expect(InferenceFailureCode.valueOf(code.name), code);
      }
    });
  });
}
