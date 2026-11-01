import 'dart:async';

/// Opens HTTP downloads for the runtime installer.
///
/// The interface is deliberately small: the downloader only needs one open
/// response at a time, a byte stream, and the headers that decide whether a
/// partial download can be resumed.
abstract interface class RuntimeFetcher {
  /// Starts a GET for [uri].
  ///
  /// When [resumeFrom] is a positive byte offset the implementation asks the
  /// server for the remainder with a `Range` header. A server that honours it
  /// answers `206` and reports the offset it started at through
  /// [RuntimeFetchResponse.contentRangeStart]; a server that ignores the range
  /// answers `200` with the whole file.
  ///
  /// A response outside the 2xx range is an error: implementations throw a
  /// [RuntimeException] with [RuntimeFailureCode.httpStatus] after draining the
  /// body, so a caller never has to inspect a failed response.
  Future<RuntimeFetchResponse> open(
    Uri uri, {
    int? resumeFrom,
    RuntimeCancelToken? cancel,
  });

  /// Releases every connection the fetcher owns.
  ///
  /// Closing twice is allowed.
  void close();
}

/// One successful open download.
final class RuntimeFetchResponse {
  /// Creates a response over [bytes].
  const RuntimeFetchResponse({
    required this.statusCode,
    required this.bytes,
    this.contentLength,
    this.etag,
    this.contentRangeStart,
  });

  /// HTTP status, either `200` for a whole file or `206` for a range.
  final int statusCode;

  /// Size of the body that follows, or null when the server did not say.
  ///
  /// For a `206` this is the remainder, not the size of the whole file.
  final int? contentLength;

  /// The server's entity tag, when it sent one.
  ///
  /// The downloader keeps this out of band and hands it back to
  /// [RuntimeFetcher.open] through the fetcher's own memory; it never writes it
  /// to disk.
  final String? etag;

  /// First byte of [bytes] in the whole file, for a `206` response.
  ///
  /// Null for `200` and for a `206` whose `Content-Range` header is missing or
  /// malformed. The downloader resumes only when this equals the offset it
  /// asked for; anything else is treated as a full restart.
  final int? contentRangeStart;

  /// The response body.
  final Stream<List<int>> bytes;
}

/// A cooperative cancellation signal shared by a caller and a download.
///
/// The downloader checks it between chunks and the HTTP fetcher aborts the
/// request when it fires, so a cancelled download stops even when the server
/// has gone quiet.
final class RuntimeCancelToken {
  final Completer<void> _cancelled = Completer<void>();

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is called.
  ///
  /// It never completes for a token that is not cancelled.
  Future<void> get whenCancelled => _cancelled.future;

  /// Signals cancellation. Calling it more than once is a no-op.
  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }
}

/// How far a runtime download has got.
final class RuntimeProgress {
  /// Creates a progress snapshot.
  const RuntimeProgress({
    required this.received,
    required this.total,
    required this.bytesPerSecond,
  });

  /// Bytes written to the partial archive so far, including resumed bytes.
  final int received;

  /// Expected size of the whole archive, from the pinned asset.
  final int total;

  /// Throughput of the current session in bytes per second.
  final double bytesPerSecond;

  /// Fraction complete, clamped to `0..1` for a zero or unknown total.
  double get fraction =>
      total <= 0 ? 0 : (received / total).clamp(0, 1).toDouble();
}
