import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _FakeProbe implements RuntimeProbe {
  _FakeProbe(this.detection);

  final RuntimeDetection detection;
  int calls = 0;

  @override
  Future<RuntimeDetection> probe() async {
    calls++;
    return detection;
  }
}

final class _FakeStore implements RuntimeStore {
  RuntimeIndex current = RuntimeIndex.empty();
  final Map<String, RuntimeManifest> manifests = <String, RuntimeManifest>{};

  @override
  Future<RuntimeIndex> index() async => current;

  @override
  Future<List<RuntimeInstallRef>> list() async => current.resolutionOrder;

  @override
  Future<RuntimeManifest?> manifest(String tag, RuntimeBackend backend) async =>
      manifests['$tag/${backend.id}'];

  @override
  Future<void> select(String tag, RuntimeBackend backend) async {}

  @override
  Future<void> remove(String tag, RuntimeBackend backend) async {}

  @override
  Future<void> commit(
    RuntimeBackend backend,
    RuntimeManifest manifest,
    Directory stagingDir, {
    bool force = false,
  }) async {}

  @override
  Future<void> cleanupOrphans({
    Duration olderThan = const Duration(days: 1),
  }) async {}

  @override
  String installDirectory(String tag, RuntimeBackend backend) =>
      p.join(tag, backend.id);
}

RuntimeDetection _detection({
  RuntimeBackend? recommended = RuntimeBackend.cuda13,
}) => RuntimeDetection(
  hardware: RuntimeHardware(
    operatingSystem: 'linux',
    arch: 'x64',
    platform: RuntimePlatform.linuxX64,
    gpus: const <RuntimeGpu>[
      RuntimeGpu(
        name: 'NVIDIA GeForce RTX 4090',
        vendor: 'nvidia',
        driverVersion: '580.95',
      ),
    ],
    hasCuda: true,
  ),
  supports: const <BackendSupport>[
    BackendSupport(
      backend: RuntimeBackend.cpu,
      supported: true,
      reason: 'runs on the host CPU',
    ),
    BackendSupport(
      backend: RuntimeBackend.cuda13,
      supported: true,
      reason: 'nvidia driver 580.95 >= 580',
    ),
    BackendSupport(
      backend: RuntimeBackend.vulkan,
      supported: false,
      reason: 'libvulkan.so.1 not found',
    ),
  ],
  recommendation: recommended == null
      ? null
      : RuntimeRecommendation(
          backend: recommended,
          reason: 'nvidia driver 580.95 >= 580',
        ),
);

RuntimeManifest _manifest({
  String? version = '0.8.0',
  String tag = 'v0.8.0',
  String buildId = 'b11960',
  String commit = '8642541b255bfb5dc39cd351a178be09013a55d6',
  String assetName = 'llama-b11960-bin-ubuntu-x64.tar.gz',
  String sha256 =
      '31cc3a6bc638ac6c48dc4b1b74888f1eaadf3d14227c1e5f67daf9a49541d97a',
  int sizeBytes = 22686210,
}) => RuntimeManifest(
  (b) => b
    ..tag = tag
    ..buildId = buildId
    ..commit = commit
    ..backend = RuntimeBackend.cpu
    ..platform = RuntimePlatform.linuxX64
    ..assetName = assetName
    ..sha256 = sha256
    ..sizeBytes = sizeBytes
    ..installedAtEpochMs = 10
    ..llamaVersion = version
    ..buildNumber = 11960
    ..backendLibs = BuiltList<String>(<String>['libggml-cpu.so']).toBuilder()
    ..files = 3,
);

RuntimeIndex _index({bool selected = true}) => RuntimeIndex(
  (b) => b
    ..selectedTag = selected ? 'v0.8.0' : ''
    ..selectedBackend = selected ? RuntimeBackend.cpu : null
    ..installed = BuiltList<RuntimeInstallRef>(<RuntimeInstallRef>[
      RuntimeInstallRef(
        (r) => r
          ..tag = 'v0.8.0'
          ..backend = RuntimeBackend.cpu
          ..platform = RuntimePlatform.linuxX64
          ..installedAtEpochMs = 10
          ..sizeBytes = 3,
      ),
    ]).toBuilder(),
);

void main() {
  late _FakeStore store;
  late _FakeProbe probe;

  setUp(() {
    store = _FakeStore();
    probe = _FakeProbe(_detection());
  });

  RuntimeStatusReader reader() =>
      RuntimeStatusReader(store: store, probe: probe);

  test('reports hardware, the recommendation and no runtime', () async {
    final status = await reader().read();

    expect(probe.calls, 1);
    expect(status.detection.hardware.platform, RuntimePlatform.linuxX64);
    expect(status.detection.hardware.gpus.single.name, contains('4090'));
    expect(status.recommendedBackend, RuntimeBackend.cuda13);
    expect(status.offeredBackends, <RuntimeBackend>[
      RuntimeBackend.cpu,
      RuntimeBackend.cuda13,
      RuntimeBackend.cuda12,
      RuntimeBackend.rocm,
      RuntimeBackend.vulkan,
    ]);
    expect(status.installs, isEmpty);
    expect(status.selected, isNull);
    expect(status.gate.verdict, RuntimeGateVerdict.notInstalled);
    expect(status.gate.accepted, isFalse);
  });

  test('an exact 0.8.0 install passes the gate', () async {
    store.current = _index();
    store.manifests['v0.8.0/cpu'] = _manifest();

    final status = await reader().read();

    expect(status.gate.verdict, RuntimeGateVerdict.exact);
    expect(status.gate.accepted, isTrue);
    expect(status.selectedManifest?.tag, 'v0.8.0');
    expect(status.installs, hasLength(1));
  });

  test('a pinned 0.8.0-dev install is attested', () async {
    store.current = _index();
    store.manifests['v0.8.0/cpu'] = _manifest(version: '0.8.0-dev');

    final status = await reader().read();

    expect(status.gate.verdict, RuntimeGateVerdict.attested);
    expect(status.gate.accepted, isTrue);
  });

  test('a 0.8.0-dev install with a foreign digest is rejected', () async {
    store.current = _index();
    store.manifests['v0.8.0/cpu'] = _manifest(
      version: '0.8.0-dev',
      sha256: 'f' * 64,
    );

    final status = await reader().read();

    expect(status.gate.verdict, RuntimeGateVerdict.rejected);
    expect(status.gate.reason, contains('SHA-256'));
    expect(status.gate.accepted, isFalse);
  });

  test('the Unsloth fork stays rejected', () async {
    store.current = _index();
    store.manifests['v0.8.0/cpu'] = _manifest(version: '0.7.0-dev');

    final status = await reader().read();

    expect(status.gate.verdict, RuntimeGateVerdict.rejected);
    expect(status.gate.reason, contains('0.7.0-dev'));
  });

  test('an install without a recorded version is unknown', () async {
    store.current = _index();
    store.manifests['v0.8.0/cpu'] = _manifest(version: null);

    final status = await reader().read();

    expect(status.gate.verdict, RuntimeGateVerdict.unknown);
  });

  test('a selected runtime with no manifest is rejected', () async {
    store.current = _index();

    final status = await reader().read();

    expect(status.gate.verdict, RuntimeGateVerdict.rejected);
    expect(status.selectedManifest, isNull);
  });

  test('the offered backends follow the release, not the probe', () async {
    probe = _FakeProbe(_detection(recommended: null));

    final status = await reader().read();

    expect(status.recommendedBackend, isNull);
    expect(status.offeredBackends, isNotEmpty);
  });
}
