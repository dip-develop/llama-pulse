# llama_pulse_core

Shared, Flutter-free core for LlamaPulse. This package owns:

- `built_value` entities: `ModelParams`, `GenerationRequest`,
  `GenerationMetrics`, `GenerationEvent`, `InferenceFailure` and
  `ModelFileInfo`, with their serializers.
- `ModelParamLimits` and `ModelParamsValidator`.
- Gateways: `LlamaEngine`, `ModelParamsRepository`, `ModelScanner`,
  `ConfigStore`.
- Use cases: `LoadModelParams`, `SaveModelParams`, `ListModels`,
  `InspectModel`.
- The YAML configuration layer: `AppPaths`, `YamlEncoder`, `YamlDecoder`,
  `YamlFileConfigStore`, `InMemoryConfigStore` and
  `YamlModelParamsRepository`.
- `ModelFileScanner` and `Utf8TokenAccumulator`.

It has no Flutter imports and no DI annotations. The import rules are enforced
by `test/architecture/core_imports_test.dart`. `dart:ffi` is allowed here
because the native bridge will only run inside the worker isolate.

The public entrypoint is:

```dart
import 'package:llama_pulse_core/llama_pulse_core.dart';
```

## Configuration

Configuration is YAML. `params.yaml` is shared by the desktop app and the CLI:

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

`InMemoryConfigStore` is useful in tests and the CLI. In the app, pass a
`YamlFileConfigStore` rooted at `AppPaths.resolve().configDirectory`.

## Status

`publish_to: none` for now; the package is versioned with the workspace and is
not published to pub.dev.
