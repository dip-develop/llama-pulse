# LlamaPulse — agent entry point

**This file is a pointer, not the manual.** The full contributor and agent
guide is [`AGENT.md`](AGENT.md); read it before changing anything. When
`AGENT.md` and this file disagree, `AGENT.md` wins and this file is fixed.

## Non-negotiables

- **Main-only repo.** There is no `develop` and none gets created. Branch from
  `origin/main` (`feature/`, `fix/`, `chore/`), open every PR with
  `--base main`, never push to `main`, never merge, tag, force-push or delete
  branches — the operator does those.
- **Work items are GitHub issues.** No `TODO.md`, no plan files. A multi-step
  plan gets one tracking issue whose steps are its checklist.
- **Configuration on disk is YAML** (`params.yaml`, `server.yaml`,
  `server-state.yaml`). JSON only for `--json` output, NDJSON and transport
  payloads.
- **`pubspec.lock` stays untracked.** One lockfile at the root; never commit a
  member lockfile.
- **Generated files are committed** (`*.g.dart`, `*.config.dart`) and never
  edited by hand. `melos run gen` twice must leave `git status` clean.
- **Before a PR:** `dart run melos run check` and
  `dart run melos run gen:catalog:check` are green.

## Quick commands (run from the repo root only)

```sh
flutter pub get                          # workspace resolve; never per package
dart run melos run gen                   # build_runner: core, then app
dart run melos run gen:catalog           # regenerate the llama.cpp parameter catalog
dart run melos run gen:catalog:check     # fail if the catalog drifted
dart run melos analyze                   # strict analysis, generated files excluded
dart run melos test                      # core + CLI + app suites
dart run melos run format:check
dart run melos run check                 # gen, catalog check, analyze, test, format, CLI build
dart run melos run app                   # desktop app with the real supervisor
dart run melos run app:stub              # synthetic embedded engine
dart run melos run app:stub-server       # synthetic server controller
dart run melos run build:cli             # native `llamapulse` executable
tool/build_llama_cpp.sh [tag]            # build the pinned shared library (v0.8.0)
```

The `gen:catalog*` scripts arrive with the parameter catalog (PR #14); on an
older checkout they do not exist yet.

## Where things live

- `packages/llama_pulse_core` — pure-Dart domain, data, YAML, native FFI layer.
  Flutter-free; enforced by an architecture test.
- `apps/llama_pulse` — Flutter desktop app: server dashboard (primary path) and
  the experimental Chat tab. The only place `package:flutter` is imported.
- `apps/llama_pulse_cli` — pure-Dart `llamapulse`: `serve`, `status`, `stop`,
  `logs`, `server`, `params`, `models`, `run`, `bench`.
- `docs/parameters.md` — the generated parameter catalog, its provenance and
  the regeneration/override policy.
- `docs/status.md` — current checkpoint: what shipped, what is in flight, what
  comes next, and the open landmines.
- `third_party/llama_cpp/v0.8.0/` — `PIN.md` (exact pin and checksums),
  `BUILD.md` (build recipe and real-model verification), `RUNTIME_ASSETS.md`
  (pinned prebuilt archives, on the runtime-downloader branch).

## Current status

Read [`docs/status.md`](docs/status.md) and the pinned checkpoint issue
[#16](https://github.com/dip-develop/llama-pulse/issues/16) before starting.
They carry the branch names, PR numbers and the ordered plan; `git branch -a`,
`gh pr list` and `gh issue list` show the live state.
