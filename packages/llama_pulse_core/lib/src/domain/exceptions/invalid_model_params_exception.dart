/// Thrown when [ModelParams] values violate their declared limits.
///
/// The [violations] list contains one human-readable message per rejected
/// field, in field declaration order.
final class InvalidModelParamsException implements Exception {
  InvalidModelParamsException(List<String> violations)
    : violations = List.unmodifiable(violations);

  /// One message per violated field.
  final List<String> violations;

  @override
  String toString() => 'Invalid model parameters: ${violations.join('; ')}';
}
