import 'runtime_asset.dart';
import 'runtime_backend.dart';
import 'runtime_platform.dart';

/// A pinned llama.cpp release: one upstream tag, one build number, one commit
/// and the archives that release ships.
///
/// Only [v080] exists for now. A new release means a new `static const` here
/// plus a new entry in `third_party/llama_cpp/<tag>/RUNTIME_ASSETS.md`; no
/// version is ever resolved from the network at install time.
class RuntimeRelease {
  const RuntimeRelease({
    required this.tag,
    required this.build,
    required this.commit,
    required this.ggmlVersion,
    required this.assets,
  });

  /// The upstream tag the archives come from.
  final String tag;

  /// The upstream build number the tag resolves to, for example `b11960`.
  final String build;

  /// The upstream commit the tag points at.
  final String commit;

  /// The `ggml` library version the release reports.
  final String ggmlVersion;

  /// Every pinned archive of this release, one per backend and platform.
  final List<RuntimeAsset> assets;

  /// Sum of every download this release needs, including CUDA runtimes.
  int get totalSizeBytes => assets.fold(
    0,
    (total, asset) =>
        total + asset.sizeBytes + (asset.cudartAsset?.sizeBytes ?? 0),
  );

  /// The archive for [backend] on [platform], or null when the release has none.
  ///
  /// An archive that serves more than one backend (macOS ships Metal and CPU in
  /// one file) answers for each of them.
  RuntimeAsset? forBackend(RuntimeBackend backend, RuntimePlatform platform) {
    for (final asset in assets) {
      if (asset.platform == platform && asset.provides(backend)) {
        return asset;
      }
    }
    return null;
  }

  /// The backends the release offers on [platform], CPU first.
  ///
  /// Order is the default preference order from
  /// [RuntimeBackend.recommendedFor], filtered to the archives that exist.
  List<RuntimeBackend> backendsFor(RuntimePlatform platform) =>
      <RuntimeBackend>[
        for (final backend in RuntimeBackend.recommendedFor(platform))
          if (forBackend(backend, platform) != null) backend,
      ];

  /// llama.cpp v0.8.0, build `b11960`.
  ///
  /// The tag, build number and commit come from `nightly-tag.txt` published on
  /// the `v0.8.0` release; every digest below was read from the release assets
  /// with `gh api` and is recorded in
  /// `third_party/llama_cpp/v0.8.0/RUNTIME_ASSETS.md`.
  static const RuntimeRelease v080 = RuntimeRelease(
    tag: _tag,
    build: 'b11960',
    commit: '8642541b255bfb5dc39cd351a178be09013a55d6',
    ggmlVersion: '0.28.0',
    assets: <RuntimeAsset>[
      // Linux x64.
      RuntimeAsset(
        tag: _tag,
        backend: RuntimeBackend.cpu,
        platform: RuntimePlatform.linuxX64,
        assetName: 'llama-b11960-bin-ubuntu-x64.tar.gz',
        sha256:
            '31cc3a6bc638ac6c48dc4b1b74888f1eaadf3d14227c1e5f67daf9a49541d97a',
        sizeBytes: 22686210,
      ),
      RuntimeAsset(
        tag: _tag,
        backend: RuntimeBackend.cuda12,
        platform: RuntimePlatform.linuxX64,
        assetName: 'llama-b11960-bin-ubuntu-cuda-12.8-x64.tar.gz',
        sha256:
            '64d57beb9abb637c177c6afb313760a0c0782224cac71e74869eed5b8f9a1ea4',
        sizeBytes: 182524002,
        cudartAsset: RuntimeAsset(
          tag: _tag,
          backend: RuntimeBackend.cuda12,
          platform: RuntimePlatform.linuxX64,
          assetName: 'cudart-llama-b11960-bin-ubuntu-cuda-12.8-x64.tar.gz',
          sha256: '7c4d5974bd39649df649649e5d71950688a70e37aaae00bf11afbb656ea2cc56',
          sizeBytes: 594371478,
        ),
      ),
      RuntimeAsset(
        tag: _tag,
        backend: RuntimeBackend.cuda13,
        platform: RuntimePlatform.linuxX64,
        assetName: 'llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz',
        sha256:
            '0cf758b28483593a5a15e0d2c9b686c40840d1f8be9b5bb2417f04a053113907',
        sizeBytes: 163957335,
        cudartAsset: RuntimeAsset(
          tag: _tag,
          backend: RuntimeBackend.cuda13,
          platform: RuntimePlatform.linuxX64,
          assetName: 'cudart-llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz',
          sha256: '756e14988abb5daa60d25f27a9766a9a78f04c88647c4b92a88fb749488d72f7',
          sizeBytes: 440232534,
        ),
      ),
      RuntimeAsset(
        tag: _tag,
        backend: RuntimeBackend.vulkan,
        platform: RuntimePlatform.linuxX64,
        assetName: 'llama-b11960-bin-ubuntu-vulkan-x64.tar.gz',
        sha256:
            '164199e978304bb32a8a6c24b8efa015528ddf286821596eab676c90b375feac',
        sizeBytes: 35474467,
      ),
      RuntimeAsset(
        tag: _tag,
        backend: RuntimeBackend.rocm,
        platform: RuntimePlatform.linuxX64,
        assetName: 'llama-b11960-bin-ubuntu-rocm-10.0-x64.tar.gz',
        sha256:
            '63546b0175840c75b261bcb55e75cce49852c6d632eee352edbfa62c3bf120e3',
        sizeBytes: 251572351,
      ),

      // macOS arm64: one archive, built for Metal, carrying the CPU backend too.
      RuntimeAsset(
        tag: _tag,
        backend: RuntimeBackend.metal,
        platform: RuntimePlatform.macosArm64,
        assetName: 'llama-b11960-bin-macos-arm64.tar.gz',
        sha256:
            '58e5a5e1d7c2bf66cedd9c29e0323f3e570660a70a1e2156d32eed08f4cc1e3c',
        sizeBytes: 16465074,
        additionalBackends: <RuntimeBackend>[RuntimeBackend.cpu],
      ),

      // Windows x64.
      RuntimeAsset(
        tag: _tag,
        backend: RuntimeBackend.cpu,
        platform: RuntimePlatform.windowsX64,
        assetName: 'llama-b11960-bin-win-cpu-x64.zip',
        sha256:
            '73f962f82850d244db47eaacb9d913637027b82399124324298576d58c5f4287',
        sizeBytes: 24407745,
      ),
      RuntimeAsset(
        tag: _tag,
        backend: RuntimeBackend.cuda13,
        platform: RuntimePlatform.windowsX64,
        assetName: 'llama-b11960-bin-win-cuda-13.4-x64.zip',
        sha256:
            '31c75ea62b80f0816c855ea783ef68757bc2d48028edaa57d904e4982bddea4a',
        sizeBytes: 164986387,
        cudartAsset: RuntimeAsset(
          tag: _tag,
          backend: RuntimeBackend.cuda13,
          platform: RuntimePlatform.windowsX64,
          assetName: 'cudart-llama-bin-win-cuda-13.4-x64.zip',
          sha256: '738f8c251ac22b70c3ae6f83a10cf222725df0395246a2cf58f32bdb85fbe668',
          sizeBytes: 423535356,
        ),
      ),
      RuntimeAsset(
        tag: _tag,
        backend: RuntimeBackend.vulkan,
        platform: RuntimePlatform.windowsX64,
        assetName: 'llama-b11960-bin-win-vulkan-x64.zip',
        sha256:
            'bac6914b5e83523eb008c6789eaa12669f93fbc196c3b9e8237b6672323b33e9',
        sizeBytes: 37345851,
      ),
    ],
  );

  static const String _tag = 'v0.8.0';
}
