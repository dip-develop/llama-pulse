# llamapulse CLI

A small command-line companion to the LlamaPulse desktop app. It reads and
writes the same `params.yaml` the app uses and lists the `.gguf` files in the
local models directory. Inference is not part of the CLI yet: `run` and `bench`
arrive together with the worker engine.

Run it from source with `dart run bin/llamapulse.dart <command>` or build a
native executable with `dart compile exe bin/llamapulse.dart`.

## Commands

### `version`

```
$ llamapulse version
llamapulse 0.1.0
```

### `params get`

Print the stored parameters as the exact YAML document the app persists. The
output can be redirected straight into the config file:

```
$ llamapulse params get
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

### `params set`

Update one or more fields and write the document. Values are validated against
the same limits the app uses; an invalid value exits with code 2 and leaves the
file untouched.

```
$ llamapulse params set --context-size 4096 --temperature 0.5
$ llamapulse params set --model-path "/models/my model.gguf"
$ llamapulse params set --reset
```

Options: `--model-path`, `--context-size`, `--gpu-layers`, `--threads`,
`--temperature`, `--top-p`, `--top-k`, `--max-tokens`, `--reset`. `--reset`
cannot be combined with another parameter option.

### `models list`

List `.gguf` files in the models directory, or in the directories passed with
the repeatable `--dir` option.

```
$ llamapulse models list
llama-3.2-3b-instruct.Q4_K_M.gguf  1918.42  /home/me/.config/llamapulse/models/llama-3.2-3b-instruct.Q4_K_M.gguf
```

Directories that cannot be read produce a warning on stderr; the command still
exits with code 0.

### `models inspect`

Print metadata for one model file.

```
$ llamapulse models inspect /models/llama-3.2-3b-instruct.Q4_K_M.gguf
path: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
fileName: llama-3.2-3b-instruct.Q4_K_M.gguf
sizeMiB: 1918.42
modified: 2026-10-30T12:00:00.000Z
```

## `--json`

Every command accepts `--json` and prints a single-line JSON object instead of
human-readable text. The YAML document used by `params get` and `params set`
stays YAML on disk; `--json` only changes the presentation.

```
$ llamapulse version --json
{"name":"llama_pulse_cli","version":"0.1.0"}
```

## Configuration paths

`params.yaml` lives in the configuration directory; `models/` is its default
model directory.

| Platform | Directory |
|---|---|
| Linux | `$XDG_CONFIG_HOME/llamapulse`, else `~/.config/llamapulse` |
| macOS | `~/Library/Application Support/LlamaPulse` |
| Windows | `%APPDATA%\LlamaPulse` |

Set `LLAMA_PULSE_CONFIG_DIR` to an absolute path to override the platform
location.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Unexpected failure |
| 2 | Invalid arguments or parameters that failed validation |
| 3 | The requested model file was not found |

## Help

```
$ llamapulse --help
$ llamapulse params --help
$ llamapulse params set --help
```
