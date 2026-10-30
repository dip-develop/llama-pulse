import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'worker_response_kind.g.dart';

/// Kind discriminator carried by every worker response.
class WorkerResponseKind extends EnumClass {
  /// A model finished loading.
  static const WorkerResponseKind loaded = _$loaded;

  /// The loaded model was released.
  static const WorkerResponseKind unloaded = _$unloaded;

  /// A chunk of generated text is available.
  static const WorkerResponseKind tokenBatch = _$tokenBatch;

  /// Token and timing metrics are available.
  static const WorkerResponseKind metrics = _$metrics;

  /// Generation finished successfully.
  static const WorkerResponseKind completed = _$completed;

  /// Generation was cancelled.
  static const WorkerResponseKind cancelled = _$cancelled;

  /// The request failed; see the response failure.
  static const WorkerResponseKind failure = _$failure;

  /// The worker answered a liveness check.
  static const WorkerResponseKind pong = _$pong;

  /// The worker is disposed.
  static const WorkerResponseKind disposed = _$disposed;

  const WorkerResponseKind._(super.name);

  /// All kinds, in protocol order.
  static BuiltSet<WorkerResponseKind> get values => _$values;

  /// Looks up a kind by its wire name.
  static WorkerResponseKind valueOf(String name) => _$valueOf(name);

  static Serializer<WorkerResponseKind> get serializer =>
      _$workerResponseKindSerializer;
}
