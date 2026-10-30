# llama_pulse_core

Shared, Flutter-free core for LlamaPulse. This package owns the server
supervisor used by the dashboard and the CLI, plus the embedded chat entities
and worker layer.

- `built_value` entities: `ModelParams`, `GenerationRequest`,
  `GenerationMetrics`, `GenerationEvent`, `InferenceFailure`,
  `WorkerRequest`/`WorkerResponse`, `ModelFileInfo`, and the `server_*`
  entities (`ServerConfig`, `ServerState`, `ServerMetrics`, `ServerPhase`,
  `ServerHealth`, `ServerFailure`, `ServerBinaryInfo`, `ServerProbeResult`,
  `ServerLogEntry`, `ServerLogStream`, `ServerFlashAttention`).
- `ModelParamLimits`, `ModelParamsValidator` and `ServerConfigValidator`.
- Gateways: `LlamaEngine`, `LlamaSession`, `ModelParamsRepository`,
  `ModelScanner`, `ConfigStore`, and the server seams
  `ServerConfigRepository`, `ServerStateRepository`, `ServerController`,
  `ServerBinaryLocator`, `ServerHttpClient`, `ServerProcess`, `PortProbe`,
  `ProcessSignaller` and `ProcessExecutor`.
- The worker-isolate inference layer: `WorkerTransport`, `WorkerLlamaEngine`,
  `WorkerLoop`, `StubLlamaSession` and the `llamaWorkerMain` entrypoint.
- Use cases: `LoadModelParams`, `SaveModelParams`, `ListModels`,
  `InspectModel`.
- The YAML configuration layer: `AppPaths`, `YamlEncoder`, `YamlDecoder`,
  `YamlFileConfigStore`, `InMemoryConfigStore`,
  `YamlModelParamsRepository`, `YamlServerConfigRepository` and
  `YamlServerStateRepository`.
- `ServerLogStore`, `ServerMonitor`, `ServerMetricsMapper`,
  `PrometheusMetrics`, `ServerArgumentBuilder`, `ServerBinaryLocatorImpl`,
  `ServerVersionParser`, `SocketPortProbe`, `LlamaServerSupervisor`,
  `StubServerController`, `SupervisorTuning` and the `dart:io` implementations
  of the process/HTTP/signal seams.
- `ModelFileScanner` and `Utf8TokenAccumulator`.

It has no Flutter imports and no DI annotations. The import rules are enforced
by `test/architecture/core_imports_test.dart`. `dart:ffi` is allowed here
because native code will only run inside the worker isolate; no FFI code exists
yet.

The public entrypoint is:

```dart
import 'package:llama_pulse_core/llama_pulse_core.dart';
```

## Server supervisor

`LlamaServerSupervisor` implements the `ServerController` gateway: it validates
`ServerConfig`, locates `llama-server`, spawns one child, waits for `/health`,
publishes states, metrics and log lines, and stops the child. In production it
owns a `ServerMonitor` that samples `/metrics`, `/slots` and `/props` about once
a second while the server runs and emits `ServerMetrics` on the metrics stream.
The dashboard, `serve`, `status` and `stop` all go through the same contracts.

```dart
final controller = LlamaServerSupervisor.production(
  paths: AppPaths.resolve(),
  configStore: YamlFileConfigStore(directory: AppPaths.resolve().configDirectory),
);
await controller.start(config);
await for (final state in controller.states) {
  // stopped -> starting -> running -> stopping -> stopped | failed
}
await controller.stop();
await controller.dispose();
```

Every collaborator is injected (`ServerProcessLauncher`, `ServerHttpClient`,
`PortProbe`, `ServerBinaryLocator`, `ServerStateRepository`, `ServerLogStore`,
`ServerConfigValidator`), so most tests use fakes. A few core tests exercise the
real launcher, a localhost socket and an in-process `HttpServer` on ephemeral
ports. `LlamaServerSupervisor.production` wires the `dart:io` implementations
and `AppPaths`.

Invariants:

- One child per supervisor run. `start` is rejected while a run is active;
  a failed start terminates the child it spawned.
- Lifecycle: `stopped → starting → running → stopping → stopped`, with `failed`
  as the terminal error state and `starting → failed` on startup errors.
- Readiness and `testConnection` both require an HTTP 200 **and** a
  `{"status":"ok"}` body; a 200 with `{"status":"loading"}` is
  `degraded`/`loading`, not healthy. The startup timeout is
  `startupTimeoutSeconds` (default 120).
- Stop is graceful (`SIGTERM`), then forced after a 5 s grace. `stop()` and
  `dispose()` wait for an in-flight `start()`: a stop request aborts readiness
  and the run never ends up `running` afterwards. `stop` is idempotent.
- A child that survives `SIGKILL` makes `stop()` throw and leaves the state
  `failed` with `serverPid` set. Terminal states clear `supervisorPid`, and pids
  are released on stop.
- No auto-restart: a child that exits after `running` marks the run `failed`
  with `processExited`.
- The port preflight is advisory; child stderr bind errors are also mapped to
  `portInUse`.
- `ServerState` is persisted to `server-state.yaml` after every transition and
  is the cross-process contract for `status`/`stop`; `stop` clears a settled
  document. Health-only changes are broadcast without a write.
- While the server runs, the monitor samples `/metrics`, `/slots` and `/props`
  about once a second. A failed sample or health probe marks the run `degraded`
  or `unreachable` without changing the phase, and health recovers when the
  server answers again.
- Logs go to a 1000-entry in-memory ring and to `server.log`
  (`timestamp<TAB>sequence<TAB>stream<TAB>line`), rotated at 1 MiB to
  `server.log.1`.
- `server.yaml` holds the API key in plaintext by design and the supervisor
  passes it to the child in argv. It is redacted from child log lines and
  failure details, and never written to state or logs.
- The argument builder always includes `--metrics --slots`, plus the configured
  model, host, port, context, threads, GPU layers, slots, flash attention,
  alias, key and load mode. `extraArgs` are appended last and may not repeat a
  managed flag.
- Binary discovery order: `binaryPath` → `LLAMA_PULSE_SERVER` →
  `<exeDir>/data/llama-server` → `<exeDir>/llama-server` →
  `<config>/bin/llama-server` → `PATH`.
- Version parsing reads `llama-server --version`. Builds below `b4000` warn
  with `supported: false`; an unknown or unreadable version reports
  `supported: true` with a warning. Neither blocks a start. Builds `b10875+`
  (and unknown builds) use `--load-mode`; older builds use
  `--mlock`/`--no-mmap`.
- The monitor requires `/metrics` and treats `/slots` and `/props` as
  best-effort. It maps `llamacpp:prompt_tokens_total`,
  `prompt_tokens_cached_total`, `prompt_seconds_total`,
  `tokens_predicted_total`, `tokens_predicted_seconds_total`, `n_decode_total`,
  `n_tokens_max`, `prompt_tokens_seconds`, `predicted_tokens_seconds`,
  `requests_processing`, `requests_deferred` and
  `n_busy_slots_per_decode`. Uptime comes from the `Process-Start-Time-Unix`
  response header; context usage and slot counts come from `/slots`; total
  slots fall back to `/props`. There is no total-request counter in current
  llama.cpp.

`StubServerController` provides the same stream shape for the dashboard demo
(`LLAMAPULSE_STUB_SERVER`). It starts no process and is only selected
explicitly.

### Configuration

`server.yaml` starts with `schemaVersion: 1` and a `server` mapping. Missing,
malformed or stale documents fall back to `ServerConfig.defaults()`; saving
validates first. `server-state.yaml` is written by the supervisor after each
transition; `stop` clears a settled document.

```yaml
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

`AppPaths` resolves the platform directory, `LLAMA_PULSE_CONFIG_DIR`,
`serverYamlFile`, `serverStateYamlFile`, `serverLogFile`, `binDirectory` and
`modelsDirectory`.

### JSON boundary

JSON decoding is confined to `lib/src/data/server/` (`ServerMonitor` decodes
`/slots` and `/props`). `jsonEncode` is forbidden in the whole package, and the
architecture test enforces both rules. Configuration on disk is YAML; JSON is
only for HTTP payloads and for the CLI's `--json`/NDJSON presentation.

## Inference engine (embedded, experimental)

`WorkerLlamaEngine` implements `LlamaEngine` on top of one long-lived worker
isolate, spawned lazily on the first `load`, `unload` or `generate`. Requests
and responses are the `built_value` `WorkerRequest`/`WorkerResponse` DTOs; the
transport waits up to 10 s for the worker's `WorkerReady` handshake and surfaces
isolate errors and unexpected exits as failures. A handshake timeout aborts the
start and the same transport can be started again; `close()` cleans up a spawn
that is still in flight, so a worker never leaks.

Guarantees the worker loop provides:

- The worker isolate owns the `LlamaSession`; the caller never runs it. Dispose
  waits for the in-flight generation and any pending cancel, so `cancel()` and
  `dispose()` never overlap.
- Cancellation is cooperative. A `cancel` request is checked between generation
  steps; `Isolate.kill` is used only by `WorkerTransport` on handshake abort and
  on `close()` after a 2 s grace, never to cancel a generation.
- Reusing an in-flight request id is rejected with one `failed` event carrying
  `engineBusy`; the live request keeps running.
- Exactly one terminal event per request: `completed`, `cancelled` or `failed`.
- Token batches are coalesced and metrics arrive every 250 ms.
- Load failures throw `InferenceFailureException`; every other engine failure
  surfaces as an `InferenceFailure` value.

The native embedded session is **not** included yet. `WorkerConfig.useStubSession`
selects the session inside the worker: `true` runs `StubLlamaSession`, which
produces deterministic text and respects the token cap; the default runs
`UnavailableLlamaSession`, whose `load` fails with `engineUnavailable` so a
normal build can never emit synthetic output silently. The selection is always
explicit: `--stub` in the CLI, `LLAMAPULSE_STUB_ENGINE` (or an injected engine)
in the app, never a runtime fallback. The native session will pin an upstream
llama.cpp tag, implement the same `LlamaSession` interface and gate the loaded
library on `llama_version()`, without changing `LlamaEngine` or its callers.

## Chat configuration

The embedded chat path reads and writes `params.yaml`:

```yaml
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

The repository treats a missing, malformed or stale document as "use defaults"
and validates before writing.

## Usage

```dart
final store = InMemoryConfigStore();
final repository = YamlModelParamsRepository(
  store: store,
  serializers: serializers,
);
await repository.save(ModelParams.defaults().copyWith(threads: 8));
final loaded = await repository.load();
```

`InMemoryConfigStore` is for tests (including CLI tests). In the app, pass a
`YamlFileConfigStore` rooted at `AppPaths.resolve().configDirectory`.

## Test seams

The server suite covers the argument builder, binary locator order, version
parser, supervisor transitions, strict readiness, stop coordination and
escalation, a child surviving `SIGKILL`, log-store rotation, metrics mapping and
the YAML config/state round-trip. Fakes implement the gateways for most tests;
a few exercise the real launcher, a localhost socket and an in-process
`HttpServer` on ephemeral ports.

## Status

`publish_to: none` for now; the package is versioned with the workspace and is
not published to pub.dev.
