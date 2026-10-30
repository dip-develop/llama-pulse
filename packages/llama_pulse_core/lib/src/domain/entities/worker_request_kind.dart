import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'worker_request_kind.g.dart';

/// Kind discriminator carried by every worker request.
class WorkerRequestKind extends EnumClass {
  /// Loads a model into the worker.
  static const WorkerRequestKind load = _$load;

  /// Starts generating text for a prompt.
  static const WorkerRequestKind generate = _$generate;

  /// Cancels a running generation request.
  static const WorkerRequestKind cancel = _$cancel;

  /// Releases the loaded model, keeping the worker alive.
  static const WorkerRequestKind unload = _$unload;

  /// Shuts the worker down and releases everything.
  static const WorkerRequestKind dispose = _$dispose;

  /// Checks that the worker is alive.
  static const WorkerRequestKind ping = _$ping;

  const WorkerRequestKind._(super.name);

  /// All kinds, in protocol order.
  static BuiltSet<WorkerRequestKind> get values => _$values;

  /// Looks up a kind by its wire name.
  static WorkerRequestKind valueOf(String name) => _$valueOf(name);

  static Serializer<WorkerRequestKind> get serializer =>
      _$workerRequestKindSerializer;
}
