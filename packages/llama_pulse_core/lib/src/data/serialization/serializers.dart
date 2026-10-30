import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';

import '../../domain/entities/generation_event.dart';
import '../../domain/entities/generation_event_kind.dart';
import '../../domain/entities/generation_metrics.dart';
import '../../domain/entities/generation_request.dart';
import '../../domain/entities/inference_failure.dart';
import '../../domain/entities/inference_failure_code.dart';
import '../../domain/entities/model_file_info.dart';
import '../../domain/entities/model_params.dart';
import '../../domain/entities/worker_request.dart';
import '../../domain/entities/worker_request_kind.dart';
import '../../domain/entities/worker_response.dart';
import '../../domain/entities/worker_response_kind.dart';

part 'serializers.g.dart';

/// Serializers for every core entity.
///
/// `StandardJsonPlugin` produces and consumes `Map<String, Object?>`; YAML and
/// isolate transport encoding happen above this layer.
@SerializersFor([
  ModelParams,
  GenerationRequest,
  GenerationMetrics,
  GenerationEvent,
  GenerationEventKind,
  InferenceFailure,
  InferenceFailureCode,
  ModelFileInfo,
  WorkerRequest,
  WorkerRequestKind,
  WorkerResponse,
  WorkerResponseKind,
])
final Serializers serializers =
    (_$serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
