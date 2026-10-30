import '../entities/inference_failure.dart';

/// Thrown inside a worker when an [InferenceFailure] must cross a call boundary.
///
/// The worker catches it and maps it to a failure response; it never reaches
/// the UI isolate as an exception.
final class InferenceFailureException implements Exception {
  /// Creates an exception carrying [failure].
  const InferenceFailureException(this.failure);

  /// Structured reason for the failure.
  final InferenceFailure failure;

  @override
  String toString() => '${failure.code.name}: ${failure.message}';
}
