# Project status — 2026-11-02

A resume point for a fresh session. Facts below were measured on the commit
named here, not copied from memory. The rules live in `AGENT.md`; this file is
a snapshot and goes stale, so check `git branch -a`, `gh pr list` and
`gh issue list` before trusting it. Its GitHub mirror is the pinned issue #16.

- Baseline: `origin/main` = `1f03e04` ("Merge pull request #21 from
  dip-develop/feature/runtime-downloader", 2026-11-02).
- Suite on `main`, measured 2026-11-02 in a clean checkout after
  `flutter pub get` and `melos run gen`: `melos test` exit `0`, **1143 tests** —
  770 core (plus 1 env-gated skip, `native_integration_test`), 225 CLI, 148 app.
- `melos run check` and `flutter build linux --debug` are green on this commit.

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
- **Build helper.** `tool/build_llama_cpp.sh [tag]` (default `v0.8.0`) clones,
  configures with `-DBUILD_SHARED_LIBS=ON -DLLAMA_BUILD_IS_DEV=OFF
  -DLLAMA_BUILD_APP=OFF -DGGML_NATIVE=ON`, builds and prints the
  `LLAMA_PULSE_LIB` / `LD_LIBRARY_PATH` exports. `BUILD.md` records the recipe.

## In flight

- **CI (issue #22).** `.github/workflows/ci.yml`: a Linux gate job
  (`melos run check`, generated-files-clean check, `flutter build linux
  --debug`), a `test` matrix on `ubuntu-latest` and `macos-latest`, and a
  Windows job that analyzes and compiles the CLI. Windows tests are blocked on
  issue #23 (POSIX assumptions in the test suite).

## Open issues (2026-11-02)

- #22 — CI: run the workspace gate on GitHub Actions (in flight).
- #23 — test: make the workspace suites portable to Windows.
- #16 — pinned status checkpoint (this file mirrors it).
- #15 (runtime) and #13 (catalog) are closed.

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

1. **CI** (issue #22): land the workflow, then watch the known supervisor flake
   on a few runs before trusting the suite under parallel load.
2. **Packaging and bundling**: ship the app with a managed runtime directory,
   icons, installers.
3. **Windows and macOS validation** of the supervisor and embedded paths, plus
   issue #23 (test portability) so Windows joins the test matrix.
4. **Per-message and Jinja chat templates** (embedded path currently renders a
   single user message).
5. **Larger models and GPU backends**: bigger context, CUDA/Vulkan/ROCm/Metal
   smoke tests.
6. **Small fix**: `stop --json` reports `forced` even when the stop was
   graceful — nit, not yet fixed.
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
- `melos run build:cli` creates its output directory with `mkdir -p`, which is
  not valid PowerShell. Local Windows builds use Git Bash or the direct
  `dart compile exe` command; the CI Windows job does the latter.
- The workspace suites are not yet Windows-clean (POSIX mode bits, `chmod`
  fixtures, symlinks): see issue #23.
- 64-bit desktop only — structs cross FFI by value.
- One embedded engine per process: `llama_backend_init` is global and there is
  no `dlclose` in `dart:ffi`.

## How to resume

```sh
git fetch origin
git branch -a                  # in-flight: chore/ci (CI workflow + this refresh)
gh pr list                     # the CI PR, if it is still open
gh issue list                  # #22 CI, #23 Windows tests, #16 pinned
```

Then read `AGENT.md`, this file and pinned issue #16, and run
`dart run melos run check` on a fresh branch cut from `origin/main`. The next
concrete step after CI is packaging: a managed runtime directory, icons and
installers. The pinned checkpoint mirror is #16.
