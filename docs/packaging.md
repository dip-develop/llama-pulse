# Packaging

`tool/package_linux.sh` produces a relocatable Linux x64 bundle of the desktop
app, optionally with one managed llama.cpp runtime inside it. It does not build
installers or sign anything.

## What it produces

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

The version comes from `apps/llama_pulse/pubspec.yaml` (`0.1.0+1` becomes
`0.1.0`). The archive is a plain `.tar.gz`: extract it anywhere writable and
run `./llama_pulse`.

## Usage

```sh
# Release build, no bundled runtime.
tool/package_linux.sh

# Release build with the installed CUDA runtime copied into the bundle.
tool/package_linux.sh --runtime v0.8.0 cuda13

# Package an existing build (CI does this against the debug bundle).
tool/package_linux.sh --skip-build \
  --bundle apps/llama_pulse/build/linux/x64/debug/bundle \
  --out dist
```

| Flag | Meaning |
|---|---|
| `--runtime <tag> <backend>` | Copy `<config>/runtime/<tag>/<backend>/` into the bundle |
| `--config-dir <dir>` | Where to read that runtime from; defaults to `LLAMA_PULSE_CONFIG_DIR`, `$XDG_CONFIG_HOME/llamapulse`, then `~/.config/llamapulse` |
| `--out <dir>` | Output directory, default `dist/` |
| `--bundle <dir>` | Bundle to package, default `apps/llama_pulse/build/linux/x64/release/bundle` |
| `--skip-build` | Do not run `flutter build linux --release` |

The runtime must already be installed (`llamapulse runtime install --backend
<id>`) and must contain `llama-server`; the script refuses a path outside the
config layout and refuses an invalid tag or backend id. A CUDA runtime is
several hundred megabytes and needs the matching NVIDIA driver on the target
machine, so bundle it only when you know the target.

## How the bundle is found

Both loaders accept a runtime beside the executable without any configuration:

- `llama-server`: `<exeDir>/runtime/<tag>/<backend>/llama-server`
- `libllama`: `<exeDir>/runtime/<tag>/<backend>/libllama.so` (`.dylib`,
  `.dll` on the other platforms)

A macOS `.app` may also keep the runtime under
`<app>.app/Contents/Resources/runtime/<tag>/<backend>/`. The loaders check that
root as well, and `Contents/Resources` wins over `Contents/MacOS` when both
carry the same runtime.

A runtime the user selected under `<config>/runtime/` still wins over the
bundled one, so installing a newer or different backend later keeps working.
The bundled one is the fallback that makes a fresh installation runnable before
anything is downloaded. A bundled `llama-server` starts from its directory with
`LD_LIBRARY_PATH`, `DYLD_LIBRARY_PATH` and `PATH` prefixed and
`GGML_BACKEND_PATH` set, exactly like a managed install.

The copied `runtime.yaml` travels with the runtime, so the attested
`0.8.0-dev` gate works for a bundled prebuilt archive just as it does for a
downloaded one.

When a bundle carries more than one runtime, the loaders try the
`<tag>/<backend>` directories in reverse path order, which is deterministic
even though a copied tree has no install time. Ship one runtime per bundle
unless you have a reason not to.

## Requirements

- Flutter 3.44+ and the Linux desktop toolchain (`clang`, `cmake`,
  `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`).
- `bash`, `tar` and `gzip` to package.
- A built bundle; the script builds the release one by default.

## Verification

```sh
tar -tzf dist/llama-pulse-0.1.0-linux-x64.tar.gz | head
mkdir -p /tmp/lp-check && tar -xzf dist/llama-pulse-0.1.0-linux-x64.tar.gz -C /tmp/lp-check
LLAMA_PULSE_CONFIG_DIR=/tmp/lp-check/config /tmp/lp-check/llama-pulse-0.1.0-linux-x64/llama_pulse
```

The app reads `LLAMA_PULSE_CONFIG_DIR` first, so the check does not touch a real
configuration directory. With a bundled runtime and an empty config directory,
the dashboard's binary line and the Runtime tab show the bundled install; the
Runtime tab still offers to install another backend.

CI runs the packaging script against the debug bundle (`--skip-build`) on every
pull request, so a broken script or a missing README/LICENSE fails the gate.

## Not included yet

- Icons and desktop entries. The bundle carries Flutter's default icon;
  `flutter_launcher_icons` is a dev dependency but has no artwork wired up.
- Installers (`.deb`, AppImage, MSIX, `.dmg`) and signing/notarization.
- Windows and macOS bundles. The resolution change is shared; the scripts are
  not written.

These are tracked on the roadmap in `docs/status.md`.
