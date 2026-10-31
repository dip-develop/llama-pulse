import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/gateways/server_http_client.dart';

/// Sends probe requests over `dart:io`'s [HttpClient].
final class DartServerHttpClient implements ServerHttpClient {
  /// Creates a client with 3 s connect and per-request timeouts.
  DartServerHttpClient() : _inner = HttpClient()..connectionTimeout = _timeout;

  static const Duration _timeout = Duration(seconds: 3);
  static const String _userAgent = 'llamapulse/0.1.0';

  final HttpClient _inner;
  bool _closed = false;

  @override
  Future<ServerHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    if (_closed) {
      throw StateError('the HTTP client is closed');
    }
    final request = await _inner.getUrl(uri).timeout(_timeout);
    request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    final response = await request.close().timeout(_timeout);
    // Reading the body to the end also drains the response and returns the
    // connection to the pool.
    final body = await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join()
        .timeout(_timeout);

    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name] = values.join(', ');
    });
    return ServerHttpResponse(
      statusCode: response.statusCode,
      body: body,
      headers: Map.unmodifiable(responseHeaders),
    );
  }

  @override
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _inner.close(force: true);
  }
}
