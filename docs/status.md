# Project status — 2026-11-03

A resume point for a fresh session. Facts below were measured on the commit
named here, not copied from memory. The rules live in `AGENT.md`; this file is
a snapshot and goes stale, so check `git branch -a`, `gh pr list` and
`gh issue list` before trusting it. Its GitHub mirror is the pinned issue #16.

- Baseline: `origin/main` = `aa35432` ("Merge pull request #31 from
  dip-develop/feature/chat-messages", 2026-11-03).
- Suite on `main`, measured 2026-11-03 in a clean checkout after
  `flutter pub get` and `melos run gen`: `melos test` exit `0`, **1172 tests** —
  791 core (plus 1 env-gated skip, `native_integration_test`), 233 CLI, 148 app.
  On Windows the same suites pass with 722 core tests run and 70 skipped (the C
  shim and native session tests need clang), plus 233 CLI and 148 app.
- `melos run check` and `flutter build linux --debug` are green on this commit,
  and the CI run for `aa35432` is green on every job.

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
  analyze, 1172 tests, format, CLI AOT), fails on generated-file drift, builds
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

- **GUI chat transcript.** Core and CLI accept a full conversation, but the
  app's chat screen still sends a single prompt. Next is a multi-turn
  transcript with a system prompt in `apps/llama_pulse`, wired to
  `GenerationRequest.messages`.
- **Packaging follow-ups (from #27).** Icons and artwork, installers and the
  Windows/macOS bundles stayed out of the v1 Linux bundle.

## Open issues (2026-11-03)

- #16 — pinned status checkpoint (this file mirrors it).
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

1. **GUI chat transcript**: the multi-turn conversation and system prompt,
   mirroring the CLI's `--system`/`--message`; core and CLI already render it
   (PR #31), the app still sends a single prompt.
2. **Packaging follow-ups** (from #27): icons and artwork, installers, and the
   Windows/macOS bundles.
3. **Chat templates beyond the built-ins**: Jinja and per-message template
   handling for the embedded path.
4. **Windows and macOS validation** of the supervisor and embedded paths.
5. **Larger models and GPU backends**: bigger context, CUDA/Vulkan/ROCm/Metal
   smoke tests.
6. **Watch the CI flake**: the supervisor test that failed once under parallel
   load now runs on every PR.
7. **Out of scope for now**: a server "router mode" (multi-model proxy).

## Open landmines

- **Known flake.** `llama_server_supervisor_test` — "stop during a launch
  before the spawn leaves no process" — failed once under parallel load and
  passed on rerun. The CI `test` job is where to watch it; do not paper over a
  real race.
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
gh pr list                     # the GUI chat PR, if one is open
gh issue list                  # only #16 (pinned status) is open
```

Then read `AGENT.md`, this file and pinned issue #16, and run
`dart run melos run check` on a fresh branch cut from `origin/main`. The next
concrete step is the GUI chat transcript, then the packaging follow-ups (icons,
installers, Windows/macOS bundles) and Windows/macOS validation. The pinned
checkpoint mirror is #16.
