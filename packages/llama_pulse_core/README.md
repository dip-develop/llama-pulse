# llama_pulse_core

Shared, Flutter-free core for LlamaPulse. This package owns:

- `built_value` entities: `ModelParams`, `GenerationRequest`,
  `GenerationMetrics`, `GenerationEvent`, `InferenceFailure`,
  `WorkerRequest`/`WorkerResponse` and `ModelFileInfo`, with their serializers.
- `ModelParamLimits` and `ModelParamsValidator`.
- Gateways: `LlamaEngine`, `LlamaSession`, `ModelParamsRepository`,
  `ModelScanner`, `ConfigStore`.
- The worker-isolate inference layer: `WorkerTransport`, `WorkerLlamaEngine`,
  `WorkerLoop`, `StubLlamaSession` and the `llamaWorkerMain` entrypoint.
- Use cases: `LoadModelParams`, `SaveModelParams`, `ListModels`,
  `InspectModel`.
- The YAML configuration layer: `AppPaths`, `YamlEncoder`, `YamlDecoder`,
  `YamlFileConfigStore`, `InMemoryConfigStore` and
  `YamlModelParamsRepository`.
- `ModelFileScanner` and `Utf8TokenAccumulator`.

It has no Flutter imports and no DI annotations. The import rules are enforced
by `test/architecture/core_imports_test.dart`. `dart:ffi` will be allowed here
because native code will only run inside the worker isolate; no FFI code exists
yet.

The public entrypoint is:

```dart
import 'package:llama_pulse_core/llama_pulse_core.dart';
```

## Inference engine

`WorkerLlamaEngine` implements `LlamaEngine` on top of one long-lived worker
isolate, spawned lazily on the first `load`, `unload` or `generate`. Requests
and responses are the `built_value` `WorkerRequest`/`WorkerResponse` DTOs; the
transport waits up to 10 s for the worker's `WorkerReady` handshake and surfaces
isolate errors and unexpected exits as failures.

Guarantees the worker loop provides:

- The worker isolate owns the `LlamaSession`; the caller never runs it.
- Cancellation is cooperative. A `cancel` request is checked between generation
  steps; `Isolate.kill` is never used during generation.
- Exactly one terminal event per request: `completed`, `cancelled` or `failed`.
- Token batches are coalesced and metrics arrive every 250 ms.
- Load failures throw `InferenceFailureException`; every other engine failure
  surfaces as an `InferenceFailure` value.

The native session is **not** included yet. The worker is hard-wired to
`StubLlamaSession`, which produces deterministic text and respects the token
cap. The native llama.cpp session will implement the same `LlamaSession`
interface and slot in without changing `LlamaEngine` or its callers.

## Configuration

Configuration is YAML. Both the CLI and the desktop app read and write the same
`params.yaml`; the app persists the form when you press Save:

```yaml
schemaVersion: 1
params:
  modelPath: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
  contextSize: 2048
  gpuLayers: 0
  threads: 4
  temperature: 0.8
  topP: 0.95
  topK: 40
  maxTokens: 256
```

The repository treats a missing, malformed or stale document as "use defaults"
and validates before writing.

## Usage

```dart
final store = InMemoryConfigStore();
final repository = YamlModelParamsRepository(
  store: store,
  serializers: serializers,
);
await repository.save(ModelParams.defaults().copyWith(threads: 8));
final loaded = await repository.load();
```

`InMemoryConfigStore` is for tests (including CLI tests). In the app, pass a
`YamlFileConfigStore` rooted at `AppPaths.resolve().configDirectory`.

## Status

`publish_to: none` for now; the package is versioned with the workspace and is
not published to pub.dev.
