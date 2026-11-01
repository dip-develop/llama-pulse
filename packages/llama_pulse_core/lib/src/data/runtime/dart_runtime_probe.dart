import 'dart:io';

import '../../domain/gateways/process_executor.dart';
import '../../domain/runtime/runtime_backend.dart';
import '../../domain/runtime/runtime_platform.dart';
import '../../domain/runtime/runtime_probe.dart';
import '../../domain/runtime/runtime_recommendation.dart';
import '../server/dart_process_executor.dart';

/// Probes the host for the GPU backends the pinned release offers.
///
/// Every vendor command is best-effort: a missing tool, a timeout or garbage
/// output degrades that backend to `supported: false` and records the failure
/// in its reason. The probe never throws.
final class DartRuntimeProbe implements RuntimeProbe {
  /// Creates a probe that runs commands through [executor].
  ///
  /// The executor can also be overridden per [probe] call, which keeps tests
  /// free of real `nvidia-smi`, `rocm-smi` and `vulkaninfo` invocations.
  const DartRuntimeProbe({this.executor = const DartProcessExecutor()});

  /// The executor used when [probe] does not receive one.
  final ProcessExecutor executor;

  /// Detects the host hardware; every injectable knob of [probeWith] keeps its
  /// production default.
  @override
  Future<RuntimeDetection> probe() => probeWith();

  /// `libvulkan` locations checked on Linux, in order.
  static const List<String> linuxVulkanLibraries = <String>[
    'libvulkan.so.1',
    '/usr/lib/x86_64-linux-gnu/libvulkan.so.1',
    '/usr/lib64/libvulkan.so.1',
    '/usr/lib/libvulkan.so.1',
  ];

  /// `vulkan-1.dll` locations checked on Windows, in order.
  static const List<String> windowsVulkanLibraries = <String>[
    'vulkan-1.dll',
    r'C:\Windows\System32\vulkan-1.dll',
  ];

  /// Directories that hold Vulkan ICD manifests on Linux.
  static const List<String> linuxVulkanIcdDirectories = <String>[
    '/usr/share/vulkan/icd.d',
    '/etc/vulkan/icd.d',
  ];

  /// Probes the host and returns its hardware, verdicts and recommendation.
  ///
  /// [operatingSystem], [arch] and [fileExists] are injectable so tests never
  /// touch the real host. When omitted they read `Platform` and `dart:io`.
  Future<RuntimeDetection> probeWith({
    ProcessExecutor? executor,
    String? operatingSystem,
    String? arch,
    bool Function(String path)? fileExists,
  }) async {
    final os = (operatingSystem ?? Platform.operatingSystem).toLowerCase();
    final architecture = _normalizeArch(arch ?? _currentArch());
    final platform = _resolvePlatform(os, architecture);
    final exists = fileExists ?? _defaultExists;

    if (platform == null) {
      return RuntimeDetection(
        hardware: RuntimeHardware(
          operatingSystem: os,
          arch: architecture,
          platform: null,
        ),
        supports: const <BackendSupport>[],
      );
    }

    final runner = executor ?? this.executor;
    final gpus = <RuntimeGpu>[];
    var hasCuda = false;
    var hasRocm = false;
    var hasVulkan = false;
    String? vulkanReason;
    String? nvidiaDriver;
    String? nvidiaError;

    if (platform != RuntimePlatform.macosArm64) {
      final nvidia = await _run(runner, 'nvidia-smi', <String>[
        '--query-gpu=name,driver_version',
        '--format=csv,noheader',
      ]);
      final parsed = _parseNvidia(nvidia);
      gpus.addAll(parsed.gpus);
      nvidiaDriver = parsed.driverVersion;
      nvidiaError = parsed.error;
      hasCuda = parsed.gpus.isNotEmpty;

      final vulkan = await _probeVulkan(runner, exists, platform);
      hasVulkan = vulkan.supported;
      vulkanReason = vulkan.reason;
    }

    String? rocmVersion;
    String? rocmError;
    String? rocmHome;
    if (platform == RuntimePlatform.linuxX64) {
      final rocm = await _run(runner, 'rocm-smi', <String>[
        '--showdriverversion',
      ]);
      rocmVersion = rocm.ok ? _firstVersion(rocm.stdout) : null;
      rocmHome = _firstPresent(exists, const <String>['/opt/rocm']);
      hasRocm = rocm.ok || rocmVersion != null || rocmHome != null;
      rocmError = hasRocm
          ? null
          : 'no ROCm driver: ${_failure(rocm, 'rocm-smi')}; '
                '/opt/rocm not found';
      if (hasRocm) {
        gpus.add(
          RuntimeGpu(
            name: 'AMD GPU',
            vendor: 'amd',
            driverVersion: rocmVersion ?? 'unknown',
          ),
        );
      }
    }

    final hardware = RuntimeHardware(
      operatingSystem: os,
      arch: architecture,
      platform: platform,
      gpus: gpus,
      hasVulkan: hasVulkan,
      hasRocm: hasRocm,
      hasCuda: hasCuda,
    );

    final supports = _supportsFor(
      platform: platform,
      hardware: hardware,
      nvidiaDriver: nvidiaDriver,
      nvidiaError: nvidiaError,
      rocmVersion: rocmVersion,
      rocmError: rocmError,
      rocmHome: rocmHome,
      hasRocm: hasRocm,
      hasVulkan: hasVulkan,
      vulkanReason: vulkanReason,
    );
    final recommendation = RuntimeRecommendation.choose(
      platform: platform,
      supports: supports,
    );
    final ranked = <BackendSupport>[
      for (final support in supports)
        support.withRecommended(support.backend == recommendation?.backend),
    ];
    return RuntimeDetection(
      hardware: hardware,
      supports: ranked,
      recommendation: recommendation,
    );
  }

  Future<_VulkanResult> _probeVulkan(
    ProcessExecutor runner,
    bool Function(String path) exists,
    RuntimePlatform platform,
  ) async {
    final info = await _run(runner, 'vulkaninfo', const <String>['--summary']);
    final isWindows = platform == RuntimePlatform.windowsX64;
    final libraries = isWindows ? windowsVulkanLibraries : linuxVulkanLibraries;
    final icds = isWindows ? const <String>[] : linuxVulkanIcdDirectories;
    final loader = _firstPresent(exists, libraries);
    final icd = _firstPresent(exists, icds);
    final loaderName = isWindows ? 'vulkan-1.dll' : 'libvulkan.so.1';
    final supported = info.ok || loader != null;
    if (supported) {
      if (loader == null) {
        return _VulkanResult(
          supported: true,
          reason: 'vulkaninfo reports a working loader',
        );
      }
      if (info.ok) {
        return _VulkanResult(
          supported: true,
          reason: 'vulkaninfo reports a working loader; $loaderName present',
        );
      }
      return _VulkanResult(
        supported: true,
        reason: '$loaderName present; ${_failure(info, 'vulkaninfo')}',
      );
    }
    final buffer = StringBuffer('$loaderName not found');
    if (!info.ok) {
      buffer
        ..write('; ')
        ..write(_failure(info, 'vulkaninfo'));
    }
    if (icd != null) {
      buffer
        ..write(' (ICD manifests in ')
        ..write(icd)
        ..write(')');
    }
    return _VulkanResult(supported: false, reason: buffer.toString());
  }

  List<BackendSupport> _supportsFor({
    required RuntimePlatform platform,
    required RuntimeHardware hardware,
    required String? nvidiaDriver,
    required String? nvidiaError,
    required String? rocmVersion,
    required String? rocmError,
    required String? rocmHome,
    required bool hasRocm,
    required bool hasVulkan,
    required String? vulkanReason,
  }) {
    final supports = <BackendSupport>[];

    if (platform == RuntimePlatform.macosArm64) {
      if (hardware.isAppleSilicon) {
        supports.add(
          const BackendSupport(
            backend: RuntimeBackend.metal,
            supported: true,
            reason: 'macOS arm64 uses Metal',
          ),
        );
      }
    } else {
      final driverMajor = nvidiaDriver == null
          ? null
          : _majorVersion(nvidiaDriver);
      final cudaReason = nvidiaDriver == null
          ? (nvidiaError ?? 'no NVIDIA GPU detected')
          : null;
      supports.add(
        BackendSupport(
          backend: RuntimeBackend.cuda13,
          supported: driverMajor != null && driverMajor >= 580,
          reason:
              cudaReason ??
              _driverReason(
                driver: nvidiaDriver,
                floor: 580,
                met: driverMajor != null && driverMajor >= 580,
              ),
        ),
      );
      if (platform == RuntimePlatform.linuxX64) {
        supports.add(
          BackendSupport(
            backend: RuntimeBackend.cuda12,
            supported: driverMajor != null && driverMajor >= 525,
            reason:
                cudaReason ??
                _driverReason(
                  driver: nvidiaDriver,
                  floor: 525,
                  met: driverMajor != null && driverMajor >= 525,
                ),
          ),
        );
        supports.add(
          BackendSupport(
            backend: RuntimeBackend.rocm,
            supported: hasRocm,
            reason: hasRocm
                ? (rocmVersion != null
                      ? 'ROCm $rocmVersion detected'
                      : rocmHome != null
                      ? 'ROCm stack at $rocmHome detected'
                      : 'ROCm stack detected')
                : (rocmError ?? 'no ROCm driver detected'),
          ),
        );
      }
      supports.add(
        BackendSupport(
          backend: RuntimeBackend.vulkan,
          supported: hasVulkan,
          reason:
              vulkanReason ??
              (hasVulkan
                  ? 'Vulkan loader and driver detected'
                  : 'libvulkan.so.1 not found'),
        ),
      );
    }

    final gpuSupported = supports.any(
      (support) => support.supported && support.backend.isGpu,
    );
    supports.add(
      BackendSupport(
        backend: RuntimeBackend.cpu,
        supported: true,
        reason: gpuSupported
            ? 'host CPU'
            : platform == RuntimePlatform.macosArm64
            ? 'no GPU backend detected; Metal requires Apple silicon'
            : 'no GPU backend detected',
      ),
    );
    return supports;
  }

  static String _driverReason({
    required String? driver,
    required int floor,
    required bool met,
  }) {
    final version = driver ?? 'unknown';
    return met
        ? 'nvidia driver $version ≥ $floor'
        : 'nvidia driver $version < $floor';
  }

  Future<ProcessOutput> _run(
    ProcessExecutor runner,
    String executable,
    List<String> arguments,
  ) async {
    try {
      return await runner.run(executable, arguments);
    } on Object catch (error) {
      return ProcessOutput(exitCode: -1, stdout: '', stderr: '$error');
    }
  }

  static _NvidiaResult _parseNvidia(ProcessOutput output) {
    if (!output.ok) {
      return _NvidiaResult(error: _failure(output, 'nvidia-smi'));
    }
    final gpus = <RuntimeGpu>[];
    var sawLine = false;
    var sawUnparsableLine = false;
    for (final rawLine in output.stdout.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      sawLine = true;
      final fields = line.split(',');
      if (fields.length < 2) {
        sawUnparsableLine = true;
        continue;
      }
      final name = fields[0].trim();
      final driver = fields[1].trim();
      if (name.isEmpty || !_versionPattern.hasMatch(driver)) {
        sawUnparsableLine = true;
        continue;
      }
      gpus.add(RuntimeGpu(name: name, vendor: 'nvidia', driverVersion: driver));
    }
    if (gpus.isEmpty) {
      return _NvidiaResult(
        error: sawUnparsableLine
            ? 'nvidia-smi output could not be parsed'
            : sawLine
            ? 'nvidia-smi reported no usable GPUs'
            : 'nvidia-smi reported no GPUs',
      );
    }
    return _NvidiaResult(
      gpus: gpus,
      driverVersion: _maxVersion(gpus.map((gpu) => gpu.driverVersion)),
    );
  }

  static RuntimePlatform? _resolvePlatform(String os, String arch) {
    final isX64 = arch == 'x64';
    return switch (os) {
      'linux' when isX64 => RuntimePlatform.linuxX64,
      'windows' when isX64 => RuntimePlatform.windowsX64,
      // RuntimePlatform only models the macOS arm64 archive family. Intel
      // macOS aliases to it, but the probe only marks the CPU backend there.
      'macos' when arch == 'arm64' || isX64 => RuntimePlatform.macosArm64,
      _ => null,
    };
  }

  static String _normalizeArch(String arch) =>
      switch (arch.toLowerCase().trim()) {
        'x64' || 'x86_64' || 'amd64' => 'x64',
        'arm64' || 'aarch64' => 'arm64',
        final other => other,
      };

  static String _currentArch() {
    final match = RegExp(r'on "([^"]+)"').firstMatch(Platform.version);
    final platform = match?.group(1);
    if (platform != null) {
      final segments = platform.split('_');
      if (segments.length > 1) {
        return segments.last;
      }
    }
    return Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '';
  }

  static bool _defaultExists(String path) {
    try {
      return FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
    } on FileSystemException {
      return false;
    }
  }

  static String? _firstPresent(
    bool Function(String path) exists,
    List<String> paths,
  ) {
    for (final path in paths) {
      try {
        if (exists(path)) {
          return path;
        }
      } on Object {
        // An injected predicate failed; treat the path as absent.
      }
    }
    return null;
  }

  static String _failure(ProcessOutput output, String command) {
    final stderr = output.stderr.trim();
    if (stderr.isNotEmpty) {
      final first = stderr.split(RegExp(r'\r?\n')).first.trim();
      return '$command is not available: $first';
    }
    return '$command exited with code ${output.exitCode}';
  }

  static String? _firstVersion(String output) {
    final match = _looseVersionPattern.firstMatch(output);
    return match?.group(0);
  }

  static int _majorVersion(String version) {
    final match = RegExp(r'^\d+').firstMatch(version);
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }

  static String _maxVersion(Iterable<String> versions) {
    var best = '';
    for (final version in versions) {
      if (best.isEmpty || _compareVersions(version, best) > 0) {
        best = version;
      }
    }
    return best;
  }

  static int _compareVersions(String left, String right) {
    final leftParts = left.split('.');
    final rightParts = right.split('.');
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftPart = index < leftParts.length
          ? int.tryParse(leftParts[index]) ?? 0
          : 0;
      final rightPart = index < rightParts.length
          ? int.tryParse(rightParts[index]) ?? 0
          : 0;
      if (leftPart != rightPart) {
        return leftPart.compareTo(rightPart);
      }
    }
    return 0;
  }

  static final RegExp _versionPattern = RegExp(r'^\d+(?:\.\d+)*$');
  static final RegExp _looseVersionPattern = RegExp(r'\d+\.\d+(?:\.\d+)*');
}

final class _NvidiaResult {
  const _NvidiaResult({
    this.gpus = const <RuntimeGpu>[],
    this.driverVersion,
    this.error,
  });

  final List<RuntimeGpu> gpus;
  final String? driverVersion;
  final String? error;
}

final class _VulkanResult {
  const _VulkanResult({required this.supported, required this.reason});

  final bool supported;
  final String reason;
}
