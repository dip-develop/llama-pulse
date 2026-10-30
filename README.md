# LlamaPulse

Run local language models through llama.cpp, from a desktop GUI or the command
line. Maintained by DIP Dev.

Status: alpha — the stub worker engine, the desktop GUI and the CLI
`run`/`bench` commands are wired end to end. The native llama.cpp session is the
next milestone.

## Why

- **Everything local.** No network, telemetry or account; files stay on disk.
- **Parameters you control.** Context, layers, threads and sampling stay visible.
- **One shared core.** GUI and CLI share entities, validation and the YAML
  parameters file: both read and write the same `params.yaml`, and the app
  persists it when you press Save.

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

- CLI commands: `version`, `params get`, `params set`, `models list`,
  `models inspect`, plus `run` and `bench`, each with documented exit codes.
  `run` and `bench` require `--stub` today; every command that prints data
  supports `--json`, and `run` also supports `--stream`.
- Core entities, validation, YAML config storage, model-file scanning and the
  worker-isolate inference layer (`WorkerRequest`/`WorkerResponse`,
  `WorkerTransport`, `WorkerLlamaEngine`, `WorkerLoop`, `StubLlamaSession`).
  The worker selects the stub session only when asked; the default fails
  `load` with `engineUnavailable`. There is no `dart:ffi` code yet.
- Demo-mode GUI: editable parameters persisted to the shared `params.yaml`, a
  prompt editor, Generate/Cancel/Unload, streamed output, a live tokens/sec
  metrics panel and a failure banner. A normal build ships no engine and says
  so; `melos run app:stub` enables the synthetic engine.
- 237 tests across the three packages (155 core, 53 CLI, 29 app).

The native llama.cpp session is the next milestone. It slots in behind
`LlamaSession` without changing the `LlamaEngine` API or the GUI.

## Requirements

Flutter 3.44+ declared (tested on 3.47.7) and Dart 3.13+. The stub engine, the
GUI and every CLI command run with no llama.cpp library installed; the native
session will need one.

## Quick start

```sh
git clone git@github.com:dip-develop/llama-pulse.git
cd llama-pulse
flutter pub get
dart run melos run gen
dart run melos run app:stub   # GUI with the synthetic stub engine
```

`dart run melos run app` starts the same GUI with **no engine**; loading or
generating then reports that the engine is unavailable in the UI. Use
`app:stub`, or pass `--dart-define=LLAMAPULSE_STUB_ENGINE=true`, to opt into
synthetic output. The demo build shows a
`Demo engine — output is synthetic.` banner so the two cannot be confused.

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

### `run`

Generate one prompt. The native engine is not implemented yet, so `--stub` is
mandatory today: without it the command exits 1 with `engineUnavailable` and
never falls back silently. In stub mode the model path is echoed into the
request but not read, so no file-existence check happens.

```
$ llamapulse run --stub --model /models/demo.gguf --prompt "Hello" --max-tokens 8
Local models run on your machine. No
$ cat prompt.txt | llamapulse run --stub --model /models/demo.gguf --file - --json
```

Flags: `--model`, `--prompt`, `--file` (`-` reads stdin), `--stream`, `--json`,
`--threads`, `--temperature`, `--top-p`, `--top-k`, `--max-tokens`,
`--context-size`. `--prompt` and `--file` are mutually exclusive; one is
required. `--json` and `--stream` cannot be combined.

`--stream` writes newline-delimited JSON (NDJSON), schema v1, one object per
line. In the order they occur, the event types are `started`, `token`,
`metrics`, `completed`, `cancelled` and `failed`:

```console
$ llamapulse run --stub --model /models/demo.gguf --prompt "Hello" --max-tokens 8 --stream
{"schemaVersion":1,"type":"started","requestId":1}
{"schemaVersion":1,"type":"token","requestId":1,"text":"Local"}
{"schemaVersion":1,"type":"token","requestId":1,"text":" models"}
{"schemaVersion":1,"type":"metrics","requestId":1,"metrics":{"promptTokenCount":1,"generatedTokenCount":8,"promptEvalMs":3,"evalMs":189,"tokensPerSecond":42.33,"promptTokensPerSecond":333.33}}
{"schemaVersion":1,"type":"completed","requestId":1,"text":"Local models run on your machine. No","metrics":{"promptTokenCount":1,"generatedTokenCount":8,"promptEvalMs":3,"evalMs":189,"tokensPerSecond":42.33,"promptTokensPerSecond":333.33}}
```

A `metrics` object carries `promptTokenCount`, `generatedTokenCount`,
`promptEvalMs`, `evalMs`, `tokensPerSecond` and `promptTokensPerSecond`; rates
are rounded to two decimals. A `failed` event carries `text` and a `failure`
object with `code`, `message` and `details`. `run --json` prints exactly one
final object instead of a stream.

### `bench`

Run the fixed prompt `The quick brown fox jumps over the lazy dog.` several
times and report aggregate throughput. `--stub` is mandatory today, as for
`run`; with no configured model, stub mode uses the `<stub>` placeholder path.

```
$ llamapulse bench --stub --runs 3
runs: 3  generatedTokens: 36  evalMs: 818  tokensPerSecond: 44.01
$ llamapulse bench --stub --runs 3 --json
{"schemaVersion":1,"type":"bench","runs":3,"modelPath":"<stub>","promptChars":44,"promptTokenCount":11,"generatedTokenCount":36,"evalMs":818,"tokensPerSecond":44.01,"perRun":[{"requestId":1,"generatedTokenCount":12,"evalMs":274,"tokensPerSecond":43.8},{"requestId":2,"generatedTokenCount":12,"evalMs":272,"tokensPerSecond":44.12},{"requestId":3,"generatedTokenCount":12,"evalMs":272,"tokensPerSecond":44.12}]}
```

Flags: `--runs` (1..50, default 3), `--json`, `--max-tokens` (default 32) and
the shared `--model`, `--threads`, `--temperature`, `--top-p`, `--top-k` and
`--context-size` overrides. `--json` prints one object with `schemaVersion`,
`type: "bench"`, `runs`, `modelPath`, `promptChars`, `promptTokenCount`,
`generatedTokenCount`, `evalMs`, `tokensPerSecond` and a `perRun` array. Human
mode prints the aggregate line on stdout; per-run progress and diagnostics go
to stderr.

stdout carries data only — generated text, NDJSON events or the final JSON
object. stderr carries diagnostics, the human summary and usage errors.

Every leaf command — `version`, `params get`, `params set`, `models list`,
`models inspect`, `run` and `bench` — accepts `--json` and prints a single-line
JSON object instead of human-readable text; `run` additionally accepts
`--stream`. The `params` and `models` groups are not invocable and take no
`--json` of their own. The configuration file stays YAML either way.

| Exit code | Meaning |
|---|---|
| 0 | Success |
| 1 | Unexpected failure, including `engineUnavailable` without `--stub` |
| 2 | Invalid arguments or values that failed validation |
| 3 | The requested model file was not found or is not a readable `.gguf` file |
| 130 | Cancelled by SIGINT |

## Configuration

The CLI and the GUI read and write the same `params.yaml` at the same platform
path. The app loads the stored values into the form and persists them when you
press Save; the CLI's `params get` prints exactly the document the repository
writes:

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

All engine work runs in a worker isolate; the UI isolate never touches it.

- `WorkerLlamaEngine` spawns exactly one long-lived isolate, lazily on the first
  `load`, `unload` or `generate`, and speaks `WorkerRequest`/`WorkerResponse`
  over ports. Caller request ids are non-negative and unique per request;
  control requests use negative ids so they cannot collide.
- The worker isolate owns the `LlamaSession`. Cancellation is cooperative: a
  `cancel` request is checked between steps and never becomes `Isolate.kill`.
- The worker coalesces token batches and emits metrics every 250 ms; exactly one
  terminal response (`completed`, `cancelled` or `failed`) ends each request.
- Persisted models and UI state are immutable `built_value` values, with
  `BuiltList` for collections.
- There is no `dart:ffi` code yet. The native session will implement the
  existing `LlamaSession` interface and drop in behind the same `LlamaEngine`
  API without changing the GUI or the CLI.
- Every engine failure surfaces as an `InferenceFailure`; load failures throw
  `InferenceFailureException`.

See [AGENT.md](AGENT.md) for the full rules.

## Roadmap

- [x] Shared core with entities, validation, scanning and YAML configuration
- [x] CLI `params` and `models` commands
- [x] Flutter app shell with DI registration
- [x] Worker isolate with a stub engine
- [x] Streaming generation with live tokens/sec metrics
- [x] Editable parameter form with bloc
- [ ] Native llama.cpp session (pinned upstream tag, runtime version gate)
- [ ] Windows and macOS builds

Immediately next: the native llama.cpp session. Planned after that: the
llama.cpp binary downloader and updater, Hugging Face CLI integration, model
manager. The downloader will **ask which compute backend to install
(CPU/ROCm/CUDA/Vulkan/Metal)** and offer a detected default rather than
guessing. Work is tracked in
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
