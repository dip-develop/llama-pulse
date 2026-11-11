# LlamaPulse — Contributor and Agent Guide

## 1. Project

LlamaPulse is a workspace for running local LLMs through llama.cpp: a Flutter
desktop GUI (`apps/llama_pulse`), a command-line companion
(`apps/llama_pulse_cli`) and a shared Dart package (`packages/llama_pulse_core`).
The product is server-first: LlamaPulse launches and supervises a local
`llama-server` and exposes it as an OpenAI-compatible endpoint for OpenCode,
IDEs and scripts. The primary screen is the server dashboard; the embedded Chat
tab is an optional, experimental path that runs a native llama.cpp session.

Today the supervisor, the dashboard and the server CLI work end to end: a
configured `llama-server` is started, waited on through `/health`, sampled
through `/metrics` and `/slots`, and stopped gracefully. The embedded path ships
a real engine: `NativeLlamaSession` behind the worker isolate loads a pinned
llama.cpp shared library, and `run`/`bench` in the CLI select it by default.
`--stub` runs the deterministic stub behind a banner (`melos run app:stub`), and
a build with no resolvable library reports `libraryNotFound` with the searched
paths instead of producing synthetic output.

MVP:

- Supervise `llama-server` from one dashboard: configuration, start/stop,
  readiness, endpoint and logs.
- Live metrics: tokens/sec, slots, requests, context usage and uptime.
- Server configuration in `server.yaml`; CLI parity for headless use.
- Cross-platform: Linux, Windows, macOS.
- No native inference on the UI isolate; the embedded engine stays in its
  worker isolate.

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
  never commit it or a member lockfile. CI resolves the newest versions the
  constraints allow, so a test must not depend on a transitive package's error
  behaviour (this is why the runtime installer verifies its payload itself
  instead of trusting the extractor's exception).
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
| `ffi` | `^2.2.0` | native bindings; `Utf8`, `calloc`, dynamic symbol lookup |
| `path` | `^1.9.1` | cross-platform paths |
| `melos` (dev) | `^8.10.0` | workspace scripts and task runner |
| `yaml` | `^3.1.4` | YAML decoding in core |
| `args` | `^2.7.0` | CLI and packaging-tool argument parsing |
| `archive` | `^4.0.0` | streaming `.tar.gz`/`.zip` extraction for the runtime installer |
| `crypto` | `^3.0.8` | SHA-256 of downloaded runtime archives; dev-only for the catalog digest |
| `flutter_launcher_icons` (dev) | `^0.14.4` | Windows/macOS launcher icons |
| `lints` (dev) | `^6.1.0` | lint baseline for core and CLI |
| `test` (dev) | `^1.31.1` | core and CLI tests |
| `flutter_lints` (dev) | `^6.0.0` | lint baseline for the Flutter app |

The root also sets `dependency_overrides: cli_util: ^0.6.0`.
`flutter_launcher_icons` only needs `cli_logging` (API-identical in
0.4.2/0.5.0/0.6.0), while Melos 8 needs `BaseDirectories` from `cli_util`
0.5.0+. `cli_util 0.6.0` satisfies both.

`args` is also a **dev** dependency of `llama_pulse_core` for
`packages/llama_pulse_core/tool/package_app.dart`. It was already resolved for
the CLI, so the packager adds no package to the workspace and no new transitive
dependency; `pubspec.lock` stays untracked either way.

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
  lib/presentation/home/        shell: rail/nav bar and the three tabs
  lib/presentation/server/      dashboard, bloc/, widgets/
  lib/presentation/runtime/     Runtime tab, RuntimeCard, bloc/, widgets/
  lib/presentation/inference/   experimental chat screen, bloc/, widgets/
  test/             app/, presentation/, support/
apps/llama_pulse_cli/
  bin/llamapulse.dart
  lib/src/          command_runner.dart, commands/, inference/, runtime/,
                    server/, cli_services.dart
  test/
packages/llama_pulse_core/
  lib/llama_pulse_core.dart     public entrypoint
  lib/src/domain/   entities/ (server_*, runtime_*), exceptions/, gateways/,
                    runtime/, usecases/, text/, server_config_validator.dart
  lib/src/data/     config/, inference/, models/, runtime/, server/,
                    serialization/
  lib/src/data/inference/native/  llama_bindings.dart, llama_library.dart,
                    native_llama_session.dart
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
Flutter-specific code stays in the app. The native session, bindings and loader
live only under `lib/src/data/inference/native/`, and the public barrel
`llama_pulse_core.dart` does not export them.

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

On-disk configuration is YAML. There are three configuration documents, all in
the same directory:

- `params.yaml` — embedded/chat parameters (`ModelParams`), including the
  default `systemPrompt`; the schema version is unchanged.
- `server.yaml` — the supervised `llama-server` configuration (`ServerConfig`).
- `server-state.yaml` — the supervisor's persisted state (`ServerState`).

The runtime store keeps its own two YAML documents under `<config>/runtime/`:
`index.yaml` (`RuntimeIndex`: what is installed and which one is selected) and
`<tag>/<backend>/runtime.yaml` (`RuntimeManifest`: the exact release, asset and
digest an install came from). They are parsed and written by
`YamlRuntimeStore`, never hand-edited, and a malformed document degrades to
"nothing installed" instead of blocking a launch.

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

### Parameter catalog

`ParameterCatalog.v080` in `lib/src/domain/parameters/` is the single source of
truth for the 362 `llama-server` `v0.8.0` parameters (12 groups: 210
configurable, 14 managed, 132 unsupported, 6 removed; 10 are catalogued for
the embedded surface, and the native session honours all of them).
`ParameterSpec`, `ParameterValidator`, `ParameterValueCodec` and
`ParameterValues` live beside it; `ParameterCatalog` stays in `domain` and
imports no `dart:io`.

Rules:

- Generated files are never hand-edited: the only editable catalog input is
  `catalog/llama_args.v0.8.0.overrides.yaml`, and
  `parameter_catalog.generated.dart` is a generated part of
  `parameter_catalog.dart`. `catalog/llama_args.v0.8.0.yaml` is generated too.
- `ServerArgumentBuilder` and `ModelArgumentBuilder` share the emission rules.
  Emit a flag and its value as separate vector tokens, never `--flag=value`;
  iterate the catalog, not the map; skip typed-owner and unavailable ids.
- A managed id cannot be stored in `params:`. An id with a typed owner is
  written through that field and may be named by `--param` as an alias; managed
  ids without an owner (`load-mode`, `metrics`, `slots`) are rejected.
- One owner per id: a value comes from its typed field or from the catalog map,
  never both. `ParameterValues.normalized` keeps map order stable and unknown
  ids sorted at the end for the validator.
- Descriptions are defined once in the catalog. The CLI listing,
  `params describe`, the validation messages and the GUI tooltips all read the
  same `summary`/`description`.
- Both YAML documents store only non-empty values: `server.yaml` under
  `server.params` and `params.yaml` under `params.params` (the outer `params` is
  the `ModelParams` document).
- `crypto` is a dev dependency only: the generator and the tests use it for the
  catalog digest and the vendored-file check.
- `dart run melos run gen:catalog` rewrites both generated files and
  `gen:catalog:check` fails on drift; both are part of `melos run check`.

## 7. FFI and isolates

A worker isolate exists. Core's `data/inference/` holds the protocol
(`WorkerRequest`/`WorkerResponse` and their kinds), `WorkerTransport`,
`WorkerLlamaEngine`, `WorkerLoop`, `StubLlamaSession`, `NativeLlamaSession`
(under `native/`), `LlamaLibraryLocator` and the `@pragma('vm:entry-point')`
`llamaWorkerMain` entrypoint. `--stub` and `LLAMAPULSE_STUB_ENGINE` set
`WorkerConfig.useStubSession` explicitly, and `WorkerConfig.libraryPath` carries
an explicit library path from `--lib`. The default session is
`NativeLlamaSession`; when no library resolves, `load` fails with
`libraryNotFound` and the searched paths in `details` instead of producing
synthetic output.

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
- Never `dart:ffi` on the UI isolate — not even to probe a symbol. Symbols come
  from `DynamicLibrary.open` + `lookupFunction`, never `@Native`; the app must
  start with no native library present.
- UTF-8 is accumulated by `Utf8TokenAccumulator`, because
  `llama_token_to_piece` can split a code point across tokens.

Native session rules:

- **Pin.** Bind only llama.cpp `v0.8.0`
  (commit `8642541b255bfb5dc39cd351a178be09013a55d6`). `LlamaVersionPin` holds
  the version, tag and commit; `RuntimeRelease.v080` holds the same tag and
  commit plus build `b11960` and every platform archive. The vendored headers,
  `PIN.md`, `SHA256SUMS`, `RUNTIME_ASSETS.md` and `abi_check.c` live in
  `third_party/llama_cpp/v0.8.0/`, and
  `sha256sum -c third_party/llama_cpp/v0.8.0/SHA256SUMS` verifies them.
- **Gate.** `LlamaLibrary.open` calls `llama_version()` and accepts exactly
  `0.8.0`. It also accepts `0.8.0-dev` — what every official prebuilt archive
  reports — only when `runtime.yaml` beside the library attests the pin: tag
  `v0.8.0`, build `b11960`, a commit prefix of the pinned commit, and the
  pinned archive name, SHA-256 and size (`RuntimeAttestation`). Everything else,
  including a local `/opt/llama.cpp-rocm` Unsloth fork that reports `0.7.0-dev`,
  fails with `libraryVersionMismatch` and the reported version; that is the gate
  working, not a bug. A local `-DLLAMA_BUILD_IS_DEV=OFF` build still reports
  `0.8.0` and needs no manifest. The build recipe is
  `third_party/llama_cpp/v0.8.0/BUILD.md`; `tool/build_llama_cpp.sh [tag]`
  (default `v0.8.0`) runs it in one command with
  `-DBUILD_SHARED_LIBS=ON -DLLAMA_BUILD_IS_DEV=OFF -DLLAMA_BUILD_TESTS=OFF
  -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_APP=OFF
  -DGGML_NATIVE=ON`. `LLAMA_BUILD_APP=OFF` is required: upstream `v0.8.0`
  otherwise fails on a missing `build-info.h` in `app/llama.cpp`, an upstream
  packaging bug.
- **Bindings.** Hand-written in `native/llama_bindings.dart` from the pinned
  headers. No `@Native`, no FFI codegen, and `dart:ffi` is imported only under
  `data/inference/native/`; the `llama_pulse_core.dart` barrel does not export
  the native layer.
- **ABI test.** `test/data/inference/native/abi_layout_test.dart` compiles
  `abi_check.c` with clang and compares every struct size, field offset and
  field width against the Dart classes. `dart:ffi` has no `offsetOf`, so offsets
  are probed from the compiled C output; a red test means the binding, not the
  test.
- **Loading.** Best-effort sibling `libggml*` preload, then
  `DynamicLibrary.open`. From the preloaded `libggml` handle, bind
  `ggml_backend_load_all_from_path` and call it with the library directory
  **before** `llama_backend_init`: without it a directory with
  `libggml-cuda.so` silently runs on the CPU. `llama_backend_init` runs once per
  process, so there is one engine per process. No `dlclose` exists in
  `dart:ffi`; a library stays mapped for the process lifetime.
- **Resolution order.** explicit `--lib`/engine path → `LLAMA_PULSE_LIB` →
  `<exeDir>/lib` → `<exeDir>` → `<exeDir>/../Frameworks` → managed runtimes
  under `<config>/runtime/<tag>/<backend>/` in `RuntimeIndex.resolutionOrder`
  (selected first, then newest first) → a runtime shipped in the bundle under
  `<exeDir>/runtime/<tag>/<backend>/` → `<config>/lib` → bare
  `libllama.so`/`llama.dll`/`libllama.dylib`. No library means
  `libraryNotFound` with every searched path in `details`; the CLI exits `1` and
  the app shows the banner. Never fall back to the stub.
- **Generation.** Tokenize the prompt, truncate on the left to
  `n_ctx - maxTokens`, prefill in `n_batch` chunks (logits only on the last
  prompt token), then sample top-k → top-p → min-p → temperature →
  distribution. `min-p` and `seed` come from the embedded catalog map (defaults
  `0.05` and `LLAMA_DEFAULT_SEED`, `0xFFFFFFFF`, which llama.cpp treats as
  random, so `bench` runs differ); `batch-size` sets `n_batch` and `n_ubatch`,
  capped at the context size. Decode each token before sampling
  the next, stop on EOG, and check cancellation at every step and prefill
  chunk.
  Metrics come from `llama_perf_context` plus the loop's token counts.
- **Chat templates.** `params.chatTemplate` null uses the model's built-in
  template, the literal `none` disables templating, and any other value names
  a built-in template passed to `llama_model_chat_template`;
  `useChatTemplate: false` forces the raw prompt. `begin` renders every
  `GenerationRequest.effectiveMessages` entry through
  `llama_chat_apply_template` in order (probe length, allocate, retry) before
  tokenization. An empty message list means the prompt is one `user` message;
  that shape renders exactly as before. When no template resolves or the call
  fails, a single user message falls back to the raw prompt and a longer
  conversation to a plain `role: content` transcript, so a model without chat
  metadata still runs. The CLI exposes the template as `--chat-template` /
  `--[no-]use-chat-template` and the conversation as `--system` plus repeatable
  `--message role:content`. The chat form has the matching template field and
  switch. `params.systemPrompt` is persisted in `params.yaml`, edited in the
  same form and prepended as the `system` message; the Chat tab keeps
  `InferenceState.transcript`, sends `[system?, …transcript, user]` (the user
  text also stays in `prompt`) and appends the assistant reply, or the partial
  text on cancel/failure. The CLI keeps its per-run `--system` and does not
  read the stored default. The transcript and stored system prompt shipped in
  the merged PR #34, with the test-strength and empty-draft follow-up in PR
  #35.
- **Platform.** 64-bit desktop only: structs are returned by value.
- **Selection.** `WorkerConfig.useStubSession` chooses
  `StubLlamaSession` (explicit `--stub` or `LLAMAPULSE_STUB_ENGINE`);
  `NativeLlamaSession` is the default.

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
- `WorkerLlamaEngine` is always registered: an explicit `engine` wins,
  `useStubEngine`/`LLAMAPULSE_STUB_ENGINE` selects
  `WorkerLlamaEngine(useStubSession: true)`, and the default registers the
  native engine (`WorkerLlamaEngine.new`). Both spawn their isolate lazily, so
  registration has no side effect.
- `InferenceBloc` is a registered factory; its fourth argument is a nullable
  `LlamaEngine`, so the screen still builds when no engine exists and reports
  `engineUnavailable` instead of throwing. A native engine that cannot find its
  library fails `load` with `libraryNotFound` and shows the searched paths in the
  failure banner; `ServerBloc` is a factory over the
  config repository, validator and the DI-owned controller; the controller
  outlives the bloc, so `close` only cancels subscriptions. An
  `AppLifecycleListener` disposes that controller when the window closes, and
  the bloc seeds the dashboard from `server-state.yaml` when it records an
  active run the controller does not own: Start is disabled and the status card
  says `Started outside this app` and points at `llamapulse stop`. While that
  external run is shown the bloc re-reads the document every 2 s; when the run
  ends (for example after `llamapulse stop`) it clears the external flag and
  enables Start again. Reload re-reads both `server.yaml` and the state
  document. On POSIX `runLlamaPulse` installs SIGTERM and SIGINT watchers that
  dispose the controller, terminating a running child, then exit `0` or `130`;
  Windows has no signal watchers.
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
`params catalog`, `params describe`, `params get`, `params set`,
`params export`, `models list`, `models inspect`, `run` and `bench` remain.
`runtime list|status|install|select|remove` manages the pinned runtimes
(section 7 and `docs/runtime.md`). `run` and `bench` are the embedded path.

- `run` and `bench` run the native session by default. `--stub` explicitly
  selects the deterministic `StubLlamaSession` inside the worker; it is not a
  fallback. `--lib <path>` names the libllama shared library; without it the
  worker resolves `LLAMA_PULSE_LIB`, `<exeDir>/lib`, `<exeDir>`, the macOS
  `Frameworks` directory, `<config>/lib` and finally the bare soname (section
  7). The library must report exactly
  `0.8.0`, or `load` fails with `libraryVersionMismatch`. A missing library
  exits `1` with `libraryNotFound` and the searched paths on stderr, or in the
  `failed` JSON object's `details`. The CLI never silently falls back to the
  stub.
- `bench` without `--stub` requires a readable `.gguf` model: a blank path is a
  usage error (`2`) and a missing, non-`.gguf` or unreadable file exits `3`.
- `run` flags: `--model`, `--lib`, `--prompt`, `--file` (`-` reads stdin),
  `--system`, repeatable `--message role:content`, `--stream`, `--json`,
  `--threads`, `--temperature`, `--top-p`, `--top-k`, `--max-tokens`,
  `--context-size`, `--chat-template`, `--[no-]use-chat-template` and repeatable
  `--param`. `--prompt` and `--file` are mutually exclusive; one of `--prompt`,
  `--file` or a user `--message` is required. A message is `role:content` split
  at the first colon; the role must be one of `ChatMessage.knownRoles`, and a
  malformed message or an unknown role exits `2` before the engine loads.
  `--system` comes first, then the `--message` entries in order, then the
  prompt as the final user turn. `--system` is per run and does not read the
  stored `systemPrompt` in `params.yaml`. `--json` and `--stream` cannot be
  combined. `--param` follows the embedded catalog rules: typed owners
  (`ctx-size`, `threads`, `gpu-layers`, `temp`, `top-k`, `top-p`,
  `chat-template`) write `ModelParams` fields, `seed`, `min-p` and `batch-size`
  stay in `params`, and an unknown or unsupported id exits `2` before the
  engine loads. Nothing is persisted.
- `bench` flags: `--runs` (1..50, default 3), `--json`, `--max-tokens`
  (default 32), plus the shared `--model`, `--lib`, `--param` and sampling
  overrides. It runs the fixed `benchPrompt` repeatedly and reports aggregate
  throughput.
- `params export` prints the `llama-cli`-shaped argument vector built by
  `ModelArgumentBuilder` from the stored embedded parameters plus `--param`;
  `--json` prints `{schemaVersion, type: "paramsExport", argv}`. `params get
  --show-modified` prints the embedded ids whose effective value differs from
  the default, and `params get --json` adds the same list under `modified`.
- `params catalog` lists the generated catalog grouped by presentation group
  with `--surface all|server|embedded`, repeatable `--group` and
  `--include-unsupported`; `params describe <id>` prints one full entry,
  including the reason and replacement of an unavailable id. Unknown groups and
  ids exit `2`.
- `--param` is shared by `server set`, `serve`, `params set`, `params export`,
  `run` and `bench`: `id=value` sets, `id=` removes and a bare `id` sets a
  boolean to `true`; a repeatable id keeps every occurrence. Values are
  canonicalized and validated against the catalog. Typed owners write their
  field; when the typed flag is also supplied the values must agree, otherwise
  the command exits `2` (`--threads and --param threads disagree (4 vs 8)`) and
  changes nothing. `server get --show-modified` prints the server ids that
  differ from the defaults.
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
- `runtime install --backend <id> [--tag v0.8.0] [--force] [--yes] [--json]`
  installs one pinned archive: NDJSON `runtimeProgress` lines then one
  `runtimeInstall` object with `--json`, a consent prompt before the CUDA
  runtime archive unless `--yes` or a non-interactive stdin. `runtime status`
  prints hardware, recommendation, offered backends, installed/selected
  runtimes and the gate verdict. `runtime select|remove <tag> <backend>`
  operate on one install; `runtime list` prints the index.
- Exit codes: `0` success (including `stop` when nothing was running), `1`
  unexpected failure (including `libraryNotFound`, any non-running `status` and
  `runtime status` on an unsupported host), `2` invalid arguments or validation
  failure, `3` requested model or runtime not found or not a readable `.gguf`
  file, `4` a downloaded runtime failed integrity verification, `5` a runtime
  download failed at the network or HTTP layer, `130` interrupted by SIGINT.
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
  `failed`; a child that survives `SIGKILL` is kept in the document with its
  pid, and `stop` can retry it.
- Stop is graceful first (`SIGTERM`). After a 5 s grace the supervisor forces
  the child and waits again. `stop()` waits for an in-flight `start()`, so a
  stop request aborts readiness and never ends up `running`; it is idempotent,
  and concurrent `stop()` calls share one in-flight future. `dispose()` closes
  its resources even when `stop()` throws. `stopping` retains `serverPid` so the
  child stays signalled. A child that survives `SIGKILL` makes `stop()` throw
  and leaves the state `failed` with `serverPid` set; a later `stop` retries
  that retained child, but such a process is never reported as stopped.
- Terminal states clear `supervisorPid`, and pids are released on stop. There
  is no auto-restart and no backoff loop. A child that exits after `running`
  marks `failed` with `processExited`; when a child retained after a failed stop
  exits on its own, the supervisor records the exit and clears the pid; only a
  caller starts again.
- One supervisor owns at most one child. `start` throws `invalidConfig` while a
  run is active (`starting`, `running` or `stopping`) and while its own state
  still records a stale `serverPid` (`a previous server process is still
  recorded; stop it first`), and the CLI `serve` additionally refuses when the
  recorded server still answers `/health`.
- The port preflight is advisory: `SocketPortProbe` binds and closes the port,
  but another process can take it in between. The supervisor also watches the
  child's stderr for bind errors and maps them to `portInUse`.
- `server-state.yaml` is the cross-process contract. The supervisor writes it
  after every transition, `stop` clears a settled document, and `status` reads
  it from another terminal. Health-only changes are broadcast without a write.
- The log store keeps a 1000-entry in-memory ring and appends
  `timestamp<TAB>sequence<TAB>stream<TAB>line` records to `server.log`,
  rotating at 1 MiB to `server.log.1`. ANSI escapes are stripped and long lines
  are truncated. Sequence numbers continue across a supervisor restart, seeded
  from the highest sequence already stored in either file.
- API keys: `server.yaml` holds the key in plaintext by design and the
  supervisor passes it to the child in argv. The key is redacted from child log
  lines and failure details, and is never written to `server-state.yaml` or
  `server.log`.
- Monitoring: the production supervisor owns a `ServerMonitor` that samples
  `/metrics`, `/slots` and `/props` about once a second while running and emits
  `ServerMetrics` on the metrics stream. The launch arguments always include
  `--metrics --slots`. `/metrics` (Prometheus) is required for a sample;
  `/slots` and `/props` are best-effort. Any monitor error, not only a
  `ServerException`, marks the run `degraded` and logs the failure; a failed
  health probe marks it `degraded` or `unreachable`. Both leave the phase
  unchanged, and health recovers when the server answers again. Uptime comes
  from the `Process-Start-Time-Unix` response
  header, context usage from `/slots`, and there is no total-request counter in
  current llama.cpp. Those HTTP payloads are the only JSON decode exception
  (`jsonDecode` stays under `data/server/`).
- Binary discovery order: `binaryPath` → `LLAMA_PULSE_SERVER` → bundled
  `<exeDir>/data/llama-server` → `<exeDir>/llama-server` → managed runtimes
  under `<config>/runtime/<tag>/<backend>/` (selected first, then newest first)
  → a runtime shipped in the bundle under `<exeDir>/runtime/<tag>/<backend>/`
  → `<config>/bin/llama-server` → `PATH`. A binary from a managed runtime is
  spawned with that directory as its working directory, with
  `LD_LIBRARY_PATH`, `DYLD_LIBRARY_PATH` and `PATH` prefixed by it and
  `GGML_BACKEND_PATH` set to it, so the matching `libggml*` and backend plugins
  win over another install. `llama-server --version` supplies the
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
  signal cannot be delivered, so a dead supervisor never masks a live child. A
  `failed` document that still records a pid is not treated as stopped: `stop`
  signals that child and retries it. `--force` signals the child first and then
  the supervisor. When a graceful signal was accepted it waits up to 10 s for
  the state file to release the pids, then forces. It reports and records a stop
  only when the document is absent or terminal with no pids; a retained pid it
  cannot signal makes it exit `1` and leaves the document untouched. `stop`
  exits `0` when nothing is running.
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
is not a target. The suites hold 1282 tests today: 883 core (plus two
host/env-gated skips: `native_integration_test` and the real macOS `ditto`
archive test), 233 CLI, 166 app.

Must test today:

- YAML round-trip (including an absent optional `systemPrompt`), quoting and
  double formatting.
- The parameter catalog: the digest over the canonical body, the vendored
  `arg.cpp` hash, unique ids and flags, group integrity, owner fields and the
  lookup helpers; coverage of every server-visible flag (covered or explicitly
  ignored with a reason), exposure disjointness and the 10-entry embedded
  subset; the codec for every type, bound, allow-list and canonical form; the
  validator's managed/unsupported/removed messages; both argument builders.
- Repository fallbacks: missing file, malformed YAML, stale `schemaVersion`,
  invalid parameters, for both `params.yaml` and `server.yaml`; the
  `server-state.yaml` round-trip. The `ModelParamsValidator` accepts a
  multi-line `systemPrompt` and rejects a blank one or one over 4096
  characters.
- Scanner warnings and path resolution.
- CLI exit codes, `--json` shape, and `run`/`bench` NDJSON and exit codes
  (`0`, `1`, `2`, `3`, `130`) with the stdout/stderr split. `run` validates
  flags, options and the model before reading stdin, and invalid UTF-8 from
  `--file` is a usage error (exit 2). A stream that ends without a terminal is
  reported as `failed(unknown, 'the engine stream ended without a result')`.
- The native layer, with a C shim rather than a real llama.cpp build:
  `test/support/native/fake_llama.c` is compiled with clang by
  `FakeLlamaBuilder`, so the binding lookups and behaviour run end to end.
  Cover the ABI layout (`abi_layout_test.dart` compiles `abi_check.c` and
  compares every struct size, field offset and the 74-entry field-width table),
  the exact `0.8.0` version gate
  (`libraryVersionMismatch` for anything else), the locator order and
  `libraryNotFound` details, library open and model load, generation
  (prefill, truncation, sampler chain, EOG, UTF-8 split tokens), metrics and
  cooperative cancel. Chat templates are covered from the session down:
  default, named `chatml`, `none`, the `useChatTemplate: false` override, an
  unknown-name fallback and the grow-and-retry buffer path. The shim enforces
  the batch and sampler contract, so the tests catch a wrong
  `n_seq_id`/`seq_id`, non-monotonic positions, logits on non-final tokens,
  `idx != -1` and sampling without logits. These tests skip when clang is not
  installed.
- The worker layer: `WorkerLoop` responses, `WorkerTransport` through a real
  isolate (handshake timeout and reuse after an aborted start, crash and exit,
  `close()` racing a spawn), and `WorkerLlamaEngine` (lazy spawn, per-request
  timeout, cooperative cancel, duplicate request ids, idempotent dispose).
- `InferenceBloc` state machine, including terminal events, cancellation, the
  100-entry metrics-history cap, unload rejected with `engineBusy` while
  generating, Generate re-validating params, and stored params never clobbering
  edits made before `Started` completes. The chat transcript: the system prompt
  and stored turns are sent as messages, the user turn is appended only after
  validation, the draft folds into an assistant reply on every terminal path
  (completed, cancelled, failed, stream ended), and a clear empties the
  transcript only while idle.
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
- The runtime slice, with fakes only: the release matrix and asset digests, the
  hardware probe's verdicts and recommendation, the YAML store (atomic commit,
  force replacement, orphan cleanup), the downloader (resume, checksum, size,
  cancellation), the extractor's traversal/link/size guards, the installer's
  staging and cleanup, the attested `0.8.0-dev` gate and the status reader's
  gate verdicts.
- The CLI `runtime` group: exit codes `0/1/2/3/4/5/130`, NDJSON progress, the
  CUDA consent prompt and the selected/runtime listing.
- `RuntimeBloc` and the Runtime tab/card: detect, install with progress and
  cancel, select, remove with confirmation, unsupported host.
- DI registration and the test overrides.
- Widget tests for the chat screen, Generate/Cancel, the editable form, the
  stored system prompt and the demo-engine banner (the experimental path), and
  for `ConversationView`: role-labelled bubbles (`You`/`Assistant`), the
  in-flight draft under `output-text`, the empty state and the clear action.
- Screen layout: wide and narrow windows, and the two-tab shell.

Supervisor, bloc and UI tests use fakes for process launch, HTTP, signals and
the port probe. A few core tests do exercise the real launcher, a localhost
socket and an in-process `HttpServer` on ephemeral ports. JSON decoding is
tested through the `data/server/` seams; the architecture test keeps
`jsonDecode` there and keeps `jsonEncode` out of the whole package.

Real-isolate tests run only in the pure-Dart suites: core's `dart test` and the
CLI's `dart test`; never in `flutter test`. Flutter's test binding and an actual
isolate handshake do not mix reliably. `native_integration_test.dart` is the one
env-gated test: it runs only when both `LLAMA_PULSE_LIB` and
`LLAMA_PULSE_MODEL` point at a real pinned library and model, and is skipped in
the normal run (one of the two host/env-gated skips in the counts above).

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

CI is `.github/workflows/ci.yml`, and it mirrors this gate rather than adding a
second one: a Linux job runs `dart run melos run check`, fails on generated-file
drift and builds the Linux desktop app; a `test` matrix runs analyze and the
suites on Ubuntu, macOS and Windows; a standalone Windows job only compiles the
CLI, with no analyze; and a `package` matrix builds, stages, archives and
verifies the Windows and macOS bundles on `windows-latest` and `macos-latest`.
The macOS job also asserts that the built app is not sandboxed. Packaging
artifacts upload only for `main` and `workflow_dispatch`, not for pull requests.
The Windows and macOS bundles are CI-verified only: the development workstation
is Linux, so their layout, archive and runtime placement cannot be re-checked
locally. It pins the Flutter baseline from section 3, not `stable`. Extend this
workflow when a new platform gate is needed.

## 15. Extending

Add a catalog parameter:
1. Change the pin if upstream changed; vendor `arg.cpp`, update `SHA256SUMS`
   and `PIN.md`.
2. Run `dart run melos run gen:catalog`; classify the new id in
   `catalog/llama_args.v0.8.0.overrides.yaml` (exposure, group, text, ranges,
   owner, surfaces) and regenerate until the generator and coverage test pass.
3. Run `gen:catalog:check` and the catalog tests.
4. If the id needs a typed field, continue with "Add an embedded parameter" or
   "Add a server setting"; otherwise it is edited through the generic panel and
   `--param`.

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

- Runtime manager: shipped as `domain/runtime/` plus `data/runtime/` in core,
  with `RuntimeProbe`, `RuntimeStore` and `RuntimeInstallService` gateways. It
  **asks which compute backend to install (CPU/ROCm/CUDA/Vulkan/Metal)** and
  offers a detected default rather than guessing. A new release means a new
  `RuntimeRelease` constant, a new `third_party/llama_cpp/<tag>/RUNTIME_ASSETS.md`
  and regenerated digests; never a network lookup at install time.
- Hugging Face / model manager: `data/models/` with structured storage (the
  `hive_ce` dependency returns with the model manager) through a core gateway.

Hard invariants for all future work: no `dart:ffi` on the UI isolate, and every
native failure surfaces as an `InferenceFailure`.

## 16. Commands

```
# at the root only
flutter pub get
dart run melos run gen
dart run melos run gen:catalog
dart run melos run gen:catalog:check
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

# native llama.cpp shared library (optional; needs git, cmake and ninja)
tool/build_llama_cpp.sh          # tag defaults to v0.8.0
tool/build_llama_cpp.sh v0.8.0

# desktop bundles: release build + README/LICENSE + optional runtime
dart run melos run package:linux
dart run melos run package:windows
dart run melos run package:macos

# equivalent direct entry point, for flags the scripts do not pass
dart run packages/llama_pulse_core/tool/package_app.dart --os windows \
  --runtime v0.8.0 cuda13
dart run packages/llama_pulse_core/tool/package_app.dart --os macos \
  --skip-build --check
```

`package:linux|windows|macos` stage the target's Flutter release output, add
`README.md`/`LICENSE`, copy one installed runtime when
`--runtime <tag> <backend>` is given, then write and verify
`dist/llama-pulse-<version>-<os>-<arch>.{tar.gz,zip}`. `--skip-build --check`
stages an existing `--bundle` into a temporary directory and verifies its layout
without writing an archive; CI runs exactly that before writing the real
archive. `tool/package_linux.sh` is a compatibility shim that forwards to the
Dart tool with `--os linux`. Run a target on its own host: `--os` is not a
cross-compiler. The packager lives in core because `archive` and `path` already
are core dependencies, and its `args` use is a dev dependency only (section 3).

`dart run melos run check` runs gen, analyze, test, the format check and the CLI
build. The multi-command scripts start with `set -e`, so it is a genuine gate; a
masked failure means the script is buggy. The CLI executable is `llamapulse`;
the desktop app binary is `llama_pulse`. From the root,
`dart run llama_pulse_cli:llamapulse …` also works. `melos run app:stub` runs
the GUI chat tab with `--dart-define=LLAMAPULSE_STUB_ENGINE=true`;
`melos run app:stub-server` swaps the real supervisor for the synthetic
controller with `--dart-define=LLAMAPULSE_STUB_SERVER=true`. Plain `melos run
app` starts the real supervisor and registers the native embedded engine.
`LLAMA_PULSE_LIB` points at the llama.cpp shared library the native session
loads; `--lib` does the same for the CLI. The library directory must also be on
`LD_LIBRARY_PATH` for the compiled CLI, because `libllama.so` otherwise resolves
`libggml.so.0` from another install such as `/opt`; `tool/build_llama_cpp.sh`
prints both exports. Never commit `.env` files, secrets or absolute local paths.

## 17. Definition of done for a change

- [ ] The workspace resolves with one lockfile (`flutter pub get` at the root).
- [ ] `pubspec.lock` stays untracked.
- [ ] `dart run melos run check` is green (1282 tests: 883 core plus two
  host/env-gated skips, 233 CLI, 166 app).
- [ ] `dart run melos run gen:catalog:check` is green, and the generated
  `llama_args.v0.8.0.yaml` and `parameter_catalog.generated.dart` are committed
  unchanged by a second generation.
- [ ] The server path works end to end: the plain app can start a real
  `llama-server` when a binary is present, and `serve`/`status`/`stop` work from
  the compiled CLI.
- [ ] No leaked process is silently reported as stopped: start failures,
  SIGINT/SIGTERM and dispose all terminate and reap the child, and a process
  that survives `SIGKILL` stays `failed` with its pid so `stop` can retry it.
- [ ] `server.yaml` and `server-state.yaml` round-trip through the YAML layer,
  and the state document releases the pids on stop.
- [ ] The embedded paths work: `--stub` and `melos run app:stub` still produce
  the deterministic stub output byte for byte, and the plain app and CLI use the
  native session, reporting `libraryNotFound` with the searched paths when no
  library resolves instead of falling back.
- [ ] The native tests pass (ABI layout, version gate, locator, load,
  generation/cancel with the C shim) or skip cleanly without clang.
- [ ] `dart run melos run gen` twice leaves `git status` clean.
- [ ] The GitHub Actions run for the PR is green.
- [ ] The desktop bundles still package: `dart run melos run package:linux`
  (or `tool/package_linux.sh --skip-build`) produces a valid archive, and the
  Windows/macOS `package` CI jobs are green. Windows and macOS bundles are
  CI-verified only; do not claim a local check on the Linux workstation. See
  `docs/packaging.md`.
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
