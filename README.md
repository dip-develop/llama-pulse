# LlamaPulse

A minimal desktop app for running local LLMs through llama.cpp.

Maintained by DIP Dev.

Status: alpha — foundation in progress.

## Why

- **Everything local.** No network calls, no telemetry, no account. Your
  prompts and model files never leave the machine.
- **Small and fast UI.** A narrow surface: parameters, output, metrics.
- **Full control over llama.cpp startup parameters.** Context size, GPU
  layers, threads and sampling are visible and editable, not hidden.
- **Cross-platform desktop.** Linux today; Windows and macOS are planned.

## What works today

- Window and inference screen shell.
- Parameter form persisted with `shared_preferences`.
- Metrics panel and token output wired to a deterministic stub engine.
- Worker-isolate protocol exercising load, generate and cancel.

The real llama.cpp session is the next milestone. Until it lands, the app
exercises the plumbing against `StubLlamaSession`.

## Requirements

- Flutter 3.47+ (Dart 3.13+).
- Linux desktop toolchain: clang, cmake, ninja, GTK 3 development headers.
- Windows and macOS: planned, not yet scaffolded.
- For the native milestone: a llama.cpp shared library
  (`libllama.so` / `llama.dll` / `libllama.dylib`).

## Quick start

```sh
git clone git@github.com:dip-develop/llama-pulse.git
cd llama-pulse
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d linux
```

Without a native library the app runs against the stub engine. Once the native
session lands, `LLAMA_PULSE_LIB=/absolute/path/to/libllama.so` points the app
at a real library.

## Architecture

Clean Architecture with one feature slice (`inference`). Entities and state
are immutable `built_value` types; all native work happens in a long-lived
worker isolate.

```
lib/
  app/            bootstrap, DI container, theme, root widget
  core/           constants and shared helpers
  domain/         inference entities, gateways, repositories, use cases
  data/           storage, serializers, FFI and worker plumbing
  presentation/   inference bloc, screen, widgets
```

Dependency rule: `presentation -> domain` and `data -> domain`. `app` may
import all of them; `domain` imports only `dart:` core libraries and `core/`.

Three invariants hold everywhere:

- No `dart:ffi` on the UI isolate.
- Persisted models and bloc state are immutable `built_value` values.
- Native failures surface as `InferenceFailure` values, never as exceptions
  thrown across the isolate port.

See [AGENT.md](AGENT.md) for the full rules.

## Configuration

| Parameter | Default | Notes |
|---|---|---|
| Model path | empty | absolute path to a GGUF file |
| Context size | 2048 | tokens |
| GPU layers | 0 | 0 keeps everything on the CPU |
| Threads | 4 | generation threads |
| Temperature | 0.8 | sampling |
| Top-p | 0.95 | nucleus sampling |
| Top-k | 40 | candidate cutoff |
| Max tokens | 256 | per generation |

These map directly to the corresponding llama.cpp knobs; nothing is renamed.

## Roadmap

MVP:

- [ ] Parameter UI
- [ ] Live tokens/sec and prompt-eval metrics
- [ ] Linux, Windows and macOS
- [ ] Isolate-confined inference

Planned after the MVP: llama.cpp binary downloader and updater, Hugging Face
CLI integration, model manager.

Work is tracked in GitHub issues; the current short list lives in
[TODO.md](TODO.md).

## Contributing

Read [AGENT.md](AGENT.md) first — it holds the architecture, immutability and
isolation rules that reviews check.

- Branch from `develop` as `feature/<topic>`, `bugfix/<topic>` or
  `chore/<topic>`; open the PR against `develop`.
- Keep PRs small and single-purpose. One concern per PR.
- Before pushing, run:

  ```sh
  dart format lib test
  flutter analyze
  flutter test
  ```

  Re-run `dart run build_runner build --delete-conflicting-outputs` after any
  `built_value` or `injectable` change, and commit the generated `.g.dart`
  and `.config.dart` files.
- Add tests for the seam you touched, or explain in the PR why not.
- Good first issues are labelled in the tracker.

## License

MIT — see [LICENSE](LICENSE). © 2026 DIP Dev.

## Acknowledgements

- [llama.cpp](https://github.com/ggml-org/llama.cpp) and
  [ggml](https://github.com/ggml-org/ggml) (MIT) for local inference.
- [Flutter](https://flutter.dev) for the desktop UI.
- [flutter_bloc](https://pub.dev/packages/flutter_bloc),
  [get_it](https://pub.dev/packages/get_it),
  [injectable](https://pub.dev/packages/injectable) and
  [built_value](https://pub.dev/packages/built_value).
