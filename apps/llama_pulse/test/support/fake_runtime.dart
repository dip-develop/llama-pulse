import 'dart:async';
import 'dart:io';

import 'package:built_collection/built_collection.dart';
import 'package:llama_pulse_core/llama_pulse_core.dart';

/// A [RuntimeProbe] that reports one fixed detection.
final class FakeRuntimeProbe implements RuntimeProbe {
  FakeRuntimeProbe({RuntimeDetection? detection})
    : detection = detection ?? linuxCuda();

  RuntimeDetection detection;
  int calls = 0;

  @override
  Future<RuntimeDetection> probe() async {
    calls++;
    return detection;
  }

  static RuntimeDetection linuxCuda() => RuntimeDetection(
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
    recommendation: const RuntimeRecommendation(
      backend: RuntimeBackend.cuda13,
      reason: 'nvidia driver 580.95 >= 580',
    ),
  );
}

/// An in-memory [RuntimeStore] for widget tests.
final class FakeRuntimeStore implements RuntimeStore {
  RuntimeIndex current = RuntimeIndex.empty();
  final Map<String, RuntimeManifest> manifests = <String, RuntimeManifest>{};
  int selectCalls = 0;
  int removeCalls = 0;

  @override
  Future<RuntimeIndex> index() async => current;

  @override
  Future<List<RuntimeInstallRef>> list() async => current.resolutionOrder;

  @override
  Future<RuntimeManifest?> manifest(String tag, RuntimeBackend backend) async =>
      manifests['$tag/${backend.id}'];

  @override
  Future<void> select(String tag, RuntimeBackend backend) async {
    selectCalls++;
    if (manifests['$tag/${backend.id}'] == null) {
      throw StateError('runtime $tag/${backend.id} is not installed');
    }
    current = current.rebuild(
      (b) => b
        ..selectedTag = tag
        ..selectedBackend = backend,
    );
  }

  @override
  Future<void> remove(String tag, RuntimeBackend backend) async {
    removeCalls++;
    manifests.remove('$tag/${backend.id}');
    current = current.rebuild((b) {
      b.installed.replace(<RuntimeInstallRef>[
        for (final install in current.installed)
          if (!(install.tag == tag && install.backend == backend)) install,
      ]);
      if (current.selectedTag == tag && current.selectedBackend == backend) {
        b
          ..selectedTag = ''
          ..selectedBackend = null;
      }
    });
  }

  @override
  Future<void> commit(
    RuntimeBackend backend,
    RuntimeManifest manifest,
    Directory stagingDir, {
    bool force = false,
  }) async {
    manifests['${manifest.tag}/${backend.id}'] = manifest;
    current = current.rebuild(
      (b) => b.installed.replace(<RuntimeInstallRef>[
        for (final install in current.installed)
          if (!(install.tag == manifest.tag && install.backend == backend))
            install,
        RuntimeInstallRef(
          (r) => r
            ..tag = manifest.tag
            ..backend = backend
            ..platform = manifest.platform
            ..installedAtEpochMs = manifest.installedAtEpochMs
            ..sizeBytes = manifest.sizeBytes,
        ),
      ]),
    );
  }

  @override
  Future<void> cleanupOrphans({
    Duration olderThan = const Duration(days: 1),
  }) async {}

  @override
  String installDirectory(String tag, RuntimeBackend backend) =>
      '$tag/${backend.id}';

  /// Registers [manifest] as installed without going through an install.
  void seed(RuntimeManifest manifest, {bool selected = false}) {
    manifests['${manifest.tag}/${manifest.backend.id}'] = manifest;
    current = current.rebuild(
      (b) => b
        ..installed.add(
          RuntimeInstallRef(
            (r) => r
              ..tag = manifest.tag
              ..backend = manifest.backend
              ..platform = manifest.platform
              ..installedAtEpochMs = manifest.installedAtEpochMs
              ..sizeBytes = manifest.sizeBytes,
          ),
        )
        ..selectedTag = selected ? manifest.tag : b.selectedTag
        ..selectedBackend = selected ? manifest.backend : b.selectedBackend,
    );
  }
}

/// A [RuntimeInstallService] that completes without touching the network.
final class FakeRuntimeInstallService implements RuntimeInstallService {
  FakeRuntimeInstallService({
    required this.release,
    this.store,
    this.error,
    this.holdUntilCancelled = false,
    this.progress = const <int>[1, 50, 100],
  });

  @override
  final RuntimeRelease release;

  /// Store that receives the manifest on a successful install.
  final FakeRuntimeStore? store;

  /// When set, [install] throws it after reporting progress.
  final Object? error;

  /// When true, [install] never completes until [cancel] is called.
  final bool holdUntilCancelled;

  /// Progress percentages reported, in order.
  final List<int> progress;

  final List<RuntimeBackend> installedBackends = <RuntimeBackend>[];
  RuntimeCancelToken? lastCancel;

  @override
  Future<void> install({
    required RuntimeAsset asset,
    required void Function(RuntimeProgress progress) onProgress,
    RuntimeCancelToken? cancel,
    bool force = false,
  }) async {
    installedBackends.add(asset.backend);
    lastCancel = cancel;
    for (final percent in progress) {
      onProgress(
        RuntimeProgress(
          received: asset.sizeBytes * percent ~/ 100,
          total: asset.sizeBytes,
          bytesPerSecond: 0,
        ),
      );
    }
    if (holdUntilCancelled) {
      await (cancel?.whenCancelled ?? Completer<void>().future);
      throw const RuntimeException(
        RuntimeFailureCode.cancelled,
        'the runtime install was cancelled',
      );
    }
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    final manifest = RuntimeManifest(
      (b) => b
        ..tag = asset.tag
        ..buildId = release.build
        ..commit = release.commit
        ..backend = asset.backend
        ..platform = asset.platform
        ..assetName = asset.assetName
        ..sha256 = asset.sha256
        ..sizeBytes = asset.sizeBytes
        ..installedAtEpochMs = 1700000000000
        ..llamaVersion = '0.8.0-dev'
        ..buildNumber = 11960
        ..backendLibs = BuiltList<String>(
          asset.backend.backendLibs(asset.platform),
        ).toBuilder()
        ..files = 4,
    );
    await store?.commit(asset.backend, manifest, Directory('staging'));
  }
}

/// The pinned release used by the runtime widget tests.
RuntimeRelease testRuntimeRelease() {
  const bytes = 1000;
  return RuntimeRelease(
    tag: 'v0.8.0',
    build: 'b11960',
    commit: '8642541b255bfb5dc39cd351a178be09013a55d6',
    ggmlVersion: '0.28.0',
    assets: <RuntimeAsset>[
      RuntimeAsset(
        tag: 'v0.8.0',
        backend: RuntimeBackend.cpu,
        platform: RuntimePlatform.linuxX64,
        assetName: 'llama-b11960-bin-ubuntu-x64.tar.gz',
        sha256: 'a' * 64,
        sizeBytes: bytes,
      ),
      RuntimeAsset(
        tag: 'v0.8.0',
        backend: RuntimeBackend.cuda13,
        platform: RuntimePlatform.linuxX64,
        assetName: 'llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz',
        sha256: 'b' * 64,
        sizeBytes: bytes,
        cudartAsset: RuntimeAsset(
          tag: 'v0.8.0',
          backend: RuntimeBackend.cuda13,
          platform: RuntimePlatform.linuxX64,
          assetName: 'cudart-llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz',
          sha256: 'c' * 64,
          sizeBytes: bytes,
        ),
      ),
      RuntimeAsset(
        tag: 'v0.8.0',
        backend: RuntimeBackend.vulkan,
        platform: RuntimePlatform.linuxX64,
        assetName: 'llama-b11960-bin-ubuntu-vulkan-x64.tar.gz',
        sha256: 'd' * 64,
        sizeBytes: bytes,
      ),
    ],
  );
}
