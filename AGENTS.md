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
- **CI runs on every PR.** `.github/workflows/ci.yml` runs the workspace gate
  and a Linux desktop build, the suites on Linux, macOS and Windows, and a
  standalone Windows job that only compiles the CLI (no analyze). A red run
  blocks the PR.

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
tool/package_linux.sh [--runtime <tag> <backend>]  # Linux app bundle in dist/
```

## Where things live

- `packages/llama_pulse_core` — pure-Dart domain, data, YAML, native FFI layer.
  Flutter-free; enforced by an architecture test.
- `apps/llama_pulse` — Flutter desktop app: server dashboard (primary path) and
  the experimental Chat tab. The only place `package:flutter` is imported.
- `apps/llama_pulse_cli` — pure-Dart `llamapulse`: `serve`, `status`, `stop`,
  `logs`, `server`, `runtime`, `params`, `models`, `run`, `bench`.
- `docs/parameters.md` — the generated parameter catalog, its provenance and
  the regeneration/override policy. `docs/runtime.md` — managed runtimes, the
  resolution order, backend loading and the version gate. `docs/packaging.md` —
  the Linux bundle and bundled-runtime resolution. `docs/status.md` — the
  current checkpoint.
- `third_party/llama_cpp/v0.8.0/` — `PIN.md` (exact pin and checksums),
  `BUILD.md` (build recipe and real-model verification) and `RUNTIME_ASSETS.md`
  (the pinned prebuilt archives).

## Resume here

A new session needs four things before it changes anything:

1. Read [`docs/status.md`](docs/status.md) and pinned issue
   [#16](https://github.com/dip-develop/llama-pulse/issues/16): shipped, in
   flight, next and landmines — the issue mirrors this file.
2. `gh pr list` and `gh issue list` — the live queue; `docs/status.md` records
   the state at the last checkpoint.
3. `git branch -a` — in-flight work is listed in `docs/status.md`; merged
   feature branches may still exist locally, and only the operator deletes
   them.
4. Packaging v1 (Linux bundle, PR #28), Windows test portability (PR #29) and
   multi-message prompts in core and the CLI (PR #31) have shipped. The next
   steps are the GUI chat transcript and the packaging follow-ups (icons,
   installers, Windows/macOS bundles).

Rules for this repo: never merge, tag, force-push or delete branches — the
operator does those, and no PR goes to anything but `main`. Before opening a
PR, `dart run melos run check` must be green.
