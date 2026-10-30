# llamapulse CLI

A small command-line companion to the LlamaPulse desktop app. It reads and
writes the same `params.yaml` the desktop app uses and lists the `.gguf` files
in the local models directory. `run` and `bench` generate text against the
deterministic `StubLlamaSession` when `--stub` is passed; `--stub` selects it
explicitly and is not a fallback. The native llama.cpp session is the next
milestone, and until it lands both commands require `--stub`.

Run it from source with `dart run bin/llamapulse.dart <command>` or build a
native executable with `dart compile exe bin/llamapulse.dart`. From the
repository root, `dart run llama_pulse_cli:llamapulse <command>` also works, and
`dart run melos run build:cli` writes `build/llamapulse`.

## Commands

### `version`

```
$ llamapulse version
llamapulse 0.1.0
```

### `params get`

Print the stored parameters as the exact document the repository writes. The
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
the same limits the shared validator enforces; an invalid value exits with code
2 and leaves the file untouched.

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

### `run`

Generate one prompt. The native engine is not implemented yet, so `--stub` is
mandatory: it selects the deterministic stub session inside the worker. Without
it the command exits 1 with
`error: engineUnavailable: the native session is unavailable; pass --stub` and
never falls back silently. In stub mode the model path is echoed into the
request but not read, so no file-existence check happens.

```
$ llamapulse run --stub --model /models/demo.gguf --prompt "Hello" --max-tokens 8
Local models run on your machine. No
$ echo "Hello" | llamapulse run --stub --model /models/demo.gguf --file - --stream
```

Flags: `--model`, `--prompt`, `--file` (`-` reads stdin), `--stream`, `--json`,
`--threads`, `--temperature`, `--top-p`, `--top-k`, `--max-tokens` and
`--context-size`. `--prompt` and `--file` are mutually exclusive; one is
required. `--json` and `--stream` cannot be combined.

`--stream` writes NDJSON: one schema-v1 object per line. Event types are
`started`, `token`, `metrics`, `completed`, `cancelled` and `failed`. A
`metrics` object carries `promptTokenCount`, `generatedTokenCount`,
`promptEvalMs`, `evalMs`, `tokensPerSecond` and `promptTokensPerSecond`; a
`failure` object carries `code`, `message` and `details`.

```console
$ llamapulse run --stub --model /models/demo.gguf --prompt "Hello" --max-tokens 8 --stream
{"schemaVersion":1,"type":"started","requestId":1}
{"schemaVersion":1,"type":"token","requestId":1,"text":"Local"}
{"schemaVersion":1,"type":"token","requestId":1,"text":" models"}
{"schemaVersion":1,"type":"metrics","requestId":1,"metrics":{"promptTokenCount":1,"generatedTokenCount":8,"promptEvalMs":3,"evalMs":189,"tokensPerSecond":42.33,"promptTokensPerSecond":333.33}}
{"schemaVersion":1,"type":"completed","requestId":1,"text":"Local models run on your machine. No","metrics":{"promptTokenCount":1,"generatedTokenCount":8,"promptEvalMs":3,"evalMs":189,"tokensPerSecond":42.33,"promptTokensPerSecond":333.33}}
```

`run --json` prints exactly one final JSON object instead of the stream.

### `bench`

Run the fixed prompt `The quick brown fox jumps over the lazy dog.` several
times and report aggregate throughput. `--stub` is mandatory, as for `run`, and
selects the same deterministic stub session; without it the same
`engineUnavailable` message exits 1. With no configured model, stub mode uses the
`<stub>` placeholder path.

```
$ llamapulse bench --stub --runs 3
runs: 3  generatedTokens: 36  evalMs: 818  tokensPerSecond: 44.01
$ llamapulse bench --stub --runs 3 --json
{"schemaVersion":1,"type":"bench","runs":3,"modelPath":"<stub>","promptChars":44,"promptTokenCount":11,"generatedTokenCount":36,"evalMs":818,"tokensPerSecond":44.01,"perRun":[{"requestId":1,"generatedTokenCount":12,"evalMs":274,"tokensPerSecond":43.8},{"requestId":2,"generatedTokenCount":12,"evalMs":272,"tokensPerSecond":44.12},{"requestId":3,"generatedTokenCount":12,"evalMs":272,"tokensPerSecond":44.12}]}
```

Flags: `--runs` (1..50, default 3), `--json`, `--max-tokens` (default 32), plus
the shared `--model`, `--threads`, `--temperature`, `--top-p`, `--top-k` and
`--context-size` overrides. Without `--json`, per-run progress lines go to
stderr and the aggregate line goes to stdout.

### stdout and stderr

stdout carries command data only: generated text, NDJSON events or the final
JSON object. stderr carries diagnostics, the human completion summary, per-run
bench progress and usage errors.

## `--json`

Every leaf command (`version`, `params get`, `params set`, `models list`,
`models inspect`, `run`, `bench`) accepts `--json` and prints a single-line JSON
object instead of human-readable text. `run` also accepts `--stream`. The
`params` and `models` groups are not invocable and have no `--json` of their
own. The YAML document used by `params get` and `params set` stays YAML on disk;
`--json` only changes the presentation.

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
| 1 | Unexpected failure, including `engineUnavailable` without `--stub` |
| 2 | Invalid arguments or parameters that failed validation |
| 3 | The requested model file was not found or is not a readable `.gguf` file |
| 130 | Generation cancelled by SIGINT |

## Help

```
$ llamapulse --help
$ llamapulse params --help
$ llamapulse params set --help
```
