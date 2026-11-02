import 'dart:async';
import 'dart:io';

import '../../domain/runtime/runtime_failure.dart';
import '../../domain/runtime/runtime_fetcher.dart';

/// Downloads runtime archives over `dart:io`'s [HttpClient].
///
/// The fetcher follows up to five redirects, disables transparent gzip
/// decoding (checksums are over the bytes on the wire), and remembers each
/// URI's ETag so a later resume can send `If-Range` and let the server decide
/// whether the partial file is still valid.
final class HttpRuntimeFetcher implements RuntimeFetcher {
  /// Creates a fetcher.
  ///
  /// [cliVersion] becomes the `llamapulse/<version>` user agent. Passing
  /// [client] is for tests; the fetcher still applies its timeout and
  /// decompression settings to it.
  factory HttpRuntimeFetcher({
    String cliVersion = '0.1.0',
    HttpClient? client,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration idleTimeout = const Duration(seconds: 60),
    int maxRedirects = 5,
  }) {
    final http = client ?? HttpClient();
    http
      ..autoUncompress = false
      ..connectionTimeout = connectTimeout;
    return HttpRuntimeFetcher._(
      'llamapulse/$cliVersion',
      http,
      connectTimeout: connectTimeout,
      idleTimeout: idleTimeout,
      maxRedirects: maxRedirects,
    );
  }

  HttpRuntimeFetcher._(
    this._userAgent,
    this._client, {
    required this.connectTimeout,
    required this.idleTimeout,
    required this.maxRedirects,
  });

  /// How long a connection may take to open, and how long the server may take
  /// to send response headers.
  final Duration connectTimeout;

  /// How long the body may be silent before the download is failed.
  final Duration idleTimeout;

  /// Maximum redirects the client follows for one request.
  final int maxRedirects;

  final String _userAgent;
  final HttpClient _client;
  final Map<Uri, String> _etags = <Uri, String>{};
  bool _closed = false;

  @override
  Future<RuntimeFetchResponse> open(
    Uri uri, {
    int? resumeFrom,
    RuntimeCancelToken? cancel,
  }) async {
    if (_closed) {
      throw StateError('the runtime fetcher is closed');
    }

    HttpClientRequest? activeRequest;
    try {
      final headers = <String, String>{
        HttpHeaders.userAgentHeader: _userAgent,
        HttpHeaders.acceptEncodingHeader: 'identity',
      };
      if (resumeFrom != null && resumeFrom > 0) {
        headers[HttpHeaders.rangeHeader] = 'bytes=$resumeFrom-';
        final etag = _etags[uri];
        if (etag != null && etag.isNotEmpty) {
          headers['If-Range'] = etag;
        }
      }

      if (cancel != null) {
        unawaited(
          cancel.whenCancelled.then((_) {
            _abort(activeRequest);
          }),
        );
      }

      // Redirects are followed by hand: HttpClient does not carry custom
      // headers such as User-Agent and Range across a redirect, and GitHub
      // answers a release download with a 302 to a CDN. Losing Range there
      // would silently turn every resume into a full download.
      var current = uri;
      var redirects = 0;
      while (true) {
        if (cancel?.isCancelled ?? false) {
          throw const RuntimeException(
            RuntimeFailureCode.cancelled,
            'the download was cancelled',
          );
        }

        final request = await _client.getUrl(current).timeout(connectTimeout);
        activeRequest = request;
        request
          ..followRedirects = false
          ..maxRedirects = 0;
        for (final entry in headers.entries) {
          request.headers.set(entry.key, entry.value);
        }

        final response = await request.close().timeout(connectTimeout);
        if (_isRedirect(response.statusCode)) {
          redirects++;
          if (redirects > maxRedirects) {
            await _discard(response);
            throw RuntimeException(
              RuntimeFailureCode.network,
              'GET $uri exceeded $maxRedirects redirects',
              actual: redirects,
            );
          }
          final location = response.headers.value(HttpHeaders.locationHeader);
          await _discard(response);
          if (location == null || location.isEmpty) {
            throw RuntimeException(
              RuntimeFailureCode.network,
              'GET $current redirected without a Location header',
            );
          }
          current = current.resolve(location);
          continue;
        }

        final statusCode = response.statusCode;
        if (statusCode < 200 || statusCode >= 300) {
          await _discard(response);
          throw RuntimeException(
            RuntimeFailureCode.httpStatus,
            'GET $uri answered HTTP $statusCode',
            actual: statusCode,
          );
        }

        final etag = response.headers.value(HttpHeaders.etagHeader);
        if (etag != null && etag.isNotEmpty) {
          _etags[uri] = etag;
          _etags[current] = etag;
        }
        final contentLength = response.contentLength;
        return RuntimeFetchResponse(
          statusCode: statusCode,
          contentLength: contentLength < 0 ? null : contentLength,
          etag: etag,
          contentRangeStart: parseContentRangeStart(
            response.headers.value('content-range'),
          ),
          bytes: _body(current, request, response, cancel),
        );
      }
    } on RuntimeException {
      rethrow;
    } on Object catch (error) {
      if (cancel?.isCancelled ?? false) {
        throw const RuntimeException(
          RuntimeFailureCode.cancelled,
          'the download was cancelled',
        );
      }
      throw RuntimeException(
        RuntimeFailureCode.network,
        'GET $uri failed: $error',
        cause: error,
      );
    }
  }

  /// Wraps the response body in a stream that can be paused and aborted.
  ///
  /// The controller propagates pause and resume to the HTTP subscription, so a
  /// slow disk never makes the client buffer a whole archive in memory. A
  /// cancellation aborts the request and closes the stream with a
  /// [RuntimeFailureCode.cancelled] error.
  Stream<List<int>> _body(
    Uri uri,
    HttpClientRequest request,
    HttpClientResponse response,
    RuntimeCancelToken? cancel,
  ) {
    late StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    var closed = false;

    controller = StreamController<List<int>>(
      onListen: () {
        if (closed) {
          return;
        }
        subscription = response
            .timeout(idleTimeout)
            .listen(
              (chunk) {
                if (!closed) {
                  controller.add(chunk);
                }
              },
              onError: (Object error, StackTrace stackTrace) {
                if (closed) {
                  return;
                }
                closed = true;
                controller.addError(
                  _mapBodyError(uri, error, cancel),
                  stackTrace,
                );
                unawaited(controller.close());
              },
              onDone: () {
                if (closed) {
                  return;
                }
                closed = true;
                unawaited(controller.close());
              },
            );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        closed = true;
        _abort(request);
        final active = subscription;
        subscription = null;
        unawaited(active?.cancel() ?? Future<void>.value());
        return Future<void>.value();
      },
    );

    if (cancel != null) {
      unawaited(
        cancel.whenCancelled.then((_) async {
          if (closed) {
            return;
          }
          closed = true;
          _abort(request);
          final active = subscription;
          subscription = null;
          // Cancel the HTTP subscription in the background: waiting for it
          // can block until the socket is released, which is exactly what a
          // stalled server will not do.
          unawaited(active?.cancel() ?? Future<void>.value());
          if (!controller.isClosed) {
            controller.addError(
              const RuntimeException(
                RuntimeFailureCode.cancelled,
                'the download was cancelled',
              ),
            );
            await controller.close();
          }
        }),
      );
    }

    return controller.stream;
  }

  static RuntimeException _mapBodyError(
    Uri uri,
    Object error,
    RuntimeCancelToken? cancel,
  ) {
    if (cancel?.isCancelled ?? false) {
      return const RuntimeException(
        RuntimeFailureCode.cancelled,
        'the download was cancelled',
      );
    }
    return RuntimeException(
      RuntimeFailureCode.network,
      'GET $uri failed while reading the body: $error',
      cause: error,
    );
  }

  @override
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _client.close(force: true);
  }

  /// Reads the first byte of a `Content-Range` response header.
  ///
  /// Returns null for a missing, `*` or malformed header, which makes the
  /// downloader restart rather than append to a part it cannot trust.
  static int? parseContentRangeStart(String? header) {
    if (header == null) {
      return null;
    }
    final match = _contentRange.firstMatch(header.trim());
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  static void _abort(HttpClientRequest? request) {
    try {
      request?.abort();
    } on Object {
      // The request already completed or was aborted by the client.
    }
  }

  static bool _isRedirect(int statusCode) =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  static Future<void> _discard(HttpClientResponse response) async {
    try {
      await response.drain<void>();
    } on Object {
      // The status is what matters; a broken error body changes nothing.
    }
  }

  static final RegExp _contentRange = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$');
}
