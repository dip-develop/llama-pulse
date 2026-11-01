// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serializers.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializers _$serializers =
    (Serializers().toBuilder()
          ..add(GenerationEvent.serializer)
          ..add(GenerationEventKind.serializer)
          ..add(GenerationMetrics.serializer)
          ..add(GenerationRequest.serializer)
          ..add(InferenceFailure.serializer)
          ..add(InferenceFailureCode.serializer)
          ..add(ModelFileInfo.serializer)
          ..add(ModelParams.serializer)
          ..add(RuntimeIndex.serializer)
          ..add(RuntimeInstallRef.serializer)
          ..add(RuntimeManifest.serializer)
          ..add(ServerBinaryInfo.serializer)
          ..add(ServerConfig.serializer)
          ..add(ServerFailure.serializer)
          ..add(ServerFailureCode.serializer)
          ..add(ServerFlashAttention.serializer)
          ..add(ServerHealth.serializer)
          ..add(ServerLogEntry.serializer)
          ..add(ServerLogStream.serializer)
          ..add(ServerMetrics.serializer)
          ..add(ServerPhase.serializer)
          ..add(ServerState.serializer)
          ..add(WorkerRequest.serializer)
          ..add(WorkerRequestKind.serializer)
          ..add(WorkerResponse.serializer)
          ..add(WorkerResponseKind.serializer)
          ..addBuilderFactory(
            const FullType(BuiltList, const [
              const FullType(RuntimeInstallRef),
            ]),
            () => ListBuilder<RuntimeInstallRef>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(String)]),
            () => ListBuilder<String>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltList, const [const FullType(String)]),
            () => ListBuilder<String>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltMap, const [
              const FullType(String),
              const FullType(String),
            ]),
            () => MapBuilder<String, String>(),
          )
          ..addBuilderFactory(
            const FullType(BuiltMap, const [
              const FullType(String),
              const FullType(String),
            ]),
            () => MapBuilder<String, String>(),
          ))
        .build();

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
