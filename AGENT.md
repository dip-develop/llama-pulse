# LlamaPulse — Contributor and Agent Guide

## 1. Project

LlamaPulse is a workspace for running local LLMs through llama.cpp: a Flutter
desktop GUI (`apps/llama_pulse`), a command-line companion
(`apps/llama_pulse_cli`) and a shared Dart package (`packages/llama_pulse_core`).
The MVP goal: pick a model and a llama.cpp library, tune the startup parameters,
watch the run. Today the GUI has an editable parameter form, streaming output and
live metrics; a plain build ships no engine and reports `engineUnavailable`,
while the opt-in demo build (`melos run app:stub`) runs the stub behind a demo
banner. The CLI reads and writes the shared configuration, lists local model
files, and its `run`/`bench` commands run the same stub behind `--stub`. Native
inference is the next milestone.

MVP:

- Visual startup-parameter configuration (model path, context size, threads,
  GPU layers, sampling).
- Live metrics: tokens/sec, prompt-eval time, generation speed.
- Cross-platform: Linux, Windows, macOS.
- All inference in isolates; the UI isolate never touches native code.

Out of scope for now: binary downloader/updater, Hugging Face CLI, model file
manager. The architecture leaves room for all three; section 14 says where.

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
  lib/presentation/inference/   screen, bloc/, widgets/
  test/             app/, presentation/, support/
apps/llama_pulse_cli/
  bin/llamapulse.dart
  lib/src/          command_runner.dart, commands/, inference/, cli_services.dart
  test/
packages/llama_pulse_core/
  lib/llama_pulse_core.dart     public entrypoint
  lib/src/domain/   entities/, exceptions/, gateways/, usecases/, text/
  lib/src/data/     config/, inference/, models/, serialization/
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
`data/{config,inference,models,serialization}`. The `inference/` feature folders
exist in core, the CLI and the app; new domain and data code goes under the
existing subfolders.

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

On-disk configuration is YAML. JSON is only for machine-readable command output
(`--json`) and isolate/transport payloads. Do not add a second config format.

The YAML layer sits above the `built_value` serializers:

- `AppPaths` resolves the per-platform directory and `LLAMA_PULSE_CONFIG_DIR`.
- `YamlEncoder` / `YamlDecoder` convert plain Dart collections. The encoder
  keeps doubles with a decimal point (`0.0`, not `0`) and quotes strings that
  would otherwise reparse as another scalar.
- `YamlFileConfigStore` writes one document per file through a temporary file
  and rename; `InMemoryConfigStore` backs tests (including CLI tests). CLI
  production wires `YamlFileConfigStore`.
- `YamlModelParamsRepository` maps `params.yaml` through the shared serializers
  and falls back to `ModelParams.defaults()` for missing, malformed or stale
  documents. Saving validates first.

`params.yaml` starts with `schemaVersion: 1` and a `params` mapping; the CLI's
`params get` prints exactly the document the repository writes.

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
- `NativeLlamaSession` (later) implements core's `LlamaSession` and runs in the
  worker. Native-PR contract: `LLAMA_PULSE_LIB` is the absolute path to the
  shared library, read only inside the worker. Resolution order is explicit path
  → env → bundle → exe-adjacent → data dir → bare soname. A runtime
  `llama_version()` gate must reject a mismatched library with a
  `libraryVersionMismatch` failure code. The build, tests and library startup
  must work with no llama.cpp binary installed.
- UTF-8 is accumulated by `Utf8TokenAccumulator`, because
  `llama_token_to_piece` can split a code point across tokens.

## 8. DI

Core has no annotations and no `get_it`; it only defines gateways.

- `apps/llama_pulse/lib/app/di/injection.dart` hand-registers the core types:
  `AppPaths`, `Serializers`, `ConfigStore`, `ModelParamsValidator`,
  `ModelParamsRepository`, `ModelFileScanner` and the use cases. `injectable`
  only generates for app-owned types; `injection.config.dart` is committed.
- `configureDependencies({engine, configStore, paths, useStubEngine})` accepts
  an explicit caller-supplied `LlamaEngine` and always accepts overrides for the
  config store and paths. The explicit `engine` wins. Otherwise
  `WorkerLlamaEngine` is registered only when `useStubEngine` is true or the
  `LLAMAPULSE_STUB_ENGINE` compile-time flag is set; with neither, no engine is
  registered.
- `InferenceBloc` is a registered factory; its fourth argument is a nullable
  `LlamaEngine`, so the screen still builds when no engine exists and reports
  `engineUnavailable` instead of throwing.
- A release build must never silently produce synthetic output. Stub selection
  is explicit at build time (`--dart-define`) or in the caller; nothing flips it
  at runtime.
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

Commands: `version`, `params get`, `params set`, `models list`,
`models inspect`, `run` and `bench`.

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
- Every leaf command accepts `--json` and prints one single-line JSON object.
  The `params` and `models` groups are not invocable. The configuration file on
  disk stays YAML.
- Exit codes: `0` success, `1` unexpected failure (including
  `engineUnavailable`), `2` invalid arguments or validation failure, `3`
  requested model not found or not a readable `.gguf` file, `130` generation
  cancelled by SIGINT.
- The `params get` and `params set` leaf commands include the active
  `params.yaml` path in their help, because the platform directory varies.

## 10. Code style

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

## 11. Testing

From the root, `dart run melos test`. Melos picks `flutter test` for the app and
`dart test` for core and CLI. Test the critical seams, not every line. Coverage
is not a target. The suites hold 258 tests today: 165 core, 61 CLI, 32 app.

Must test today:

- YAML round-trip, quoting and double formatting.
- Repository fallbacks: missing file, malformed YAML, stale `schemaVersion`,
  invalid parameters.
- Scanner warnings and path resolution.
- CLI exit codes, `--json` shape, and `run`/`bench` NDJSON and exit codes
  (`0`, `1`, `2`, `130`) with the stdout/stderr split. `run` validates flags,
  options and the model before reading stdin, and invalid UTF-8 from `--file` is
  a usage error (exit 2). A stream that ends without a terminal is reported as
  `failed(unknown, 'the engine stream ended without a result')`.
- The worker layer: `WorkerLoop` responses, `WorkerTransport` through a real
  isolate (handshake timeout and reuse after an aborted start, crash and exit,
  `close()` racing a spawn), and `WorkerLlamaEngine` (lazy spawn, per-request
  timeout, cooperative cancel, duplicate request ids, idempotent dispose).
- `InferenceBloc` state machine, including terminal events, cancellation, the
  100-entry metrics-history cap, unload rejected with `engineBusy` while
  generating, Generate re-validating params, and stored params never clobbering
  edits made before `Started` completes.
- Widget tests for streamed output, Generate/Cancel, the editable form and the
  demo-engine banner.
- DI registration and the test overrides.
- Screen layout: wide and narrow windows.

Real-isolate tests run only in the pure-Dart suites: core's `dart test` and the
CLI's `dart test`; never in `flutter test`. Flutter's test binding and an actual
isolate handshake do not mix reliably.

Tests mirror the package layout. Most core fakes are declared inline in the
test file that uses them; the app keeps shared fakes in `test/support/`. Never
call platform plugins; inject the dependency. No `pumpAndSettle` against
never-ending fake streams. Every PR touches tests or states why not.

## 12. Codegen

Run `dart run melos run gen` from the root. It runs build_runner in core, then
in the app. Never pass the removed conflicting-outputs flag: build_runner 2.16
deleted it. The CLI has no codegen.

Every `built_value`/`EnumClass` file has `part '<file>.g.dart';` next to it.
Generated files (`.g.dart`, `.config.dart`) are committed and never edited by
hand. A change is not done until codegen is re-run and a second run leaves
`git status` clean.

`serializers.dart` uses `StandardJsonPlugin`. The YAML layer sits above it and
stores plain collections — no `TypeAdapter`s, no freezed.

## 13. Git, issues and docs

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

## 14. Extending

Add a config parameter:
1. Add the field and default to `ModelParams` and its builder.
2. Update `copyWith` and the limits in `ModelParamLimits`/validator.
3. Add a serialization test for the default and a YAML round-trip.
4. Wire the CLI flag; add the form field when the editable UI lands.

Add an engine implementation: implement `LlamaSession` in core's
`data/inference/` for the worker, or a test `LlamaEngine` registered through
`configureDependencies(engine: …)`, and add a fake in `test/support/`. No
annotations in core.

Add a feature slice: `domain/<feature>` and `data/<feature>` in core, plus
`presentation/<feature>` in the app; one gateway in domain, one bloc per screen,
no imports of another feature's data layer.

Post-MVP landing spots:

- Native llama.cpp session: replace `StubLlamaSession` in the worker with a
  `LlamaSession` implementation pinned to the latest upstream llama.cpp tag, and
  gate the loaded library behind a runtime `llama_version()` check. Keep
  `LLAMA_PULSE_LIB` and the resolution order from section 7. A local install at
  `/opt/llama.cpp-rocm` is an Unsloth fork (`0.7.0-dev`), so it cannot be used
  with upstream-pinned bindings.
- Binary downloader: `data/downloads/` in an app layer plus a library locator
  strategy; the UI reaches it through a core gateway. It must
  **ask which compute backend to install (CPU/ROCm/CUDA/Vulkan/Metal)** and
  offer a detected default rather than guessing.
- Hugging Face / model manager: `data/models/` with structured storage (the
  `hive_ce` dependency returns with the model manager) through a core gateway.

Hard invariants for all future work: no `dart:ffi` on the UI isolate, and every
native failure surfaces as an `InferenceFailure`.

## 15. Commands

```
# at the root only
flutter pub get
dart run melos run gen
dart run melos run check
dart run melos run app
dart run melos run app:stub
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
the GUI with `--dart-define=LLAMAPULSE_STUB_ENGINE=true`; plain `melos run app`
starts with no engine. `LLAMA_PULSE_LIB` points at a llama.cpp shared library in
the future native milestone. Never commit `.env` files, secrets or absolute
local paths.

## 16. Definition of done for a change

- [ ] The workspace resolves with one lockfile (`flutter pub get` at the root).
- [ ] `pubspec.lock` stays untracked.
- [ ] `dart run melos run check` is green (258 tests: 165 core, 61 CLI, 32 app).
- [ ] The stub path works end to end from the compiled CLI (`--stub`) and the
  demo app (`melos run app:stub`); the plain app reports `engineUnavailable`.
- [ ] No `dart:ffi` in this batch.
- [ ] `dart run melos run gen` twice leaves `git status` clean.
- [ ] Layers respected; no Flutter imports in core, no `dart:ffi` on the UI
  isolate.
- [ ] Immutability rules from section 5 followed.
- [ ] YAML configuration round-trips (encoder/decoder tests cover the change).
- [ ] Codegen re-run and generated output committed.
- [ ] Tests added for the critical seam touched (or the gap justified).
- [ ] No new dependency without a one-line justification.
- [ ] GitHub issues updated; the tracking issue checklist reflects the change.
- [ ] PR body carries `Refs #<n>`; the PR base matches the branch type.
