# Managed llama.cpp runtimes

LlamaPulse can download, verify and install the official prebuilt llama.cpp
releases into a directory it owns, then prefer that runtime over a bundled or
hand-built one. This document describes the layout, the pinned assets, the
resolution order, the version gate and the CLI/GUI surfaces.

The digests themselves live in
[`third_party/llama_cpp/v0.8.0/RUNTIME_ASSETS.md`](../third_party/llama_cpp/v0.8.0/RUNTIME_ASSETS.md),
and the code that mirrors them is
`packages/llama_pulse_core/lib/src/domain/runtime/runtime_release.dart`.

## The pinned release

| | |
|---|---|
| Tag | `v0.8.0` |
| Build | `b11960` |
| Commit | `8642541b255bfb5dc39cd351a178be09013a55d6` |
| ggml | `0.28.0` |
| Source | https://github.com/ggml-org/llama.cpp |

Upstream publishes the tag with a single `nightly-tag.txt` asset naming the
nightly build (`b11960`); the binaries live on that nightly release. Nothing is
resolved through the GitHub API at install time: the tag, build, commit, asset
name, size and SHA-256 of every archive are constants in `RuntimeRelease.v080`.

## Backend matrix

Only the backends upstream actually ships are offered, per platform:

| Platform | Backends |
|---|---|
| Linux x64 | `cpu`, `cuda13`, `cuda12`, `rocm`, `vulkan` |
| macOS arm64 | `metal`, and `cpu` as an alias of the same archive |
| Windows x64 | `cpu`, `cuda13`, `vulkan` |

`DartRuntimeProbe` reads `nvidia-smi`, `rocm-smi`, `vulkaninfo`, the Vulkan ICD
directories and `/opt/rocm`, then ranks the supported backends: CUDA 13, CUDA
12, ROCm, Vulkan, CPU on Linux/Windows; Metal, then CPU on macOS. Every verdict
carries the evidence (`nvidia driver 580.95 >= 580`, `libvulkan.so.1 not
found`), which is what the CLI and the GUI show. The probe never throws; a
missing tool only makes that backend unavailable.

A CUDA backend links against `cudart`, which upstream ships as a second archive
(440–594 MB on Linux). The installer downloads it as part of the same install,
but only after the caller consents: `runtime install` asks unless `--yes` is
given, and the GUI's install dialog states both sizes and the driver floor.

## Layout

Everything lives under `<config>/runtime/`:

```
<config>/runtime/index.yaml
<config>/runtime/<tag>/<backend>/runtime.yaml
<config>/runtime/<tag>/<backend>/llama-server
<config>/runtime/<tag>/<backend>/libllama.so|.dylib|.dll
<config>/runtime/<tag>/<backend>/libggml*.so
<config>/runtime/.tmp-<tag>-<backend>-<pid>-<n>/   (staging, transient)
```

`<config>` is the platform directory described in the README's configuration
section (`~/.config/llamapulse` on Linux, `%APPDATA%\LlamaPulse` on Windows,
`~/Library/Application Support/LlamaPulse` on macOS).

`index.yaml` records every committed runtime and which one is selected:

```yaml
schemaVersion: 1
selectedTag: v0.8.0
selectedBackend: cuda13
installed:
  - tag: v0.8.0
    backend: cuda13
    platform: linux-x64
    installedAtEpochMs: 1767225600000
    sizeBytes: 163957335
```

`runtime.yaml` is the manifest written at commit time:

```yaml
schemaVersion: 1
tag: v0.8.0
build: b11960
commit: 8642541b255bfb5dc39cd351a178be09013a55d6
backend: cuda13
platform: linux-x64
assetName: llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz
sha256: 0cf758b28483593a5a15e0d2c9b686c40840d1f8be9b5bb2417f04a053113907
sizeBytes: 163957335
installedAtEpochMs: 1767225600000
llamaVersion: 0.8.0-dev
buildNumber: 11960
backendLibs:
  - libggml-cuda.so
requires: NVIDIA driver r580 or newer (CUDA 13.4 runtime).
files: 42
```

A malformed or missing index reads as "no managed runtime"; a malformed
manifest reads as "not installed". Neither blocks a launch, and the next
mutation rewrites the index.

## Install pipeline

1. **Staging.** A fresh `.tmp-<tag>-<backend>-<pid>-<n>` directory is created
   under `<config>/runtime/`. An interrupted download leaves exactly one
   `asset.part` there, which a retry resumes with `Range`/`If-Range`.
2. **Download.** `HttpRuntimeFetcher` over `dart:io` follows redirects, disables
   transparent gzip so digests cover the wire bytes, and aborts on
   cancellation. Progress is throttled to about 200 ms.
3. **Verify.** The stream is hashed while it is written; the size and SHA-256
   must match the pinned asset or the partial file is deleted and the install
   fails. A free-space check reserves archive size x 2.5.
4. **Extract.** `ArchiveExtractor` streams `.tar.gz` and `.zip`, strips the one
   top-level directory, and rejects absolute paths, `..`, symlinks, hard links,
   duplicates, device entries and oversized payloads.
5. **Probe.** With an executor, `llama-server --version` supplies the version,
   build and commit. A failing probe is informational only.
6. **Commit.** `YamlRuntimeStore.commit` verifies the expected files, moves the
   staging tree into place with one rename (replacing an existing install only
   with `--force`), writes `runtime.yaml`, and updates `index.yaml` atomically.
7. **Cleanup.** The staging shell is removed, and `cleanupOrphans` deletes
   abandoned staging trees older than a day.

`RuntimeInstaller` owns this pipeline; `RuntimeDownloader` and
`YamlRuntimeStore` stay independent so they can be tested on their own.

## Resolution order

Both the server binary and the embedded library prefer managed runtimes.

`llama-server` (`ServerBinaryLocatorImpl`):

1. `server.yaml`'s `binaryPath`
2. `LLAMA_PULSE_SERVER`
3. `<exeDir>/data/llama-server`, `<exeDir>/llama-server`
4. installed runtimes, in `RuntimeIndex.resolutionOrder`: the selected backend
   first, then the other installs newest first
5. `<config>/bin/llama-server`
6. `PATH`

`libllama` (`LlamaLibraryLocator`):

1. `--lib` / engine path
2. `LLAMA_PULSE_LIB`
3. `<exeDir>/lib`, `<exeDir>`, `<exeDir>/../Frameworks`
4. installed runtimes, same order as above
5. `<config>/lib`
6. the bare soname

A binary resolved from a runtime starts with that directory as its working
directory and with `LD_LIBRARY_PATH`, `DYLD_LIBRARY_PATH` and `PATH` prefixed by
it, plus `GGML_BACKEND_PATH` set to it. That is what makes `libllama` find the
`libggml*` files of the same install and stops an older `/opt` install from
being picked up.

## GPU backend loading

Pre-opening `libggml*` siblings is not enough: ggml only registers a backend
plugin when it is asked to. `LlamaLibrary` therefore binds
`ggml_backend_load_all_from_path` from the preloaded `libggml` handle and calls
it with the library's directory **before** `llama_backend_init`. Without that
call a directory with `libggml-cuda.so` silently runs on the CPU.

The symbol lives in the top-level `libggml`, not in the plugins, so the loader
tries each sibling and keeps the first handle that exports it. A directory with
no `libggml` (a self-contained build) still opens.

## Version gate

A locally built `-DLLAMA_BUILD_IS_DEV=OFF` library reports `0.8.0` and passes
the exact check.

Official prebuilt archives are built with `LLAMA_BUILD_IS_DEV=ON`, so the same
source reports `0.8.0-dev`. The gate accepts that string only with an
**attestation**: `runtime.yaml` beside the library must name

- tag `v0.8.0`,
- build `b11960`,
- a commit that is a prefix of `8642541b255bfb5dc39cd351a178be09013a55d6`
  (at least 7 characters),
- the pinned archive name, SHA-256 and size for that backend and platform.

Anything else, including `/opt/llama.cpp-rocm`, an Unsloth fork that reports
`0.7.0-dev`, fails with `libraryVersionMismatch` and the reported version. The
gate never accepts a library on an unreadable manifest, and `runtime status`
prints the verdict it would reach (`exact`, `attested`, `unknown`, `rejected`,
`notInstalled`) with its reason.

## CLI

```console
$ llamapulse runtime status
host: linux/x64 (linux-x64)
gpu: NVIDIA GeForce RTX 4090 (nvidia, driver 580.95)
detected: cuda=true rocm=false vulkan=true
recommendation: cuda13 (nvidia driver 580.95 >= 580)
release: v0.8.0 b11960
backends: cpu, cuda13, cuda12, rocm, vulkan
selected: none
installed: 0
gate: notInstalled (no runtime is selected)

$ llamapulse runtime install --backend cuda13
installing cuda13 for linux-x64: 156.36 MiB
requires: NVIDIA driver r580 or newer (CUDA 13.4 runtime).
cuda13 also installs the CUDA runtime (419.84 MiB) ...
continue? [y/N] y
downloading llama-b11960-bin-ubuntu-cuda-13.4-x64.tar.gz: 40% ...
installed v0.8.0/cuda13 at /home/you/.config/llamapulse/runtime/v0.8.0/cuda13

$ llamapulse runtime select v0.8.0 cuda13
selected v0.8.0/cuda13
$ llamapulse runtime list
selected: v0.8.0/cuda13
* v0.8.0/cuda13   linux-x64    156.36 MiB
$ llamapulse runtime remove v0.8.0 cuda13
removed v0.8.0/cuda13
```

`runtime install --json` emits NDJSON on stdout: `runtimeProgress` lines while
the archive downloads, then one `runtimeInstall` object. A failure adds a
`runtimeFailed` object and a diagnostic on stderr. `runtime list`, `status`,
`select` and `remove` accept `--json` and print one object.

Flags: `--backend <id>` (required), `--tag` (default `v0.8.0`; anything else is
a usage error), `--force` to replace an existing install, `--yes` to accept the
CUDA runtime without prompting.

Exit codes for the group: `0` success, `1` unexpected failure (`status` on an
unsupported host), `2` usage or validation, `3` the requested runtime is not
installed, `4` integrity (checksum, size, extraction, unsafe archive, manifest),
`5` network or HTTP, `130` interrupted by SIGINT (the install is cancelled and
its staging tree removed).

## GUI

The Runtime tab and the compact card under the dashboard status card share one
`RuntimeBloc`. Both show the detected hardware, the recommended backend chip,
the installed and selected runtime and the gate verdict. The install dialog
states the download size (including the CUDA runtime) and the driver floor
before it starts; a running install shows a progress bar with Cancel, and
removal asks for confirmation.

## Tests

Runtime tests use fakes only: an in-memory fetcher, an in-memory store, a canned
probe and a scripted installer. No test downloads an archive or runs a vendor
tool. The native loader tests compile the C shims under
`packages/llama_pulse_core/test/support/native/` with clang (skipped without
clang), including a fake `libggml` that records whether backend registration
happened before `llama_backend_init`.

## Landmines

- `/opt/llama.cpp-rocm` is an Unsloth fork that reports `0.7.0-dev`; it must
  stay rejected. That is the gate working, not a bug.
- A shell that inherits `LD_LIBRARY_PATH` from another llama.cpp install can
  still confuse a non-managed binary; managed runtimes avoid this by prefixing
  the variable themselves.
- One embedded engine per process: `llama_backend_init` is process-global and
  `dart:ffi` cannot `dlclose`, so a backend set cannot be swapped after the
  first successful load.
- 64-bit desktop only; the native structs cross FFI by value.
