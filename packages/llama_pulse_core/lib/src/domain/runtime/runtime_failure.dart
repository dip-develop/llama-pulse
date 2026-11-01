/// Why a runtime download or extraction failed.
enum RuntimeFailureCode {
  /// The connection failed, timed out or was cut off.
  network,

  /// The server answered with a status outside the 2xx range.
  httpStatus,

  /// The downloaded bytes do not match the pinned SHA-256.
  checksumMismatch,

  /// Fewer or more bytes arrived than the pinned asset size.
  sizeMismatch,

  /// There is not enough free space for the archive and its unpacked tree.
  diskSpace,

  /// The archive could not be decoded or written to disk.
  extraction,

  /// The archive contains a path, link, type or size that is not safe to
  /// extract.
  unsafeArchive,

  /// The runtime manifest cannot be built or written.
  manifest,

  /// The caller cancelled the download.
  cancelled,

  /// An unexpected failure, for example a broken staging directory.
  unknown,
}

/// A runtime install failure carrying a machine-readable [code].
final class RuntimeException implements Exception {
  /// Creates a failure.
  const RuntimeException(
    this.code,
    this.message, {
    this.expected,
    this.actual,
    this.cause,
  });

  /// What went wrong.
  final RuntimeFailureCode code;

  /// Human-readable detail, safe to show in a CLI.
  final String message;

  /// The expected value for a size or digest check.
  final Object? expected;

  /// The value that was actually observed.
  final Object? actual;

  /// The underlying error, when there is one.
  final Object? cause;

  @override
  String toString() {
    final buffer = StringBuffer('RuntimeException(${code.name}): $message');
    if (expected != null || actual != null) {
      buffer
        ..write(' (expected: ')
        ..write(expected ?? 'unknown')
        ..write(', actual: ')
        ..write(actual ?? 'unknown')
        ..write(')');
    }
    return buffer.toString();
  }
}
