import 'dart:async';
import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

import '../../support/server_fakes.dart';

String _body(String name) =>
    File('test/data/server/fixtures/$name')
        .readAsLinesSync()
        .skip(1)
        .join('\n');

ServerConfig _config({
  String host = '127.0.0.1',
  int port = 8080,
  String apiKey = '',
}) => ServerConfig(
  (b) => b
    ..modelPath = '/models/model.gguf'
    ..host = host
    ..port = port
    ..contextSize = 4096
    ..threads = 4
    ..gpuLayers = 0
    ..parallelSlots = 2
    ..modelAlias = 'llama-pulse'
    ..apiKey = apiKey
    ..flashAttention = ServerFlashAttention.auto
    ..mlock = false
    ..mmap = true
    ..binaryPath = ''
    ..startupTimeoutSeconds = 120,
);

ServerHttpResponse _metricsResponse() => ServerHttpResponse(
  statusCode: 200,
  body: _body('metrics.prom'),
  headers: const <String, String>{'process-start-time-unix': '1700000000'},
);

ServerHttpResponse _slotsResponse() =>
    ServerHttpResponse(statusCode: 200, body: _body('slots.json'));

ServerHttpResponse _propsResponse() =>
    ServerHttpResponse(statusCode: 200, body: _body('props.json'));

/// A client whose requests never complete.
final class _HangingHttpClient implements ServerHttpClient {
  @override
  Future<ServerHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) => Completer<ServerHttpResponse>().future;

  @override
  void close() {}
}

void main() {
  late FakeHttpClient httpClient;

  setUp(() {
    httpClient = FakeHttpClient();
  });

  ServerMonitor monitor({Duration timeout = const Duration(seconds: 3)}) =>
      ServerMonitor(
        httpClient: httpClient,
        timeout: timeout,
        clock: () => 1700000100000,
      );

  test(
    'maps the fixture responses and derives uptime from the header',
    () async {
      httpClient
        ..addResponse('/metrics', _metricsResponse())
        ..addResponse('/slots', _slotsResponse())
        ..addResponse('/props', _propsResponse());

      final metrics = await monitor().sample(_config());

      expect(metrics.promptTokensTotal, 42);
      expect(metrics.tokensPredictedTotal, 128);
      expect(metrics.tokensPerSecond, closeTo(36.57, 1e-9));
      expect(metrics.promptTokensPerSecond, 35.0);
      expect(metrics.activeSlots, 1);
      expect(metrics.totalSlots, 2);
      expect(metrics.contextUsageRatio, closeTo(350 / 4096, 1e-12));
      expect(metrics.uptimeSeconds, 100);
      expect(metrics.capturedAtEpochMs, 1700000100000);
      expect(httpClient.paths, ['/metrics', '/slots', '/props']);
      expect(
        httpClient.requests.first.uri.toString(),
        'http://127.0.0.1:8080/metrics',
      );
    },
  );

  test('sends the API key as a bearer token when configured', () async {
    httpClient
      ..addResponse('/metrics', _metricsResponse())
      ..addResponse('/slots', _slotsResponse())
      ..addResponse('/props', _propsResponse());

    await monitor().sample(_config(apiKey: 'secret-token'));

    expect(httpClient.requests, hasLength(3));
    for (final request in httpClient.requests) {
      expect(request.headers['Authorization'], 'Bearer secret-token');
    }
  });

  test('sends no authorization header without an API key', () async {
    httpClient
      ..addResponse('/metrics', _metricsResponse())
      ..addResponse('/slots', _slotsResponse())
      ..addResponse('/props', _propsResponse());

    await monitor().sample(_config());

    for (final request in httpClient.requests) {
      expect(request.headers.containsKey('Authorization'), isFalse);
    }
  });

  test('throws a httpError when /metrics answers 501', () async {
    httpClient.addResponse(
      '/metrics',
      const ServerHttpResponse(statusCode: 501, body: ''),
    );

    await expectLater(
      monitor().sample(_config(apiKey: 'secret-token')),
      throwsA(
        isA<ServerException>()
            .having(
              (error) => error.failure.code,
              'code',
              ServerFailureCode.httpError,
            )
            .having(
              (error) => error.failure.message,
              'message',
              'metrics unavailable (HTTP 501)',
            )
            .having(
              (error) => error.toString(),
              'toString',
              isNot(contains('secret-token')),
            ),
      ),
    );
    expect(httpClient.paths, ['/metrics']);
  });

  test('still samples when /slots answers 500', () async {
    httpClient
      ..addResponse('/metrics', _metricsResponse())
      ..addResponse(
        '/slots',
        const ServerHttpResponse(statusCode: 500, body: ''),
      )
      ..addResponse('/props', _propsResponse());

    final metrics = await monitor().sample(_config());

    expect(metrics.promptTokensTotal, 42);
    expect(metrics.activeSlots, 0);
    expect(metrics.totalSlots, 2);
    expect(metrics.contextUsageRatio, 0.5);
  });

  test('falls back to defaults when /props fails', () async {
    httpClient
      ..addResponse('/metrics', _metricsResponse())
      ..addResponse('/slots', _slotsResponse())
      ..addResponse(
        '/props',
        const ServerHttpResponse(statusCode: 500, body: ''),
      );

    final metrics = await monitor().sample(_config());

    expect(metrics.activeSlots, 1);
    expect(metrics.totalSlots, 2);
    expect(metrics.contextUsageRatio, closeTo(350 / 4096, 1e-12));
  });

  test('throws a httpError when /metrics is unparseable', () async {
    httpClient.addResponse(
      '/metrics',
      const ServerHttpResponse(statusCode: 200, body: 'not a metric'),
    );

    await expectLater(
      monitor().sample(_config()),
      throwsA(
        isA<ServerException>().having(
          (error) => error.failure.code,
          'code',
          ServerFailureCode.httpError,
        ),
      ),
    );
  });

  test('throws a httpError with a non-leaking message on timeout', () async {
    final hanging = _HangingHttpClient();
    final timed = ServerMonitor(
      httpClient: hanging,
      timeout: const Duration(milliseconds: 20),
      clock: () => 1700000100000,
    );

    await expectLater(
      timed.sample(_config(apiKey: 'secret-token')),
      throwsA(
        isA<ServerException>()
            .having(
              (error) => error.failure.code,
              'code',
              ServerFailureCode.httpError,
            )
            .having(
              (error) => error.failure.message,
              'message',
              'metrics unavailable (timeout)',
            )
            .having(
              (error) => error.failure.message,
              'secret-free message',
              isNot(contains('secret-token')),
            )
            .having(
              (error) => error.failure.message,
              'no bearer header',
              isNot(contains('Bearer')),
            ),
      ),
    );
  });
}
