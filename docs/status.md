# Project status — 2026-11-08

A resume point for a fresh session. Facts below were measured on the commit
named here, not copied from memory. The rules live in `AGENT.md`; this file is
a snapshot and goes stale, so check `git branch -a`, `gh pr list` and
`gh issue list` before trusting it. Its GitHub mirror is the pinned issue #16.

- Baseline: `origin/main` = `5f19cfe` ("Merge pull request #32 from
  dip-develop/chore/status-refresh-3", 2026-11-03), the merge base of the
  feature branch below.
- Suite on `feature/chat-transcript`, measured 2026-11-08 after `flutter pub
  get` and `melos run gen`: `melos test` exit `0`, **1199 tests** — 800 core
  (plus 1 env-gated skip, `native_integration_test`), 233 CLI, 166 app.
  The last Windows run (on `aa35432`) had 722 core tests run and 70 skipped (the
  C shim and native session tests need clang), plus 233 CLI and 148 app; this
  branch was not re-measured on Windows.
- `melos run check` (gen twice, catalog check, analyze, 1199 tests, format, CLI
  AOT) and `flutter build linux --debug` are green on this branch. The CI run
  for `5f19cfe`, its base, is green on every job.

## Shipped

- **Pub + Melos workspace.** One root `pubspec.yaml` is both the pub workspace
  root and the Melos 8 configuration (no `melos.yaml`); members are
  `packages/llama_pulse_core`, `apps/llama_pulse` and `apps/llama_pulse_cli`.
  One root `pubspec.lock`, untracked. `melos run check` = gen, catalog check,
  analyze, test, format check, CLI build.
- **Shared core.** Pure-Dart Clean Architecture: domain entities, gateways and
  use cases, `built_value` immutability, hand-written YAML codec, architecture
  test that keeps `package:flutter` out of core and `dart:ffi` inside
  `data/inference/native/`.
- **YAML configuration.** `params.yaml`, `server.yaml` (`schemaVersion: 1`) and
  `server-state.yaml`, each with a repository, atomic write, defaults fallback
  and round-trip tests. The runtime store adds `runtime/index.yaml` and
  `<tag>/<backend>/runtime.yaml`.
- **Server supervisor, dashboard and CLI.** `LlamaServerSupervisor` implements
  `ServerController`: validate, locate binary, spawn with an argv vector, wait
  for `/health`, enrich from `/props`, sample `/metrics` + `/slots`, graceful
  `SIGTERM` then force after 5 s, `server-state.yaml` as the cross-process
  contract, 1000-line ring plus `server.log` rotation at 1 MiB, API-key
  redaction, no auto-restart. CLI: `serve`, `status`, `stop`, `logs`, `server
  get|set`, all with `--json`; app: editable `server.yaml` form, lifecycle card,
  endpoint with Copy/Test connection, live metrics, log tail, external-run
  detection.
- **Native embedded engine.** Vendored `v0.8.0` headers under
  `third_party/llama_cpp/v0.8.0/` (`PIN.md`, `SHA256SUMS`, `abi_check.c`),
  hand-written bindings with no FFI codegen, an ABI/width test that compiles
  `abi_check.c` with clang, generation with prefill/truncation/sampler
  chain/cooperative cancel/metrics, chat templates (built-in, named, `none`,
  `--[no-]use-chat-template`), all inside one long-lived worker isolate. The
  gate accepts `0.8.0`, or `0.8.0-dev` only with a runtime manifest that
  attests the pin.
- **Parameter catalog (PR #14).** Generated from the vendored `common/arg.cpp`:
  362 parameters in 12 groups (210 configurable, 14 managed, 132 unsupported,
  6 removed). `docs/parameters.md` records provenance and override policy;
  `gen:catalog` / `gen:catalog:check` run in `check`; CLI `params
  catalog|describe|export` and `--param`; grouped, searchable GUI panels.
- **Managed runtimes (PR #21, issue #15).** Pinned `v0.8.0` = `b11960` assets
  with SHA-256s (`third_party/llama_cpp/v0.8.0/RUNTIME_ASSETS.md`), a hardware
  probe with a recommendation, a streaming download → checksum → safe-extract
  pipeline, a YAML runtime store with atomic commit, resolver integration in
  both locators (selected runtime first, then newest), `llama-server` spawned
  from its runtime directory with loader variables prefixed and
  `GGML_BACKEND_PATH` set, `ggml_backend_load_all_from_path` before
  `llama_backend_init`, the attested-`0.8.0-dev` gate, CLI `runtime
  list|status|install|select|remove` (exit codes `0/1/2/3/4/5/130`), the GUI
  Runtime tab and dashboard card, and `docs/runtime.md`.
- **Real-model verification.** 2026-11-01, upstream `v0.8.0` CPU build (ggml
  `0.28.0`, 64-bit Linux, 6 cores) with a 12B-A2.5B Q8_0 MoE model (12.04 GiB,
  context 512, two threads): integration test passed in ~5.5 s including a
  reload at 12.8 GB peak RSS; CLI `run` generated 16 tokens at 19.4 tok/s on
  the first run and 23.9–24.3 tok/s on repeats. CPU only, no GPU backend.
- **CI (PR #24, Windows suites in PR #29).** `.github/workflows/ci.yml`: a
  Linux `Workspace gate` job runs `melos run check` (gen, catalog drift,
  analyze, 1199 tests, format, CLI AOT), fails on generated-file drift, builds
  the Linux desktop app and smoke-tests the packaging script; a `test` matrix
  runs analyze and the suites on Ubuntu, macOS and Windows (the C-shim and
  native-session tests skip where clang or a native library is missing), and a
  standalone Windows job only compiles the CLI. Flutter is pinned to `3.47.7`,
  superseded runs on the same ref are cancelled and the workflow is read-only.
- **`stop --json` accuracy (PR #26).** A stop that ends without a kill reports
  `forced: false`; the command re-reads the state document before escalating
  and only forces when it still records a live run.
- **Linux bundle (PR #28, issue #27).** A relocatable bundle from
  `tool/package_linux.sh`, with an optional managed runtime copied to
  `<bundle>/runtime/<tag>/<backend>/`; both locators resolve that directory
  after a user-selected runtime and before `<config>/bin`/`lib` and `PATH`.
  `docs/packaging.md` records the layout and resolution order; the CI gate
  smoke-tests the script.
- **Multi-message chat prompts (PR #31, issue #30).** `ChatMessage`,
  `GenerationRequest.messages` and `WorkerRequest` carry a conversation; the
  native session renders every message through `llama_chat_apply_template`,
  and a single user message keeps the old raw-prompt fallback. CLI `run` gained
  `--system` and repeatable `--message role:content`.
- **Build helper.** `tool/build_llama_cpp.sh [tag]` (default `v0.8.0`) clones,
  configures with `-DBUILD_SHARED_LIBS=ON -DLLAMA_BUILD_IS_DEV=OFF
  -DLLAMA_BUILD_APP=OFF -DGGML_NATIVE=ON`, builds and prints the
  `LLAMA_PULSE_LIB` / `LD_LIBRARY_PATH` exports. `BUILD.md` records the recipe.
  `melos run build:cli` goes through `apps/llama_pulse_cli/tool/build_cli.dart`,
  so it works in PowerShell and writes `llamapulse.exe` on Windows.

## In flight

- **Chat transcript and stored system prompt (issue #33, PR #34).** Branch
  `feature/chat-transcript` carries the GUI transcript, the clear action and
  the stored system prompt; it is waiting for review and merge; it is not on
  `main`. `ModelParams.systemPrompt` is a nullable field with the `copyWith`
  `_unset` sentinel, a 4096-character limit and a validator that rejects blank
  or over-limit values and accepts multi-line text; it is persisted in
  `params.yaml` and omitted when null, so the schema version stays `1` and
  `params_golden.yaml` is untouched. The Chat tab keeps completed turns in
  `InferenceState.transcript` (never a `system` message) and sends
  `[system?, …transcript, user]`; the user turn is appended only after
  validation, and every terminal path folds the streamed draft into an
  assistant reply, so a cancelled or failed turn keeps its partial text.
  `ConversationView` (replacing `GenerationOutput`) renders role-labelled
  bubbles, the in-flight draft, an empty state and a Clear conversation action
  that is a no-op while a turn is running; the form gained a `system-prompt`
  field saved by the existing Save action, blank meaning null.
- **Packaging follow-ups (from #27).** Icons and artwork, installers and the
  Windows/macOS bundles stayed out of the v1 Linux bundle.

## Open issues (2026-11-08)

- #16 — pinned status checkpoint (this file mirrors it).
- #33 — chat transcript and stored system prompt; open, implemented on branch
  `feature/chat-transcript` (PR #34).
- #27 (packaging), #25 (stop `--json`), #23 (Windows test portability), #22
  (CI), #15 (runtime) and #13 (catalog) are closed; #28 (Linux bundle), #29
  (Windows suites) and #31 (multi-message prompts) are merged.

## Decisions already made — do not relitigate

- Server-first product: LlamaPulse supervises `llama-server` and exposes an
  OpenAI-compatible endpoint; the embedded engine is the eventual default but
  stays experimental until then.
- Configuration is YAML only; JSON is only for `--json`, NDJSON and transport.
- The generated catalog is never hand-edited; it is regenerated from the
  vendored source and reviewed through the overrides file.
- The native gate accepts exactly `0.8.0`, plus `0.8.0-dev` **only** with a
  manifest that attests tag `v0.8.0`, build `b11960`, the pinned commit and the
  pinned archive name/SHA-256/size. It is implemented and tested; do not widen
  it further, and do not accept a bare `0.8.0-dev`.
- Runtime v1 backend matrix: Linux x64 (cpu, cuda12, cuda13, vulkan, rocm);
  macOS arm64 (metal, which also carries a `cpu` alias); Windows x64 (cpu,
  cuda13, vulkan). Every asset for nightly `b11960` is pinned by SHA-256 in
  `runtime_release.dart` and mirrored in `RUNTIME_ASSETS.md`; nothing is looked
  up through a GitHub release API at install time.
- The CUDA runtime archive is a second, large download (440–594 MB on Linux)
  and is bundled only with explicit user consent.
- Runtime work takes `crypto` and `archive` as core dependencies; the CLI takes
  `crypto` and `path` as dev dependencies for its archive fixtures.
- CI pins Flutter `3.47.7` (the baseline in `AGENT.md`), not `stable`.

## Remaining plan, in order

1. **Land the chat transcript PR** (issue #33), then the **packaging
   follow-ups** (from #27): icons and artwork, installers, and the Windows/macOS
   bundles.
2. **Jinja chat templates** for the embedded path: the built-in, named, `none`
   and per-message rendering already ship (PR #31, issue #33); a Jinja engine
   is the remaining template work.
3. **Windows and macOS validation** of the supervisor and embedded paths.
4. **Larger models and GPU backends**: bigger context, CUDA/Vulkan/ROCm/Metal
   smoke tests.
5. **Watch the CI flake**: the supervisor test that failed once under parallel
   load now runs on every PR.
6. **Out of scope for now**: a server "router mode" (multi-model proxy).

## Open landmines

- **Known flake.** `llama_server_supervisor_test` — "stop during a launch
  before the spawn leaves no process" — failed once under parallel load and
  passed on rerun. The CI `test` job is where to watch it; do not paper over a
  real race.
- `params.yaml`'s `systemPrompt` is the Chat tab's default only; the CLI's
  `run` keeps its per-run `--system` and does not read the stored value.
- A chat turn that fails before producing text stays in the transcript with no
  assistant reply. "Clear conversation" is the escape hatch; it is disabled
  while a turn is running, and clearing never deletes the stored system prompt.
- `/opt/llama.cpp-rocm` is an Unsloth fork reporting `0.7.0-dev`; the gate
  rejects it. That is the gate working, not a bug.
- Without `LD_LIBRARY_PATH` (or the sibling `libggml*` preload) the loader can
  pick an unrelated `libggml.so.0`, e.g. from `/opt`; a compiled CLI needs the
  export even when `LLAMA_PULSE_LIB` is set. Managed runtimes prefix it for
  their child.
- The server path sends raw prompts: `llama-server` never receives a chat
  template; templating exists only in the embedded session.
- On Windows the core suite skips the C-shim/ABI and native-session tests when
  clang and a native library are absent (722 run, 70 skip), so a green Windows
  run says less than a green Linux one.
- `pubspec.lock` is untracked, so CI resolves newer transitive versions than a
  long-lived local checkout. The first CI run surfaced exactly that: `archive
  4.6.0` accepted a garbage payload that 4.5.2 rejected, and the installer now
  verifies the unpacked payload itself. Treat a green local run as necessary,
  not sufficient.
- 64-bit desktop only — structs cross FFI by value.
- One embedded engine per process: `llama_backend_init` is global and there is
  no `dlclose` in `dart:ffi`.

## How to resume

```sh
git fetch origin
git branch -a                  # merged feature/fix branches may linger locally
gh pr list                     # the open chat transcript PR, if any
gh issue list                  # #16 (pinned status) and #33 (chat transcript)
```

Then read `AGENT.md`, this file and pinned issue #16, and run
`dart run melos run check` on a fresh branch cut from `origin/main`. The next
concrete step is the packaging follow-ups (icons, installers, Windows/macOS
bundles), Jinja templates and Windows/macOS validation, after the chat
transcript PR merges. The pinned checkpoint mirror is #16.
