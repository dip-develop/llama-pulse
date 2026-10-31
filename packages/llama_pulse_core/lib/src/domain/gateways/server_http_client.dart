/// A fully read HTTP response.
final class ServerHttpResponse {
  /// Creates a response; [headers] maps lower-case names to joined values.
  const ServerHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  /// HTTP status code.
  final int statusCode;

  /// Response body decoded as UTF-8.
  final String body;

  /// Response headers with case-insensitive, lower-case names.
  final Map<String, String> headers;
}

/// Sends probe requests to a running server.
///
/// Test seam: replaces the network with a fake client in supervisor tests.
abstract interface class ServerHttpClient {
  /// Sends a GET to [uri] and returns the fully read response.
  Future<ServerHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  });

  /// Releases open connections; safe to call more than once.
  void close();
}
