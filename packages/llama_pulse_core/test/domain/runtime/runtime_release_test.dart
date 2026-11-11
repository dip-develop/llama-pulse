import 'package:llama_pulse_core/llama_pulse_core.dart';
import 'package:test/test.dart';

final _digest = RegExp(r'^[0-9a-f]{64}$');

void main() {
  final release = RuntimeRelease.v080;

  Iterable<RuntimeAsset> allAssets() sync* {
    for (final asset in release.assets) {
      yield asset;
      final cudart = asset.cudartAsset;
      if (cudart != null) {
        yield cudart;
      }
    }
  }

  group('RuntimeRelease.v080 pin', () {
    test('pins the tag, build, commit and ggml version', () {
      expect(release.tag, 'v0.8.0');
      expect(release.build, 'b11960');
      expect(release.ggmlVersion, '0.28.0');
    });

    test('commit matches LlamaVersionPin', () {
      expect(release.commit, LlamaVersionPin.commit);
    });

    test('every digest is a lower-case SHA-256', () {
      for (final asset in allAssets()) {
        expect(
          asset.sha256,
          matches(_digest),
          reason: '${asset.assetName} digest "${asset.sha256}"',
        );
      }
    });

    test('every archive has a positive size', () {
      for (final asset in allAssets()) {
        expect(asset.sizeBytes, greaterThan(0), reason: asset.assetName);
      }
    });

    test('no asset name is listed twice', () {
      final names = allAssets().map((asset) => asset.assetName).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('every url points at the pinned tag and its asset name', () {
      for (final asset in allAssets()) {
        expect(
          asset.url,
          startsWith(
            'https://github.com/ggml-org/llama.cpp/releases/download/v0.8.0/',
          ),
          reason: asset.assetName,
        );
        expect(asset.url, endsWith('/${asset.assetName}'));
      }
    });

    test('unpacked size estimates the archive at 2.5x', () {
      for (final asset in allAssets()) {
        expect(asset.unpackedBytes, (asset.sizeBytes * 2.5).round());
        expect(asset.unpackedBytes, greaterThan(asset.sizeBytes));
      }
    });

    test('totalSizeBytes sums every archive, CUDA runtimes included', () {
      var expected = 0;
      for (final asset in release.assets) {
        expected += asset.sizeBytes + (asset.cudartAsset?.sizeBytes ?? 0);
      }
      expect(release.totalSizeBytes, expected);
      expect(release.totalSizeBytes, greaterThan(0));
    });

    test('releases lists the pin and forTag resolves only known tags', () {
      expect(RuntimeRelease.releases, contains(release));
      expect(RuntimeRelease.forTag('v0.8.0'), same(release));
      expect(RuntimeRelease.forTag('v0.7.0'), isNull);
    });
  });

  group('platform coverage', () {
    test('cpu is available on every platform', () {
      for (final platform in RuntimePlatform.values) {
        expect(
          release.forBackend(RuntimeBackend.cpu, platform),
          isNotNull,
          reason: platform.id,
        );
      }
    });

    test('metal is macOS only', () {
      expect(
        release.forBackend(RuntimeBackend.metal, RuntimePlatform.macosArm64),
        isNotNull,
      );
      expect(
        release.forBackend(RuntimeBackend.metal, RuntimePlatform.linuxX64),
        isNull,
      );
      expect(
        release.forBackend(RuntimeBackend.metal, RuntimePlatform.windowsX64),
        isNull,
      );
    });

    test('cuda12 is Linux only', () {
      expect(
        release.forBackend(RuntimeBackend.cuda12, RuntimePlatform.linuxX64),
        isNotNull,
      );
      expect(
        release.forBackend(RuntimeBackend.cuda12, RuntimePlatform.macosArm64),
        isNull,
      );
      expect(
        release.forBackend(RuntimeBackend.cuda12, RuntimePlatform.windowsX64),
        isNull,
      );
    });

    test('rocm is Linux only', () {
      expect(
        release.forBackend(RuntimeBackend.rocm, RuntimePlatform.linuxX64),
        isNotNull,
      );
      expect(
        release.forBackend(RuntimeBackend.rocm, RuntimePlatform.macosArm64),
        isNull,
      );
      expect(
        release.forBackend(RuntimeBackend.rocm, RuntimePlatform.windowsX64),
        isNull,
      );
    });

    test('cuda13 covers Linux and Windows', () {
      expect(
        release.forBackend(RuntimeBackend.cuda13, RuntimePlatform.linuxX64),
        isNotNull,
      );
      expect(
        release.forBackend(RuntimeBackend.cuda13, RuntimePlatform.windowsX64),
        isNotNull,
      );
      expect(
        release.forBackend(RuntimeBackend.cuda13, RuntimePlatform.macosArm64),
        isNull,
      );
    });

    test('vulkan covers Linux and Windows', () {
      expect(
        release.forBackend(RuntimeBackend.vulkan, RuntimePlatform.linuxX64),
        isNotNull,
      );
      expect(
        release.forBackend(RuntimeBackend.vulkan, RuntimePlatform.windowsX64),
        isNotNull,
      );
      expect(
        release.forBackend(RuntimeBackend.vulkan, RuntimePlatform.macosArm64),
        isNull,
      );
    });
  });

  group('forBackend', () {
    test('returns the pinned archive per platform', () {
      const expected = <RuntimePlatform, Map<RuntimeBackend, String>>{
        RuntimePlatform.linuxX64: <RuntimeBackend, String>{
          RuntimeBackend.cpu: 'llama-b11960-bin-ubuntu-x64.tar.gz',
          RuntimeBackend.cuda12: 'llama-b11960-bin-ubuntu-cuda-12.8-x64.tar.gz',
          RuntimeBackend.cuda13: 'llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz',
          RuntimeBackend.vulkan: 'llama-b11960-bin-ubuntu-vulkan-x64.tar.gz',
          RuntimeBackend.rocm: 'llama-b11960-bin-ubuntu-rocm-10.0-x64.tar.gz',
        },
        RuntimePlatform.macosArm64: <RuntimeBackend, String>{
          RuntimeBackend.cpu: 'llama-b11960-bin-macos-arm64.tar.gz',
          RuntimeBackend.metal: 'llama-b11960-bin-macos-arm64.tar.gz',
        },
        RuntimePlatform.windowsX64: <RuntimeBackend, String>{
          RuntimeBackend.cpu: 'llama-b11960-bin-win-cpu-x64.zip',
          RuntimeBackend.cuda13: 'llama-b11960-bin-win-cuda-13.4-x64.zip',
          RuntimeBackend.vulkan: 'llama-b11960-bin-win-vulkan-x64.zip',
        },
      };

      expected.forEach((platform, perBackend) {
        perBackend.forEach((backend, assetName) {
          final asset = release.forBackend(backend, platform);
          expect(asset, isNotNull, reason: '${backend.id} on ${platform.id}');
          expect(asset!.assetName, assetName);
          expect(asset.platform, platform);
          expect(asset.tag, 'v0.8.0');
        });
      });
    });

    test('macOS ships CPU and Metal in one archive', () {
      final cpu = release.forBackend(
        RuntimeBackend.cpu,
        RuntimePlatform.macosArm64,
      );
      final metal = release.forBackend(
        RuntimeBackend.metal,
        RuntimePlatform.macosArm64,
      );

      expect(cpu, same(metal));
      expect(cpu!.provides(RuntimeBackend.cpu), isTrue);
      expect(cpu.provides(RuntimeBackend.metal), isTrue);
    });

    test('an unknown combination returns null', () {
      expect(
        release.forBackend(RuntimeBackend.metal, RuntimePlatform.windowsX64),
        isNull,
      );
    });
  });

  group('backendsFor', () {
    test('Linux offers CPU first, then every GPU build', () {
      expect(release.backendsFor(RuntimePlatform.linuxX64), <RuntimeBackend>[
        RuntimeBackend.cpu,
        RuntimeBackend.cuda13,
        RuntimeBackend.cuda12,
        RuntimeBackend.rocm,
        RuntimeBackend.vulkan,
      ]);
    });

    test('macOS offers CPU first, then Metal', () {
      expect(release.backendsFor(RuntimePlatform.macosArm64), <RuntimeBackend>[
        RuntimeBackend.cpu,
        RuntimeBackend.metal,
      ]);
    });

    test('Windows offers CPU first, then CUDA and Vulkan', () {
      expect(release.backendsFor(RuntimePlatform.windowsX64), <RuntimeBackend>[
        RuntimeBackend.cpu,
        RuntimeBackend.cuda13,
        RuntimeBackend.vulkan,
      ]);
    });

    test('every offered backend has an archive', () {
      for (final platform in RuntimePlatform.values) {
        for (final backend in release.backendsFor(platform)) {
          expect(
            release.forBackend(backend, platform),
            isNotNull,
            reason: '${backend.id} on ${platform.id}',
          );
        }
      }
    });
  });

  group('CUDA runtime archives', () {
    test('CUDA rows carry a cudart archive; the others do not', () {
      for (final asset in release.assets) {
        final cudart = asset.cudartAsset;
        if (asset.backend.bundlesCudart) {
          expect(cudart, isNotNull, reason: asset.assetName);
        } else {
          expect(cudart, isNull, reason: asset.assetName);
        }
      }
    });

    test(
      'cudart archives are named, sized and digested like the primary one',
      () {
        for (final asset in release.assets) {
          final cudart = asset.cudartAsset;
          if (cudart == null) {
            continue;
          }
          expect(cudart.assetName, isNot(asset.assetName));
          expect(cudart.sha256, matches(_digest));
          expect(cudart.sizeBytes, greaterThan(0));
          expect(cudart.platform, asset.platform);
          expect(cudart.backend, asset.backend);
          expect(cudart.cudartAsset, isNull);
          expect(cudart.url, endsWith('/${cudart.assetName}'));
        }
      },
    );
  });

  group('RuntimeBackend', () {
    test('ids are unique wire strings', () {
      final ids = RuntimeBackend.values.map((backend) => backend.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final backend in RuntimeBackend.values) {
        expect(RuntimeBackend.fromId(backend.id), same(backend));
      }
      expect(RuntimeBackend.fromId('opencl'), isNull);
    });

    test('only CUDA bundles a separate runtime', () {
      for (final backend in RuntimeBackend.values) {
        expect(
          backend.bundlesCudart,
          backend == RuntimeBackend.cuda12 || backend == RuntimeBackend.cuda13,
          reason: backend.id,
        );
      }
    });

    test('backend libraries use the platform library naming', () {
      expect(
        RuntimeBackend.cuda13.backendLibs(RuntimePlatform.linuxX64),
        <String>['libggml-cuda.so'],
      );
      expect(
        RuntimeBackend.vulkan.backendLibs(RuntimePlatform.windowsX64),
        <String>['ggml-vulkan.dll'],
      );
      expect(
        RuntimeBackend.metal.backendLibs(RuntimePlatform.macosArm64),
        <String>['libggml-metal.dylib'],
      );
      expect(
        RuntimeBackend.rocm.backendLibs(RuntimePlatform.linuxX64),
        <String>['libggml-hip.so'],
      );
      expect(RuntimeBackend.cpu.backendLibs(RuntimePlatform.linuxX64), <String>[
        'libggml-cpu.so',
      ]);
    });

    test('containsBackendLib matches the archive backends', () {
      final cuda = release.forBackend(
        RuntimeBackend.cuda13,
        RuntimePlatform.linuxX64,
      )!;
      expect(cuda.containsBackendLib('libggml-cuda.so'), isTrue);
      expect(cuda.containsBackendLib('libggml-metal.dylib'), isFalse);

      final macos = release.forBackend(
        RuntimeBackend.metal,
        RuntimePlatform.macosArm64,
      )!;
      expect(macos.containsBackendLib('libggml-metal.dylib'), isTrue);
      expect(macos.containsBackendLib('libggml-cpu.dylib'), isTrue);
    });

    test('recommendedFor keeps CPU first on every platform', () {
      for (final platform in RuntimePlatform.values) {
        final recommended = RuntimeBackend.recommendedFor(platform);
        expect(recommended.first, RuntimeBackend.cpu, reason: platform.id);
        expect(
          recommended.where((backend) => backend.isGpu),
          isNotEmpty,
          reason: platform.id,
        );
      }
    });
  });

  group('RuntimePlatform', () {
    test('ids are unique wire strings', () {
      final ids = RuntimePlatform.values
          .map((platform) => platform.id)
          .toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final platform in RuntimePlatform.values) {
        expect(RuntimePlatform.fromId(platform.id), same(platform));
      }
      expect(RuntimePlatform.fromId('linux-arm64'), isNull);
    });

    test('archive and binary naming follows the platform', () {
      expect(RuntimePlatform.linuxX64.archiveExtension, '.tar.gz');
      expect(RuntimePlatform.macosArm64.archiveExtension, '.tar.gz');
      expect(RuntimePlatform.windowsX64.archiveExtension, '.zip');
      expect(RuntimePlatform.linuxX64.serverBinaryName, 'llama-server');
      expect(RuntimePlatform.windowsX64.serverBinaryName, 'llama-server.exe');
      expect(RuntimePlatform.linuxX64.libraryFileName, 'libllama.so');
      expect(RuntimePlatform.macosArm64.libraryFileName, 'libllama.dylib');
      expect(RuntimePlatform.windowsX64.libraryFileName, 'llama.dll');
    });

    test('every pinned archive name uses its platform extension', () {
      for (final asset in release.assets) {
        expect(
          asset.assetName,
          endsWith(asset.platform.archiveExtension),
          reason: asset.assetName,
        );
      }
    });
  });
}
