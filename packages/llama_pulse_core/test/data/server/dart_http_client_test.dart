import 'dart:convert';
import 'dart:io';

import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late DartServerHttpClient client;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/missing') {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('nope');
      } else {
        request.response.headers.set('x-test', 'value');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'ok': true,
            'authorization': request.headers.value(
              HttpHeaders.authorizationHeader,
            ),
            'userAgent': request.headers.value(HttpHeaders.userAgentHeader),
          }),
        );
      }
      await request.response.close();
    });
    client = DartServerHttpClient();
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  Uri uri(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  test('returns status, body and headers', () async {
    final response = await client.get(uri('/health'));

    expect(response.statusCode, 200);
    expect(response.headers['x-test'], 'value');
    expect(response.headers['content-type'], startsWith('application/json'));
    final body = jsonDecode(response.body) as Map<String, Object?>;
    expect(body['ok'], isTrue);
    expect(body['userAgent'], 'llamapulse/0.1.0');
  });

  test('forwards caller headers untouched', () async {
    final response = await client.get(
      uri('/health'),
      headers: {'Authorization': 'Bearer secret'},
    );

    final body = jsonDecode(response.body) as Map<String, Object?>;
    expect(body['authorization'], 'Bearer secret');
  });

  test('returns a 404 response instead of throwing', () async {
    final response = await client.get(uri('/missing'));

    expect(response.statusCode, 404);
    expect(response.body, 'nope');
  });

  test('close is idempotent', () {
    client.close();
    expect(() => client.close(), returnsNormally);
  });
}
