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
      expect(params.chatTemplate, isNull);
      expect(params.useChatTemplate, isNull);
      expect(ModelParams.schemaVersion, 1);
    });

    test('copyWith changes only the given field', () {
      final params = ModelParams.defaults().copyWith(threads: 8);
      expect(params.threads, 8);
      expect(params.contextSize, 2048);
      expect(params.temperature, 0.8);
      expect(params.maxTokens, 256);
      expect(params.chatTemplate, isNull);
      expect(params.useChatTemplate, isNull);
    });

    test('copyWith sets and clears the chat-template fields', () {
      final named = ModelParams.defaults().copyWith(
        chatTemplate: 'chatml',
        useChatTemplate: false,
      );
      expect(named.chatTemplate, 'chatml');
      expect(named.useChatTemplate, isFalse);

      final cleared = named.copyWith(chatTemplate: null, useChatTemplate: null);
      expect(cleared.chatTemplate, isNull);
      expect(cleared.useChatTemplate, isNull);
    });

    test('round-trips through the serializers', () {
      final params = ModelParams.defaults().copyWith(
        modelPath: 'models/tiny.gguf',
        temperature: 0.0,
        topP: 0.5,
        chatTemplate: 'chatml',
        useChatTemplate: true,
      );
      expect(roundTrip(ModelParams.serializer, params), params);
    });

    test('serializes null chat-template fields as absent keys', () {
      final serialized = serializers.serializeWith(
        ModelParams.serializer,
        ModelParams.defaults(),
      );
      expect(serialized, isA<Map<String, Object?>>());
      final document = serialized as Map<String, Object?>;
      expect(document.containsKey('chatTemplate'), isFalse);
      expect(document.containsKey('useChatTemplate'), isFalse);
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

    test('without messages the prompt is the single user message', () {
      final request = GenerationRequest.create(
        requestId: 7,
        prompt: 'hello',
        params: ModelParams.defaults(),
      );

      expect(request.messages, isEmpty);
      expect(request.effectiveMessages, hasLength(1));
      expect(request.effectiveMessages.single.role, 'user');
      expect(request.effectiveMessages.single.content, 'hello');
    });

    test('round-trips a message list', () {
      final request = GenerationRequest.create(
        requestId: 8,
        prompt: 'and one more',
        params: ModelParams.defaults(),
        messages: <ChatMessage>[
          ChatMessage.create(role: 'system', content: 'be brief'),
          ChatMessage.create(role: 'user', content: 'tell me a joke'),
          ChatMessage.create(role: 'assistant', content: 'why did the…'),
          ChatMessage.create(role: 'user', content: 'and one more'),
        ],
      );

      expect(request.effectiveMessages, hasLength(4));
      expect(request.effectiveMessages.first.role, 'system');
      expect(request.effectiveMessages.last.content, 'and one more');
      expect(roundTrip(GenerationRequest.serializer, request), request);
    });

    test('ChatMessage reports known and unknown roles', () {
      expect(
        ChatMessage.create(role: 'system', content: 'x').hasKnownRole,
        isTrue,
      );
      expect(
        ChatMessage.create(role: 'wizard', content: 'x').hasKnownRole,
        isFalse,
      );
      expect(ChatMessage.knownRoles, contains('assistant'));
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
