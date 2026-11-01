import 'dart:math' as math;

import '../../domain/entities/model_params.dart';

/// Runtime values of the embedded catalog parameters that have no typed field
/// on [ModelParams]: `min-p`, `seed` and `batch-size`.
///
/// The three values live in [ModelParams.params] as canonical strings. The
/// validator gates every stored document and every `run`/`bench`/`params
/// export` call, so [resolve] treats an unparseable or out-of-range value as
/// "not set" and falls back to the documented default instead of failing in
/// the middle of inference.
final class EmbeddedRuntimeConfig {
  /// Creates a resolved runtime configuration.
  const EmbeddedRuntimeConfig({
    required this.minP,
    required this.seed,
    required this.batchSize,
  });

  /// Resolves the runtime values stored on [params].
  ///
  /// `batch-size` is relative to [ModelParams.contextSize] and never exceeds
  /// it. An absent value resolves to llama.cpp's default: min-p [defaultMinP],
  /// the random [defaultSeed] and a batch size of
  /// `min(defaultBatchSizeCap, contextSize)`.
  static EmbeddedRuntimeConfig resolve(ModelParams params) =>
      EmbeddedRuntimeConfig(
        minP: _minP(params.params['min-p']),
        seed: _seed(params.params['seed']),
        batchSize: _batchSize(params.params['batch-size'], params.contextSize),
      );

  /// Min-p that llama.cpp applies when the parameter is not set.
  static const double defaultMinP = 0.05;

  /// `LLAMA_DEFAULT_SEED` from `llama.h`; llama.cpp treats it as random.
  static const int defaultSeed = 0xFFFFFFFF;

  /// Largest batch size used when `batch-size` is not set.
  static const int defaultBatchSizeCap = 512;

  /// Minimum sampling probability relative to the most likely token.
  final double minP;

  /// Seed for the distribution sampler; [defaultSeed] means random.
  final int seed;

  /// Logical batch size, never larger than the configured context.
  final int batchSize;

  /// Parses `min-p`, falling back to [defaultMinP] outside `0..1`.
  static double _minP(String? raw) {
    if (raw == null) {
      return defaultMinP;
    }
    final value = double.tryParse(raw.trim());
    if (value == null || !value.isFinite || value < 0 || value > 1) {
      return defaultMinP;
    }
    return value;
  }

  /// Parses `seed`, mapping `-1` to [defaultSeed] and clamping to 32 bits.
  static int _seed(String? raw) {
    if (raw == null) {
      return defaultSeed;
    }
    final value = int.tryParse(raw.trim());
    if (value == null) {
      return defaultSeed;
    }
    // `-1` is the catalog default and means "draw a random seed", which
    // llama.cpp spells as LLAMA_DEFAULT_SEED. Every other value is clamped to
    // the uint32 range llama_sampler_init_dist accepts.
    if (value == -1) {
      return defaultSeed;
    }
    if (value < 0) {
      return 0;
    }
    return value > defaultSeed ? defaultSeed : value;
  }

  /// Parses `batch-size`, capped at [contextSize].
  static int _batchSize(String? raw, int contextSize) {
    // The validator rejects a context below 128, but a direct caller may still
    // pass 0; llama.cpp needs a positive batch size, so never resolve to 0.
    final limit = math.max(1, contextSize);
    final fallback = math.min(defaultBatchSizeCap, limit);
    if (raw == null) {
      return fallback;
    }
    final value = int.tryParse(raw.trim());
    if (value == null || value <= 0) {
      return fallback;
    }
    return math.min(value, limit);
  }
}
