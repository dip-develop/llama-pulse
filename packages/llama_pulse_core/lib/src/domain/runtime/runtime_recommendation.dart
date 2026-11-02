import 'runtime_backend.dart';
import 'runtime_platform.dart';

/// Whether one backend can run on the probed host, and why.
final class BackendSupport {
  /// Creates a support verdict for [backend].
  const BackendSupport({
    required this.backend,
    required this.supported,
    required this.reason,
    this.recommended = false,
  });

  /// The backend this verdict describes.
  final RuntimeBackend backend;

  /// Whether the host has the driver and libraries the backend needs.
  final bool supported;

  /// Human-readable evidence for [supported], for example
  /// `nvidia driver 580.12 >= 580` or `libvulkan.so.1 not found`.
  final String reason;

  /// Whether this is the backend the probe picked as the default.
  final bool recommended;

  /// Returns a copy with [recommended] replaced.
  BackendSupport withRecommended(bool recommended) => BackendSupport(
    backend: backend,
    supported: supported,
    reason: reason,
    recommended: recommended,
  );
}

/// The default backend the probe picked and the evidence behind it.
final class RuntimeRecommendation {
  /// Creates a recommendation for [backend].
  const RuntimeRecommendation({required this.backend, required this.reason});

  /// The backend a fresh install should default to.
  final RuntimeBackend backend;

  /// Why [backend] won, taken from its [BackendSupport.reason].
  final String reason;

  /// The backend preference order for [platform].
  ///
  /// Metal is only ranked on macOS; everywhere else CUDA 13 is the first
  /// choice, then CUDA 12, ROCm, Vulkan and finally the CPU.
  static List<RuntimeBackend> rankingFor(RuntimePlatform? platform) {
    if (platform == RuntimePlatform.macosArm64) {
      return const <RuntimeBackend>[RuntimeBackend.metal, RuntimeBackend.cpu];
    }
    return const <RuntimeBackend>[
      RuntimeBackend.cuda13,
      RuntimeBackend.cuda12,
      RuntimeBackend.rocm,
      RuntimeBackend.vulkan,
      RuntimeBackend.cpu,
    ];
  }

  /// Picks the highest-ranked supported backend from [supports].
  ///
  /// Returns null when [supports] is empty, which only happens when the host
  /// platform is not one the pinned release targets.
  static RuntimeRecommendation? choose({
    required RuntimePlatform? platform,
    required Iterable<BackendSupport> supports,
  }) {
    final byBackend = <RuntimeBackend, BackendSupport>{
      for (final support in supports) support.backend: support,
    };
    for (final backend in rankingFor(platform)) {
      final support = byBackend[backend];
      if (support != null && support.supported) {
        return RuntimeRecommendation(backend: backend, reason: support.reason);
      }
    }
    return null;
  }
}
