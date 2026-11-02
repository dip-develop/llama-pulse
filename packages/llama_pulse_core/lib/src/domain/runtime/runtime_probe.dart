import 'runtime_backend.dart';
import 'runtime_platform.dart';
import 'runtime_recommendation.dart';

/// A GPU the probe found through the platform's vendor tooling.
final class RuntimeGpu {
  /// Creates a GPU description.
  const RuntimeGpu({
    required this.name,
    required this.vendor,
    required this.driverVersion,
    this.memoryBytes,
  });

  /// Name reported by the vendor tool, for example `NVIDIA GeForce RTX 4090`.
  final String name;

  /// Vendor id, for example `nvidia` or `amd`.
  final String vendor;

  /// Driver version reported by the vendor tool.
  final String driverVersion;

  /// Total memory in bytes, when the vendor tool reported it.
  final int? memoryBytes;
}

/// Everything the probe learned about the host.
final class RuntimeHardware {
  /// Creates a hardware snapshot.
  RuntimeHardware({
    required this.operatingSystem,
    required this.arch,
    required this.platform,
    List<RuntimeGpu> gpus = const <RuntimeGpu>[],
    this.hasVulkan = false,
    this.hasRocm = false,
    this.hasCuda = false,
  }) : gpus = List<RuntimeGpu>.unmodifiable(gpus);

  /// Normalized operating system: `linux`, `windows`, `macos` or the raw
  /// `Platform.operatingSystem` value when it is unsupported.
  final String operatingSystem;

  /// Normalized architecture: `x64`, `arm64` or the raw value when unknown.
  final String arch;

  /// The platform id the pinned release uses.
  ///
  /// Null means the pinned release has no archive for this host. Intel macOS
  /// aliases to [RuntimePlatform.macosArm64] because the platform enum only
  /// models the archive family; [arch] keeps the real architecture.
  final RuntimePlatform? platform;

  /// Every GPU the vendor tools reported.
  final List<RuntimeGpu> gpus;

  /// Whether a Vulkan loader or a successful `vulkaninfo --summary` was found.
  final bool hasVulkan;

  /// Whether an AMD ROCm stack was found.
  final bool hasRocm;

  /// Whether `nvidia-smi` reported at least one NVIDIA GPU.
  final bool hasCuda;

  /// Whether this is Apple silicon, the only macOS host the release targets.
  bool get isAppleSilicon =>
      platform == RuntimePlatform.macosArm64 && arch == 'arm64';
}

/// Detects the host hardware and the pinned backends it can run.
abstract interface class RuntimeProbe {
  /// Probes the host.
  ///
  /// Never throws: a host the pinned release does not target reports no
  /// platform, no verdicts and no recommendation.
  Future<RuntimeDetection> probe();
}

/// The result of probing one host: hardware, per-backend verdicts and the
/// default backend to offer.
final class RuntimeDetection {
  /// Creates a detection result.
  RuntimeDetection({
    required this.hardware,
    required List<BackendSupport> supports,
    this.recommendation,
  }) : supports = List<BackendSupport>.unmodifiable(supports);

  /// What the probe found on the host.
  final RuntimeHardware hardware;

  /// One verdict per backend the pinned release could offer on this host.
  final List<BackendSupport> supports;

  /// The backend a fresh install should default to, or null when the host is
  /// not supported.
  final RuntimeRecommendation? recommendation;

  /// The recommended backend, when there is one.
  RuntimeBackend? get recommendedBackend => recommendation?.backend;

  /// Why [recommendedBackend] won, when there is one.
  String? get recommendedReason => recommendation?.reason;

  /// The verdict for [backend], or null when it is unavailable on this host.
  BackendSupport? supportFor(RuntimeBackend backend) {
    for (final support in supports) {
      if (support.backend == backend) {
        return support;
      }
    }
    return null;
  }

  /// Whether [backend] can run on this host.
  bool isSupported(RuntimeBackend backend) =>
      supportFor(backend)?.supported ?? false;
}
