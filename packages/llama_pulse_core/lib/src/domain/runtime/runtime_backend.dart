import 'runtime_platform.dart';

/// A llama.cpp compute backend that the pinned release ships as an archive.
///
/// The backend picks which archive to download and which `ggml` shared
/// libraries the loader must pre-open. Detection lives outside the domain; this
/// enum only describes what each backend needs and where it runs.
enum RuntimeBackend {
  /// Plain host CPU inference; always available.
  cpu(
    id: 'cpu',
    displayName: 'CPU',
    requires: 'No GPU driver; runs on the host CPU.',
    libraryStems: <String>['ggml-cpu'],
  ),

  /// NVIDIA CUDA 12.8 build.
  cuda12(
    id: 'cuda12',
    displayName: 'CUDA 12.8',
    requires: 'NVIDIA driver r525 or newer (CUDA 12.8 runtime).',
    libraryStems: <String>['ggml-cuda'],
  ),

  /// NVIDIA CUDA 13.4 build.
  cuda13(
    id: 'cuda13',
    displayName: 'CUDA 13.4',
    requires: 'NVIDIA driver r580 or newer (CUDA 13.4 runtime).',
    libraryStems: <String>['ggml-cuda'],
  ),

  /// Vulkan build, which drives AMD, Intel and NVIDIA GPUs through the loader.
  vulkan(
    id: 'vulkan',
    displayName: 'Vulkan',
    requires: 'A Vulkan 1.2+ loader and a working Vulkan driver.',
    libraryStems: <String>['ggml-vulkan'],
  ),

  /// AMD ROCm 10.0 build.
  rocm(
    id: 'rocm',
    displayName: 'ROCm 10.0',
    requires: 'An AMD GPU with ROCm 10.0 kernel support (amdgpu).',
    libraryStems: <String>['ggml-hip'],
  ),

  /// Apple Metal build; Apple silicon only.
  metal(
    id: 'metal',
    displayName: 'Metal',
    requires: 'macOS on Apple silicon; Metal ships with the OS.',
    libraryStems: <String>['ggml-metal'],
  );

  const RuntimeBackend({
    required this.id,
    required this.displayName,
    required this.requires,
    required this.libraryStems,
  });

  /// Stable wire string used in configuration, CLI flags and the runtime store.
  final String id;

  /// Human-readable name for the CLI and the GUI.
  final String displayName;

  /// The driver floor a host must meet before this build can run.
  final String requires;

  /// Shared-library base names that carry this backend.
  ///
  /// `ggml-cuda` resolves to `libggml-cuda.so` on Linux, `libggml-cuda.dylib`
  /// on macOS and `ggml-cuda.dll` on Windows.
  final List<String> libraryStems;

  /// Whether this backend accelerates a GPU rather than the CPU.
  bool get isGpu => this != RuntimeBackend.cpu;

  /// Whether the download must also fetch a CUDA runtime archive.
  ///
  /// CUDA builds link against `cudart` and ship it as a second archive; the
  /// other backends bundle what they need.
  bool get bundlesCudart =>
      this == RuntimeBackend.cuda12 || this == RuntimeBackend.cuda13;

  /// The shared libraries this backend is loaded through on [platform].
  ///
  /// The loader pre-opens these before the main `llama` library. They match the
  /// `.so` (Linux), `.dylib` (macOS) and `.dll` (Windows) files the archive
  /// ships.
  List<String> backendLibs(RuntimePlatform platform) => <String>[
    for (final stem in libraryStems) platform.sharedLibraryName(stem),
  ];

  /// Whether this build exists for [platform] in the pinned release.
  bool supports(RuntimePlatform platform) => switch (this) {
    RuntimeBackend.cpu => true,
    RuntimeBackend.metal => platform == RuntimePlatform.macosArm64,
    RuntimeBackend.cuda12 ||
    RuntimeBackend.rocm => platform == RuntimePlatform.linuxX64,
    RuntimeBackend.cuda13 || RuntimeBackend.vulkan =>
      platform == RuntimePlatform.linuxX64 ||
          platform == RuntimePlatform.windowsX64,
  };

  /// Backends worth offering on [platform], CPU first and then GPUs in the
  /// default preference order.
  ///
  /// This is a stable ordering, not a hardware judgement: a detection layer
  /// moves the backend it found to the front. Entries the pinned release has no
  /// archive for are dropped by the caller.
  static List<RuntimeBackend> recommendedFor(RuntimePlatform platform) =>
      <RuntimeBackend>[
        for (final backend in _preference)
          if (backend.supports(platform)) backend,
      ];

  /// Looks up a backend by its [id], or returns null when unknown.
  static RuntimeBackend? fromId(String id) {
    for (final backend in values) {
      if (backend.id == id) {
        return backend;
      }
    }
    return null;
  }

  static const List<RuntimeBackend> _preference = <RuntimeBackend>[
    RuntimeBackend.cpu,
    RuntimeBackend.cuda13,
    RuntimeBackend.cuda12,
    RuntimeBackend.rocm,
    RuntimeBackend.vulkan,
    RuntimeBackend.metal,
  ];
}
