import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'server_metrics.g.dart';

/// Counters and throughput sampled from a running `llama-server`.
abstract class ServerMetrics
    implements Built<ServerMetrics, ServerMetricsBuilder> {
  /// Prompt tokens processed since the server started.
  int get promptTokensTotal;

  /// Prompt tokens served from the cache since the server started.
  int get promptTokensCachedTotal;

  /// Tokens generated since the server started.
  int get tokensPredictedTotal;

  /// Decode steps since the server started.
  int get nDecodeTotal;

  /// Largest token count seen by one decode step.
  int get nTokensMax;

  /// Requests being processed right now.
  int get requestsProcessing;

  /// Requests waiting for a free slot.
  int get requestsDeferred;

  /// Busy slots counted per decode step.
  int get nBusySlotsPerDecode;

  /// Seconds spent evaluating prompts since the server started.
  double get promptSecondsTotal;

  /// Seconds spent decoding since the server started.
  double get tokensPredictedSecondsTotal;

  /// Generated tokens per second.
  double get tokensPerSecond;

  /// Prompt tokens per second.
  double get promptTokensPerSecond;

  /// Slots handling a request right now.
  int get activeSlots;

  /// Slots the server was started with.
  int get totalSlots;

  /// Server uptime in seconds, when the server reports it.
  int? get uptimeSeconds;

  /// Share of the context window in use, 0.0 to 1.0, when known.
  double? get contextUsageRatio;

  /// When the sample was taken, as milliseconds since the Unix epoch.
  int get capturedAtEpochMs;

  factory ServerMetrics([void Function(ServerMetricsBuilder)? updates]) =
      _$ServerMetrics;

  /// Returns a zeroed sample for a server that reports no counters yet.
  factory ServerMetrics.empty(int capturedAtEpochMs) => ServerMetrics(
    (b) => b
      ..promptTokensTotal = 0
      ..promptTokensCachedTotal = 0
      ..tokensPredictedTotal = 0
      ..nDecodeTotal = 0
      ..nTokensMax = 0
      ..requestsProcessing = 0
      ..requestsDeferred = 0
      ..nBusySlotsPerDecode = 0
      ..promptSecondsTotal = 0
      ..tokensPredictedSecondsTotal = 0
      ..tokensPerSecond = 0
      ..promptTokensPerSecond = 0
      ..activeSlots = 0
      ..totalSlots = 0
      ..capturedAtEpochMs = capturedAtEpochMs,
  );

  ServerMetrics._();

  static Serializer<ServerMetrics> get serializer => _$serverMetricsSerializer;
}
