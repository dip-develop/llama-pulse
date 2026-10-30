# LlamaPulse — Contributor and Agent Guide

## 1. Project

LlamaPulse is a workspace for running local LLMs through llama.cpp: a Flutter
desktop GUI (`apps/llama_pulse`), a command-line companion
(`apps/llama_pulse_cli`) and a shared Dart package (`packages/llama_pulse_core`).
Pick a model and a llama.cpp library, tune the startup parameters, watch the run.
The CLI reads and writes the same configuration and lists local model files.

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
- Exactly one `pubspec.lock`, at the root. Never commit a member lockfile.
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
core. State management with bloc returns with the editable parameter UI. DI:
`get_it` + `injectable` in the app, a hand-written composition root in the CLI.
Immutable models, state and entities: `built_value` + `built_collections`.
Configuration: YAML through the hand-written codec in core.

Pins are deliberate; do not loosen them without reproducing the resolution:

| Package | Pin | Why |
|---|---|---|
| `built_value` | `8.13.0` | exact; generator and runtime move together |
| `built_collection` | `^5.1.2` | 6.x is incompatible with `built_value 8.13` |
| `build_runner` | `2.16.1` | exact; 2.17.x requires `build 5.x`, while `built_value_generator 8.13.0` declares `build <5.0.0` and `injectable_generator 3.1.3` declares `build ^4.0.4` |
| `built_value_generator` | `8.13.0` | exact; must match the `built_value` runtime |
| `injectable_generator` | `3.1.3` | exact; paired with `injectable ^3.0.0` |
| `get_it` | `^9.3.0` | DI container in the app |
| `injectable` | `^3.0.0` | annotations for app-owned registrations |
| `ffi` | `^2.2.0` | `Utf8`, `calloc`, native helpers (FFI milestone) |
| `path` | `^1.9.1` | cross-platform paths |
| `melos` (dev) | `^8.10.0` | workspace scripts and task runner |
| `yaml` | `^3.1.4` | YAML decoding in core |
| `args` | `^2.7.0` | CLI argument and command parsing |
| `flutter_launcher_icons` (dev) | `^0.14.4` | Windows/macOS launcher icons |
| `lints` (dev) | `^6.1.0` | lint baseline for core and CLI |
| `test` (dev) | `^1.31.1` | core and CLI tests |
| `meta` | `^1.18.3` | annotations |
| `flutter_lints` (dev) | `^6.0.0` | lint baseline for the Flutter app |

The root also sets `dependency_overrides: cli_util: ^0.6.0`.
`flutter_launcher_icons` pins `cli_util ^0.4.1`, while Melos 8 needs
`BaseDirectories` from 0.5+. The override is safe because both packages only use
`cli_logging`, whose API is identical across 0.4.2/0.5.0/0.6.0.

`packages/llama_pulse_core/LICENSE` is a copy of the root MIT license so the
package is self-contained.

Rules: no new dependency without a one-line justification in the PR that adds
it; `pubspec.lock` is committed.

## 4. Layout and dependency rule

```
apps/llama_pulse/
  lib/main.dart
  lib/app/          bootstrap.dart, app.dart, di/, theme/
  lib/presentation/inference/   screen, widgets, bloc/ (next)
  test/             app/, presentation/, support/
apps/llama_pulse_cli/
  bin/llamapulse.dart
  lib/src/          command_runner.dart, commands/, cli_services.dart
  test/
packages/llama_pulse_core/
  lib/llama_pulse_core.dart     public entrypoint
  lib/src/domain/   entities/, gateways/, usecases/, text/
  lib/src/data/     config/, models/, serialization/
  test/             architecture/, data/, domain/
```

Dependency rule:

- `presentation -> domain` (entities, gateways, use cases from core)
- `data -> domain`; data implements the core gateways
- `app` may import all of them; `presentation` never imports `data` directly
- core's `domain/` imports only `dart:` core libraries and core's own domain
- `package:flutter/` is imported only by `apps/llama_pulse`

`packages/llama_pulse_core` must stay Flutter-free. The import rules are enforced
by `packages/llama_pulse_core/test/architecture/core_imports_test.dart`.
`dart:ffi` **is** allowed in core because it only runs inside the worker isolate;
Flutter-specific code stays in the app.

Feature folders keep the same name in every layer: `inference` today,
`models`/`downloads` later. New code goes into its layer, never a new top-level
folder.

## 5. Immutability

`built_value` is mandatory for anything persisted, held in bloc state, or sent
across the isolate boundary: entities (`ModelParams`, `GenerationRequest`,
`GenerationMetrics`, `GenerationEvent`, `InferenceFailure`), the persisted
envelope, worker request/response DTOs, and `InferenceState` once it exists.

Lists in state are `BuiltList`, never growable `List`. Never mutate; never
expose a builder outside the file that owns the type.

Two deliberate exceptions, both in core:

1. `WorkerConfig` / `WorkerReady` (later) hold `SendPort`, which `built_value`
   cannot serialize. Keep them minimal and construct them only in worker
   plumbing.
2. `ModelScanResult` is a transient plain class: the scanner produces it on
   demand, it is never persisted and never compared structurally. Its lists are
   unmodifiable.

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
  and rename; `InMemoryConfigStore` backs tests and the CLI.
- `YamlModelParamsRepository` maps `params.yaml` through the shared serializers
  and falls back to `ModelParams.defaults()` for missing, malformed or stale
  documents. Saving validates first.

`params.yaml` starts with `schemaVersion: 1` and a `params` mapping; the CLI's
`params get` prints exactly the document the app persists.

## 7. FFI and isolates

The engine is **not implemented yet**. These are the rules for the milestone
that adds it:

- One long-lived worker isolate per engine, spawned lazily on the first
  `loadModel`. No engine state on the UI isolate.
- Never `dart:ffi` on the UI isolate — not even to probe a symbol.
- Symbols via `DynamicLibrary.open` + `lookupFunction`, never `@Native`; the
  app must start with no native library present.
- `NativeLlamaSession` (later) implements the core `LlamaEngine` gateway and
  runs in the worker. There is no stub fallback in production once `run` exists.
- Protocol: worker request/response messages, monotonic `requestId`, exactly
  one terminal response per request, token batches coalesced every 16–33 ms,
  metrics every ~250 ms.
- Cancellation is cooperative: a `cancel` request checked between decode steps.
  Never `Isolate.kill` during generation — it leaks native memory.
- Failures cross the port as `InferenceFailure` values, never as thrown
  exceptions.
- UTF-8 is accumulated by `Utf8TokenAccumulator`, because
  `llama_token_to_piece` can split a code point across tokens.
- `LLAMA_PULSE_LIB` is the future contract for the absolute path to the shared
  library; it is read only inside the worker. The build, tests and library
  startup must work with no llama.cpp binary installed.

## 8. DI

Core has no annotations and no `get_it`; it only defines gateways.

- `apps/llama_pulse/lib/app/di/injection.dart` hand-registers the core types:
  `AppPaths`, `Serializers`, `ConfigStore`, `ModelParamsValidator`,
  `ModelParamsRepository`, `ModelFileScanner` and the use cases. `injectable`
  only generates for app-owned types; `injection.config.dart` is committed.
- `configureDependencies({engine, configStore, paths})` optionally registers a
  caller-supplied `LlamaEngine` and always accepts overrides for the config
  store and paths.
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
`models inspect`. `run` and `bench` do not exist yet.

- Every command accepts `--json` and prints one single-line JSON object. The
  configuration file on disk stays YAML.
- Exit codes: `0` success, `1` unexpected failure, `2` invalid arguments or
  validation failure, `3` requested model not found.
- stdout carries command data; stderr carries diagnostics, warnings and usage
  errors.
- Command help includes the active `params.yaml` path, because the platform
  directory varies.
- Once `run` lands it must use the real engine and fail loudly. The CLI never
  silently falls back to a stub engine.

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

Analysis must be clean under `strict-casts`, `strict-inference`,
`strict-raw-types`, plus `always_declare_return_types`, `avoid_dynamic_calls`,
`directives_ordering`, `prefer_final_locals`, `unawaited_futures`,
`use_super_parameters`. Generated files are excluded. No `dynamic` in public
APIs, no `!` on nullable values, no empty `catch` blocks.

## 11. Testing

From the root, `dart run melos test`. Melos picks `flutter test` for the app and
`dart test` for core and CLI. Test the critical seams, not every line. Coverage
is not a target.

Must test today:

- YAML round-trip, quoting and double formatting.
- Repository fallbacks: missing file, malformed YAML, stale `schemaVersion`,
  invalid parameters.
- Scanner warnings and path resolution.
- CLI exit codes and `--json` shape.
- DI registration and the test overrides.
- Screen layout: wide and narrow windows, placeholder content.

Must test when they land:

- Worker protocol round-trip through the real isolate transport: load,
  streaming, completion, cancellation, `engineBusy`.
- `InferenceBloc` state machine, including terminal events and cancellation.

Tests mirror the package layout. Fakes live in `test/support/`. Never call
platform plugins; inject the dependency. No `pumpAndSettle` against
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

Roadmap in GitHub issues; current work in `TODO.md` (one line per item, newest
first, ~20 items), riding in the feature branch. Close an issue only after its
PR merges. Any change to architecture, pins or these rules updates `AGENT.md`
in the same PR.

## 14. Extending

Add a config parameter:
1. Add the field and default to `ModelParams` and its builder.
2. Update `copyWith` and the limits in `ModelParamLimits`/validator.
3. Add a serialization test for the default and a YAML round-trip.
4. Wire the CLI flag; add the form field when the editable UI lands.

Add an engine implementation: implement `LlamaEngine` in core (worker-side),
register it through `configureDependencies(engine: …)`, and add a fake in
`test/support/`. No annotations in core.

Add a feature slice: `domain/<feature>` and `data/<feature>` in core, plus
`presentation/<feature>` in the app; one gateway in domain, one bloc per screen,
no imports of another feature's data layer.

Post-MVP landing spots:

- Binary downloader: `data/downloads/` in an app layer plus a library locator
  strategy; the UI reaches it through a core gateway.
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
dart run melos run build:app
dart run melos run build:cli
dart run melos analyze
dart run melos test
dart run melos run format:check

# inside one package
dart format lib test
```

`dart run melos run check` runs gen, analyze, test, the format check and the CLI
build. The CLI executable is `llamapulse`; the desktop app binary is
`llama_pulse`. From the root, `dart run llama_pulse_cli:llamapulse …` also
works. `LLAMA_PULSE_LIB` points at a llama.cpp shared library in the future
FFI milestone. Never commit `.env` files, secrets or absolute local paths.

## 16. Definition of done for a change

- [ ] The workspace resolves with one lockfile (`flutter pub get` at the root).
- [ ] `dart run melos run check` is green.
- [ ] Layers respected; no Flutter imports in core, no `dart:ffi` on the UI
  isolate.
- [ ] Immutability rules from section 5 followed.
- [ ] YAML configuration round-trips (encoder/decoder tests cover the change).
- [ ] Codegen re-run and generated output committed.
- [ ] Tests added for the critical seam touched (or the gap justified).
- [ ] No new dependency without a one-line justification.
- [ ] `TODO.md`/issues updated.
- [ ] PR base matches the branch type.
