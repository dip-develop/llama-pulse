# llama.cpp v0.8.0 runtime assets

The runtime downloader installs upstream prebuilt `llama.cpp` archives instead
of building them locally. This file records exactly which files are pinned, so
the code in
`packages/llama_pulse_core/lib/src/domain/runtime/runtime_release.dart` can be
audited against upstream without network access.

## Which build is `v0.8.0`?

Upstream publishes two kinds of release under the same tag:

- `v0.8.0` — the tagged release. It carries a single asset, `nightly-tag.txt`,
  which names the nightly build the tag was cut from.
- `b11960` — that nightly build. All binaries live here.

`nightly-tag.txt` (7 bytes) contains `b11960`:

| | |
|---|---|
| Tag | `v0.8.0` |
| Commit | `8642541b255bfb5dc39cd351a178be09013a55d6` |
| `nightly-tag.txt` content | `b11960` |
| `nightly-tag.txt` SHA-256 | `724adc02ee641157d1baadcf9136e832bba209ad0170e16e30872bc09f44b44f` |
| Binary build | `b11960` |
| ggml | `0.28.0` |
| Upstream repo | https://github.com/ggml-org/llama.cpp |

`LlamaVersionPin.commit` and `RuntimeRelease.v080.commit` are the same commit;
`RuntimeRelease.v080.build` is `b11960`.

## How the table was produced

```sh
# The tag to build number mapping.
curl -fsSL \
  https://github.com/ggml-org/llama.cpp/releases/download/v0.8.0/nightly-tag.txt
# -> b11960

# Every asset of the nightly build: name, size in bytes, digest.
gh api repos/ggml-org/llama.cpp/releases/tags/b11960 \
  --jq '.assets[] | [.name, .size, .digest] | @tsv'
```

Sizes and digests below are copied verbatim from that output. Nothing here is
estimated except the unpacked-size factor the downloader uses for its free
space check (archive size x 2.5).

## Pinned assets

Linux x64:

| Backend | Asset | Size (bytes) | SHA-256 |
|---|---|---|---|
| `cpu` | `llama-b11960-bin-ubuntu-x64.tar.gz` | 22686210 | `31cc3a6bc638ac6c48dc4b1b74888f1eaadf3d14227c1e5f67daf9a49541d97a` |
| `cuda12` | `llama-b11960-bin-ubuntu-cuda-12.8-x64.tar.gz` | 182524002 | `64d57beb9abb637c177c6afb313760a0c0782224cac71e74869eed5b8f9a1ea4` |
| `cuda12` runtime | `cudart-llama-b11960-bin-ubuntu-cuda-12.8-x64.tar.gz` | 594371478 | `7c4d5974bd39649df649649e5d71950688a70e37aaae00bf11afbb656ea2cc56` |
| `cuda13` | `llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz` | 163957335 | `0cf758b28483593a5a15e0d2c9b686c40840d1f8be9b5bb2417f04a053113907` |
| `cuda13` runtime | `cudart-llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz` | 440232534 | `756e14988abb5daa60d25f27a9766a9a78f04c88647c4b92a88fb749488d72f7` |
| `vulkan` | `llama-b11960-bin-ubuntu-vulkan-x64.tar.gz` | 35474467 | `164199e978304bb32a8a6c24b8efa015528ddf286821596eab676c90b375feac` |
| `rocm` | `llama-b11960-bin-ubuntu-rocm-10.0-x64.tar.gz` | 251572351 | `63546b0175840c75b261bcb55e75cce49852c6d632eee352edbfa62c3bf120e3` |

macOS arm64:

| Backend | Asset | Size (bytes) | SHA-256 |
|---|---|---|---|
| `metal` (+ `cpu`) | `llama-b11960-bin-macos-arm64.tar.gz` | 16465074 | `58e5a5e1d7c2bf66cedd9c29e0323f3e570660a70a1e2156d32eed08f4cc1e3c` |

The macOS archive is built for Metal and also contains the CPU backend, so
there is one download for both. `RuntimeAsset.additionalBackends` records this:
`forBackend(cpu, macosArm64)` and `forBackend(metal, macosArm64)` return the
same object.

Windows x64:

| Backend | Asset | Size (bytes) | SHA-256 |
|---|---|---|---|
| `cpu` | `llama-b11960-bin-win-cpu-x64.zip` | 24407745 | `73f962f82850d244db47eaacb9d913637027b82399124324298576d58c5f4287` |
| `cuda13` | `llama-b11960-bin-win-cuda-13.4-x64.zip` | 164986387 | `31c75ea62b80f0816c855ea783ef68757bc2d48028edaa57d904e4982bddea4a` |
| `cuda13` runtime | `cudart-llama-bin-win-cuda-13.4-x64.zip` | 423535356 | `738f8c251ac22b70c3ae6f83a10cf222725df0395246a2cf58f32bdb85fbe668` |
| `vulkan` | `llama-b11960-bin-win-vulkan-x64.zip` | 37345851 | `bac6914b5e83523eb008c6789eaa12669f93fbc196c3b9e8237b6672323b33e9` |

The Windows CUDA runtime asset keeps upstream's name, which omits the build
number (`cudart-llama-bin-win-cuda-13.4-x64.zip`); the Linux one includes it.
That is upstream's naming, not a transcription error.

Not pinned for v1: CUDA 12.x on Windows, ROCm on Windows, SYCL, OpenVINO,
OpenCL, Snapdragon/Adreno, s390x, the xcframework, the UI archive and all
arm64 Linux assets. They are present in the release and can be added to
`RuntimeRelease.v080` later.

## Rule: digests are pinned here, never looked up at install time

GitHub release assets are mutable: upstream can delete and re-upload an asset
under the same name, and the bytes can change. The downloader therefore:

1. resolves the asset from the `const` table in
   `runtime_release.dart` — never from a `releases/latest` or `releases/tags/...`
   API call;
2. downloads `asset.url` and checks the SHA-256 against `asset.sha256` before
   unpacking;
3. rejects the archive and deletes the partial file on a mismatch.

Changing a pin means editing `runtime_release.dart`, this file and the test in
`packages/llama_pulse_core/test/domain/runtime/runtime_release_test.dart` in the
same commit.

`sha256sum -c third_party/llama_cpp/v0.8.0/SHA256SUMS` still verifies the
vendored headers described in [`PIN.md`](PIN.md); it does not cover the runtime
archives above.
