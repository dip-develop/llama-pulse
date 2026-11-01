# Project status — 2026-11-01

A resume point for a fresh session. Facts below were measured on the commit
named here, not copied from memory. The rules live in `AGENT.md`; this file is
a snapshot and goes stale, so check `git branch -a`, `gh pr list` and
`gh issue list` before trusting it. Its GitHub mirror is the pinned issue #16.

- Baseline: `origin/main` = `3d007c00e88ef3c52063faf9460d9a8a1fe6d091`
  ("Merge pull request #12 from dip-develop/feature/chat-template", 2026-11-01).
- Suite on that commit, from a clean worktree: `melos test` exit `0`, **698
  tests passed** — 474 core (plus 1 env-gated skip, `native_integration_test`),
  136 CLI, 88 app.

## Shipped

- **Pub + Melos workspace.** One root `pubspec.yaml` is both the pub workspace
  root and the Melos 8 configuration (no `melos.yaml`); members are
  `packages/llama_pulse_core`, `apps/llama_pulse`, `apps/llama_pulse_cli`. One
  root `pubspec.lock`, untracked. `melos run check` = gen, analyze, test,
  format check, CLI build.
- **Shared core.** Pure-Dart Clean Architecture: domain entities, gateways and
  use cases, `built_value` immutability, hand-written YAML codec, architecture
  test that keeps `package:flutter` out of core and `dart:ffi` inside
  `data/inference/native/`.
- **YAML configuration.** `params.yaml`, `server.yaml` (`schemaVersion: 1`) and
  `server-state.yaml`, each with a repository, atomic write, defaults fallback
  and round-trip tests.
- **Server supervisor, dashboard and CLI.** `LlamaServerSupervisor` implements
  `ServerController`: validate, locate binary, spawn with an argv vector, wait
  for `/health`, enrich from `/props`, sample `/metrics` + `/slots`, graceful
  `SIGTERM` then force after 5 s, `server-state.yaml` as the cross-process
  contract, 1000-line ring plus `server.log` rotation at 1 MiB, API-key
  redaction, no auto-restart. CLI: `serve`, `status`, `stop`, `logs`, `server
  get|set`, all with `--json` and exit codes `0/1/2/3/130`. App: editable
  `server.yaml` form, lifecycle card, endpoint with Copy/Test connection, live
  metrics, log tail, external-run detection.
- **Native embedded engine.** Vendored `v0.8.0` headers under
  `third_party/llama_cpp/v0.8.0/` (`PIN.md`, `SHA256SUMS`, `abi_check.c`),
  hand-written bindings with no FFI codegen, an ABI/width test that compiles
  `abi_check.c` with clang, an exact `0.8.0` version gate, generation with
  prefill/truncation/sampler chain/cooperative cancel/metrics, chat templates
  (built-in, named, `none`, `--[no-]use-chat-template`), all inside one
  long-lived worker isolate.
- **Parameter catalog** — complete on `feature/llamacpp-params`, in review as
  PR #14, **not on `main` yet**. Generated from vendored `common/arg.cpp`:
  362 parameters in 12 groups (210 configurable, 14 managed, 132 unsupported,
  6 removed); CLI `params catalog|describe|export` and `--param`; grouped,
  searchable GUI panels; `docs/parameters.md`; `gen:catalog` /
  `gen:catalog:check` Melos scripts.
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

- **PR #14 — `feat(params): expose the full llama.cpp parameter catalog`.**
  OPEN, `MERGEABLE`, base `main`, head `origin/feature/llamacpp-params`
  (`62703d2`), 10 commits. Tracking issue #13 (steps 2–10 still unticked in the
  issue text even though the branch implements most of them). Touches ~100
  files: catalog generation and overrides, `ParameterCatalog.v080`,
  `server.yaml`/`params.yaml` catalog values, both argument builders, CLI
  `params catalog|describe|export` and `--param`, GUI panels,
  `docs/parameters.md`, an `AGENT.md` rewrite and the `gen:catalog` scripts.
  Wait for the operator to merge before branching anything that needs the
  catalog.
- **`feature/runtime-downloader` — local branch only, not pushed, no PR.**
  Tracking issue #15 (`feat(runtime): download and manage pinned llama.cpp
  runtimes`). Progress: one commit, `11ba022` "feat(runtime): add the backend
  matrix and pinned release assets" — `RuntimeBackend`, `RuntimePlatform`,
  `RuntimeAsset`, `RuntimeRelease`, their tests (398 lines) and
  `third_party/llama_cpp/v0.8.0/RUNTIME_ASSETS.md`; adds `crypto ^3.0.8` and
  `archive ^4.0.0` to core. Issue step 1 is done; the issue checklist has not
  been ticked. **In-progress step: the downloader and extractor** (HTTP fetch,
  streaming SHA-256 verification against the pinned digest, archive unpack,
  partial-file cleanup on mismatch, free-space check at archive size × 2.5).

## Decisions already made — do not relitigate

- Server-first product: LlamaPulse supervises `llama-server` and exposes an
  OpenAI-compatible endpoint; the embedded engine is the eventual default but
  stays experimental until then.
- Configuration is YAML only; JSON is only for `--json`, NDJSON and transport.
- The generated catalog is never hand-edited; it is regenerated from the
  vendored source and reviewed through the overrides file.
- The native gate accepts exactly `0.8.0`. A **planned** additional acceptance
  of an attested `0.8.0-dev` covers the official prebuilt `b11960` archives,
  which report `0.8.0-dev`.
- Runtime v1 backend matrix: Linux x64 (cpu, cuda12, cuda13, vulkan, rocm);
  macOS arm64 (metal, which also carries cpu); Windows x64 (cpu, cuda13,
  vulkan). Digests are pinned in `runtime_release.dart`, never looked up at
  install time.
- The CUDA runtime archive is a second, large download (440–594 MB on Linux)
  and is only fetched with explicit user consent.
- Runtime work takes `crypto` and `archive` as core dependencies; `cli_util` is
  a root `dependency_overrides` pin; `pubspec.lock` stays git-ignored.

## Remaining plan, in order

1. **Finish the runtime downloader** (issue #15): downloader/extractor, then
   resolver integration plus `ggml_backend_load_all_from_path`, then the gate
   relaxation, then CLI `runtime` (list/install/remove), then the GUI Runtime
   tab, then docs.
2. **CI**: GitHub Actions — catalog/gen drift, `dart analyze`, tests on three
   platforms, a Linux desktop build, and the CLI AOT build.
3. **Packaging and bundling**: ship the app with a managed runtime directory,
   icons, installers.
4. **Per-message and Jinja chat templates** (embedded path currently renders a
   single user message).
5. **Windows and macOS validation** of supervisor and embedded paths.
6. **Larger models and GPU backends**: bigger context, CUDA/Vulkan/ROCm/Metal
   smoke tests.
7. **Small fix**: `stop --json` reports `forced` even when the stop was
   graceful — nit, not yet fixed.
8. **Out of scope for now**: a server "router mode" (multi-model proxy).

## Open landmines

- `/opt/llama.cpp-rocm` is an Unsloth fork reporting `0.7.0-dev`; the gate
  rejects it. That is the gate working, not a bug.
- Official prebuilt archives report `0.8.0-dev`, so the exact `0.8.0` gate
  rejects every downloaded runtime until the attested acceptance lands.
- Without `LD_LIBRARY_PATH` (or the sibling `libggml*` preload) the loader can
  pick an unrelated `libggml.so.0`, e.g. from `/opt`; the compiled CLI needs
  the export even when `LLAMA_PULSE_LIB` is set.
- The server path has no chat template: `llama-server` receives the raw prompt
  LlamaPulse builds. Templating exists only in the embedded session.
- 64-bit desktop only — structs cross FFI by value.
- One embedded engine per process: `llama_backend_init` is global and there is
  no `dlclose` in `dart:ffi`.

## How to resume

```sh
git fetch origin
git branch -a                  # local work: feature/runtime-downloader
gh pr list                     # PR #14 open
gh issue list                  # #13 params, #15 runtime
```

Then read `AGENT.md`, `docs/parameters.md` (after PR #14 merges), this file, and
run `dart run melos run check` on a fresh branch cut from `origin/main`. The
open parameter-catalog issue is #13, the runtime downloader issue is #15.
