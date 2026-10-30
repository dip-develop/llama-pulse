/// Allowed ranges for [ModelParams] fields.
///
/// These bounds are validated in the domain layer; native code does not check
/// them and must not be trusted to reject out-of-range values.
abstract final class ModelParamLimits {
  /// Smallest accepted context window, in tokens.
  static const int minContextSize = 128;

  /// Largest accepted context window, in tokens.
  static const int maxContextSize = 1048576;

  /// Smallest accepted GPU layer count.
  static const int minGpuLayers = 0;

  /// Largest accepted GPU layer count.
  static const int maxGpuLayers = 999;

  /// Smallest accepted thread count.
  static const int minThreads = 1;

  /// Largest accepted thread count.
  static const int maxThreads = 256;

  /// Smallest accepted sampling temperature.
  static const double minTemperature = 0.0;

  /// Largest accepted sampling temperature.
  static const double maxTemperature = 2.0;

  /// Smallest accepted nucleus sampling probability.
  static const double minTopP = 0.0;

  /// Largest accepted nucleus sampling probability.
  static const double maxTopP = 1.0;

  /// Smallest accepted top-k cutoff.
  static const int minTopK = 1;

  /// Largest accepted top-k cutoff.
  static const int maxTopK = 1000;

  /// Smallest accepted generation token budget.
  static const int minMaxTokens = 1;

  /// Largest accepted generation token budget.
  static const int maxMaxTokens = 131072;
}
