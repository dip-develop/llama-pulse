# LlamaPulse

Run local language models through llama.cpp, from a desktop GUI or the command
line. Maintained by DIP Dev.

Status: alpha — the inference engine is not wired in yet.

## Why

- **Everything local.** No network, telemetry or account; files stay on disk.
- **Parameters you control.** Context, layers, threads and sampling stay visible.
- **One shared core.** GUI and CLI share entities and validation. The CLI reads
  and writes the YAML parameters file today; the app will use the same path and
  format once its editable form lands.

## Repository layout

```
llama-pulse/
├── pubspec.yaml            pub-workspace root and Melos 8 configuration
├── pubspec.lock            generated, git-ignored; shared by all members
├── analysis_options.yaml   shared lint rules
├── apps/llama_pulse/       Flutter desktop app
├── apps/llama_pulse_cli/   pure-Dart CLI, executable `llamapulse`
├── packages/llama_pulse_core/  Flutter-free entities, YAML config, scanning
├── AGENT.md                contributor and agent rules
└── LICENSE                 MIT
```

Naming: app `llama_pulse`, CLI `llamapulse`, package `llama_pulse_core`.

## What works today

- CLI commands: `version`, `params get`, `params set`, `models list` and
  `models inspect`, each with `--json` and documented exit codes. The CLI reads
  and writes the YAML parameters file.
- Core entities, validation, YAML config storage and model-file scanning.
- A Flutter window with a static inference screen that renders
  `ModelParams.defaults()` and says `Defaults — not yet editable`, plus launcher
  icons for Windows and macOS. The YAML repository and use cases are registered
  in DI, but nothing in `lib/` calls them yet.
- 135 tests across the three packages (107 core, 21 CLI, 7 app).

The llama.cpp engine, streaming generation, live metrics and the editable
parameter form are the next milestone.

## Requirements

Flutter 3.44+ declared (tested on 3.47.7), Dart 3.13+, and a llama.cpp shared
library only for the upcoming inference milestone.

## Quick start

```sh
git clone git@github.com:dip-develop/llama-pulse.git
cd llama-pulse
flutter pub get
dart run melos run gen
dart run melos run app
```

Build the CLI with `dart run melos run build:cli`. `melos` is a root
dev-dependency, so `dart run melos` needs no global install. Run `flutter pub get`
at the root only: the workspace resolves all three members into one lockfile.

## CLI

Run with `dart run llama_pulse_cli:llamapulse …` from the root, or use the
compiled `apps/llama_pulse_cli/build/llamapulse` after `build:cli`:

```console
$ llamapulse version
llamapulse 0.1.0
$ llamapulse params get
schemaVersion: 1
params:
  modelPath: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
  ...
$ llamapulse params set --context-size 4096 --temperature 0.5
$ llamapulse models list
llama-3.2-3b-instruct.Q4_K_M.gguf  1918.09  /home/you/.config/llamapulse/models/llama-3.2-3b-instruct.Q4_K_M.gguf
$ llamapulse models inspect /models/llama-3.2-3b-instruct.Q4_K_M.gguf
path: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
fileName: llama-3.2-3b-instruct.Q4_K_M.gguf
sizeMiB: 1918.09
modified: 2026-10-30T11:46:17.116Z
```

Every leaf command — `params get`, `params set`, `models list`, `models inspect`
and `version` — accepts `--json` and prints a single-line JSON object instead of
human-readable text. The `params` and `models` groups are not invocable and take
no `--json` of their own. The configuration file stays YAML either way.

| Exit code | Meaning |
|---|---|
| 0 | Success |
| 1 | Unexpected failure |
| 2 | Invalid arguments or values that failed validation |
| 3 | The requested model file was not found or is not a readable `.gguf` file |

## Configuration

The CLI reads and writes `params.yaml` today. The GUI will use the same file at
the same path once the parameter form is wired; nothing in the app reads or
writes it yet:

```yaml
# ~/.config/llamapulse/params.yaml (Linux)
schemaVersion: 1
params:
  modelPath: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
  contextSize: 2048
  gpuLayers: 0
  threads: 4
  temperature: 0.8
  topP: 0.95
  topK: 40
  maxTokens: 256
```

| Platform | Directory |
|---|---|
| Linux | `$XDG_CONFIG_HOME/llamapulse`, else `~/.config/llamapulse` |
| macOS | `~/Library/Application Support/LlamaPulse` |
| Windows | `%APPDATA%\LlamaPulse` |

Set `LLAMA_PULSE_CONFIG_DIR` to an absolute path to override the platform
location; `models/` sits inside it. Config is YAML; JSON only for `--json`.

## Architecture

The core is pure Dart; the app is the only Flutter member. The dependency rule
is `presentation → domain` and `data → domain`. Core's `domain` may use Dart
core libraries, `built_value`, `built_collection` and its own domain types; it
never imports Flutter, `dart:io` or plugins.

- Persisted models are immutable `built_value` values; UI state will be too once
  it exists.
- No `dart:ffi` work runs on the UI isolate once the engine lands.
- Every native failure surfaces as an `InferenceFailure`.

See [AGENT.md](AGENT.md) for the full rules.

## Roadmap

- [x] Shared core with entities, validation, scanning and YAML configuration
- [x] CLI `params` and `models` commands
- [x] Flutter app shell with DI registration
- [ ] Worker isolate and FFI engine
- [ ] Streaming generation with live tokens/sec metrics
- [ ] Editable parameter form with bloc
- [ ] Windows and macOS builds

Planned: llama.cpp binary downloader and updater, Hugging Face CLI integration,
model manager. Work is tracked in
[GitHub issues](https://github.com/dip-develop/llama-pulse/issues).

## Contributing

Read [AGENT.md](AGENT.md) first; it holds the workspace, architecture,
immutability and configuration rules reviews check.

- Branch from the current integration branch as `feature/<topic>`, `bugfix/<topic>`
  or `chore/<topic>`. PR base is `main` for now: there is no `develop` branch yet.
- Before pushing, run `dart run melos run gen`, `dart run melos analyze`,
  `dart run melos test` and `dart run melos run format:check`.
- Generated `.g.dart` and `.config.dart` files are committed; re-run gen after a
  model change, and add tests for the seam you touched or explain why not.

## License

MIT — see [LICENSE](LICENSE). © 2026 DIP Dev.

## Acknowledgements

- [llama.cpp](https://github.com/ggml-org/llama.cpp) and
  [ggml](https://github.com/ggml-org/ggml) for local inference.
- [Flutter](https://flutter.dev) for the desktop UI.
- [bloc](https://bloclibrary.dev), [get_it](https://pub.dev/packages/get_it),
  [injectable](https://pub.dev/packages/injectable) and
  [built_value](https://pub.dev/packages/built_value).
