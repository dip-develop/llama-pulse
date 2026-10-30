import 'package:built_collection/built_collection.dart';
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
import '../../domain/entities/server_binary_info.dart';
import '../../domain/entities/server_config.dart';
import '../../domain/entities/server_failure.dart';
import '../../domain/entities/server_failure_code.dart';
import '../../domain/entities/server_flash_attention.dart';
import '../../domain/entities/server_health.dart';
import '../../domain/entities/server_log_entry.dart';
import '../../domain/entities/server_log_stream.dart';
import '../../domain/entities/server_metrics.dart';
import '../../domain/entities/server_phase.dart';
import '../../domain/entities/server_state.dart';
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
  ServerConfig,
  ServerFlashAttention,
  ServerPhase,
  ServerHealth,
  ServerFailureCode,
  ServerFailure,
  ServerMetrics,
  ServerState,
  ServerLogStream,
  ServerLogEntry,
  ServerBinaryInfo,
  WorkerRequest,
  WorkerRequestKind,
  WorkerResponse,
  WorkerResponseKind,
])
final Serializers serializers =
    (_$serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
