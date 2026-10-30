import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'generation_request.dart';
import 'model_params.dart';
import 'worker_request_kind.dart';

part 'worker_request.g.dart';

/// One message sent to the inference worker isolate.
///
/// A single class with a [kind] is used instead of six subclasses because the
/// message crosses an isolate boundary: one wire type keeps the transport
/// contract stable and avoids polymorphic serializers.
abstract class WorkerRequest
    implements Built<WorkerRequest, WorkerRequestBuilder> {
  /// Discriminator describing which fields are meaningful.
  WorkerRequestKind get kind;

  /// Identifier of this request.
  int get requestId;

  /// Request being cancelled, set on cancel requests only.
  int? get targetRequestId;

  /// Model parameters, set on load and generate requests.
  ModelParams? get params;

  /// Prompt text, set on generate requests only.
  String? get prompt;

  /// Token cap, set on generate requests only.
  int? get maxTokens;

  factory WorkerRequest([void Function(WorkerRequestBuilder)? updates]) =
      _$WorkerRequest;

  /// Builds a request to load [params].
  factory WorkerRequest.load(int requestId, ModelParams params) =>
      WorkerRequest(
        (b) => b
          ..kind = WorkerRequestKind.load
          ..requestId = requestId
          ..params.replace(params),
      );

  /// Builds a request to generate text for [request].
  factory WorkerRequest.generate(GenerationRequest request) => WorkerRequest(
    (b) => b
      ..kind = WorkerRequestKind.generate
      ..requestId = request.requestId
      ..prompt = request.prompt
      ..params.replace(request.params)
      ..maxTokens = request.params.maxTokens,
  );

  /// Builds a request to cancel [targetRequestId].
  factory WorkerRequest.cancel(int requestId, int targetRequestId) =>
      WorkerRequest(
        (b) => b
          ..kind = WorkerRequestKind.cancel
          ..requestId = requestId
          ..targetRequestId = targetRequestId,
      );

  /// Builds a request to unload the model.
  factory WorkerRequest.unload(int requestId) => WorkerRequest(
    (b) => b
      ..kind = WorkerRequestKind.unload
      ..requestId = requestId,
  );

  /// Builds a request to dispose the worker.
  factory WorkerRequest.dispose(int requestId) => WorkerRequest(
    (b) => b
      ..kind = WorkerRequestKind.dispose
      ..requestId = requestId,
  );

  /// Builds a liveness-check request.
  factory WorkerRequest.ping(int requestId) => WorkerRequest(
    (b) => b
      ..kind = WorkerRequestKind.ping
      ..requestId = requestId,
  );

  WorkerRequest._();

  static Serializer<WorkerRequest> get serializer => _$workerRequestSerializer;
}
