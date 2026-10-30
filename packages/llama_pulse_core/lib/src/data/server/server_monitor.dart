import 'dart:async';
import 'dart:convert';

import '../../domain/entities/server_config.dart';
import '../../domain/entities/server_failure.dart';
import '../../domain/entities/server_failure_code.dart';
import '../../domain/entities/server_metrics.dart';
import '../../domain/exceptions/server_exception.dart';
import '../../domain/gateways/server_http_client.dart';
import 'prometheus_metrics_parser.dart';
import 'server_metrics_mapper.dart';

int _nowEpochMs() => DateTime.now().millisecondsSinceEpoch;

/// Samples the metrics, slots and props endpoints of a running server.
///
/// `/metrics` is required: without it there is nothing to show. `/slots` and
/// `/props` are best-effort and degrade to empty data.
class ServerMonitor {
  /// Creates a monitor with a per-request [timeout] and a [clock] in epoch ms.
  ServerMonitor({
    required this._httpClient,
    this._mapper = const ServerMetricsMapper(),
    this._timeout = const Duration(seconds: 3),
    this._clock = _nowEpochMs,
  });

  final ServerHttpClient _httpClient;
  final ServerMetricsMapper _mapper;
  final Duration _timeout;
  final int Function() _clock;

  /// Takes one sample of [config], optionally using the known [startedAtEpochMs].
  ///
  /// Throws [ServerException] with a `httpError` failure when `/metrics` is
  /// missing, fails or returns no samples. The exception message never holds
  /// the API key or request headers.
  Future<ServerMetrics> sample(
    ServerConfig config, {
    int? startedAtEpochMs,
  }) async {
    final capturedAtEpochMs = _clock();
    final headers = _headers(config);
    final metricsResponse = await _fetchMetrics(config, headers);
    final metrics = PrometheusMetrics.parse(metricsResponse.body);
    if (metrics.samples.isEmpty) {
      throw _metricsError('metrics unavailable (unparseable response)');
    }
    return _mapper.from(
      metrics: metrics,
      slots: await _slots(config, headers),
      props: await _props(config, headers),
      config: config,
      startedAtEpochMs: startedAtEpochMs,
      processStartTimeUnixSeconds: _processStartTime(metricsResponse.headers),
      capturedAtEpochMs: capturedAtEpochMs,
    );
  }

  Future<ServerHttpResponse> _fetchMetrics(
    ServerConfig config,
    Map<String, String> headers,
  ) async {
    final ServerHttpResponse response;
    try {
      response = await _httpClient
          .get(_uri(config, '/metrics'), headers: headers)
          .timeout(_timeout);
    } on TimeoutException {
      throw _metricsError('metrics unavailable (timeout)');
    } catch (_) {
      throw _metricsError('metrics unavailable (request failed)');
    }
    if (response.statusCode != 200) {
      throw _metricsError('metrics unavailable (HTTP ${response.statusCode})');
    }
    return response;
  }

  Future<List<Object?>> _slots(
    ServerConfig config,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _httpClient
          .get(_uri(config, '/slots'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return const <Object?>[];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List<Object?>) {
        return decoded;
      }
    } catch (_) {
      return const <Object?>[];
    }
    return const <Object?>[];
  }

  Future<Map<String, Object?>> _props(
    ServerConfig config,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _httpClient
          .get(_uri(config, '/props'), headers: headers)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return const <String, Object?>{};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<Object?, Object?>) {
        final props = <String, Object?>{};
        decoded.forEach((key, value) {
          if (key is String) {
            props[key] = value;
          }
        });
        return props;
      }
    } catch (_) {
      return const <String, Object?>{};
    }
    return const <String, Object?>{};
  }

  Map<String, String> _headers(ServerConfig config) {
    if (config.apiKey.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer ${config.apiKey}'};
  }

  int? _processStartTime(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != 'process-start-time-unix') {
        continue;
      }
      final raw = entry.value.trim();
      final seconds = int.tryParse(raw);
      if (seconds != null) {
        return seconds;
      }
      final parsed = double.tryParse(raw);
      if (parsed != null && parsed.isFinite) {
        return parsed.toInt();
      }
    }
    return null;
  }

  Uri _uri(ServerConfig config, String path) =>
      Uri.parse('http://${config.clientHost}:${config.port}$path');
}

ServerException _metricsError(String message) => ServerException(
  ServerFailure(
    (b) => b
      ..code = ServerFailureCode.httpError
      ..message = message,
  ),
);
