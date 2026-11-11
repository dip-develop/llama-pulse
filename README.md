# LlamaPulse

Run local models as an OpenAI-compatible server from a desktop app. LlamaPulse
launches and supervises `llama-server` so OpenCode, IDEs and scripts can use a
local endpoint. Maintained by DIP Dev.

Status: alpha — the `llama-server` supervisor, the server dashboard and the CLI
server commands are the primary paths and work end to end. The experimental Chat
tab and the CLI `run`/`bench` commands drive a real embedded native session
against a pinned llama.cpp shared library; without one they report
`libraryNotFound` instead of producing synthetic output. Pinned prebuilt
runtimes can be downloaded, verified and installed per GPU backend, and both
paths prefer them.

## Why

- **Your models, your machine.** No account, telemetry or hosted API; model
  files, configuration and logs stay on disk.
- **A real OpenAI-compatible endpoint.** Start `llama-server` once and point
  any compatible client at `http://127.0.0.1:8080/v1`.
- **Every parameter you can see.** A generated catalog of all 362 `llama.cpp`
  `v0.8.0` server parameters drives the CLI and both GUI panels, with the same
  descriptions, defaults and validation everywhere.
- **A runtime that matches your GPU.** Download the pinned llama.cpp build for
  the backend LlamaPulse detects (CPU, CUDA, ROCm, Vulkan, Metal), verified
  against a pinned SHA-256, instead of guessing or building by hand.
- **One shared core.** The GUI, the CLI and the supervisor share entities,
  validation, configuration and the process seam.

## Repository layout

```
llama-pulse/
├── pubspec.yaml            pub-workspace root and Melos 8 configuration
├── pubspec.lock            generated, git-ignored; shared by all members
├── analysis_options.yaml   shared lint rules
├── apps/llama_pulse/       Flutter desktop app
│   └── lib/presentation/   home/ (shell), server/, runtime/, inference/
├── apps/llama_pulse_cli/   pure-Dart CLI, executable `llamapulse`
├── packages/llama_pulse_core/
│   ├── lib/src/domain/     entities/, gateways/, usecases/, text/
│   └── lib/src/data/       config/, inference/, models/, runtime/, server/
├── third_party/llama_cpp/  vendored v0.8.0 headers, arg.cpp and build recipe
├── docs/                   parameter catalog, runtimes, packaging and workflow docs
├── tool/                   build_llama_cpp.sh and the package_linux.sh shim;
│                           the cross-platform packager lives in core/tool/
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
- **Chat tab, experimental**: an embedded native `LlamaSession` runs in the
  worker isolate against a llama.cpp `libllama` shared library (see
  [Embedded native engine](#embedded-native-engine)). It is not the primary path
  and does not use the supervised server. Without a resolvable library the
  screen reports `libraryNotFound` with every searched path.
- **Managed runtimes**: detect the host GPU, download the matching pinned
  backend, verify its SHA-256, extract it safely and install it under
  `<config>/runtime/<tag>/<backend>/`. The CLI (`runtime
  list|status|install|select|remove`) and a Runtime tab drive it; see
  [docs/runtime.md](docs/runtime.md).
- **CLI**: `server get|set`, `serve`, `status`, `stop`, `logs`, `runtime
  list|status|install|select|remove`, plus `params
  catalog|describe|get|set|export`, `models list|inspect`, `run` and `bench`.
- **Binary discovery and version warning**: a configured path, an environment
  variable, the app bundle, installed runtimes, the config `bin/` directory and
  `PATH` are tried in that order. Builds below `b4000` warn, and an unknown or unreadable
  `llama-server --version` reports `supported: true` with a warning; nothing
  blocks a start on the version.
- **1291 tests** across the three packages (892 core, 233 CLI, 166 app); two
  further tests are skipped: the core integration test unless a native library
  and model are set, and the real macOS `ditto` archive test unless the host is
  macOS.

## Requirements

Flutter 3.44+ declared (tested on 3.47.7) and Dart 3.13+. The CLI and the core
build without llama.cpp. To actually serve a model you need a `llama-server`
binary; build `b4000` or newer is supported, while older or unknown/unreadable
builds only warn. Put it on
`PATH`, next to the executable, in the app's `data/` directory, in
`<config>/bin/`, or point `LLAMA_PULSE_SERVER` or `server.yaml`'s
`binaryPath` at it.

The easiest way to get both is a managed runtime:

```sh
llamapulse runtime status                     # what the host can run
llamapulse runtime install --backend cuda13   # verified download
llamapulse runtime select v0.8.0 cuda13
```

The embedded engine also accepts a llama.cpp **shared library** built from the
pinned `v0.8.0` tag. A local `-DLLAMA_BUILD_IS_DEV=OFF` build reports `0.8.0`
and passes the exact gate; an official prebuilt archive reports `0.8.0-dev`
and passes only with a matching runtime manifest (see
[Version gate](#version-gate)). The recipe and the output layout are in
[third_party/llama_cpp/v0.8.0/BUILD.md](third_party/llama_cpp/v0.8.0/BUILD.md).

## Embedded native engine

The Chat tab and the CLI `run`/`bench` commands use `NativeLlamaSession`, which
implements the existing `LlamaSession` interface and runs inside the worker
isolate. `LlamaLibrary` opens the shared library with `DynamicLibrary.open` and
resolves every symbol with `lookupFunction`; there is no `@Native` binding. It
pre-opens sibling `libggml*` libraries, binds
`ggml_backend_load_all_from_path` from the `libggml` handle and calls it with
the library's directory **before** `llama_backend_init` (otherwise a GPU plugin
beside the library is silently ignored), calls `llama_backend_init` once per
process, and then gates on `llama_version()`.

Resolution order for the library:

1. an explicit path (`--lib` on the CLI)
2. `LLAMA_PULSE_LIB`
3. `<exeDir>/lib`
4. `<exeDir>`
5. `<exeDir>/../Frameworks` (macOS bundles)
6. installed runtimes under `<config>/runtime/<tag>/<backend>/`, selected first
   and then the others newest first
7. a runtime shipped in the app bundle, `<exeDir>/runtime/<tag>/<backend>/`
8. `<config>/lib`
9. the bare soname (`libllama.so`, `llama.dll`, `libllama.dylib`)

A path that does not resolve fails with `libraryNotFound` and **every** searched
path in `details`; the CLI prints them and exits `1`. Nothing falls back to the
stub: `--stub` (or `LLAMAPULSE_STUB_ENGINE` in the app) is the only way to run
the deterministic stub, and its output is byte-identical to before. In the app,
the default DI registration is the native engine; `melos run app:stub` selects
the stub.

### Version gate

A load of a library whose version differs fails with `libraryVersionMismatch`
and the reported version. Two cases are accepted:

- `0.8.0`, the string a local `-DLLAMA_BUILD_IS_DEV=OFF` build reports.
- `0.8.0-dev`, the string every official prebuilt archive reports, but only
  when `runtime.yaml` beside the library names the pinned tag, build, commit and
  archive SHA-256. That is an attestation of the downloaded, verified install,
  not a loosened check.

The local `/opt/llama.cpp-rocm` install is an Unsloth fork that reports
`0.7.0-dev` and stays rejected, which is the gate working as intended.

The native path is 64-bit desktop only: the structs are passed and returned by
value. One engine per process, because `llama_backend_init` is global. Fetch the
matching library with one command:

```sh
tool/build_llama_cpp.sh          # tag defaults to v0.8.0
```

It clones into `build/llama.cpp-v0.8.0`, applies the flags below, builds, and
prints the `LLAMA_PULSE_LIB` and `LD_LIBRARY_PATH` exports. The same steps by
hand:

```sh
git clone --depth 1 --branch v0.8.0 https://github.com/ggml-org/llama.cpp
cmake -S llama.cpp -B llama.cpp/build -G Ninja -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_BUILD_IS_DEV=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_APP=OFF -DGGML_NATIVE=ON
cmake --build llama.cpp/build -j
export LLAMA_PULSE_LIB=$PWD/llama.cpp/build/bin/libllama.so
export LD_LIBRARY_PATH=$PWD/llama.cpp/build/bin:${LD_LIBRARY_PATH:-}
```

`-DLLAMA_BUILD_APP=OFF` is not optional: upstream `v0.8.0` otherwise tries to
build `app/llama.cpp` without the generated `build-info.h` and fails. Keep
`libllama.so` and `libggml*.so` in one directory and point the loader at it, or
an older `/opt` ggml install can be picked up instead of the matching build.

Generation tokenizes the prompt, truncates it from the left to
`n_ctx - maxTokens`, prefills it in `n_batch` chunks (logits only on the last
prompt token), and samples through a top-k → top-p → min-p → temperature →
distribution chain. The `min-p` and `seed` parameters feed the chain (defaults
`0.05` and `LLAMA_DEFAULT_SEED`, `0xFFFFFFFF`, which llama.cpp treats as
random, so `bench` runs differ), and `batch-size` sets `n_batch` and `n_ubatch`,
capped at the context size.
Each token is decoded before the next one is sampled, EOG tokens end the
response, and `Utf8TokenAccumulator` reassembles code points split across
tokens. Cancellation is cooperative and checked at every step and prefill
chunk. Metrics come from `llama_perf_context` plus the loop's token counts.

Verified end to end on 2026-11-01 with an upstream `v0.8.0` CPU build (ggml
`0.28.0`, 64-bit Linux, 6 cores) and a 12B-A2.5B Q8_0 MoE thinking model (12.04
GiB, context 512, two threads): the integration test passed in about 5.5 s
wall time including a reload, at 12.8 GB peak RSS, and the CLI generated 16
tokens at 19.4 tok/s on the first run and 23.9–24.3 tok/s on repeats. All of it
is CPU inference; no GPU backend is used. The exact recipe and layout are in
[third_party/llama_cpp/v0.8.0/BUILD.md](third_party/llama_cpp/v0.8.0/BUILD.md).

The bindings in
`packages/llama_pulse_core/lib/src/data/inference/native/llama_bindings.dart`
are hand-written from the vendored `v0.8.0` headers;
`third_party/llama_cpp/v0.8.0/` holds the headers, the pin, the checksums and
`abi_check.c`. `sha256sum -c` verifies the pin, and
`packages/llama_pulse_core/test/data/inference/native/abi_layout_test.dart`
compiles `abi_check.c` with clang and compares every struct size and field
offset. The headers are a binding reference only: they are not compiled by the
Flutter build and no llama.cpp binary ships with LlamaPulse. `dart:ffi` stays
inside the worker isolate.

## Parameters

LlamaPulse exposes every command-line parameter of the pinned `llama.cpp`
`v0.8.0` `llama-server` through one generated catalog. It holds 362 parameters
in 12 groups: 210 configurable, 14 managed by LlamaPulse, 132 unsupported and
6 removed. The embedded native session has 10 catalog ids
(`ctx-size`, `threads`, `gpu-layers`, `temp`, `top-k`, `top-p`, `min-p`, `seed`,
`batch-size` and `chat-template`), and it honours all 10.

The catalog is generated from the vendored `common/arg.cpp` and a reviewed
overrides file, not typed by hand. It is the one source of truth for
descriptions: the CLI listing, `params describe`, every validation message and
every GUI tooltip read the same `ParameterSpec`. Change the overrides file and
run `dart run melos run gen:catalog`; `gen:catalog:check` fails when the
generated YAML or Dart file is stale. The full workflow is in
[docs/parameters.md](docs/parameters.md).

### Browsing the catalog

```console
$ llamapulse params catalog --group sampling
Sampling & penalties (sampling)
  seed  -s --seed  int  default=-1  configurable
  temp  --temp --temperature  double  default=0.8  configurable
  top-k  --top-k  int  default=40  configurable
  ...
$ llamapulse params describe min-p
id: min-p
flags: --min-p
type: double
default: 0.05
range: 0..1
surfaces: server, embedded
exposure: configurable
$ llamapulse params catalog --surface embedded --json
```

`--surface` filters to `all`, `server` or `embedded`; `--group` is repeatable;
`--include-unsupported` also lists the 132 unsupported and 6 removed ids with
their reasons. `params describe <id>` answers for every id, including the
reason and replacement of an unavailable one. Both commands accept `--json`.

### Setting values

`--param` works on `server set`, `serve`, `params set`, `run`, `bench` and
`params export`:

```console
$ llamapulse server set --param repeat-penalty=1.1 --param cont-batching=false
$ llamapulse server get --show-modified
$ llamapulse params set --param chat-template=chatml
$ llamapulse params export
$ llamapulse run --stub --model /tmp/demo.gguf --prompt hi --param temp=0.2
```

`id=value` sets a value, `id=` removes it and a bare `id` sets a boolean to
`true`; a repeatable id keeps every occurrence. Values are canonicalized and
validated against the catalog before anything is written or loaded. An unknown,
unsupported, removed, wrong-surface or ownerless managed id exits `2` with the
catalog's message. A typed owner writes its field (`--param threads=8` stores `threads:
8`); when the typed flag is supplied too, the two values must agree, otherwise
the command exits `2` with `--threads and --param threads disagree (4 vs 8)`.
`params export` prints the `llama-cli`-shaped argument vector for the stored
embedded configuration without writing anything. Nothing about `run`, `bench`
or `params export` is persisted.

### GUI parameter panel

The server dashboard and the Chat tab share one grouped, collapsible panel
under their essentials form. It offers search across ids, flags, names and
descriptions; a modified-only switch; per-row and per-group reset with undo;
and an info tooltip built from the same catalog entry. Managed, unsupported and
removed rows are locked: managed rows show their effective value when there is
one and who owns them, while unavailable rows explain the reason without a
control. The Chat panel also locks the values its essentials form owns and the
server flags the embedded engine cannot honour.

Only non-empty values are stored: `server.yaml` keeps them in `server.params`
and `params.yaml` in `params.params`; an empty map removes the key. Values are
written in catalog order, and clearing a field removes it rather than copying
the default. See [docs/parameters.md](docs/parameters.md) for the overrides
file, the digest, the pin-bump procedure and the emission rules both argument
builders share.

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
banner; it runs the embedded native engine and needs a matching `libllama`
shared library (export `LLAMA_PULSE_LIB` or place it next to the executable).
Without one it reports `libraryNotFound` and lists every path it tried.

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

### Package it

| Target | Command | Archive |
|---|---|---|
| Linux x64 | `dart run melos run package:linux` | `dist/llama-pulse-<version>-linux-x64.tar.gz` |
| Windows x64 | `dart run melos run package:windows` | `dist/llama-pulse-<version>-windows-x64.zip` |
| macOS arm64 | `dart run melos run package:macos` | `dist/llama-pulse-<version>-macos-arm64.zip` |

The packager at `packages/llama_pulse_core/tool/package_app.dart` builds the
release bundle, adds `README.md`/`LICENSE`, copies one managed runtime to
`runtime/<tag>/<backend>/` (macOS: `Contents/Resources/runtime/...`) when asked,
and writes and verifies the platform archive. Run each target on its own host;
`tool/package_linux.sh` remains as a shim. A bundled runtime is a fallback: a
runtime the user selects under `<config>/runtime/` still wins. `--skip-build
--check` stages and verifies an existing bundle without writing an archive, which
is what CI runs. See [docs/packaging.md](docs/packaging.md). Icons, installers
and signing/notarisation are not part of it yet.

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

### Runtime commands

`runtime status` prints the detected host, the recommended backend, the release,
the offered backends, the installed and selected runtimes and the native gate
verdict. `runtime install --backend <id>` downloads, verifies and installs the
pinned archive, prompts before the CUDA runtime archive unless `--yes` is
given, and accepts `--tag` (only `v0.8.0`) and `--force`. `runtime select <tag>
<backend>` marks the default, `runtime remove <tag> <backend>` deletes it, and
`runtime list` prints what is installed. Every leaf accepts `--json`;
`install --json` streams `runtimeProgress` NDJSON and ends with one
`runtimeInstall` object. See [docs/runtime.md](docs/runtime.md).

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
The native engine runs by default and `--lib` names the llama.cpp shared
library; without it the worker searches `LLAMA_PULSE_LIB`, `<exeDir>/lib`,
`<exeDir>`, the macOS `Frameworks` directory, `<config>/lib` and finally the
bare soname (see [Embedded native engine](#embedded-native-engine)).
The library must report `0.8.0` from `llama_version()`. A missing library exits 1
with `libraryNotFound` and the searched paths, and never falls back silently.
`--stub` explicitly selects the deterministic stub, where the model path is
echoed into the request but not read.

```
$ llamapulse run --stub --model /models/demo.gguf --prompt "Hello" --max-tokens 8
Local models run on your machine. No
$ cat prompt.txt | llamapulse run --stub --model /models/demo.gguf --file - --json
```

Flags: `--model`, `--lib`, `--prompt`, `--file` (`-` reads stdin), `--system`,
repeatable `--message role:content`, `--stream`, `--json`, `--threads`,
`--temperature`, `--top-p`, `--top-k`, `--max-tokens`, `--context-size`,
`--chat-template`, `--[no-]use-chat-template`, repeatable `--param`. `--prompt`
and `--file` are mutually exclusive; one of `--prompt`, `--file` or a user
`--message` is required. `--json` and `--stream` cannot be combined. `--param`
applies the embedded catalog rules for this run only; an unknown or unsupported
id exits 2 before the engine loads. `--chat-template` names a built-in template
(for example `chatml`); `none` disables templating and `--no-use-chat-template`
sends the raw prompt.

The embedded session renders the whole conversation through the model's chat
template. `--system` prepends a system message and every `--message
role:content` adds one entry in order (`system`, `user`, `assistant` or `tool`);
the prompt is the final user turn. A model without chat metadata falls back to
the raw prompt for a single user message and to a plain `role: content`
transcript for a longer conversation. `--stub` ignores the conversation and
echoes the final user text.

```console
$ llamapulse run --stub --model /models/demo.gguf \
    --system "You are terse." \
    --message user:"Say hi" --message assistant:"Hi" \
    --prompt "One more"
```


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
several times and reports aggregate throughput. The default seed is random, so
the numbers differ between runs. Without `--stub` the model must
be a readable `.gguf` file: a blank path is a usage error (exit 2) and a missing
or non-`.gguf` file exits 3. In stub mode with no configured model it uses the
`<stub>` placeholder path.

```
$ llamapulse bench --stub --runs 3
runs: 3  generatedTokens: 36  evalMs: 818  tokensPerSecond: 44.01
$ llamapulse bench --stub --runs 3 --json
{"schemaVersion":1,"type":"bench","runs":3,"modelPath":"<stub>","promptChars":44,"promptTokenCount":11,"generatedTokenCount":36,"evalMs":818,"tokensPerSecond":44.01,"perRun":[{"requestId":1,"generatedTokenCount":12,"evalMs":274,"tokensPerSecond":43.8},{"requestId":2,"generatedTokenCount":12,"evalMs":272,"tokensPerSecond":44.12},{"requestId":3,"generatedTokenCount":12,"evalMs":272,"tokensPerSecond":44.12}]}
```

Flags: `--runs` (1..50, default 3), `--json`, `--max-tokens` (default 32) and
the shared `--model`, `--threads`, `--temperature`, `--top-p`, `--top-k`,
`--context-size` and `--param` overrides. `--json` prints one object with
`schemaVersion`, `type: "bench"`, `runs`, `modelPath`, `promptChars`,
`promptTokenCount`, `generatedTokenCount`, `evalMs`, `tokensPerSecond` and a
`perRun` array. Human mode prints the aggregate line on stdout; per-run
progress and diagnostics go to stderr.

`params get --json` adds a `modified` list of the embedded ids whose effective
value differs from the default, and `params get --show-modified` prints just
those ids. `params export` prints the `llama-cli`-shaped argument vector for the
stored embedded parameters; `--param` overrides it for that invocation only.
`params export --json` prints `{schemaVersion, type: "paramsExport", argv}`.

stdout carries data only — generated text, NDJSON events or the final JSON
object. stderr carries diagnostics, the human summary and usage errors.

Every leaf command — `version`, `params get`, `params set`, `params export`,
`models list`, `models inspect`, `server get`, `server set`, `serve`, `status`,
`stop`, `logs`, `runtime list`, `runtime status`, `runtime install`,
`runtime select`, `runtime remove`, `run` and `bench` — accepts `--json`;
`serve`, `logs --follow` and `runtime install` emit NDJSON, the rest print one
single-line JSON object. The `params`, `models`, `server` and `runtime` groups
are not invocable and take no `--json` of their own. The configuration files on
disk stay YAML either way.

| Exit code | Meaning |
|---|---|
| 0 | Success; `status` only when running and healthy; `stop` also when nothing was running |
| 1 | Unexpected failure, `status` for any non-running state, `serve` when a server is already recorded, `libraryNotFound` |
| 2 | Invalid arguments or values that failed validation |
| 3 | The requested model file or runtime was not found |
| 4 | A downloaded runtime failed checksum, size or extraction verification |
| 5 | A runtime download failed at the network or HTTP layer |
| 130 | Interrupted by SIGINT (`serve`, `logs --follow`, a generation, a runtime install) |

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
location; `models/`, `bin/`, `runtime/` and the log file sit inside it. Set
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

The embedded worker isolate backs both the experimental Chat tab and the CLI
`run`/`bench` commands:

- `WorkerLlamaEngine` spawns exactly one long-lived isolate, lazily on the first
  `load`, `unload` or `generate`, and speaks `WorkerRequest`/`WorkerResponse`
  over ports. Caller request ids are non-negative and unique while in flight;
  reusing an in-flight id is rejected with `engineBusy`, and control requests use
  negative ids so they cannot collide.
- The worker isolate owns the `LlamaSession`. `NativeLlamaSession` is the
  default and `StubLlamaSession` is selected explicitly. Cancellation is
  cooperative; `Isolate.kill` is used only by `WorkerTransport` on handshake
  abort and on `close()` after a 2 s grace.
- The worker coalesces token batches and emits metrics every 250 ms; exactly one
  terminal response (`completed`, `cancelled` or `failed`) ends each request.
- Persisted models and UI state are immutable `built_value` values, with
  `BuiltList` for collections.
- Every engine failure surfaces as an `InferenceFailure`; load failures throw
  `InferenceFailureException`. A missing native library is a `libraryNotFound`
  failure, not synthetic output.
- Never `dart:ffi` on the UI isolate. Symbols come from `DynamicLibrary.open`
  plus `lookupFunction`, never `@Native`, and the app starts without any native
  library present.

Runtime management lives in `packages/llama_pulse_core/lib/src/data/runtime/`
and `lib/src/domain/runtime/`; the probe, the store and the installer are
domain gateways so the GUI's `RuntimeBloc` never imports the data layer. The
`archive` and `crypto` packages are the only runtime dependencies. See
[docs/runtime.md](docs/runtime.md) and [AGENT.md](AGENT.md) for the full rules.

## Known limitations

- **The embedded surface is a subset.** The catalog marks 10 of the 362
  parameters as embedded, and the native session honours all of them. Every
  other server flag is locked in the Chat panel and rejected by
  `run`/`bench --param` with exit `2`; it is not silently ignored.
- **Pinned version gate.** The library must report `0.8.0`, or `0.8.0-dev` with
  a runtime manifest that attests the pinned release. Any other version,
  including a newer one and the `0.7.0-dev` Unsloth fork, is rejected at load
  with `libraryVersionMismatch`.
- **64-bit desktop only.** The native structs are passed and returned by value,
  so the bindings do not work on 32-bit targets.
- **One engine per process.** `llama_backend_init` is global and `dart:ffi` has
  no `dlclose`, so a session cannot unload a library and load another one in the
  same process.

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
- [x] Native embedded session (pinned upstream tag, `llama_version()` gate)
- [x] Chat templates and prompt formatting for the embedded engine
- [x] Full `llama.cpp` parameter catalog: 362 ids, 12 groups, GUI panel and
  `--param` on the server surface, plus the 10 ids catalogued for the embedded
  engine
- [x] llama.cpp runtime downloader: pinned assets, hardware detection,
  verified installs, CLI `runtime` group and the GUI Runtime tab
- [ ] GPU smoke tests on CUDA, Vulkan, ROCm and Metal
- [x] Windows and macOS desktop builds
- [x] CI for analyze, tests and builds
- [x] Desktop bundles for Linux, Windows and macOS with an optional managed
  runtime (`packages/llama_pulse_core/tool/package_app.dart`;
  `tool/package_linux.sh` is a shim)
- [ ] Icons and installers

The runtime manager **asks which compute backend to install
(CPU/ROCm/CUDA/Vulkan/Metal)** and offers the detected default rather than
guessing. Work is tracked in
[GitHub issues](https://github.com/dip-develop/llama-pulse/issues).

## Contributing

Read [AGENT.md](AGENT.md) first; it holds the workspace, architecture,
immutability and configuration rules reviews check.

- Branch from the current integration branch as `feature/<topic>`, `bugfix/<topic>`
  or `chore/<topic>`. PR base is `main` for now: there is no `develop` branch yet.
- Before pushing, run `dart run melos run check`; it runs gen, analyze, tests,
  the format check and the CLI build. Every PR also runs
  [`.github/workflows/ci.yml`](.github/workflows/ci.yml): the same gate plus a
  Linux desktop debug build, tests on Ubuntu, macOS and Windows, a
  standalone Windows job that only compiles the CLI, and `Package (macos)` /
  `Package (windows)` jobs that build, write and verify the bundles. Packaging
  artifacts upload only on `main` and `workflow_dispatch`.
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
