import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

final class _FakeExecutor implements ProcessExecutor {
  _FakeExecutor([Map<String, ProcessOutput> responses = const {}])
    : _responses = responses;

  final Map<String, ProcessOutput> _responses;
  final List<String> calls = <String>[];

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    calls.add(executable);
    return _responses[executable] ??
        const ProcessOutput(
          exitCode: -1,
          stdout: '',
          stderr: 'No such file or directory',
        );
  }
}

final class _ThrowingExecutor implements ProcessExecutor {
  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    throw StateError('boom');
  }
}

ProcessOutput _ok(String stdout) =>
    ProcessOutput(exitCode: 0, stdout: stdout, stderr: '');

bool Function(String path) _existing(Set<String> paths) =>
    (path) => paths.contains(path);

BackendSupport _support(RuntimeDetection detection, RuntimeBackend backend) {
  final support = detection.supportFor(backend);
  expect(support, isNotNull, reason: 'missing support for ${backend.id}');
  return support as BackendSupport;
}

void main() {
  const probe = DartRuntimeProbe();

  Future<RuntimeDetection> probeLinux({
    Map<String, ProcessOutput> responses = const {},
    Set<String> files = const {},
    String arch = 'x64',
  }) => probe.probeWith(
    executor: _FakeExecutor(responses),
    operatingSystem: 'linux',
    arch: arch,
    fileExists: _existing(files),
  );

  group('Linux CPU fallback', () {
    test('no vendor tools reports CPU with a no-GPU reason', () async {
      final detection = await probeLinux();

      expect(detection.hardware.platform, RuntimePlatform.linuxX64);
      expect(detection.hardware.arch, 'x64');
      expect(detection.hardware.gpus, isEmpty);
      expect(detection.hardware.hasCuda, isFalse);
      expect(detection.hardware.hasVulkan, isFalse);
      expect(detection.hardware.hasRocm, isFalse);
      expect(
        detection.supports.map((support) => support.backend),
        <RuntimeBackend>[
          RuntimeBackend.cuda13,
          RuntimeBackend.cuda12,
          RuntimeBackend.rocm,
          RuntimeBackend.vulkan,
          RuntimeBackend.cpu,
        ],
      );
      expect(detection.isSupported(RuntimeBackend.cuda13), isFalse);
      expect(
        _support(detection, RuntimeBackend.cuda13).reason,
        contains('nvidia-smi is not available'),
      );
      expect(detection.isSupported(RuntimeBackend.cuda12), isFalse);
      expect(
        _support(detection, RuntimeBackend.rocm).reason,
        contains('/opt/rocm not found'),
      );
      expect(
        _support(detection, RuntimeBackend.vulkan).reason,
        contains('libvulkan.so.1 not found'),
      );
      expect(detection.isSupported(RuntimeBackend.cpu), isTrue);
      expect(detection.recommendedBackend, RuntimeBackend.cpu);
      expect(detection.recommendedReason, 'no GPU backend detected');
      expect(_support(detection, RuntimeBackend.cpu).recommended, isTrue);
    });
  });

  group('NVIDIA', () {
    test('a 580 driver enables CUDA 13 and recommends it', () async {
      final detection = await probeLinux(
        responses: <String, ProcessOutput>{
          'nvidia-smi': _ok('NVIDIA GeForce RTX 4090, 580.12\n'),
        },
      );

      expect(detection.hardware.hasCuda, isTrue);
      expect(detection.hardware.gpus, hasLength(1));
      final gpu = detection.hardware.gpus.single;
      expect(gpu.name, 'NVIDIA GeForce RTX 4090');
      expect(gpu.vendor, 'nvidia');
      expect(gpu.driverVersion, '580.12');
      expect(detection.isSupported(RuntimeBackend.cuda13), isTrue);
      expect(
        _support(detection, RuntimeBackend.cuda13).reason,
        'nvidia driver 580.12 ≥ 580',
      );
      expect(detection.isSupported(RuntimeBackend.cuda12), isTrue);
      expect(
        _support(detection, RuntimeBackend.cuda12).reason,
        'nvidia driver 580.12 ≥ 525',
      );
      expect(detection.recommendedBackend, RuntimeBackend.cuda13);
      expect(_support(detection, RuntimeBackend.cuda13).recommended, isTrue);
      expect(_support(detection, RuntimeBackend.cuda12).recommended, isFalse);
    });

    test('a 545 driver enables only CUDA 12', () async {
      final detection = await probeLinux(
        responses: <String, ProcessOutput>{
          'nvidia-smi': _ok('NVIDIA RTX A4000, 545.29.06\n'),
        },
      );

      expect(detection.isSupported(RuntimeBackend.cuda13), isFalse);
      expect(
        _support(detection, RuntimeBackend.cuda13).reason,
        'nvidia driver 545.29.06 < 580',
      );
      expect(detection.isSupported(RuntimeBackend.cuda12), isTrue);
      expect(detection.recommendedBackend, RuntimeBackend.cuda12);
    });

    test('the highest driver across GPUs decides', () async {
      final detection = await probeLinux(
        responses: <String, ProcessOutput>{
          'nvidia-smi': _ok(
            'NVIDIA GeForce GTX 1080, 545.29.06\n'
            'NVIDIA GeForce RTX 5090, 580.65\n',
          ),
        },
      );

      expect(detection.hardware.gpus, hasLength(2));
      expect(detection.isSupported(RuntimeBackend.cuda13), isTrue);
      expect(
        _support(detection, RuntimeBackend.cuda13).reason,
        contains('580.65'),
      );
      expect(detection.recommendedBackend, RuntimeBackend.cuda13);
    });

    test('below both floors keeps the CPU recommendation', () async {
      final detection = await probeLinux(
        responses: <String, ProcessOutput>{
          'nvidia-smi': _ok('NVIDIA GeForce GTX 970, 470.86\n'),
        },
      );

      expect(detection.hardware.hasCuda, isTrue);
      expect(detection.isSupported(RuntimeBackend.cuda13), isFalse);
      expect(detection.isSupported(RuntimeBackend.cuda12), isFalse);
      expect(detection.recommendedBackend, RuntimeBackend.cpu);
    });

    test('garbage output degrades instead of throwing', () async {
      final detection = await probeLinux(
        responses: <String, ProcessOutput>{
          'nvidia-smi': _ok('not a csv line\n???, not-a-version\n'),
        },
      );

      expect(detection.hardware.hasCuda, isFalse);
      expect(detection.isSupported(RuntimeBackend.cuda13), isFalse);
      expect(
        _support(detection, RuntimeBackend.cuda13).reason,
        contains('could not be parsed'),
      );
      expect(detection.recommendedBackend, RuntimeBackend.cpu);
    });

    test('an executor that throws still returns a detection', () async {
      final detection = await probe.probeWith(
        executor: _ThrowingExecutor(),
        operatingSystem: 'linux',
        arch: 'x64',
        fileExists: _existing(const <String>{}),
      );

      expect(detection.isSupported(RuntimeBackend.cpu), isTrue);
      expect(detection.recommendedBackend, RuntimeBackend.cpu);
      expect(
        _support(detection, RuntimeBackend.cuda13).reason,
        contains('boom'),
      );
    });
  });

  group('ROCm', () {
    test('rocm-smi reports a version', () async {
      final detection = await probeLinux(
        responses: <String, ProcessOutput>{
          'rocm-smi': _ok('Driver version: 6.2.0\n'),
        },
      );

      expect(detection.hardware.hasRocm, isTrue);
      expect(detection.hardware.gpus.single.vendor, 'amd');
      expect(detection.hardware.gpus.single.driverVersion, '6.2.0');
      expect(detection.isSupported(RuntimeBackend.rocm), isTrue);
      expect(
        _support(detection, RuntimeBackend.rocm).reason,
        'ROCm 6.2.0 detected',
      );
      expect(detection.recommendedBackend, RuntimeBackend.rocm);
    });

    test('/opt/rocm alone marks ROCm supported', () async {
      final detection = await probeLinux(files: <String>{'/opt/rocm'});

      expect(detection.hardware.hasRocm, isTrue);
      expect(detection.isSupported(RuntimeBackend.rocm), isTrue);
      expect(
        _support(detection, RuntimeBackend.rocm).reason,
        contains('/opt/rocm'),
      );
      expect(detection.recommendedBackend, RuntimeBackend.rocm);
    });
  });

  group('Vulkan', () {
    test('a loader without vulkaninfo is supported with a warning', () async {
      final detection = await probeLinux(files: <String>{'libvulkan.so.1'});

      expect(detection.hardware.hasVulkan, isTrue);
      expect(detection.isSupported(RuntimeBackend.vulkan), isTrue);
      final reason = _support(detection, RuntimeBackend.vulkan).reason;
      expect(reason, contains('libvulkan.so.1 present'));
      expect(reason, contains('vulkaninfo is not available'));
      expect(detection.recommendedBackend, RuntimeBackend.vulkan);
    });

    test('vulkaninfo alone is enough', () async {
      final detection = await probeLinux(
        responses: <String, ProcessOutput>{
          'vulkaninfo': _ok('Vulkan version 1.3.280\n'),
        },
      );

      expect(detection.hardware.hasVulkan, isTrue);
      expect(detection.isSupported(RuntimeBackend.vulkan), isTrue);
      expect(
        _support(detection, RuntimeBackend.vulkan).reason,
        contains('vulkaninfo reports a working loader'),
      );
      expect(detection.recommendedBackend, RuntimeBackend.vulkan);
    });

    test(
      'an ICD directory without a loader or vulkaninfo is not enough',
      () async {
        final detection = await probeLinux(
          files: <String>{'/usr/share/vulkan/icd.d'},
        );

        expect(detection.hardware.hasVulkan, isFalse);
        expect(detection.isSupported(RuntimeBackend.vulkan), isFalse);
        expect(
          _support(detection, RuntimeBackend.vulkan).reason,
          contains('ICD manifests in /usr/share/vulkan/icd.d'),
        );
      },
    );
  });

  group('Windows', () {
    test('a 580 driver offers CUDA 13 only', () async {
      final detection = await probe.probeWith(
        executor: _FakeExecutor(<String, ProcessOutput>{
          'nvidia-smi': _ok('NVIDIA GeForce RTX 4080, 580.12\n'),
        }),
        operatingSystem: 'windows',
        arch: 'x64',
        fileExists: _existing(const <String>{}),
      );

      expect(detection.hardware.platform, RuntimePlatform.windowsX64);
      expect(detection.isSupported(RuntimeBackend.cuda13), isTrue);
      expect(detection.supportFor(RuntimeBackend.cuda12), isNull);
      expect(detection.supportFor(RuntimeBackend.rocm), isNull);
      expect(detection.recommendedBackend, RuntimeBackend.cuda13);
    });

    test('vulkan-1.dll alone recommends Vulkan', () async {
      final detection = await probe.probeWith(
        executor: _FakeExecutor(),
        operatingSystem: 'windows',
        arch: 'x64',
        fileExists: _existing(<String>{'vulkan-1.dll'}),
      );

      expect(detection.isSupported(RuntimeBackend.vulkan), isTrue);
      expect(detection.recommendedBackend, RuntimeBackend.vulkan);
      expect(
        _support(detection, RuntimeBackend.vulkan).reason,
        contains('vulkan-1.dll present'),
      );
    });
  });

  group('macOS', () {
    test('arm64 always recommends Metal and never probes vendors', () async {
      final executor = _FakeExecutor();
      final detection = await probe.probeWith(
        executor: executor,
        operatingSystem: 'macos',
        arch: 'arm64',
        fileExists: _existing(const <String>{}),
      );

      expect(detection.hardware.platform, RuntimePlatform.macosArm64);
      expect(detection.hardware.isAppleSilicon, isTrue);
      expect(
        detection.supports.map((support) => support.backend),
        <RuntimeBackend>[RuntimeBackend.metal, RuntimeBackend.cpu],
      );
      expect(detection.isSupported(RuntimeBackend.metal), isTrue);
      expect(
        _support(detection, RuntimeBackend.metal).reason,
        'macOS arm64 uses Metal',
      );
      expect(detection.isSupported(RuntimeBackend.cpu), isTrue);
      expect(detection.recommendedBackend, RuntimeBackend.metal);
      expect(executor.calls, isEmpty);
    });

    test('x64 aliases the macOS platform but offers CPU only', () async {
      final detection = await probe.probeWith(
        executor: _FakeExecutor(),
        operatingSystem: 'macos',
        arch: 'x64',
        fileExists: _existing(const <String>{}),
      );

      expect(detection.hardware.platform, RuntimePlatform.macosArm64);
      expect(detection.hardware.arch, 'x64');
      expect(detection.hardware.isAppleSilicon, isFalse);
      expect(
        detection.supports.map((support) => support.backend),
        <RuntimeBackend>[RuntimeBackend.cpu],
      );
      expect(detection.supportFor(RuntimeBackend.metal), isNull);
      expect(detection.recommendedBackend, RuntimeBackend.cpu);
      expect(detection.recommendedReason, contains('no GPU backend detected'));
      expect(detection.recommendedReason, contains('Apple silicon'));
    });
  });

  group('unsupported hosts', () {
    test('an unknown OS reports no platform and no backends', () async {
      final executor = _FakeExecutor();
      final detection = await probe.probeWith(
        executor: executor,
        operatingSystem: 'freebsd',
        arch: 'x64',
        fileExists: _existing(const <String>{}),
      );

      expect(detection.hardware.platform, isNull);
      expect(detection.hardware.operatingSystem, 'freebsd');
      expect(detection.supports, isEmpty);
      expect(detection.recommendedBackend, isNull);
      expect(executor.calls, isEmpty);
    });

    test('an unknown architecture reports no platform', () async {
      final detection = await probeLinux(arch: 'riscv64');

      expect(detection.hardware.platform, isNull);
      expect(detection.supports, isEmpty);
    });

    test('x86_64 and amd64 are normalized to x64', () async {
      for (final arch in <String>['x86_64', 'amd64']) {
        final detection = await probeLinux(arch: arch);
        expect(detection.hardware.platform, RuntimePlatform.linuxX64);
        expect(detection.hardware.arch, 'x64');
      }
    });
  });
}
