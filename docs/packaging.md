# Packaging

`packages/llama_pulse_core/tool/package_app.dart` stages a relocatable
desktop bundle and writes its archive for Linux, Windows and macOS, optionally
with one managed llama.cpp runtime inside it. It does not build installers, and
it does not sign or notarise anything beyond macOS's ad-hoc signature. The old
`tool/package_linux.sh` is a compatibility shim over the same Dart tool.

The tool lives in core because that package already depends on `archive` and
`path`; no new package enters the workspace resolution.

## Shared behaviour

The version comes from `apps/llama_pulse/pubspec.yaml` (`0.1.0+1` becomes
`0.1.0`). Stage and archive names are
`llama-pulse-<version>-<os>-<arch>`, where `<os>-<arch>` is `linux-x64`,
`windows-x64`, `macos-arm64` or `macos-x64` as reported by the host ABI. Run a
target on its own host: `--os` exists for CI and for staging a bundle copied
from another machine, not for cross-compiling a Flutter app.

```sh
dart run melos run package:linux
dart run melos run package:windows
dart run melos run package:macos
```

Each script runs the Dart tool with `--os <target>`. The Linux shim keeps the
old entry point:

```sh
tool/package_linux.sh
tool/package_linux.sh --runtime v0.8.0 cuda13
tool/package_linux.sh --skip-build --bundle apps/llama_pulse/build/linux/x64/debug/bundle
```

The shim `cd`s to the repository root before it runs the Dart tool, so relative
`--bundle`, `--out` and `--config-dir` paths in the examples above are resolved
from the repo root, not from the caller's working directory.

| Flag | Meaning |
|---|---|
| `--os linux\|windows\|macos` | Target; defaults to the host OS |
| `--runtime <tag> <backend>` | Copy `<config>/runtime/<tag>/<backend>/` into the bundle |
| `--config-dir <dir>` | Where to read that runtime from; defaults to `LLAMA_PULSE_CONFIG_DIR`, then the platform config directory |
| `--out <dir>` | Output directory, default `<repo>/dist` |
| `--bundle <dir>` | Bundle to package; defaults to the target's Flutter release output |
| `--skip-build` | Do not run `flutter build <os> --release` |
| `--check` | Stage into a temporary directory and verify the layout; write no archive |
| `-h`, `--help` | Usage |

| Exit code | Meaning |
|---|---|
| 0 | Success, including `--help` and `--check` |
| 1 | Missing bundle or runtime, a failed build, a filesystem error (unwritable or occupied `--out`), or a layout/archive verification problem |
| 2 | Usage or validation error: unknown OS, empty `--bundle`/`--out`, a stage path inside the bundle, an unsupported ABI, an unknown or invalid tag, or an unknown/unpublished backend |

The runtime must already be installed (`llamapulse runtime install --backend
<id>`) and must contain `llama-server` (`llama-server.exe` on Windows) plus
`runtime.yaml`. Before it looks for an installed runtime, the tool rejects a tag
this build does not package (`unknown runtime tag v0.7.0; this build packages
v0.8.0`), an invalid tag, or an unknown/unpublished backend, and lists the
backends actually published for the target (exit 2); only a valid backend that
is not installed reaches the "install the runtime first" message (exit 1). The
same precedence holds for the other usage errors: an `--out` that resolves the
stage inside the bundle is reported (exit 2) even when the runtime is also
missing. It copies the runtime verbatim; it never generates or rewrites
`runtime.yaml`, so the attested `0.8.0-dev` gate works for a bundled install
exactly as it does for a downloaded one. A CUDA runtime is several hundred
megabytes and needs the matching NVIDIA driver, so bundle it only when you know
the target.

Archives are written in the platform's format: `tar.gz` on Linux, `zip` on
Windows and macOS. macOS uses `ditto --sequesterRsrc --keepParent` so framework
symlinks and extended attributes survive; Windows uses a Dart ZIP written and
re-read as a stream, so a bundle with a large CUDA runtime is never held in
memory in one piece, and each entry's file handle is closed before the next one
opens. A failed write deletes the truncated archive instead of leaving it at the
final path. Before the tool reports success it re-reads the archive it
just wrote and compares every required entry with the staged tree; on macOS it
extracts the archive with
`ditto` and re-checks the layout, the executable bit and the ad-hoc signature
rather than trusting a file listing. `--check` exercises the same staging and
layout verification without writing an archive.

## Linux

```
dist/
├── llama-pulse-<version>-linux-x64/          staging tree
│   ├── llama_pulse                           the GTK executable
│   ├── lib/                                  Flutter engine, plugins, libapp.so
│   ├── data/                                 Flutter assets, icon
│   ├── README.md, LICENSE
│   └── runtime/<tag>/<backend>/              only with --runtime
└── llama-pulse-<version>-linux-x64.tar.gz
```

Host requirement: Linux x64 with Flutter 3.47.7 and the desktop toolchain
(`clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`),
plus `bash`, `tar` and `gzip` to package. Backends: `cpu`, `cuda12`, `cuda13`,
`vulkan`, `rocm`.

```sh
dart run melos run package:linux
dart run melos run package:linux -- --runtime v0.8.0 cuda13
```

The archive is a plain `.tar.gz`: extract it anywhere writable and run
`./llama_pulse`.

## Windows

```
dist/
├── llama-pulse-<version>-windows-x64/
│   ├── llama_pulse.exe
│   ├── flutter_windows.dll
│   ├── file_selector_windows_plugin.dll    plugin DLLs sit beside the executable
│   ├── data/
│   │   ├── icudtl.dat
│   │   └── flutter_assets/
│   ├── README.md, LICENSE
│   └── runtime/<tag>/<backend>/             only with --runtime
└── llama-pulse-<version>-windows-x64.zip
```

Host requirement: Windows 10/11 x64, Visual Studio 2022 with the "Desktop
development with C++" workload, and Flutter 3.47.7. Backends: `cpu`, `cuda13`,
`vulkan`. The staging copy drops `*.pdb`, `*.exp` and `*.lib`; those are build
artefacts and stay out of the shipped bundle.

```powershell
dart run melos run package:windows
dart run melos run package:windows -- --runtime v0.8.0 cuda13
```

Verify the archive the same way CI does:

```powershell
$zip = Get-ChildItem dist/*.zip | Select-Object -First 1
Expand-Archive -Path $zip.FullName -DestinationPath dist/verify
Get-ChildItem dist/verify -Recurse -Filter llama_pulse.exe
```

Then run `dist\verify\llama-pulse-<version>-windows-x64\llama_pulse.exe` with
`LLAMA_PULSE_CONFIG_DIR` pointed at an empty directory. Windows FFI loads
`llama.dll` and its sibling `ggml` DLLs from that runtime directory; only CI
exercises that path on a real Windows host.

## macOS

```
dist/
├── llama-pulse-<version>-macos-arm64/
│   ├── llama_pulse.app/
│   │   └── Contents/
│   │       ├── MacOS/llama_pulse
│   │       ├── Frameworks/                  FlutterMacOS, App and plugin frameworks
│   │       └── Resources/
│   │           └── runtime/<tag>/<backend>/ only with --runtime
│   ├── README.md, LICENSE                   beside the .app, never inside Contents/
│   └── ...
└── llama-pulse-<version>-macos-arm64.zip
```

Host requirement: macOS with Xcode installed. Apple silicon is required for
`--runtime`, because LlamaPulse pins only the `macos-arm64` runtime archive; an
Intel host can still package a `macos-x64` bundle without a bundled runtime.
Backends: `metal` and its `cpu` alias; there is no separate macOS CPU asset.
The runtime goes under `Contents/Resources/runtime/<tag>/<backend>/`, the
conventional location the loaders check first.

```sh
dart run melos run package:macos
dart run melos run package:macos -- --runtime v0.8.0 metal
```

Staging copies the whole `.app` as one unit, keeping the framework symlinks,
adds `README.md`/`LICENSE` beside it and the optional runtime inside
`Contents/Resources`, then refreshes the ad-hoc signature with
`codesign --force --deep --sign - llama_pulse.app`. That re-sign is required
because the added resources invalidate the signature Flutter produced.

The App Sandbox is deliberately off: LlamaPulse supervises an external
`llama-server` process and opens `.gguf` files the user selects anywhere on
disk, both of which the sandbox forbids. Mac App Store distribution is out of
scope, so `Release.entitlements` and `DebugProfile.entitlements` carry no
`com.apple.security.app-sandbox` key.

Verify the archive with `ditto`, which preserves the app's symlinks:

```sh
ditto -x -k dist/llama-pulse-0.1.0-macos-arm64.zip dist/verify
codesign --verify --deep --strict dist/verify/llama-pulse-0.1.0-macos-arm64/llama_pulse.app
open dist/verify/llama-pulse-0.1.0-macos-arm64/llama_pulse.app
```

A ZIP downloaded through a browser or another transfer picks up the
`com.apple.quarantine` attribute. Gatekeeper then blocks an unsigned, ad-hoc
signed app on first launch; right-click → Open bypasses it once, or
`xattr -dr com.apple.quarantine llama_pulse.app` clears the attribute. This is
the expected consequence of shipping without a Developer ID.

## How the bundle is found

Both loaders accept a runtime beside the executable without any configuration:

- `llama-server`: `<exeDir>/runtime/<tag>/<backend>/llama-server`
  (`llama-server.exe` on Windows)
- `libllama`: `<exeDir>/runtime/<tag>/<backend>/libllama.so` (`.dylib`, `.dll`
  on the other platforms)

A macOS `.app` keeps it under
`<app>.app/Contents/Resources/runtime/<tag>/<backend>/`; the loaders check that
root as well, and `Contents/Resources` wins over `Contents/MacOS` when both
carry the same runtime.

A runtime the user selected under `<config>/runtime/` still wins over the
bundled one, so installing a newer or different backend later keeps working.
The bundled one is the fallback that makes a fresh installation runnable before
anything is downloaded. A bundled `llama-server` starts from its directory with
`LD_LIBRARY_PATH`, `DYLD_LIBRARY_PATH` and `PATH` prefixed and
`GGML_BACKEND_PATH` set, exactly like a managed install.

When a bundle carries more than one runtime, the loaders try the
`<tag>/<backend>` directories in reverse path order, which is deterministic
even though a copied tree has no install time. Ship one runtime per bundle
unless you have a reason not to.

## What was verified where

| Target | Built | Smoke-tested |
|---|---|---|
| Linux x64 | On the Linux development workstation | Earlier check (PR #28, not re-run on this branch): archive extracted, app launched with an empty `LLAMA_PULSE_CONFIG_DIR`, bundled runtime reported by the dashboard. This branch re-produces and extracts the archive only. |
| Windows x64 | CI, `windows-latest` | CI: `Expand-Archive`, `llama_pulse.exe` present; no interactive launch |
| macOS arm64 | CI, `macos-latest` | CI, runtime-free and runtime-bearing bundles: `ditto -x -k`, executable bit, `codesign --verify --deep --strict`, and an assertion that the app is not sandboxed; the runtime-bearing bundle must also carry `Contents/Resources/runtime/v0.8.0/metal/` |

CI packages a **runtime-free** bundle on both CI hosts: it invokes the packager
without `--runtime`. On macOS it also packages a **runtime-bearing** bundle,
but with a **fixture** runtime built in the job: a compiled Mach-O
`libllama.dylib` (plus a `libggml-metal.dylib` copy, so `codesign --deep` signs
nested code rather than only a resource), a scripted `llama-server` and a
realistic `runtime.yaml`. That check extracts the archive with `ditto`, asserts
the runtime files under `Contents/Resources`, the executable bit and
`codesign --verify --deep --strict`, and re-reads the entitlements. It proves
`codesign --force --deep` covers the added runtime code; it does not prove a
**downloaded production** Metal runtime works, and Windows FFI loading of a
bundled runtime remains unexercised. The same gap does not exist for Linux
because the runtime is a plain file tree under the stage root, and Windows
runtimes are unsigned DLLs/EXEs already.

macOS archive correctness cannot be verified on the Linux workstation: `ditto`
and `codesign` do not exist there, and the real-ditto test skips unless the host
is macOS. Consequently the macOS archive layout and signature are covered by CI
on `macos-latest`, for runtime-free bundles and for a fixture runtime-bearing
bundle; the production dylibs from the pinned archive are still covered only by
unit tests. GPU backends are never exercised by packaging; they need real
hardware and are validated separately.

## Verification limits

- **No signing or notarisation.** The macOS app is ad-hoc signed only, and the
  Windows executables are unsigned. A future release needs a Developer ID plus
  either a hardened runtime with
  `com.apple.security.cs.disable-library-validation` or signatures on every
  runtime dylib, and notarisation for macOS; Windows needs Authenticode.
- The archive verifier checks structure, not execution. CI proves the bundles
  unpack and the macOS signature verifies, including a fixture runtime-bearing
  macOS bundle; it does not start a GUI, load a model, load a downloaded
  production runtime or run a GPU backend, and it does not exercise Windows FFI
  loading of a bundled runtime.
- Icons and desktop entries. Every bundle carries Flutter's default icon;
  `flutter_launcher_icons` is a dev dependency but has no artwork wired up.
- Installers (`.deb`, AppImage, MSIX, `.dmg`). These need new tooling and
  dependencies and are not part of the packager.

These are tracked on the roadmap in `docs/status.md`.
