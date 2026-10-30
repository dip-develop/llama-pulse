import 'package:built_value/serializer.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

T roundTrip<T>(Serializer<T> serializer, T value) {
  final serialized = serializers.serializeWith(serializer, value);
  expect(serialized, isNotNull);
  final deserialized = serializers.deserializeWith(serializer, serialized);
  expect(deserialized, value);
  return deserialized as T;
}

final _params = ModelParams.defaults().copyWith(
  modelPath: 'models/tiny.gguf',
  maxTokens: 64,
);

final _failure = InferenceFailure(
  (b) => b
    ..code = InferenceFailureCode.nativeError
    ..message = 'boom',
);

void main() {
  group('WorkerRequestKind', () {
    test('exposes every protocol kind', () {
      expect(WorkerRequestKind.values.map((kind) => kind.name), [
        'load',
        'generate',
        'cancel',
        'unload',
        'dispose',
        'ping',
      ]);
    });

    test('round-trips every kind through the serializers', () {
      for (final kind in WorkerRequestKind.values) {
        expect(roundTrip(WorkerRequestKind.serializer, kind), kind);
      }
    });
  });

  group('WorkerRequest', () {
    test('load carries only the request id and params', () {
      final request = WorkerRequest.load(1, _params);
      expect(request.kind, WorkerRequestKind.load);
      expect(request.requestId, 1);
      expect(request.params, _params);
      expect(request.targetRequestId, isNull);
      expect(request.prompt, isNull);
      expect(request.maxTokens, isNull);
      expect(roundTrip(WorkerRequest.serializer, request), request);
    });

    test('generate copies the generation request fields', () {
      final generation = GenerationRequest.create(
        requestId: 7,
        prompt: 'hello world',
        params: _params,
      );
      final request = WorkerRequest.generate(generation);
      expect(request.kind, WorkerRequestKind.generate);
      expect(request.requestId, 7);
      expect(request.prompt, 'hello world');
      expect(request.params, _params);
      expect(request.maxTokens, 64);
      expect(request.targetRequestId, isNull);
      expect(roundTrip(WorkerRequest.serializer, request), request);
    });

    test('cancel carries the target request id only', () {
      final request = WorkerRequest.cancel(2, 7);
      expect(request.kind, WorkerRequestKind.cancel);
      expect(request.requestId, 2);
      expect(request.targetRequestId, 7);
      expect(request.params, isNull);
      expect(request.prompt, isNull);
      expect(request.maxTokens, isNull);
      expect(roundTrip(WorkerRequest.serializer, request), request);
    });

    test('unload, dispose and ping carry only the request id', () {
      final requests = [
        WorkerRequest.unload(3),
        WorkerRequest.dispose(4),
        WorkerRequest.ping(5),
      ];
      final kinds = [
        WorkerRequestKind.unload,
        WorkerRequestKind.dispose,
        WorkerRequestKind.ping,
      ];
      for (var index = 0; index < requests.length; index++) {
        final request = requests[index];
        expect(request.kind, kinds[index]);
        expect(request.requestId, 3 + index);
        expect(request.targetRequestId, isNull);
        expect(request.params, isNull);
        expect(request.prompt, isNull);
        expect(request.maxTokens, isNull);
        expect(roundTrip(WorkerRequest.serializer, request), request);
      }
    });

    test('identical requests are equal', () {
      expect(WorkerRequest.load(1, _params), WorkerRequest.load(1, _params));
      expect(WorkerRequest.cancel(2, 7), isNot(WorkerRequest.cancel(2, 8)));
    });
  });

  group('WorkerResponseKind', () {
    test('exposes every protocol kind', () {
      expect(WorkerResponseKind.values.map((kind) => kind.name), [
        'loaded',
        'unloaded',
        'tokenBatch',
        'metrics',
        'completed',
        'cancelled',
        'failure',
        'pong',
        'disposed',
      ]);
    });

    test('round-trips every kind through the serializers', () {
      for (final kind in WorkerResponseKind.values) {
        expect(roundTrip(WorkerResponseKind.serializer, kind), kind);
      }
    });
  });

  group('WorkerResponse', () {
    test('simple responses default text to an empty string', () {
      final responses = [
        WorkerResponse.loaded(1),
        WorkerResponse.unloaded(2),
        WorkerResponse.completed(3),
        WorkerResponse.cancelled(4),
        WorkerResponse.pong(5),
        WorkerResponse.disposed(6),
      ];
      for (final response in responses) {
        expect(response.text, '');
        expect(response.metrics, isNull);
        expect(response.failure, isNull);
        expect(roundTrip(WorkerResponse.serializer, response), response);
      }
    });

    test('tokenBatch carries its text and nothing else', () {
      final response = WorkerResponse.tokenBatch(7, 'Local');
      expect(response.kind, WorkerResponseKind.tokenBatch);
      expect(response.requestId, 7);
      expect(response.text, 'Local');
      expect(response.metrics, isNull);
      expect(response.failure, isNull);
      expect(roundTrip(WorkerResponse.serializer, response), response);
    });

    test('metrics carries a GenerationMetrics payload', () {
      final metrics = GenerationMetrics(
        (b) => b
          ..promptTokenCount = 3
          ..generatedTokenCount = 9
          ..promptEvalMs = 3
          ..evalMs = 40,
      );
      final response = WorkerResponse.metrics(8, metrics);
      expect(response.kind, WorkerResponseKind.metrics);
      expect(response.text, '');
      expect(response.metrics, metrics);
      expect(response.failure, isNull);
      expect(roundTrip(WorkerResponse.serializer, response), response);
    });

    test('failure carries an InferenceFailure payload', () {
      final response = WorkerResponse.failure(9, _failure);
      expect(response.kind, WorkerResponseKind.failure);
      expect(response.text, '');
      expect(response.metrics, isNull);
      expect(response.failure, _failure);
      expect(roundTrip(WorkerResponse.serializer, response), response);
    });
  });
}
