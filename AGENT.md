# LlamaPulse — Contributor and Agent Guide

## 1. Project

LlamaPulse is a workspace for running local LLMs through llama.cpp: a Flutter
desktop GUI (`apps/llama_pulse`), a command-line companion
(`apps/llama_pulse_cli`) and a shared Dart package (`packages/llama_pulse_core`).
The product is server-first: LlamaPulse launches and supervises a local
`llama-server` and exposes it as an OpenAI-compatible endpoint for OpenCode,
IDEs and scripts. The primary screen is the server dashboard; the embedded Chat
tab is an optional, experimental path that still runs the existing
stub/embedded engine.

Today the supervisor, the dashboard and the server CLI work end to end: a
configured `llama-server` is started, waited on through `/health`, sampled
through `/metrics` and `/slots`, and stopped gracefully. The embedded chat path
still ships no native engine: a plain build reports `engineUnavailable`, and
the opt-in `melos run app:stub` demo runs the stub behind a banner. `run` and
`bench` in the CLI are also embedded/experimental and require `--stub`. The
native embedded session is deferred.

MVP:

- Supervise `llama-server` from one dashboard: configuration, start/stop,
  readiness, endpoint and logs.
- Live metrics: tokens/sec, slots, requests, context usage and uptime.
- Server configuration in `server.yaml`; CLI parity for headless use.
- Cross-platform: Linux, Windows, macOS.
- No native inference on the UI isolate; the embedded engine stays in its
  worker isolate when it lands.

Out of scope for now: binary downloader/updater, Hugging Face CLI, model file
manager. The architecture leaves room for all three; section 15 says where.

LlamaPulse is developed and maintained by DIP Dev., which also holds the
copyright; the project is released under the MIT license (see `LICENSE`).

## 2. Workspace

The repository is one pub workspace and one Melos workspace.

- Root `pubspec.yaml` is the pub-workspace root **and** the Melos configuration.
  Melos 7+ reads its config there; there is no `melos.yaml`.
- Members are `packages/llama_pulse_core`, `apps/llama_pulse` and
  `apps/llama_pulse_cli`, each declaring `resolution: workspace`.
- Exactly one `pubspec.lock`, at the root. It is generated and git-ignored;
  never commit it or a member lockfile.
- Run `flutter pub get` at the root only; never inside a member directory.
- `melos` is a root dev-dependency. Use `dart run melos …`; no global install.
- The `gen` script runs build_runner in dependency order: core, then app.
- Never define scripts named `analyze`, `test` or `format`: those are Melos
  built-ins and a script with the same name shadows them.
- No `packageFilters` in scripts. When a filter matches nothing Melos prompts,
  and prompts fail in CI.

## 3. Stack (locked)

Flutter/Dart, Clean Architecture. Dart `>=3.13.0 <4.0.0`, Flutter `>=3.44`
(baseline: Flutter 3.47.7 / Dart 3.13.5). Shared logic lives in the pure-Dart
core. State management is bloc (`flutter_bloc`). DI:
`get_it` + `injectable` in the app, a hand-written composition root in the CLI.
Immutable models, state and entities: `built_value` + `built_collection`.
Configuration: YAML through the hand-written codec in core.

Pins are deliberate; do not loosen them without reproducing the resolution:

| Package | Pin | Why |
|---|---|---|
| `built_value` | `8.13.0` | exact; generator and runtime move together; core entities and `InferenceState` |
| `built_collection` | `^5.1.2` | 6.x is incompatible with `built_value 8.13`; `BuiltList` in core and app state |
| `build_runner` | `2.16.1` | exact; 2.17.x requires `build 5.x`, while `built_value_generator 8.13.0` declares `build <5.0.0` and `injectable_generator 3.1.3` declares `build ^4.0.4` |
| `built_value_generator` | `8.13.0` | exact; must match the `built_value` runtime |
| `flutter_bloc` | `^9.1.1` | app state management for the inference screen |
| `file_selector` | `^1.1.0` | native file dialog behind `ModelPathPicker` |
| `bloc_test` (dev) | `^10.0.0` | bloc transition tests in the app |
| `injectable_generator` | `3.1.3` | exact; paired with `injectable ^3.0.0` |
| `get_it` | `^9.3.0` | DI container in the app |
| `injectable` | `^3.0.0` | annotations for app-owned registrations |
| `ffi` | `^2.2.0` | `Utf8`, `calloc`, native helpers; arrives with the FFI milestone, nothing declares it yet |
| `path` | `^1.9.1` | cross-platform paths |
| `melos` (dev) | `^8.10.0` | workspace scripts and task runner |
| `yaml` | `^3.1.4` | YAML decoding in core |
| `args` | `^2.7.0` | CLI argument and command parsing |
| `flutter_launcher_icons` (dev) | `^0.14.4` | Windows/macOS launcher icons |
| `lints` (dev) | `^6.1.0` | lint baseline for core and CLI |
| `test` (dev) | `^1.31.1` | core and CLI tests |
| `flutter_lints` (dev) | `^6.0.0` | lint baseline for the Flutter app |

The root also sets `dependency_overrides: cli_util: ^0.6.0`.
`flutter_launcher_icons` only needs `cli_logging` (API-identical in
0.4.2/0.5.0/0.6.0), while Melos 8 needs `BaseDirectories` from `cli_util`
0.5.0+. `cli_util 0.6.0` satisfies both.

The server batch added no runtime dependency: HTTP, process launch and port
probing use `dart:io` behind core gateways. `shelf` and `go_router` were
evaluated and **not adopted**. `shelf` is server-side only — LlamaPulse is the
client of `llama-server`, not an HTTP server — and `go_router` solves routing
the app does not have: the shell is two tabs in an `IndexedStack`, not a URL
hierarchy.

`packages/llama_pulse_core/LICENSE` is a copy of the root MIT license so the
package is self-contained.

Rules: no new dependency without a one-line justification in the PR that adds
it. Reproducibility comes from the exact pins above, the
`dependency_overrides` pin, and the codegen-idempotency gate: `melos run gen`
must leave the tree clean when run twice.

## 4. Layout and dependency rule

```
apps/llama_pulse/
  lib/main.dart
  lib/app/          bootstrap.dart, app.dart, di/, platform/, theme/
  lib/presentation/home/        shell: rail/nav bar and the two tabs
  lib/presentation/server/      dashboard, bloc/, widgets/
  lib/presentation/inference/   experimental chat screen, bloc/, widgets/
  test/             app/, presentation/, support/
apps/llama_pulse_cli/
  bin/llamapulse.dart
  lib/src/          command_runner.dart, commands/, inference/, server/,
                    cli_services.dart
  test/
packages/llama_pulse_core/
  lib/llama_pulse_core.dart     public entrypoint
  lib/src/domain/   entities/ (server_*), exceptions/, gateways/ (server_*),
                    usecases/, text/, server_config_validator.dart
  lib/src/data/     config/, inference/, models/, server/, serialization/
  test/             architecture/, data/, domain/
```

Dependency rule:

- `presentation -> domain` (entities, gateways, use cases from core)
- `data -> domain`; data implements the core gateways
- `app` may import all of them; `presentation` never imports `data` directly
- core's `domain/` may use Dart core libraries, `built_value`,
  `built_collection` and core's own domain types; it never imports Flutter,
  `dart:io` or plugins
- `package:flutter/` is imported only by `apps/llama_pulse`

`packages/llama_pulse_core` must stay Flutter-free. The import rules are enforced
by `packages/llama_pulse_core/test/architecture/core_imports_test.dart`.
`dart:ffi` **is** allowed in core because it only runs inside the worker isolate;
Flutter-specific code stays in the app.

Core is organised as `domain/{entities,exceptions,gateways,usecases,text}` and
`data/{config,inference,models,server,serialization}`. The `inference/` and
`server/` feature folders exist in core, the CLI and the app; new domain and
data code goes under the existing subfolders.

## 5. Immutability

`built_value` is mandatory for anything persisted, held in bloc state, or sent
across the isolate boundary: entities (`ModelParams`, `GenerationRequest`,
`GenerationMetrics`, `GenerationEvent`, `InferenceFailure`), the persisted
envelope, worker request/response DTOs, and `InferenceState`.

Lists in state are `BuiltList`, never growable `List`; `InferenceState` keeps
`outputChunks` and a 100-entry-capped `metricsHistory` this way. Never mutate;
never expose a builder outside the file that owns the type.

Deliberate non-`built_value` types, all immutable:

1. `WorkerConfig` / `WorkerReady` hold `SendPort`, which `built_value` cannot
   serialize. Keep them minimal and construct them only in worker plumbing.
2. `ModelScanResult` is a transient plain class: the scanner produces it on
   demand, it is never persisted and never compared structurally. Its lists are
   unmodifiable.
3. `GenerationStep` is produced on demand by a `LlamaSession` inside the worker:
   it is never persisted, never crosses the isolate boundary and never compared
   structurally.
4. The sealed `InferenceEvent` hierarchy holds transient UI commands that never
   cross the isolate boundary. Two members are internal plumbing that the bloc
   feeds back to itself — `InferenceEngineEventReceived` and
   `InferenceEngineStreamEnded` — and UI code never adds them.

Adding a mutable field to state or an entity is a review blocker. If
`built_value` codegen hurts, fix the model; do not switch libraries.

## 6. Configuration

On-disk configuration is YAML. There are three documents, all in the same
directory:

- `params.yaml` — embedded/chat parameters (`ModelParams`), unchanged.
- `server.yaml` — the supervised `llama-server` configuration (`ServerConfig`).
- `server-state.yaml` — the supervisor's persisted state (`ServerState`).

JSON is only for machine-readable command output (`--json` and `serve`'s
NDJSON), isolate/transport payloads, and decoding the `/metrics`, `/slots` and
`/props` HTTP payloads. `jsonDecode` is confined to `lib/src/data/server/` and
`jsonEncode` is forbidden everywhere; the architecture test enforces both. Do
not add a second config format.

The YAML layer sits above the `built_value` serializers:

- `AppPaths` resolves the per-platform directory and `LLAMA_PULSE_CONFIG_DIR`,
  plus `serverYamlFile`, `serverStateYamlFile`, `serverLogFile`, `binDirectory`
  and `modelsDirectory`.
- `YamlEncoder` / `YamlDecoder` convert plain Dart collections. The encoder
  keeps doubles with a decimal point (`0.0`, not `0`) and quotes strings that
  would otherwise reparse as another scalar.
- `YamlFileConfigStore` writes one document per file through a temporary file
  and rename; `InMemoryConfigStore` backs tests (including CLI tests). CLI
  production wires `YamlFileConfigStore`.
- `YamlModelParamsRepository` maps `params.yaml` and falls back to
  `ModelParams.defaults()` for missing, malformed or stale documents.
- `YamlServerConfigRepository` maps `server.yaml` (`schemaVersion: 1` and a
  `server` mapping) and falls back to `ServerConfig.defaults()` the same way.
  Saving validates first and refuses invalid values.
- `YamlServerStateRepository` maps `server-state.yaml`; a missing or unreadable
  state document means "nothing is recorded".

The CLI's `params get` and `server get` print exactly the document the matching
repository writes. Changing a field means updating the entity, the validator,
the YAML round-trip test, the CLI flags and the dashboard form.

## 7. FFI and isolates

A worker isolate exists. Core's `data/inference/` holds the protocol
(`WorkerRequest`/`WorkerResponse` and their kinds), `WorkerTransport`,
`WorkerLlamaEngine`, `WorkerLoop`, `StubLlamaSession`, the
`UnavailableLlamaSession` placeholder and the `@pragma('vm:entry-point')`
`llamaWorkerMain` entrypoint. There is no `dart:ffi` code yet;
`--stub` and `LLAMAPULSE_STUB_ENGINE` set `WorkerConfig.useStubSession`
explicitly. The default session is `UnavailableLlamaSession`, whose `load`
fails with `engineUnavailable` ("the native llama.cpp session is not implemented
yet"), so a plain build has no engine.

- One long-lived worker isolate per engine, spawned lazily on the first
  `load`/`unload`/`generate`. A failed start is retried on the next call. No
  engine state on the UI isolate.
- `Isolate.spawn` resolves the entrypoint by value, so `llamaWorkerMain` keeps
  its `@pragma('vm:entry-point')`.
- Messages across the port are `built_value` DTOs. Caller request ids are
  non-negative and unique while in flight; reusing an in-flight id is rejected
  with one `failed` event carrying `engineBusy` and leaves the live request
  untouched. Control requests use negative ids so they cannot collide.
- The worker isolate owns the session: it is the only place that calls `open`,
  `load`, `begin`/`next`, `cancel`, `unload` and `dispose` on a `LlamaSession`.
  Dispose awaits the in-flight generation and any pending cancel before calling
  `LlamaSession.dispose`, so `cancel()` and `dispose()` never overlap.
- Cancellation is cooperative: a `cancel` request is checked between decode
  steps. `Isolate.kill` is used only by `WorkerTransport`, on handshake abort and
  on `close()` after a 2 s grace; it is never used to cancel a generation, which
  would leak native memory.
- Exactly one terminal event per request: `completed`, `cancelled` or `failed`.
- Token batches are coalesced and metrics are emitted every 250 ms.
- `WorkerTransport` waits up to 10 s for the `WorkerReady` handshake and
  surfaces isolate errors and unexpected exits as failures. A handshake timeout
  aborts the start and the transport can be started again; a `close()` that
  races an in-flight spawn still kills the worker, so nothing leaks.
  `WorkerLlamaEngine` applies a 30 s load/unload timeout and a 5 min per-request
  timeout, and its `dispose` is idempotent, awaits the transport teardown and
  cancels its subscriptions.
- Failures cross the port as `InferenceFailure` values, never as thrown
  exceptions. Load failures throw `InferenceFailureException` on the caller
  side.
- Never `dart:ffi` on the UI isolate — not even to probe a symbol. Symbols, once
  native code exists, come from `DynamicLibrary.open` + `lookupFunction`, never
  `@Native`; the app must start with no native library present.
- `NativeLlamaSession` (deferred) implements core's `LlamaSession` and runs in
  the worker, pinned to an upstream llama.cpp tag. Native-PR contract:
  `LLAMA_PULSE_LIB` is the absolute path to the shared library, read only inside
  the worker. Resolution order is explicit path → env → bundle → exe-adjacent →
  data dir → bare soname. A runtime `llama_version()` gate must reject a
  mismatched library with a `libraryVersionMismatch` failure code. The build,
  tests and library startup must work with no llama.cpp binary installed.
- UTF-8 is accumulated by `Utf8TokenAccumulator`, because
  `llama_token_to_piece` can split a code point across tokens.

## 8. DI

Core has no annotations and no `get_it`; it only defines gateways.

- `apps/llama_pulse/lib/app/di/injection.dart` hand-registers the core types:
  `AppPaths`, `Serializers`, `ConfigStore`, `ModelParamsValidator`,
  `ModelParamsRepository`, `ModelFileScanner`, `ServerConfigValidator`,
  `ServerConfigRepository`, `ServerStateRepository`, `ServerLogStore` and the
  use cases. `injectable` only generates for app-owned types;
  `injection.config.dart` is committed.
- `configureDependencies({engine, serverController, configStore, paths,
  useStubEngine, useStubServer})` accepts explicit caller-supplied engines and
  controllers plus overrides for the config store and paths. An explicit
  `serverController` wins; otherwise `StubServerController` is used only when
  `useStubServer` is true or `LLAMAPULSE_STUB_SERVER` is set, and
  `LlamaServerSupervisor.production` is the default.
- `WorkerLlamaEngine` is registered only when an explicit `engine` arrives or
  `useStubEngine`/`LLAMAPULSE_STUB_ENGINE` is set; with neither, no engine is
  registered.
- `InferenceBloc` is a registered factory; its fourth argument is a nullable
  `LlamaEngine`, so the screen still builds when no engine exists and reports
  `engineUnavailable` instead of throwing. `ServerBloc` is a factory over the
  config repository, validator and the DI-owned controller; the controller
  outlives the bloc, so `close` only cancels subscriptions. An
  `AppLifecycleListener` disposes that controller when the window closes, and
  the bloc seeds the dashboard from `server-state.yaml` when it records an
  active run the controller does not own: Start is disabled and the status card
  says `Started outside this app` and points at `llamapulse stop`.
- A release build must never silently produce synthetic output or a synthetic
  server. Stub selection is explicit at build time (`--dart-define`) or in the
  caller; nothing flips it at runtime.
- The CLI has no service locator. `CliServices` in
  `apps/llama_pulse_cli/lib/src/cli_services.dart` is the manual composition
  root, built in `bin/llamapulse.dart` for production and directly in tests.
- Constructor injection everywhere; `getIt` is read only in `main`/`bootstrap`
  and in a `BlocProvider`'s `create` — never inside `build`, callbacks, domain
  or data code.
- App tests call `getIt.reset()` and then
  `configureDependencies(engine: …, configStore: …, paths: …)`; there is no
  `@Environment('test')` and no manual unregister dance.

## 9. CLI

The primary commands are the server group: `server get`, `server set`,
`serve`, `status`, `stop` and `logs` (section 10.2). The earlier `version`,
`params get`, `params set`, `models list`, `models inspect`, `run` and `bench`
remain. `run` and `bench` are the embedded/experimental path.

- `run` and `bench` require `--stub` until the native engine lands. `--stub`
  explicitly selects the deterministic `StubLlamaSession` inside the worker; it
  is not a fallback. Without it, both exit `1` with
  `engineUnavailable: the native session is unavailable; pass --stub`. The CLI
  never silently falls back to the stub.
- `run` flags: `--model`, `--prompt`, `--file` (`-` reads stdin), `--stream`,
  `--json`, `--threads`, `--temperature`, `--top-p`, `--top-k`, `--max-tokens`
  and `--context-size`. `--prompt` and `--file` are mutually exclusive; one is
  required. `--json` and `--stream` cannot be combined.
- `bench` flags: `--runs` (1..50, default 3), `--json`, `--max-tokens`
  (default 32), plus the shared `--model` and sampling overrides. It runs the
  fixed `benchPrompt` repeatedly and reports aggregate throughput.
- Schema-v1 NDJSON covers `started`, `token`, `metrics`, `completed`,
  `cancelled` and `failed`, each line carrying `schemaVersion` and `type`.
  `metrics` and `failure` are nested objects. `bench --json` emits one
  aggregate `type: "bench"` object instead of a stream.
- stdout carries command data only; stderr carries diagnostics, human summaries
  and usage errors.
- Every leaf command accepts `--json`. Server leaves print one single-line
  JSON object except `serve` and `logs --follow`, which emit NDJSON. The
  `params`, `models` and `server` groups are not invocable. Configuration files
  on disk stay YAML.
- Exit codes: `0` success (including `stop` when nothing was running), `1`
  unexpected failure (including `engineUnavailable` and any non-running
  `status`), `2` invalid arguments or validation failure, `3` requested model
  not found or not a readable `.gguf` file, `130` interrupted by SIGINT.
- The `params get`, `params set`, `server get`, `server set` and `logs` leaf
  commands include the active file path in their help, because the platform
  directory varies.

## 10. Server supervisor

The supervisor is `LlamaServerSupervisor` in core's `data/server/`; it
implements the `ServerController` gateway. The dashboard, `serve` and `status`
use the same `ServerController` contract. Process launch, HTTP, signalling and
port probing are injected, so the supervisor tests replace them with fakes.

### 10.1 Lifecycle and invariants

- Phases: `stopped → starting → running → stopping → stopped`, with `failed`
  as the terminal error state and `starting → failed` for startup errors. The
  enum lives in `server_phase.dart`.
- `start` validates the configuration, locates the binary, checks that the model
  is a file, probes the port, spawns the child with an argument vector (never a
  shell string), waits for `/health` and enriches with `/props`. Readiness and
  `testConnection` both require an HTTP 200 **and** `{"status":"ok"}`; a 200
  with `{"status":"loading"}` is `degraded`/`loading`, not healthy.
- The startup timeout is `ServerConfig.startupTimeoutSeconds` (default 120).
  An exit before readiness or a timeout terminates the child and marks the run
  `failed`; it never leaves a process behind.
- Stop is graceful first (`SIGTERM`). After a 5 s grace the supervisor forces
  the child and waits again. `stop()` waits for an in-flight `start()`, so a
  stop request aborts readiness and never ends up `running`; it is idempotent.
  A child that survives `SIGKILL` makes `stop()` throw and leaves the state
  `failed` with `serverPid` set.
- Terminal states clear `supervisorPid`, and pids are released on stop. There
  is no auto-restart and no backoff loop. A child that exits after `running`
  marks `failed` with `processExited`; only a caller starts again.
- One supervisor owns at most one child. `start` throws `invalidConfig` while a
  run is active (`starting`, `running` or `stopping`), and the CLI `serve`
  additionally refuses when the recorded server still answers `/health`.
- The port preflight is advisory: `SocketPortProbe` binds and closes the port,
  but another process can take it in between. The supervisor also watches the
  child's stderr for bind errors and maps them to `portInUse`.
- `server-state.yaml` is the cross-process contract. The supervisor writes it
  after every transition, `stop` clears a settled document, and `status` reads
  it from another terminal. Health-only changes are broadcast without a write.
- The log store keeps a 1000-entry in-memory ring and appends
  `timestamp<TAB>sequence<TAB>stream<TAB>line` records to `server.log`,
  rotating at 1 MiB to `server.log.1`. ANSI escapes are stripped and long lines
  are truncated.
- API keys: `server.yaml` holds the key in plaintext by design and the
  supervisor passes it to the child in argv. The key is redacted from child log
  lines and failure details, and is never written to `server-state.yaml` or
  `server.log`.
- Monitoring: the production supervisor owns a `ServerMonitor` that samples
  `/metrics`, `/slots` and `/props` about once a second while running and emits
  `ServerMetrics` on the metrics stream. The launch arguments always include
  `--metrics --slots`. `/metrics` (Prometheus) is required for a sample;
  `/slots` and `/props` are best-effort. A failed sample or health probe marks
  the run `degraded` or `unreachable` without changing the phase, and health
  recovers when the server answers again. Uptime comes from the `Process-Start-Time-Unix` response
  header, context usage from `/slots`, and there is no total-request counter in
  current llama.cpp. Those HTTP payloads are the only JSON decode exception
  (`jsonDecode` stays under `data/server/`).
- Binary discovery order: `binaryPath` → `LLAMA_PULSE_SERVER` → bundled
  `<exeDir>/data/llama-server` → `<exeDir>/llama-server` →
  `<config>/bin/llama-server` → `PATH`. `llama-server --version` supplies the
  build. Builds below `b4000` warn with `supported: false`; an unknown or
  unreadable version reports `supported: true` with a warning (shown in the
  UI). Nothing blocks a start on the version.
- `--load-mode` is used for build `b10875` and newer, and for an unknown build;
  older builds get legacy `--mlock`/`--no-mmap`. `extraArgs` are appended and
  must not repeat a managed flag.

### 10.2 Server CLI

- `server get` prints `server.yaml` (defaults when absent) and never writes.
  `server set` validates and writes; `--reset` restores defaults and cannot be
  combined with other settings.
- Shared flags for `server set` and `serve`: `--model-path` (alias `--model`),
  `--host`, `--port`, `--context-size`, `--threads`, `--gpu-layers`,
  `--parallel`, `--alias`, `--api-key`, `--flash-attn on|off|auto`, negatable
  `--[no-]mlock` and `--[no-]mmap`, repeatable `--extra-arg` (replaces the
  stored list), `--binary`, `--startup-timeout`, `--json`.
- `serve` runs in the foreground, applies its flags over the stored
  configuration for one run, mirrors child output and stops on SIGINT/SIGTERM.
  It subscribes to the controller streams before `start`, so `starting` and the
  first log lines appear immediately; SIGINT or SIGTERM during startup stops
  the child immediately and exits `130` or `0`. A supervisor stream that closes
  without a terminal event becomes
  `failed(unknown, 'the supervisor stream ended')`. `serve --json` is NDJSON on
  stdout with `starting`, `ready`, `metrics`, `log`, `stopping`, `stopped` and
  `failed`; a pre-start failure still emits exactly one `failed` line, and
  diagnostics stay on stderr. `stopping` is emitted by `stop()` only, with
  reason `sigint` or `sigterm`.
- `status` reads the state file and probes `/health`. `starting`, `running` and
  `stopping` count as an active run. It exits `0` only when the phase is
  `running` and `/health` returns 200 with `{"status":"ok"}`; a 200 with
  `{"status":"loading"}` is `loading`, and `stopped`, `stale` and `failed` exit
  `1`. Human status is `running`, `stopped`, `stale` or a phase name; uptime is
  reported from `startedAtEpochMs` even when the server is unreachable.
- `stop` signals the recorded supervisor and falls back to `serverPid` when the
  signal cannot be delivered; `--force` targets the process that actually
  accepted the signal. It waits up to 10 s for the state file to release the
  pids, then forces. It reports and records a stop only when the document is
  absent or terminal with no pids; otherwise it exits `1` and leaves the
  document untouched. `stop` exits `0` when nothing is running.
- `logs` prints the newest 1..1000 lines from the log store (default 100).
  `--follow` follows by sequence number, so it survives rotation, then exits
  `130` on interrupt. The on-disk format is
  `timestamp<TAB>sequence<TAB>stream<TAB>line`.
- Server commands share the CLI exit codes: `0` success, `1` unexpected
  failure or non-running `status`, `2` invalid arguments/configuration, `3`
  missing model, `130` SIGINT.

## 11. Code style

Clean, self-documenting code. Comments only where the reason is non-obvious (an
ABI layout, a llama.cpp quirk, a workaround). Do not narrate what the code
does, do not comment every member, no commented-out code, no TODOs without an
issue reference.

`///` doc comments only on public API contracts: gateway interfaces, entities'
derived getters, the bloc's public surface. Document sparingly: doc comments
explain contracts and non-obvious reasons, not restate signatures.

Prefer modern Dart 3 where it genuinely simplifies: `sealed` hierarchies with
exhaustive `switch` expressions; class modifiers (`abstract interface class`,
`final class`); records for private multi-value returns; patterns for
destructuring; `unawaited` for intentional fire-and-forget; `super.name`
params; primary constructors only on plain classes, never on `built_value`.

Formatting: `dart format`, 80 columns, single quotes, trailing commas.

YAML output: strings with newlines or control characters are emitted
double-quoted with escapes; everything else stays plain or single-quoted. The
YAML layer must round-trip through `YamlDecoder`; the tests enforce it.

Analysis must be clean under `strict-casts`, `strict-inference`,
`strict-raw-types`, plus `always_declare_return_types`, `avoid_dynamic_calls`,
`directives_ordering`, `prefer_final_locals`, `unawaited_futures`,
`use_super_parameters`. Generated files are excluded. No `dynamic` in public
APIs, no `!` on nullable values, no empty `catch` blocks.

## 12. Testing

From the root, `dart run melos test`. Melos picks `flutter test` for the app and
`dart test` for core and CLI. Test the critical seams, not every line. Coverage
is not a target. The suites hold 577 tests today: 379 core, 119 CLI, 79 app.

Must test today:

- YAML round-trip, quoting and double formatting.
- Repository fallbacks: missing file, malformed YAML, stale `schemaVersion`,
  invalid parameters, for both `params.yaml` and `server.yaml`; the
  `server-state.yaml` round-trip.
- Scanner warnings and path resolution.
- CLI exit codes, `--json` shape, and `run`/`bench` NDJSON and exit codes
  (`0`, `1`, `2`, `3`, `130`) with the stdout/stderr split. `run` validates
  flags, options and the model before reading stdin, and invalid UTF-8 from
  `--file` is a usage error (exit 2). A stream that ends without a terminal is
  reported as `failed(unknown, 'the engine stream ended without a result')`.
- The worker layer: `WorkerLoop` responses, `WorkerTransport` through a real
  isolate (handshake timeout and reuse after an aborted start, crash and exit,
  `close()` racing a spawn), and `WorkerLlamaEngine` (lazy spawn, per-request
  timeout, cooperative cancel, duplicate request ids, idempotent dispose).
- `InferenceBloc` state machine, including terminal events, cancellation, the
  100-entry metrics-history cap, unload rejected with `engineBusy` while
  generating, Generate re-validating params, and stored params never clobbering
  edits made before `Started` completes.
- Server slice seams, with fakes only:
  - `ServerArgumentBuilder`: managed flags, alias/api-key presence, legacy vs
    `--load-mode`, `extraArgs` append order, no shell quoting.
  - `ServerBinaryLocatorImpl`: discovery order, `LLAMA_PULSE_SERVER` forms,
    not-found and not-executable failures.
  - `ServerVersionParser`: full version/build/commit, bare build, unknown
    output warns instead of throwing, `b4000` boundary.
  - `LlamaServerSupervisor`: transitions, strict readiness, startup timeout,
    exit before ready, bind-error mapping, graceful→force escalation, a stop
    during an in-flight start, a child surviving `SIGKILL`, released pids,
    health/monitor degradation and recovery, no auto-restart, dispose
    idempotence.
  - `ServerLogStore`: ring cap, rotation at 1 MiB with one backup, ANSI
    stripping, truncation and unparsable-line tolerance.
  - `ServerMetricsMapper` / `PrometheusMetrics`: every mapped name, missing
    metrics, slot-derived active/total slots and context usage, uptime header.
  - CLI server commands: exit codes, `--json` shape, `serve` NDJSON event
    order, `status` 0-only-when-healthy, `stop` escalation, `logs --follow`.
  - `ServerBloc` and the dashboard widgets: dirty/save, start/stop, test
    connection, 120-sample metrics history, 1000-line log cap, wide/narrow
    layout, demo-server banner.
- DI registration and the test overrides.
- Widget tests for the chat screen, Generate/Cancel, the editable form and the
  demo-engine banner (the experimental path).
- Screen layout: wide and narrow windows, and the two-tab shell.

Supervisor, bloc and UI tests use fakes for process launch, HTTP, signals and
the port probe. A few core tests do exercise the real launcher, a localhost
socket and an in-process `HttpServer` on ephemeral ports. JSON decoding is
tested through the `data/server/` seams; the architecture test keeps
`jsonDecode` there and keeps `jsonEncode` out of the whole package.

Real-isolate tests run only in the pure-Dart suites: core's `dart test` and the
CLI's `dart test`; never in `flutter test`. Flutter's test binding and an actual
isolate handshake do not mix reliably.

Tests mirror the package layout. Most core fakes are declared inline in the
test file that uses them; the app keeps shared fakes in `test/support/`. Never
call platform plugins; inject the dependency. No `pumpAndSettle` against
never-ending fake streams. Every PR touches tests or states why not.

## 13. Codegen

Run `dart run melos run gen` from the root. It runs build_runner in core, then
in the app. Never pass the removed conflicting-outputs flag: build_runner 2.16
deleted it. The CLI has no codegen.

Every `built_value`/`EnumClass` file has `part '<file>.g.dart';` next to it.
Generated files (`.g.dart`, `.config.dart`) are committed and never edited by
hand. A change is not done until codegen is re-run and a second run leaves
`git status` clean.

`serializers.dart` uses `StandardJsonPlugin`. The YAML layer sits above it and
stores plain collections — no `TypeAdapter`s, no freezed.

## 14. Git, issues and docs

`main` is production; `develop` is integration once it exists. Until then the PR
base is `main`. Both change only through PRs.

Branches: `feature/<topic>`, `bugfix/<topic>`, `chore/<topic>`, `hotfix/<topic>`.
The PR base must match the branch type (`hotfix/*` targets `main`; everything
else targets the integration branch). Never commit to `main`/`develop`, never
merge, tag or force-push.

Commits are small, single-purpose, imperative:
`feat(inference): add worker transport`.

Roadmap and current work live in GitHub issues: one tracking issue per
multi-step plan, its steps as a checklist. A PR body carries `Refs #<n>`. Close
an issue only after its PR merges. Any change to architecture, pins or these
rules updates `AGENT.md` in the same PR.

## 15. Extending

Add an embedded parameter:
1. Add the field and default to `ModelParams` and its builder.
2. Update `copyWith` and the limits in `ModelParamLimits`/validator.
3. Add a serialization test for the default and a YAML round-trip.
4. Wire the CLI flag and the chat form field.

Add a server setting:
1. Add the field and default to `ServerConfig` and its builder.
2. Update `copyWith`, `ServerConfigValidator` and `managedFlags` when the field
   emits a `llama-server` flag.
3. Add a YAML round-trip and a validator boundary test.
4. Wire the shared CLI flag in `addServerOptionFlags`, then the dashboard form
   field.

Add an engine implementation: implement `LlamaSession` in core's
`data/inference/` for the worker, or a test `LlamaEngine` registered through
`configureDependencies(engine: …)`, and add a fake in `test/support/`. No
annotations in core.

Add a feature slice: `domain/<feature>` and `data/<feature>` in core, plus
`presentation/<feature>` in the app; one gateway in domain, one bloc per screen,
no imports of another feature's data layer.

Post-MVP landing spots:

- Native embedded llama.cpp session (deferred): add a `LlamaSession`
  implementation next to `StubLlamaSession` in the worker, pinned to an upstream
  llama.cpp tag, and gate the loaded library behind a runtime `llama_version()`
  check. Keep `LLAMA_PULSE_LIB` and the resolution order from section 7. A local
  install at `/opt/llama.cpp-rocm` is an Unsloth fork (`0.7.0-dev`); do not bind
  against it. Upstream `v0.8.0` already carries `load_mode`, `lazy_mode`,
  `load_mtp`, `n_rs_seq`, `outputs_max`, `ctx_type`, `moe_cache_size` and
  `ctx_other`, so nothing in this plan depends on fork-only struct fields.
- Binary downloader: `data/downloads/` in an app layer plus a library locator
  strategy; the UI reaches it through a core gateway. It must
  **ask which compute backend to install (CPU/ROCm/CUDA/Vulkan/Metal)** and
  offer a detected default rather than guessing.
- Hugging Face / model manager: `data/models/` with structured storage (the
  `hive_ce` dependency returns with the model manager) through a core gateway.

Hard invariants for all future work: no `dart:ffi` on the UI isolate, and every
native failure surfaces as an `InferenceFailure`.

## 16. Commands

```
# at the root only
flutter pub get
dart run melos run gen
dart run melos run check
dart run melos run app
dart run melos run app:stub
dart run melos run app:stub-server
dart run melos run build:app
dart run melos run build:cli
dart run melos analyze
dart run melos test
dart run melos run format:check

# inside one package
dart format lib test
```

`dart run melos run check` runs gen, analyze, test, the format check and the CLI
build. The multi-command scripts start with `set -e`, so it is a genuine gate; a
masked failure means the script is buggy. The CLI executable is `llamapulse`;
the desktop app binary is `llama_pulse`. From the root,
`dart run llama_pulse_cli:llamapulse …` also works. `melos run app:stub` runs
the GUI chat tab with `--dart-define=LLAMAPULSE_STUB_ENGINE=true`;
`melos run app:stub-server` swaps the real supervisor for the synthetic
controller with `--dart-define=LLAMAPULSE_STUB_SERVER=true`. Plain `melos run
app` starts the real supervisor and registers no embedded engine.
`LLAMA_PULSE_LIB` points at a llama.cpp shared library in the future native
milestone. Never commit `.env` files, secrets or absolute local paths.

## 17. Definition of done for a change

- [ ] The workspace resolves with one lockfile (`flutter pub get` at the root).
- [ ] `pubspec.lock` stays untracked.
- [ ] `dart run melos run check` is green (577 tests: 379 core, 119 CLI, 79 app).
- [ ] The server path works end to end: the plain app can start a real
  `llama-server` when a binary is present, and `serve`/`status`/`stop` work from
  the compiled CLI.
- [ ] No process leaks: start failures, SIGINT/SIGTERM and dispose all terminate
  and reap the child; no orphaned `llama-server` remains.
- [ ] `server.yaml` and `server-state.yaml` round-trip through the YAML layer,
  and the state document releases the pids on stop.
- [ ] The embedded stub path still works from the CLI (`--stub`) and the demo
  chat (`melos run app:stub`); the plain app reports `engineUnavailable` for
  chat.
- [ ] No `dart:ffi` in this batch.
- [ ] `dart run melos run gen` twice leaves `git status` clean.
- [ ] Layers respected; no Flutter imports in core, no `dart:ffi` on the UI
  isolate.
- [ ] Immutability rules from section 5 followed.
- [ ] YAML configuration round-trips (encoder/decoder tests cover the change);
  `jsonDecode` stays under `data/server/` and `jsonEncode` stays absent.
- [ ] Codegen re-run and generated output committed.
- [ ] Tests added for the critical seam touched (or the gap justified).
- [ ] No new dependency without a one-line justification.
- [ ] GitHub issues updated; the tracking issue checklist reflects the change.
- [ ] PR body carries `Refs #<n>`; the PR base matches the branch type.
