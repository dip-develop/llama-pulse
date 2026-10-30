import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'generation_metrics.dart';
import 'inference_failure.dart';
import 'worker_response_kind.dart';

part 'worker_response.g.dart';

/// One message sent back from the inference worker isolate.
///
/// Like [WorkerRequest], this is a single wire type discriminated by [kind] so
/// it can cross the isolate boundary without polymorphic serializers.
abstract class WorkerResponse
    implements Built<WorkerResponse, WorkerResponseBuilder> {
  /// Discriminator describing which fields are meaningful.
  WorkerResponseKind get kind;

  /// Identifier of the request this response belongs to.
  int get requestId;

  /// Text chunk for token responses, empty otherwise.
  String get text;

  /// Token and timing metrics, set on metrics responses.
  GenerationMetrics? get metrics;

  /// Failure payload, set on failure responses.
  InferenceFailure? get failure;

  factory WorkerResponse([void Function(WorkerResponseBuilder)? updates]) =
      _$WorkerResponse;

  /// Builds a response signalling that the model loaded.
  factory WorkerResponse.loaded(int requestId) => WorkerResponse(
    (b) => b
      ..kind = WorkerResponseKind.loaded
      ..requestId = requestId
      ..text = '',
  );

  /// Builds a response signalling that the model unloaded.
  factory WorkerResponse.unloaded(int requestId) => WorkerResponse(
    (b) => b
      ..kind = WorkerResponseKind.unloaded
      ..requestId = requestId
      ..text = '',
  );

  /// Builds a response carrying the next [text] chunk.
  factory WorkerResponse.tokenBatch(int requestId, String text) =>
      WorkerResponse(
        (b) => b
          ..kind = WorkerResponseKind.tokenBatch
          ..requestId = requestId
          ..text = text,
      );

  /// Builds a response carrying interim [metrics].
  factory WorkerResponse.metrics(int requestId, GenerationMetrics metrics) =>
      WorkerResponse(
        (b) => b
          ..kind = WorkerResponseKind.metrics
          ..requestId = requestId
          ..text = ''
          ..metrics.replace(metrics),
      );

  /// Builds a response signalling successful completion.
  factory WorkerResponse.completed(int requestId) => WorkerResponse(
    (b) => b
      ..kind = WorkerResponseKind.completed
      ..requestId = requestId
      ..text = '',
  );

  /// Builds a response signalling that generation was cancelled.
  factory WorkerResponse.cancelled(int requestId) => WorkerResponse(
    (b) => b
      ..kind = WorkerResponseKind.cancelled
      ..requestId = requestId
      ..text = '',
  );

  /// Builds a response carrying [failure] details.
  factory WorkerResponse.failure(int requestId, InferenceFailure failure) =>
      WorkerResponse(
        (b) => b
          ..kind = WorkerResponseKind.failure
          ..requestId = requestId
          ..text = ''
          ..failure.replace(failure),
      );

  /// Builds a response answering a liveness check.
  factory WorkerResponse.pong(int requestId) => WorkerResponse(
    (b) => b
      ..kind = WorkerResponseKind.pong
      ..requestId = requestId
      ..text = '',
  );

  /// Builds a response signalling that the worker disposed.
  factory WorkerResponse.disposed(int requestId) => WorkerResponse(
    (b) => b
      ..kind = WorkerResponseKind.disposed
      ..requestId = requestId
      ..text = '',
  );

  WorkerResponse._();

  static Serializer<WorkerResponse> get serializer =>
      _$workerResponseSerializer;
}
