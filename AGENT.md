# LlamaPulse — Contributor and Agent Guide

## 1. Project

LlamaPulse is a minimal Flutter Desktop app (Linux/Windows/macOS) that runs
local LLMs through llama.cpp via `dart:ffi`: pick a model and a llama.cpp
library, tune the startup parameters, watch the run.

MVP:

- Visual startup-parameter configuration (model path, context size, threads,
  GPU layers, sampling).
- Live metrics: tokens/sec, prompt-eval time, generation speed.
- Cross-platform: Linux, Windows, macOS.
- All inference in isolates; the UI isolate never touches native code.

Out of scope for now: binary downloader/updater, Hugging Face CLI, model file
manager. The architecture leaves room for all three; section 11 says where.

LlamaPulse is developed and maintained by DIP Dev., which also holds the
copyright; the project is released under the MIT license (see `LICENSE`).

## 2. Stack (locked)

Flutter/Dart, Clean Architecture. Dart `>=3.13.0 <4.0.0`, Flutter `>=3.44`
(baseline: Flutter 3.47.7 / Dart 3.13.5). State: `flutter_bloc`. DI: `get_it` +
`injectable`. Light prefs: `shared_preferences` (`SharedPreferencesAsync`).
Structured storage when needed: `hive_ce`. Immutable models, state and
entities: `built_value` + `built_collections`.

Pins are deliberate; do not loosen them without reproducing the resolution:

| Package | Pin | Why |
|---|---|---|
| `built_value` | `8.13.0` | exact; generator and runtime move together |
| `built_collection` | `^5.1.2` | 6.x is incompatible with `built_value 8.13` |
| `build_runner` | `2.16.1` | exact; 2.17.x requires `build 5.x`, while `built_value_generator 8.13.0` declares `build <5.0.0` and `injectable_generator 3.1.3` declares `build ^4.0.4` |
| `built_value_generator` | `8.13.0` | exact; must match the `built_value` runtime |
| `injectable_generator` | `3.1.3` | exact; paired with `injectable ^3.0.0` |
| `get_it` | `^9.3.0` | DI container |
| `injectable` | `^3.0.0` | annotations and generated registrations |
| `flutter_bloc` | `^9.1.1` | presentation state management |
| `ffi` | `^2.2.0` | `Utf8`, `calloc`, native type helpers |
| `path` | `^1.9.1` | cross-platform paths |
| `file_selector` | `^1.1.0` | native model/library pickers |
| `hive_ce` | `^2.22.0` | structured local storage (post-MVP) |
| `flutter_lints`, `mocktail`, `bloc_test` (dev) | `^6.0.0`, `^1.0.5`, `^10.0.0` | lint, fakes, bloc tests |

Rules: no new dependency without a one-line justification in the PR that adds
it; `pubspec.lock` is committed.

## 3. Layout and dependency rule

```
lib/
  main.dart
  app/            bootstrap.dart, app.dart, di/, theme/
  core/           constants/, text/
  domain/inference/   models/, gateways/, repositories/, usecases/
  data/           inference/{models,ffi}, serialization/, storage/
  presentation/inference/  bloc/, screen, widgets/
```

Dependency rule:

- `presentation -> domain`
- `data -> domain`
- `app -> all`
- `core -> nothing` (no imports from other layers)
- `domain/` imports only `dart:` core libraries and `core/`. It must never
  import `package:flutter/*`, `dart:ffi`, `dart:io`, or any data-layer file.

Feature folders keep the same name in every layer: `inference` today,
`models`/`downloads` later. New code goes into its layer, never a new top-level
folder.

## 4. Immutability

`built_value` is mandatory for anything persisted, held in bloc state, or sent
across the isolate boundary: entities (`ModelParams`, `GenerationRequest`,
`GenerationMetrics`, `GenerationEvent`, `InferenceFailure`), the persisted
envelope, worker request/response DTOs, and `InferenceState`.

Lists in state are `BuiltList`, never growable `List`. Never mutate; never
expose a builder outside the file that owns the type.

Two deliberate exceptions, and only these:
1. The bloc event hierarchy and the internal `GenerationStep` are `sealed
   class` / plain record-like classes. They are commands and transient
   control-flow values: never serialized, never compared structurally.
2. `WorkerConfig` / `WorkerReady` hold `SendPort`, which `built_value` cannot
   serialize. Keep them minimal and construct them only in worker plumbing.

Adding a mutable field to state or an entity is a review blocker. If
`built_value` codegen hurts, fix the model; do not switch libraries.

## 5. FFI and isolates

- One long-lived worker isolate per engine, spawned lazily on the first
  `loadModel`. No engine state on the UI isolate.
- Never `dart:ffi` on the UI isolate — not even to probe a symbol.
- Symbols via `DynamicLibrary.open` + `lookupFunction`, never `@Native`; the
  app must start with no native library present.
- `NativeLlamaSession` and `StubLlamaSession` implement the `LlamaSession`
  gateway; the stub reports `engineUnavailable`.
- Protocol: `WorkerRequest`/`WorkerResponse`, monotonic `requestId`, exactly
  one terminal response per request, token batches coalesced every 16–33 ms,
  metrics every ~250 ms.
- Cancellation is cooperative: a `cancel` request checked between decode steps.
  Never `Isolate.kill` during generation — it leaks native memory.
- Failures cross the port as `InferenceFailure` values, never as thrown
  exceptions.
- UTF-8 is accumulated by `Utf8TokenAccumulator`, because
  `llama_token_to_piece` can split a code point across tokens.
- The library must build and run with no llama.cpp binary installed.

## 6. DI

`get_it` + `injectable`. One `getIt` in `lib/app/di/injection.dart`; generated
`injection.config.dart` is committed.

- Third-party types only via `@module` (`InfrastructureModule`).
- `LlamaEngine`, repositories and the storage store are
  `@LazySingleton(as: Interface)` with side-effect-free constructors.
- Use cases and blocs are `@injectable`.
- Constructor injection everywhere; `getIt` is read only in `main`/`bootstrap`
  and in a `BlocProvider`'s `create` — never inside `build`, callbacks, domain
  or data code.

Tests override registrations in `test/support/test_di.dart` (`getIt.reset()`,
then `unregister` + `registerSingleton`); no `@Environment('test')` in
production annotations.

## 7. Code style

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

## 8. Testing

Test the critical seams, not every line. Coverage is not a target.

Must test:

- Worker protocol round-trip through the real isolate transport: load,
  streaming, completion, cancellation, `engineBusy`.
- `SharedPreferencesModelParamsRepository` fallbacks: missing key, corrupt
  JSON, unknown schema version, storage failure.
- `InferenceBloc` state machine: load, generate, terminal events, metrics
  history capped at 100, failure.
- `ModelParams`/`GenerationMetrics` defaults and derived math.
- `LlamaLibraryLocator` path order.
- One widget smoke test per screen.

Tests mirror `lib/` under `test/`; fakes live in `test/support/`. Never
construct `SharedPreferencesAsync` in tests (it throws). Never call platform
plugins (`file_selector`) — inject the picker. No `pumpAndSettle` against
never-ending fake streams. Every PR touches tests or states why not.

## 9. Codegen

Run `dart run build_runner build --delete-conflicting-outputs`.

Every `built_value`/`EnumClass` file has `part '<file>.g.dart';` next to it.
Generated files (`.g.dart`, `.config.dart`) are committed and never edited by
hand. A change is not done until codegen is re-run and a second run leaves
`git status` clean.

`serializers.dart` uses `StandardJsonPlugin`. Persistence stores plain JSON
from the shared serializers — no `TypeAdapter`s, no freezed.

## 10. Git, issues and docs

`main` is production, `develop` is integration; both change only through PRs.
Branches: `feature/<topic>`, `bugfix/<topic>`, `chore/<topic>`,
`hotfix/<topic>`. The PR base must match the branch type (`hotfix/*` targets
`main`; everything else `develop`). Never commit to `main`/`develop`, never
merge, tag or force-push.

Commits are small, single-purpose, imperative:
`feat(inference): add worker transport`.

Roadmap in GitHub issues; current work in `TODO.md` (one line per item, newest
first, ~20 items), riding in the feature branch. Close an issue only after its
PR merges. Any change to architecture, pins or these rules updates `AGENT.md`
in the same PR.

## 11. Extending

Add a config parameter:
1. Add the field and default to `ModelParams` and its builder.
2. Update every `copyWith` caller that must carry the value.
3. Add the form field, wired to the bloc event.
4. Add a serialization test for default and round-trip.

Add an engine implementation: implement `LlamaEngine` in `data/`, register it
`@LazySingleton(as: LlamaEngine)`, re-run codegen, add a fake in `test/support/`.

Add a feature slice: `domain/<feature>` + `data/<feature>` +
`presentation/<feature>`; one repository interface in domain, one bloc per
screen, no imports of another feature's data layer.

Post-MVP landing spots:

- Binary downloader: `data/downloads/` plus a new `LlamaLibraryLocator`
  strategy; the UI reaches it through a domain gateway.
- Hugging Face / model manager: `data/models/` with `hive_ce` for metadata and
  JSON through the existing serializers.

Hard invariants for all future work: no `dart:ffi` on the UI isolate, and every
native failure surfaces as an `InferenceFailure`.

## 12. Commands

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

`LLAMA_PULSE_LIB` points at a llama.cpp shared library; without it the app runs
against `StubLlamaSession` and reports `engineUnavailable` cleanly. Never commit
`.env` files, secrets or absolute local paths.

## 13. Definition of done for a change

- [ ] Layers respected; no `dart:ffi`, Flutter or data imports in `domain/`.
- [ ] Immutability rules from section 4 followed.
- [ ] Codegen re-run and generated output committed.
- [ ] `dart format`, `flutter analyze`, `flutter test` green.
- [ ] Tests added for the critical seam touched (or the gap justified).
- [ ] No new dependency without a one-line justification.
- [ ] `TODO.md`/issues updated.
- [ ] PR base matches the branch type.
