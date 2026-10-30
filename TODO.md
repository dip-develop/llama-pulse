# TODO

- [x] Scaffold Flutter Linux app with pinned toolchain
- [x] Pin runtime and codegen dependencies and record resolved versions
- [x] Add community README, MIT license and refresh AGENT.md
- [ ] Domain: `ModelParams`, `GenerationRequest`, `GenerationMetrics`, `GenerationEvent`, `InferenceFailure`
- [ ] Data: serializers and `SharedPreferences`-backed parameter storage
- [ ] Data: `LlamaSession` gateway and `StubLlamaSession`
- [ ] Data: worker isolate protocol (load, generate, cancel, request ids)
- [ ] Presentation: `InferenceBloc` state machine with capped metrics history
- [ ] Presentation: inference screen with parameter form and metrics panel
- [ ] App: `get_it`/`injectable` wiring and bootstrap
- [ ] Test: worker protocol round-trip and storage fallback
- [ ] Next: `NativeLlamaSession` over `dart:ffi` with `LlamaLibraryLocator`
- [ ] Next: Windows and macOS platforms
- [ ] Next: desktop packaging and release artifacts
- [ ] Next: CI for analyze, test and Linux build
- [ ] Later: llama.cpp binary downloader and updater
- [ ] Later: Hugging Face CLI integration
- [ ] Later: model manager backed by `hive_ce`
