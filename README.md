# LlamaPulse

Run local models as an OpenAI-compatible server from a desktop app. LlamaPulse
launches and supervises `llama-server` so OpenCode, IDEs and scripts can use a
local endpoint. Maintained by DIP Dev.

Status: alpha — the `llama-server` supervisor, the server dashboard and the CLI
server commands work. The native embedded engine behind the experimental Chat
tab is deferred; that tab still uses the existing stub/embedded path.

## Why

- **Your models, your machine.** No account, telemetry or hosted API; model
  files, configuration and logs stay on disk.
- **A real OpenAI-compatible endpoint.** Start `llama-server` once and point
  any compatible client at `http://127.0.0.1:8080/v1`.
- **Parameters you can see.** Model, context, threads, GPU layers, slots and
  sampling stay visible and editable in `server.yaml`.
- **One shared core.** The GUI, the CLI and the supervisor share entities,
  validation, configuration and the process seam.

## Repository layout

```
llama-pulse/
├── pubspec.yaml            pub-workspace root and Melos 8 configuration
├── pubspec.lock            generated, git-ignored; shared by all members
├── analysis_options.yaml   shared lint rules
├── apps/llama_pulse/       Flutter desktop app
│   └── lib/presentation/   home/ (shell), server/ (dashboard), inference/
├── apps/llama_pulse_cli/   pure-Dart CLI, executable `llamapulse`
├── packages/llama_pulse_core/
│   ├── lib/src/domain/     entities/, gateways/, usecases/, text/
│   └── lib/src/data/       config/, inference/, models/, server/, serialization/
├── AGENT.md                contributor and agent rules
└── LICENSE                 MIT
```

Naming: app `llama_pulse`, CLI `llamapulse`, package `llama_pulse_core`.

## What works today

- **Server dashboard** (the primary screen): an editable `server.yaml` form,
  start/stop, supervisor status, the endpoint with Copy and Test connection,
  live metrics and a log tail. If `server-state.yaml` records an active run the
  app did not start, it seeds the dashboard from that document, disables Start
  and tells you to run `llamapulse stop` (`Started outside this app`). While it
  shows such an external run it re-reads the document every 2 s; when the run
  ends (for example after `llamapulse stop`) the dashboard clears the external
  flag and enables Start again. Reload re-reads `server.yaml` and the state
  document. On POSIX the app installs SIGTERM and SIGINT handlers that dispose
  the controller, so a running child is terminated, then exits `0` or `130`;
  Windows has no signal watchers. The app also disposes the DI-owned
  `ServerController` when the window closes.
- **Configuration in `server.yaml`**: model path, host, port, context size,
  threads, GPU layers, parallel slots, model alias, API key, flash attention,
  mlock/mmap, extra `llama-server` arguments, binary path and startup timeout.
- **Supervised lifecycle**: validate, locate the binary, spawn, wait for
  `/health`, report `running`, then stop gracefully and force after a 5 s
  grace. `stop()` and `dispose()` wait for an in-flight `start()`, so the run
  never ends up `running` after a stop request, and `stop()` retries a child
  pid that a `failed` document still records. A process that survives `SIGKILL`
  is not reported as stopped: the document stays `failed` with its pid, a later
  `stop` can retry it, and the supervisor refuses a new `start` while its state
  still records that pid.
  There is no auto-restart: a failed or exited server stays failed until you
  start it again.
- **Health and readiness** from `GET /health`, plus `/props` enrichment. Health
  is `ok` only for an HTTP 200 whose body is `{"status":"ok"}`; a 200 with
  `{"status":"loading"}` is `degraded`/`loading`, not healthy. While the server
  runs the supervisor polls `/health` about once a second and marks the run
  `degraded` or `unreachable` when a probe fails, keeping the phase unchanged;
  health recovers when the server answers again. The port preflight is
  advisory; a bind failure reported on the child's stderr is mapped to the same
  `portInUse` failure.
- **Metrics**: the production supervisor owns a `ServerMonitor` that samples
  `/metrics` (Prometheus), `/slots` and `/props` about once a second while the
  server runs and emits `ServerMetrics` on the metrics stream. It reports
  generation and prompt tokens/sec, active/total slots, processing and deferred
  requests, prompt and predicted token totals, uptime from the
  `Process-Start-Time-Unix` response header, and context usage derived from
  `/slots`. Current llama.cpp has no total-request counter, so LlamaPulse does
  not show one.
- **Log tail**: in-memory ring of 1000 lines and `server.log` on disk, rotated
  at 1 MiB to `server.log.1`, with one `timestamp<TAB>sequence<TAB>stream<TAB>line`
  record per line. Sequence numbers continue across a supervisor restart,
  seeded from the highest sequence already stored.
- **Endpoint actions**: copy the base URL and test the connection, including
  the API key when one is configured.
- **Chat tab, experimental**: still the existing stub/embedded engine. It is
  not the primary path and does not use the supervised server.
- **CLI**: `server get|set`, `serve`, `status`, `stop`, `logs`, plus the
  earlier `version`, `params get|set`, `models list|inspect`, `run` and `bench`.
- **Binary discovery and version warning**: a configured path, an environment
  variable, the app bundle, the config `bin/` directory and `PATH` are tried in
  that order. Builds below `b4000` warn, and an unknown or unreadable
  `llama-server --version` reports `supported: true` with a warning; nothing
  blocks a start on the version.
- **596 tests** across the three packages (388 core, 121 CLI, 87 app).

## Requirements

Flutter 3.44+ declared (tested on 3.47.7) and Dart 3.13+. The CLI and the core
build without llama.cpp. To actually serve a model you need a `llama-server`
binary; build `b4000` or newer is supported, while older or unknown/unreadable
builds only warn. Put it on
`PATH`, next to the executable, in the app's `data/` directory, in
`<config>/bin/`, or point `LLAMA_PULSE_SERVER` or `server.yaml`'s
`binaryPath` at it.

## Quick start

```sh
git clone git@github.com:dip-develop/llama-pulse.git
cd llama-pulse
flutter pub get
dart run melos run gen
dart run melos run app        # dashboard + the real llama-server supervisor
```

Enter a `.gguf` model path, press Save, then Start. The dashboard shows the
lifecycle, `/health`, live metrics and the log tail. `dart run melos run
app:stub-server` opens the same dashboard with a synthetic controller and a
demo banner, and starts no process; use it when no llama.cpp binary is
installed. The Chat tab is reached from the rail and carries an `Experimental`
banner.

For a headless server:

```sh
dart run melos run build:cli
apps/llama_pulse_cli/build/llamapulse serve \
  --model /models/llama-3.2-3b-instruct.Q4_K_M.gguf \
  --port 8080
```

`serve` stays in the foreground and mirrors `llama-server` output. From another
terminal:

```console
$ llamapulse status
status: running
pid: 38612
supervisorPid: 38601
endpoint: http://127.0.0.1:8080/v1
model: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
binary: /usr/local/bin/llama-server (b6250, build 6250)
health: ok
uptime: 128s
$ llamapulse stop
stopped
```

The OpenAI-compatible endpoint is `http://127.0.0.1:8080/v1` (the model alias
defaults to `llama-pulse`):

```sh
curl http://127.0.0.1:8080/v1/models
curl http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"llama-pulse","messages":[{"role":"user","content":"Hello"}]}'
```

An OpenCode custom provider:

```jsonc
// opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "llama-pulse": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LlamaPulse",
      "options": { "baseURL": "http://127.0.0.1:8080/v1" },
      "models": { "llama-pulse": { "name": "llama-pulse" } }
    }
  }
}
```

When `apiKey` is set, clients must send it as `Authorization: Bearer <key>`.
When it is empty, authentication is off; some clients still insist on a
non-empty API-key field, so pass any placeholder. `server.yaml` stores a single
key in plaintext and the supervisor passes it to `llama-server` in argv; the
key is redacted from child log lines and failure details and is never written
to `server-state.yaml`. There is no multi-user authentication, and the server
is plain HTTP, not TLS. Only bind a non-loopback host on a network you trust.

Build the CLI with `dart run melos run build:cli`. `melos` is a root
dev-dependency, so `dart run melos` needs no global install. Run `flutter pub
get` at the root only: the workspace resolves all three members into one
lockfile.

## CLI

Run with `dart run llama_pulse_cli:llamapulse …` from the root, or use the
compiled `apps/llama_pulse_cli/build/llamapulse` after `build:cli`:

```console
$ llamapulse version
llamapulse 0.1.0
$ llamapulse server get
schemaVersion: 1
server:
  modelPath: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
  host: 127.0.0.1
  port: 8080
  ...
$ llamapulse server set --context-size 8192 --parallel 2
$ llamapulse params get
schemaVersion: 1
params:
  modelPath: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
  ...
$ llamapulse models list
llama-3.2-3b-instruct.Q4_K_M.gguf  1918.09  /home/you/.config/llamapulse/models/llama-3.2-3b-instruct.Q4_K_M.gguf
$ llamapulse models inspect /models/llama-3.2-3b-instruct.Q4_K_M.gguf
path: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
fileName: llama-3.2-3b-instruct.Q4_K_M.gguf
sizeMiB: 1918.09
modified: 2026-10-30T11:46:17.116Z
```

### Server commands

`server get` prints the stored document, or the defaults when nothing is stored;
it never writes. `server set` validates and writes, refuses an invalid value
with exit code 2, and supports `--reset`. Flags shared by `server set` and
`serve`: `--model-path` (alias `--model`), `--host`, `--port`,
`--context-size`, `--threads`, `--gpu-layers`, `--parallel`, `--alias`,
`--api-key`, `--flash-attn on|off|auto`, negatable `--[no-]mlock` and
`--[no-]mmap`, repeatable `--extra-arg` (replaces the stored list), `--binary`
and `--startup-timeout`, plus `--json`.

`serve` applies the same flags on top of the stored configuration for one run
and supervises the child in the foreground. It refuses to start when the state
file records a `starting`, `running` or `stopping` server that still answers
`/health`; run `stop` first. The controller streams are subscribed before
`start`, so `starting` and the first log lines appear immediately; SIGINT or
SIGTERM during startup stops the child immediately and exits `130` or `0`. A
supervisor stream that closes without a terminal event is reported as
`failed(unknown, 'the supervisor stream ended')`.

`--json` switches `serve` to NDJSON on stdout, one schema-v1 object per line,
with event types `starting`, `ready`, `metrics`, `log`, `stopping`, `stopped`
and `failed`. A failure before the controller publishes anything still emits
exactly one `failed` line. `metrics` carries `tokensPerSecond`,
`promptTokensPerSecond`, `activeSlots`, `totalSlots`, `requestsProcessing`,
`requestsDeferred`, `promptTokensTotal`, `tokensPredictedTotal`,
`contextUsageRatio`, `uptimeSeconds` and `capturedAtEpochMs`; `failed` carries
a `failure` object (`code`, `message`, `details`) and `lastExitCode`.
Diagnostics still go to stderr.

`status` reads `server-state.yaml` and probes the recorded server. `starting`,
`running` and `stopping` all count as an active run, which is why a second
`serve` is refused while that server still answers `/health`. It exits `0` only
when the phase is `running` **and** `/health` returns 200 with
`{"status":"ok"}`; a 200 with `{"status":"loading"}` is `loading`, and
`stopped`, `stale` and `failed` all exit `1`. Uptime is reported from
`startedAtEpochMs` even when the server is unreachable.

`stop` signals the recorded supervisor; when that signal cannot be delivered it
signals `serverPid` instead, so a dead supervisor never masks a live child. A
`failed` document that still records that pid is not treated as stopped: `stop`
signals the child and retries it. `--force` signals the child first and then the
supervisor. The command only reports (and records) a stop once the document is
absent or terminal with no pids; a retained pid that cannot be signalled makes
it exit `1` and leaves the document untouched. `logs` prints the newest lines
(default 100, range 1..1000), and `--follow` follows by sequence number until
interrupted, so it survives rotation without repeating or dropping a line.

### `run` and `bench` (embedded, experimental)

Generate one prompt or benchmark repeated prompts against the embedded path.
The native embedded engine is not implemented, so `--stub` is mandatory today:
without it the command exits 1 with `engineUnavailable` and never falls back
silently. In stub mode the model path is echoed into the request but not read,
so no file-existence check happens.

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

`bench` runs the fixed prompt `The quick brown fox jumps over the lazy dog.`
several times and reports aggregate throughput. `--stub` is mandatory today, as
for `run`; with no configured model, stub mode uses the `<stub>` placeholder
path.

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
`models inspect`, `server get`, `server set`, `serve`, `status`, `stop`,
`logs`, `run` and `bench` — accepts `--json`; `serve` and `logs --follow` emit
NDJSON, the rest print one single-line JSON object. The `params`, `models` and
`server` groups are not invocable and take no `--json` of their own. The
configuration files on disk stay YAML either way.

| Exit code | Meaning |
|---|---|
| 0 | Success; `status` only when running and healthy; `stop` also when nothing was running |
| 1 | Unexpected failure, `status` for any non-running state, `serve` when a server is already recorded, `engineUnavailable` without `--stub` |
| 2 | Invalid arguments or values that failed validation |
| 3 | The requested model file was not found or is not a readable `.gguf` file |
| 130 | Interrupted by SIGINT (`serve`, `logs --follow`, a generation) |

## Configuration

The CLI, the dashboard and the supervisor share one directory. The chat path
uses `params.yaml`; the supervised server uses `server.yaml` and
`server-state.yaml`:

```yaml
# ~/.config/llamapulse/server.yaml (Linux)
schemaVersion: 1
server:
  modelPath: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
  host: 127.0.0.1
  port: 8080
  contextSize: 4096
  threads: 4
  gpuLayers: 0
  parallelSlots: 1
  modelAlias: llama-pulse
  apiKey: ''
  flashAttention: auto
  mlock: false
  mmap: true
  extraArgs: []
  binaryPath: ''
  startupTimeoutSeconds: 120
```

`server-state.yaml` is the cross-process contract: `phase`
(`stopped`, `starting`, `running`, `stopping`, `failed`), `health`, the
supervisor and server pids, host/port/model/binary, start and update times, the
last exit code and the last failure. The supervisor writes it after every
transition, `stop` clears a settled document, and `status` only reads it.
Terminal states clear `supervisorPid`; `stopping` keeps `serverPid` so a stop
can still target the child, and pids are released once a stop settles. A process
that survives `SIGKILL` leaves the document `failed` with `serverPid` set, so
`stop` can retry it; if the child later exits on its own, the supervisor records
the exit and clears the pid. The supervisor refuses a new `start` while its
state still records a stale pid. It never contains the API key. `server.log`
holds supervisor and child output, one
`timestamp<TAB>sequence<TAB>stream<TAB>line` record per line, and rotates to
`server.log.1` at 1 MiB; sequence numbers continue across a supervisor restart.

The embedded chat path keeps its earlier `params.yaml`:

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
location; `models/`, `bin/` and the log file sit inside it. Set
`LLAMA_PULSE_SERVER` to a `llama-server` executable (absolute path, path with a
separator, or a bare name looked up on `PATH`). Config and state are YAML; JSON
is only for `--json`/NDJSON command output and for decoding the `/metrics`,
`/slots` and `/props` HTTP payloads in `data/server/`.

## Architecture

The core is pure Dart; the app is the only Flutter member. The dependency rule
is `presentation → domain` and `data → domain`. Core's `domain` may use Dart
core libraries, `built_value`, `built_collection` and its own domain types; it
never imports Flutter, `dart:io` or plugins.

Server supervision lives in `packages/llama_pulse_core/lib/src/data/server/`
behind domain entities (`server_*`) and gateways. Process launch, HTTP,
signalling and port probing are injected seams. Most server tests use fakes, but
a few core tests exercise the real launcher, a localhost socket and an
in-process `HttpServer` on ephemeral ports.

Supervisor invariants:

- One supervisor owns at most one `llama-server` per run. `start` is rejected
  while the previous run is active, and `serve` refuses when the recorded
  server still answers `/health`.
- Lifecycle: `stopped → starting → running → stopping → stopped`, with
  `failed` as the terminal error state and `starting → failed` on startup
  errors.
- Readiness and `testConnection` both require an HTTP 200 **and** a
  `{"status":"ok"}` body; a 200 with `{"status":"loading"}` is
  `degraded`/`loading`, not healthy. The startup timeout defaults to 120 s.
- `stop()` and `dispose()` wait for an in-flight `start()`; a stop request
  aborts the wait for readiness and the run never ends up `running` afterwards.
  Concurrent `stop()` calls share one in-flight future, and `dispose()` closes
  its resources even when `stop()` throws.
- Stops are graceful first, forced after a 5 s grace, and exit monitoring is
  always cleaned up. `stopping` retains `serverPid` so the child stays
  signalled. A failed start terminates the child it spawned. A child that
  survives `SIGKILL` makes `stop()` throw and leaves the state `failed` with
  `serverPid` set; `stop()` can retry that retained pid, but a process that
  survives `SIGKILL` is never reported as stopped.
- Terminal states clear `supervisorPid`, and pids are released on stop. No
  auto-restart. A child that exits after `running` marks the run `failed` with
  `processExited`; when a child retained after a failed stop exits on its own,
  the supervisor records the exit and clears the pid. A new `start` is refused
  while its state still records a stale pid (`a previous server process is
  still recorded; stop it first`); the caller decides whether to start again.
- Log sequence numbers continue across a supervisor restart: the store seeds its
  counter from the highest sequence already in `server.log` and `server.log.1`,
  so `tail()` and `logs --follow` stay monotonic.
- The port preflight is advisory: the port can be taken between probe and
  bind, so child stderr bind errors are mapped to `portInUse` as well.
- The supervisor writes `server-state.yaml` after every transition and `stop`
  clears a settled document; `status` reads it. It never contains the API key,
  and child log lines and failure details redact it.
- Always pass `--metrics --slots`; the exact Prometheus names mapped are
  `llamacpp:prompt_tokens_total`, `prompt_tokens_cached_total`,
  `prompt_seconds_total`, `tokens_predicted_total`,
  `tokens_predicted_seconds_total`, `n_decode_total`, `n_tokens_max`,
  `prompt_tokens_seconds`, `predicted_tokens_seconds`,
  `requests_processing`, `requests_deferred` and `n_busy_slots_per_decode`.
  `/slots` supplies context usage; the `Process-Start-Time-Unix` header
  supplies uptime.
- `--load-mode` is used for builds `b10875` and newer (and for an unknown
  build, assumed current); older builds get the legacy `--mlock`/`--no-mmap`
  pair.

The embedded worker isolate is still present for the experimental Chat tab:

- `WorkerLlamaEngine` spawns exactly one long-lived isolate, lazily on the first
  `load`, `unload` or `generate`, and speaks `WorkerRequest`/`WorkerResponse`
  over ports. Caller request ids are non-negative and unique while in flight;
  reusing an in-flight id is rejected with `engineBusy`, and control requests use
  negative ids so they cannot collide.
- The worker isolate owns the `LlamaSession`. Cancellation is cooperative;
  `Isolate.kill` is used only by `WorkerTransport` on handshake abort and on
  `close()` after a 2 s grace.
- The worker coalesces token batches and emits metrics every 250 ms; exactly one
  terminal response (`completed`, `cancelled` or `failed`) ends each request.
- Persisted models and UI state are immutable `built_value` values, with
  `BuiltList` for collections.
- There is no `dart:ffi` code yet. The native embedded session will pin an
  upstream llama.cpp tag, implement the existing `LlamaSession` interface and
  gate the loaded library on `llama_version()`.
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
- [x] `llama-server` supervisor: start/stop, readiness, graceful stop
- [x] Server dashboard with endpoint actions, metrics and log tail
- [x] Server CLI: `server get|set`, `serve`, `status`, `stop`, `logs`
- [ ] Native embedded session (pinned upstream tag, `llama_version()` gate)
- [ ] llama.cpp binary downloader and updater
- [ ] Windows and macOS builds
- [ ] CI for analyze, tests and builds
- [ ] Packaging (app bundle and CLI archives)

The downloader will **ask which compute backend to install
(CPU/ROCm/CUDA/Vulkan/Metal)** and offer a detected default rather than
guessing. Work is tracked in
[GitHub issues](https://github.com/dip-develop/llama-pulse/issues).

## Contributing

Read [AGENT.md](AGENT.md) first; it holds the workspace, architecture,
immutability and configuration rules reviews check.

- Branch from the current integration branch as `feature/<topic>`, `bugfix/<topic>`
  or `chore/<topic>`. PR base is `main` for now: there is no `develop` branch yet.
- Before pushing, run `dart run melos run check`; it runs gen, analyze, tests,
  the format check and the CLI build.
- Generated `.g.dart` and `.config.dart` files are committed; re-run gen after a
  model change, and add tests for the seam you touched or explain why not.

## License

MIT — see [LICENSE](LICENSE). © 2026 DIP Dev.

## Acknowledgements

- [llama.cpp](https://github.com/ggml-org/llama.cpp) and
  [ggml](https://github.com/ggml-org/ggml) for local inference and
  `llama-server`.
- [Flutter](https://flutter.dev) for the desktop UI.
- [bloc](https://bloclibrary.dev), [get_it](https://pub.dev/packages/get_it),
  [injectable](https://pub.dev/packages/injectable) and
  [built_value](https://pub.dev/packages/built_value).
