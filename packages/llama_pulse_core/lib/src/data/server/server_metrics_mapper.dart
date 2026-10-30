import '../../domain/entities/server_config.dart';
import '../../domain/entities/server_metrics.dart';
import 'prometheus_metrics_parser.dart';

/// Maps a raw `/metrics`, `/slots` and `/props` snapshot to [ServerMetrics].
///
/// The mapper never throws: a missing or wrongly typed value becomes `0` or
/// `null`, so a partially reachable server still yields a usable sample.
final class ServerMetricsMapper {
  /// Creates a stateless mapper.
  const ServerMetricsMapper();

  /// Builds one sample from the three server endpoints.
  ///
  /// [slots] is the decoded `/slots` array and [props] the decoded `/props`
  /// object; both are passed as loose JSON so malformed entries can be
  /// ignored. [processStartTimeUnixSeconds] comes from the `/metrics`
  /// `Process-Start-Time-Unix` header and wins over [startedAtEpochMs].
  ServerMetrics from({
    required PrometheusMetrics metrics,
    required List<Object?> slots,
    required Map<String, Object?> props,
    required ServerConfig config,
    int? startedAtEpochMs,
    int? processStartTimeUnixSeconds,
    required int capturedAtEpochMs,
  }) {
    final nTokensMax = _metricInt(metrics.get('llamacpp:n_tokens_max'));
    return ServerMetrics(
      (b) => b
        ..promptTokensTotal = _metricInt(
          metrics.get('llamacpp:prompt_tokens_total'),
        )
        ..promptTokensCachedTotal = _metricInt(
          metrics.get('llamacpp:prompt_tokens_cached_total'),
        )
        ..promptSecondsTotal = _finiteDouble(
          metrics.get('llamacpp:prompt_seconds_total'),
        )
        ..tokensPredictedTotal = _metricInt(
          metrics.get('llamacpp:tokens_predicted_total'),
        )
        ..tokensPredictedSecondsTotal = _finiteDouble(
          metrics.get('llamacpp:tokens_predicted_seconds_total'),
        )
        ..nDecodeTotal = _metricInt(metrics.get('llamacpp:n_decode_total'))
        ..nTokensMax = nTokensMax
        ..requestsProcessing = _metricInt(
          metrics.get('llamacpp:requests_processing'),
        )
        ..requestsDeferred = _metricInt(
          metrics.get('llamacpp:requests_deferred'),
        )
        ..nBusySlotsPerDecode = _metricInt(
          metrics.get('llamacpp:n_busy_slots_per_decode'),
        )
        ..tokensPerSecond = _finiteDouble(
          metrics.get('llamacpp:predicted_tokens_seconds'),
        )
        ..promptTokensPerSecond = _finiteDouble(
          metrics.get('llamacpp:prompt_tokens_seconds'),
        )
        ..activeSlots = _activeSlots(slots)
        ..totalSlots = _totalSlots(props, slots)
        ..uptimeSeconds = _uptimeSeconds(
          capturedAtEpochMs: capturedAtEpochMs,
          startedAtEpochMs: startedAtEpochMs,
          processStartTimeUnixSeconds: processStartTimeUnixSeconds,
        )
        ..contextUsageRatio = _contextUsageRatio(slots, config, nTokensMax)
        ..capturedAtEpochMs = capturedAtEpochMs,
    );
  }

  int _activeSlots(List<Object?> slots) {
    var active = 0;
    for (final slot in slots) {
      if (slot is Map<Object?, Object?> && slot['is_processing'] == true) {
        active++;
      }
    }
    return active;
  }

  int _totalSlots(Map<String, Object?> props, List<Object?> slots) {
    final declared = _slotDouble(props['total_slots']);
    if (declared != null && declared >= 0) {
      return declared.toInt();
    }
    return slots.length;
  }

  double? _contextUsageRatio(
    List<Object?> slots,
    ServerConfig config,
    int nTokensMax,
  ) {
    if (slots.isEmpty) {
      if (nTokensMax > 0 && config.contextSize > 0) {
        return (nTokensMax / config.contextSize).clamp(0.0, 1.0).toDouble();
      }
      return null;
    }
    var highest = 0.0;
    for (final slot in slots) {
      if (slot is! Map<Object?, Object?>) {
        continue;
      }
      if (slot['is_processing'] != true) {
        continue;
      }
      final nCtx = _slotDouble(slot['n_ctx']);
      if (nCtx == null || nCtx <= 0) {
        continue;
      }
      final prompt =
          _slotDouble(slot['n_prompt_tokens']) ??
          _slotDouble(slot['prompt_tokens']) ??
          0;
      var decoded = 0.0;
      final nextToken = slot['next_token'];
      if (nextToken is Map<Object?, Object?>) {
        decoded = _slotDouble(nextToken['n_decoded']) ?? 0;
      }
      final ratio = (prompt + decoded) / nCtx;
      if (ratio > highest) {
        highest = ratio;
      }
    }
    return highest.clamp(0.0, 1.0).toDouble();
  }

  int? _uptimeSeconds({
    required int capturedAtEpochMs,
    required int? startedAtEpochMs,
    required int? processStartTimeUnixSeconds,
  }) {
    final int seconds;
    if (processStartTimeUnixSeconds != null) {
      seconds = capturedAtEpochMs ~/ 1000 - processStartTimeUnixSeconds;
    } else if (startedAtEpochMs != null) {
      seconds = (capturedAtEpochMs - startedAtEpochMs) ~/ 1000;
    } else {
      return null;
    }
    return seconds < 0 ? 0 : seconds;
  }

  int _metricInt(double value) => value.isFinite ? value.toInt() : 0;

  double _finiteDouble(double value) => value.isFinite ? value : 0;

  double? _slotDouble(Object? value) {
    final double? number;
    if (value is num) {
      number = value.toDouble();
    } else if (value is String) {
      number = double.tryParse(value);
    } else {
      number = null;
    }
    if (number == null || !number.isFinite) {
      return null;
    }
    return number;
  }
}
