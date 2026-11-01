import 'dart:async';
import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late HttpRuntimeFetcher fetcher;
  final requests = <_SeenRequest>[];
  Completer<void>? slowRelease;
  const body = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  setUp(() async {
    requests.clear();
    slowRelease = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        requests.add(
          _SeenRequest(
            path: request.uri.path,
            userAgent: request.headers.value(HttpHeaders.userAgentHeader),
            range: request.headers.value(HttpHeaders.rangeHeader),
            ifRange: request.headers.value('if-range'),
          ),
        );
        final response = request.response;
        switch (request.uri.path) {
          case '/asset':
            final range = request.headers.value(HttpHeaders.rangeHeader);
            final ifRange = request.headers.value('if-range');
            if (range != null && ifRange == '"asset-etag"') {
              final match = RegExp(r'bytes=(\d+)-').firstMatch(range);
              final start = int.parse(match!.group(1)!);
              response.statusCode = HttpStatus.partialContent;
              response.headers.set('ETag', '"asset-etag"');
              response.headers.set(
                HttpHeaders.contentRangeHeader,
                'bytes $start-${body.length - 1}/${body.length}',
              );
              response.contentLength = body.length - start;
              response.add(body.sublist(start));
            } else {
              response.headers.set('ETag', '"asset-etag"');
              response.contentLength = body.length;
              response.add(body);
            }
          case '/redirect':
            response.statusCode = HttpStatus.found;
            response.headers.set(HttpHeaders.locationHeader, '/asset');
          case '/missing':
            response.statusCode = HttpStatus.notFound;
            response.write('missing');
          case '/slow':
            response.bufferOutput = false;
            response.add(<int>[1, 2, 3, 4]);
            await response.flush();
            slowRelease = Completer<void>();
            await slowRelease!.future;
        }
        await response.close();
      } on Object {
        // A cancelled client closes the socket under the handler.
      }
    });
    fetcher = HttpRuntimeFetcher(cliVersion: '9.9.9');
  });

  tearDown(() async {
    if (slowRelease != null && !slowRelease!.isCompleted) {
      slowRelease!.complete();
    }
    fetcher.close();
    await server.close(force: true);
  });

  Uri uri(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<List<int>> read(Stream<List<int>> bytes) =>
      bytes.expand((chunk) => chunk).toList();

  test('returns status, length and ETag with the user agent', () async {
    final response = await fetcher.open(uri('/asset'));

    expect(response.statusCode, 200);
    expect(response.contentLength, body.length);
    expect(response.etag, '"asset-etag"');
    expect(response.contentRangeStart, isNull);
    expect(await read(response.bytes), body);
    expect(requests.single.userAgent, 'llamapulse/9.9.9');
  });

  test('follows a redirect', () async {
    final response = await fetcher.open(uri('/redirect'));

    expect(response.statusCode, 200);
    expect(await read(response.bytes), body);
    expect(requests.map((request) => request.path).toList(), <String>[
      '/redirect',
      '/asset',
    ]);
    expect(requests.last.userAgent, 'llamapulse/9.9.9');
  });

  test('keeps Range and If-Range across a redirect', () async {
    final first = await fetcher.open(uri('/redirect'));
    await read(first.bytes);

    final resumed = await fetcher.open(uri('/redirect'), resumeFrom: 4);
    final received = await read(resumed.bytes);

    expect(resumed.statusCode, 206);
    expect(resumed.contentRangeStart, 4);
    expect(received, body.sublist(4));
    final hops = requests.sublist(requests.length - 2);
    expect(hops.map((request) => request.path).toList(), <String>[
      '/redirect',
      '/asset',
    ]);
    expect(hops.every((request) => request.range == 'bytes=4-'), isTrue);
    expect(hops.every((request) => request.ifRange == '"asset-etag"'), isTrue);
  });

  test('sends Range and If-Range when resuming', () async {
    final first = await fetcher.open(uri('/asset'));
    await read(first.bytes);

    final resumed = await fetcher.open(uri('/asset'), resumeFrom: 4);
    final received = await read(resumed.bytes);

    expect(resumed.statusCode, 206);
    expect(resumed.contentRangeStart, 4);
    expect(resumed.contentLength, body.length - 4);
    expect(received, body.sublist(4));
    expect(requests.last.range, 'bytes=4-');
    expect(requests.last.ifRange, '"asset-etag"');
  });

  test('maps a non-2xx response to httpStatus', () async {
    await expectLater(
      fetcher.open(uri('/missing')),
      throwsA(
        isA<RuntimeException>()
            .having(
              (error) => error.code,
              'code',
              RuntimeFailureCode.httpStatus,
            )
            .having((error) => error.actual, 'actual', 404)
            .having((error) => error.message, 'message', contains('404')),
      ),
    );
  });

  test('maps a connection failure to network', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await socket.close();
    });
    socket.listen((client) => client.destroy());

    await expectLater(
      fetcher.open(Uri.parse('http://127.0.0.1:${socket.port}/')),
      throwsA(
        isA<RuntimeException>().having(
          (error) => error.code,
          'code',
          RuntimeFailureCode.network,
        ),
      ),
    );
  });

  test('aborts the request when the token is cancelled', () async {
    final cancel = RuntimeCancelToken();
    final response = await fetcher.open(uri('/slow'), cancel: cancel);
    var received = 0;

    await response.bytes
        .forEach((chunk) {
          received += chunk.length;
          cancel.cancel();
        })
        .catchError((Object _) {})
        .timeout(const Duration(seconds: 3));

    expect(received, greaterThan(0));
  });
}

final class _SeenRequest {
  const _SeenRequest({
    required this.path,
    this.userAgent,
    this.range,
    this.ifRange,
  });

  final String path;
  final String? userAgent;
  final String? range;
  final String? ifRange;
}
