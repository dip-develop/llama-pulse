import 'dart:math';

import 'package:llama_pulse_core/llama_pulse_core.dart';

/// A [RuntimeFetcher] that serves in-memory bytes without a socket.
///
/// Every test gets exactly the network behaviour it asks for: missing routes
/// answer 404, `honourResume` decides between 206 and 200, and `truncateTo`
/// cuts a body short. No test ever reaches the network.
final class FakeRuntimeFetcher implements RuntimeFetcher {
  FakeRuntimeFetcher({
    Map<String, List<int>>? routes,
    this.etag = '"fake-etag"',
    this.chunkSize = 1024,
    this.honourResume = true,
    this.truncateTo,
    this.onChunk,
    this.openError,
  }) : routes = routes ?? <String, List<int>>{};

  /// Body bytes keyed by full URL.
  final Map<String, List<int>> routes;

  /// Entity tag sent with every response.
  final String etag;

  /// Largest chunk the body stream emits.
  final int chunkSize;

  /// Whether a range request is answered with 206 instead of 200.
  final bool honourResume;

  /// When set, the body stops after that many bytes have been sent.
  final int? truncateTo;

  /// Called after each chunk with the bytes sent so far and the token.
  ///
  /// Tests use it to cancel halfway through.
  final void Function(int sent, RuntimeCancelToken? cancel)? onChunk;

  /// When set, [open] throws it instead of returning a response.
  final Object? openError;

  /// Every open call in order.
  final List<FakeFetchRequest> requests = <FakeFetchRequest>[];

  /// How often [close] was called.
  int closeCalls = 0;

  bool _closed = false;

  @override
  Future<RuntimeFetchResponse> open(
    Uri uri, {
    int? resumeFrom,
    RuntimeCancelToken? cancel,
  }) async {
    if (_closed) {
      throw StateError('the fake fetcher is closed');
    }
    requests.add(FakeFetchRequest(uri: uri, resumeFrom: resumeFrom));
    final error = openError;
    if (error != null) {
      throw error;
    }

    final bytes = routes[uri.toString()];
    if (bytes == null) {
      return RuntimeFetchResponse(
        statusCode: 404,
        contentLength: 0,
        etag: null,
        bytes: const Stream<List<int>>.empty(),
      );
    }

    final asked = resumeFrom ?? 0;
    final start = honourResume && asked > 0 && asked < bytes.length ? asked : 0;
    final body = bytes.sublist(start);
    final statusCode = start > 0 ? 206 : 200;

    return RuntimeFetchResponse(
      statusCode: statusCode,
      contentLength: body.length,
      etag: etag,
      contentRangeStart: start > 0 ? start : null,
      bytes: _chunks(body, cancel),
    );
  }

  Stream<List<int>> _chunks(List<int> body, RuntimeCancelToken? cancel) async* {
    var sent = 0;
    for (var offset = 0; offset < body.length; offset += chunkSize) {
      final end = min(offset + chunkSize, body.length);
      final limit = truncateTo;
      var chunk = body.sublist(offset, end);
      if (limit != null && sent + chunk.length >= limit) {
        chunk = chunk.sublist(0, limit - sent);
        if (chunk.isNotEmpty) {
          yield chunk;
          sent += chunk.length;
          onChunk?.call(sent, cancel);
        }
        return;
      }
      yield chunk;
      sent += chunk.length;
      onChunk?.call(sent, cancel);
    }
  }

  @override
  void close() {
    closeCalls++;
    _closed = true;
  }
}

/// One open call made by the downloader.
final class FakeFetchRequest {
  const FakeFetchRequest({required this.uri, required this.resumeFrom});

  final Uri uri;
  final int? resumeFrom;

  @override
  String toString() => 'FakeFetchRequest($uri, from: $resumeFrom)';
}

/// A process executor that returns canned output and records the command.
final class FakeProcessExecutor implements ProcessExecutor {
  FakeProcessExecutor(this.output);

  final ProcessOutput output;
  String? executable;
  List<String>? arguments;

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    return output;
  }
}
