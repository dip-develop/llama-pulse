import '../entities/server_failure.dart';

/// Thrown when a server operation cannot be completed.
///
/// Carries the same [ServerFailure] that is written into the persisted state,
/// so callers can report the failure and still read it later.
final class ServerException implements Exception {
  /// Creates an exception carrying [failure].
  const ServerException(this.failure);

  /// Structured reason for the failure.
  final ServerFailure failure;

  @override
  String toString() => '${failure.code.name}: ${failure.message}';
}
