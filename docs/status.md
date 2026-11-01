# Project status — 2026-11-01

A resume point for a fresh session. Facts below were measured on the commit
named here, not copied from memory. The rules live in `AGENT.md`; this file is
a snapshot and goes stale, so check `git branch -a`, `gh pr list` and
`gh issue list` before trusting it. Its GitHub mirror is the pinned issue #16.

- Baseline: `origin/main` = `3d007c00e88ef3c52063faf9460d9a8a1fe6d091`
  ("Merge pull request #12 from dip-develop/feature/chat-template", 2026-11-01).
  Re-checked 2026-11-01: `origin/main` is unchanged, and this checkpoint branch
  (`chore/project-status-2`) is one docs commit on top of `f07d5a1`.
- Suite on `main`, re-measured 2026-11-01 in this worktree after
  `flutter pub get`: `melos test` exit `0`, **698 tests passed** — 474 core
  (plus 1 env-gated skip, `native_integration_test`), 136 CLI, 88 app. These are
  `main` numbers: `feature/runtime-downloader` has an extra core suite on top
  (~7.2k added lines) and its counts are higher.

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

## Open PRs (2026-11-01)

All three target `main` and are the operator's to merge.

- **#14** `feat(params): expose the full llama.cpp parameter catalog`
  (`feature/llamacpp-params`, `62703d2`).
- **#17** `docs: add AGENTS.md and a project status checkpoint`
  (`chore/project-status`, `f07d5a1`) — the branch this checkpoint updates.
- **#18** `fix(ci): create the CLI build directory before compiling`
  (`chore/build-cli-dir`, `9d1583b`) — `dart compile exe` does not create its
  output directory, so `melos run build:cli` (and therefore `melos run check`)
  fails on a fresh checkout where `apps/llama_pulse_cli/build/` does not exist.
  One-line `mkdir -p` in the Melos script.

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
  runtimes`). Three commits on top of `origin/main` (`3d007c0`), 38 files,
  ~7.2k added lines, confined to `packages/llama_pulse_core` plus
  `third_party/llama_cpp/v0.8.0/RUNTIME_ASSETS.md`; `apps/` is untouched.
  - `11ba022` — backend matrix and pinned assets: `RuntimeBackend`,
    `RuntimePlatform`, `RuntimeAsset`, `RuntimeRelease`, `RUNTIME_ASSETS.md`,
    tests (398 lines). Digests are the `b11960` nightly assets, which is the
    build the upstream `v0.8.0` tag names in `nightly-tag.txt`.
  - `523f38e` — hardware probe and installed-runtime store: `RuntimeProbe` /
    `DartRuntimeProbe` (arch, CPU count, memory, NVIDIA/ROCm/Metal detection),
    `RuntimeStore` / `YamlRuntimeStore`, `RuntimeManifest`, `RuntimeInstallRef`,
    `RuntimeRecommendation`, enum serializers, a runtime directory in
    `app_paths`.
  - `d57efec` — download, verify, extract: `RuntimeFetcher` /
    `HttpRuntimeFetcher` over `dart:io` `HttpClient` (redirects, no transparent
    gzip so checksums cover the wire bytes, ETag + `If-Range` resume, pause and
    cancellation), `RuntimeDownloader` (streaming SHA-256 against the pinned
    digest, cleanup of partial files on mismatch, free-space check at archive
    size × 2.5), `ArchiveExtractor` (streaming `.tar.gz` / `.zip`, strict path
    and entry validation), `RuntimeFailure`, `RuntimeInstallResult`.
  - Adds `crypto ^3.0.8` and `archive ^4.0.0` to core; regenerated serializers.
  - **Still missing:** resolver integration, i.e. the native session loading
    backends via `ggml_backend_load_all_from_path` (today it is only a
    declaration in the vendored `ggml-backend.h`); the gate relaxation to an
    attested `0.8.0-dev`; CLI `runtime list|install|remove`; the GUI Runtime
    tab; user docs. The issue #15 checklist is untouched, so it still shows
    step 1 as open.

## Decisions already made — do not relitigate

- Server-first product: LlamaPulse supervises `llama-server` and exposes an
  OpenAI-compatible endpoint; the embedded engine is the eventual default but
  stays experimental until then.
- Configuration is YAML only; JSON is only for `--json`, NDJSON and transport.
- The generated catalog is never hand-edited; it is regenerated from the
  vendored source and reviewed through the overrides file.
- The native gate accepts exactly `0.8.0`. Acceptance of an **attested**
  `0.8.0-dev` (official prebuilt `b11960` archives report `0.8.0-dev`) is
  **decided but not implemented** — no gate code has changed yet.
- Runtime v1 backend matrix: Linux x64 (cpu, cuda12, cuda13, vulkan, rocm);
  macOS arm64 (metal, which also carries a `cpu` alias); Windows x64 (cpu,
  cuda13, vulkan). Every asset for nightly `b11960` is pinned by SHA-256 in
  `runtime_release.dart` and mirrored in `RUNTIME_ASSETS.md`; nothing is looked
  up through a GitHub release API at install time.
- The CUDA runtime archive is a second, large download (440–594 MB on Linux)
  and is bundled only with explicit user consent.
- Runtime work takes `crypto` and `archive` as core dependencies; `cli_util` is
  a root `dependency_overrides` pin; `pubspec.lock` stays git-ignored.

## Remaining plan, in order

1. **Finish the runtime downloader** (issue #15). Download, verify and extract
   are done on `feature/runtime-downloader`; left: resolver integration plus
   `ggml_backend_load_all_from_path`, then the attested-`0.8.0-dev` gate
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
git branch -a                  # in-flight work: feature/runtime-downloader (local only)
gh pr list                     # open: #14 params, #17 status docs, #18 CLI build dir
gh issue list                  # pinned checkpoint #16, #13 params, #15 runtime
```

Then read `AGENT.md`, this file and pinned issue #16, and run
`dart run melos run check` on a fresh branch cut from `origin/main`. The open
parameter-catalog issue is #13, the runtime downloader issue is #15, and the
checkpoint mirror is #16. `docs/parameters.md` exists only after PR #14 merges.
The next concrete step is resolver integration on `feature/runtime-downloader`.
