# llamapulse CLI

The command-line companion to LlamaPulse. Its primary job is to configure,
start and inspect a local `llama-server` that other tools can use through an
OpenAI-compatible endpoint; `status`, `stop` and `logs` work from a second
terminal because the supervisor records `server-state.yaml`.

The embedded chat path (`run`, `bench` and the `params` it uses) is the older,
experimental path. `run` and `bench` still require `--stub`; the native embedded
session is deferred.

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

### `server get`

Print the stored `server.yaml` document. With no stored document (or a stale
`schemaVersion`) it prints the defaults and writes nothing.

```
$ llamapulse server get
schemaVersion: 1
server:
  modelPath: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
  host: 127.0.0.1
  port: 8080
  contextSize: 4096
  threads: 4
  gpuLayers: 0
  parallelSlots: 1
  modelAlias: llama-pulse
  apiKey: ''
  flashAttention: auto
  mlock: false
  mmap: true
  extraArgs: []
  binaryPath: ''
  startupTimeoutSeconds: 120
```

`--json` prints the same document as one line.

### `server set`

Update one or more server settings and write `server.yaml`. Values are
validated before writing; an invalid value exits `2`, prints the violations on
stderr and leaves the file untouched. The resulting document is printed on
stdout.

```
$ llamapulse server set --model-path /models/llama-3.2-3b-instruct.Q4_K_M.gguf \
    --context-size 8192 --parallel 2 --alias local-llama
$ llamapulse server set --flash-attn on --mlock --no-mmap
$ llamapulse server set --reset
```

Options: `--model-path` (alias `--model`), `--host`, `--port`,
`--context-size`, `--threads`, `--gpu-layers`, `--parallel`, `--alias`,
`--api-key`, `--flash-attn` (`on`, `off`, `auto`), `--[no-]mlock`,
`--[no-]mmap`, repeatable `--extra-arg`, `--binary`, `--startup-timeout`,
`--reset` and `--json`. Omitted flags keep the stored value. `--mlock` and
`--mmap` are negatable, and `--extra-arg` replaces the stored list.
`--reset` restores the defaults and cannot be combined with other options.

`--extra-arg` must not repeat a flag LlamaPulse manages (`-m`, `--host`,
`--port`, `-c`, `-t`, `-ngl`, `-np`, `-a`, `--api-key`, `-fa`, `--metrics`,
`--slots`, `-lm`, `--mlock`, `--mmap` and their long forms); such an argument is
rejected with exit `2`.

The API key is stored in plaintext in `server.yaml` by design and passed to
`llama-server` in argv. It is redacted from child log lines and failure details
and never written to `server-state.yaml`.

### `serve`

Start and supervise `llama-server` in the foreground. `serve` applies the same
flags as `server set` on top of the stored configuration for this run, validates
that the model path is a `.gguf` file, locates the binary and waits for
`/health`. It does not daemonize: child stdout is mirrored to stdout, child and
supervisor diagnostics go to stderr, and SIGINT/SIGTERM stop the child.

```
$ llamapulse serve --model /models/llama-3.2-3b-instruct.Q4_K_M.gguf --port 8080
```

The command refuses to start when `server-state.yaml` records a server in
`starting`, `running` or `stopping` that still answers `/health`; run `stop`
first. From another terminal, `status` shows the run and `stop` ends it. The
controller streams are subscribed before `start`, so `starting` and the first
log lines appear immediately. SIGINT or SIGTERM during startup stops the child
right away and exits `130` or `0` instead of waiting for the startup timeout. A
supervisor stream that closes without a terminal event is reported as
`failed(unknown, 'the supervisor stream ended')`.

`serve --json` writes NDJSON on stdout, one schema-v1 object per line:

```console
$ llamapulse serve --model /models/llama-3.2-3b-instruct.Q4_K_M.gguf --json
{"schemaVersion":1,"type":"starting","supervisorPid":38601,"modelPath":"/models/llama-3.2-3b-instruct.Q4_K_M.gguf","host":"127.0.0.1","port":8080,"binaryPath":"/usr/local/bin/llama-server","binaryVersion":"b6250"}
{"schemaVersion":1,"type":"ready","serverPid":38612,"baseUrl":"http://127.0.0.1:8080/v1","startupMs":4312}
{"schemaVersion":1,"type":"metrics","metrics":{"tokensPerSecond":0.0,"promptTokensPerSecond":0.0,"activeSlots":0,"totalSlots":1,"requestsProcessing":0,"requestsDeferred":0,"promptTokensTotal":0,"tokensPredictedTotal":0,"contextUsageRatio":null,"uptimeSeconds":4,"capturedAtEpochMs":1790000000000}}
{"schemaVersion":1,"type":"log","stream":"stdout","line":"main: server is listening on http://127.0.0.1:8080"}
{"schemaVersion":1,"type":"stopping","reason":"sigint"}
{"schemaVersion":1,"type":"stopped","exitCode":0}
```

Event types and their extra keys:

| `type` | Extra keys |
|---|---|
| `starting` | `supervisorPid`, `modelPath`, `host`, `port`, `binaryPath`, `binaryVersion` |
| `ready` | `serverPid`, `baseUrl`, `startupMs` |
| `metrics` | `metrics` object: `tokensPerSecond`, `promptTokensPerSecond`, `activeSlots`, `totalSlots`, `requestsProcessing`, `requestsDeferred`, `promptTokensTotal`, `tokensPredictedTotal`, `contextUsageRatio`, `uptimeSeconds`, `capturedAtEpochMs` |
| `log` | `stream` (`stdout`, `stderr`, `supervisor`), `line` |
| `stopping` | `reason` (`sigint`, `sigterm`) |
| `stopped` | `exitCode` |
| `failed` | `failure` object (`code`, `message`, `details`), `lastExitCode` |

SIGINT exits `130`; SIGTERM exits `0`. Startup failures (model missing, port
taken, bind error on stderr, readiness timeout) emit `failed` and exit `1`, `2`
or `3` as appropriate. A failure that happens before the controller publishes
anything (invalid flags, a missing model, an already-recorded server) still
prints exactly one `failed` NDJSON line when `--json` is set.

### `status`

Read `server-state.yaml` and probe the recorded server's `/health`.

```
$ llamapulse status
status: running
pid: 38612
supervisorPid: 38601
endpoint: http://127.0.0.1:8080/v1
model: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
binary: /usr/local/bin/llama-server (b6250, build 6250)
health: ok
uptime: 128s
```

Human `status` is `running`, `stopped`, `stale` or a phase name. `stale` means
the state file is active but `/health` does not answer. `starting`, `running`
and `stopping` all count as an active run, which is why a second `serve` is
refused while the recorded server still answers `/health`. The command exits
`0` only when the phase is `running` **and** `/health` returns 200 with
`{"status":"ok"}`; a 200 with `{"status":"loading"}` reports `loading` and
exits `1`. Every other state exits `1`. Uptime is reported from
`startedAtEpochMs` even when the server is unreachable.

`--json` prints one object:

```json
{"schemaVersion":1,"type":"serverStatus","running":true,"status":"running","health":"ok","pid":38612,"supervisorPid":38601,"host":"127.0.0.1","port":8080,"baseUrl":"http://127.0.0.1:8080/v1","modelPath":"/models/llama-3.2-3b-instruct.Q4_K_M.gguf","binary":{"path":"/usr/local/bin/llama-server","version":"b6250","buildNumber":6250,"supported":true,"warning":null},"uptimeSeconds":128,"lastExitCode":null,"failure":null}
```

### `stop`

Stop the server recorded in `server-state.yaml`. The command signals the
recorded supervisor first; when that signal cannot be delivered it falls back
to `serverPid`, so a dead supervisor never masks a live child. It waits up to
10 s for the state file to release the pids, then sends a forced kill to the
process that is actually alive. `--force` skips the graceful phase. Stopping
when nothing is recorded is a success.

```
$ llamapulse stop
stopped
$ llamapulse stop --json
{"schemaVersion":1,"type":"serverStop","stopped":true,"pid":38601,"forced":false}
```

`pid` is the pid that accepted the signal, or the last target tried when none
did. The command reports `stopped: true` and clears the document only when the
state is absent or terminal with no pids left. A document that still lists them
is left untouched and the command exits `1` with `stopped: false`.

### `logs`

Print the newest supervisor and `llama-server` lines from the log store.

```
$ llamapulse logs --lines 3
[supervisor] starting /usr/local/bin/llama-server on 127.0.0.1:8080
[stdout] main: server is listening on http://127.0.0.1:8080
[stderr] all slots are idle
```

`--lines` accepts `1..1000` (default 100). `--follow` follows by sequence
number, so it survives rotation without repeating or dropping a line, and
exits `130` when interrupted. `--json` prints one object per line with
`sequence`, `timestampEpochMs`, `stream` and `line`.

The on-disk file is `server.log` in the configuration directory, one
`timestamp<TAB>sequence<TAB>stream<TAB>line` record per line, rotated at 1 MiB
to `server.log.1`.

### `params get` and `params set` (embedded)

The chat parameters live in `params.yaml`. `params get` prints the exact
document and `params set` validates and writes it:

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
$ llamapulse params set --context-size 4096 --temperature 0.5
$ llamapulse params set --model-path "/models/my model.gguf"
$ llamapulse params set --reset
```

Options: `--model-path`, `--context-size`, `--gpu-layers`, `--threads`,
`--temperature`, `--top-p`, `--top-k`, `--max-tokens`, `--reset`. `--reset`
cannot be combined with another parameter option.

### `models list` and `models inspect`

```
$ llamapulse models list
llama-3.2-3b-instruct.Q4_K_M.gguf  1918.42  /home/me/.config/llamapulse/models/llama-3.2-3b-instruct.Q4_K_M.gguf
$ llamapulse models inspect /models/llama-3.2-3b-instruct.Q4_K_M.gguf
path: /models/llama-3.2-3b-instruct.Q4_K_M.gguf
fileName: llama-3.2-3b-instruct.Q4_K_M.gguf
sizeMiB: 1918.42
modified: 2026-10-30T12:00:00.000Z
```

`models list` takes a repeatable `--dir`; unreadable directories warn on stderr
and still exit `0`.

### `run` and `bench` (embedded, experimental)

Both generate against the embedded worker path and require `--stub`. The stub
selects the deterministic `StubLlamaSession`; it is not a fallback. Without it
they exit `1` with `engineUnavailable: the native session is unavailable; pass
--stub`. In stub mode the model path is echoed but not read.

```
$ llamapulse run --stub --model /models/demo.gguf --prompt "Hello" --max-tokens 8
Local models run on your machine. No
$ echo "Hello" | llamapulse run --stub --model /models/demo.gguf --file - --stream
$ llamapulse bench --stub --runs 3
runs: 3  generatedTokens: 36  evalMs: 818  tokensPerSecond: 44.01
```

`run` flags: `--model`, `--prompt`, `--file` (`-` reads stdin), `--stream`,
`--json`, `--threads`, `--temperature`, `--top-p`, `--top-k`, `--max-tokens`
and `--context-size`. `--prompt` and `--file` are mutually exclusive; one is
required. `--json` and `--stream` cannot be combined. `--stream` writes NDJSON
with `started`, `token`, `metrics`, `completed`, `cancelled` and `failed`.
`bench` flags: `--runs` (1..50, default 3), `--json`, `--max-tokens` (default
32) and the shared overrides.

## `--json`

Every leaf command accepts `--json`. `server get`, `server set`, `status`,
`stop` and `version` print one single-line JSON object; `serve` and
`logs --follow` emit NDJSON. The `params`, `models` and `server` groups are not
invocable and have no `--json` of their own. Configuration files on disk stay
YAML.

## Configuration paths

All files live in one directory:

```
<config>/server.yaml          supervised server configuration
<config>/server-state.yaml    phases, pids, health, last exit
<config>/server.log           supervisor and child output (rotated at 1 MiB)
<config>/params.yaml          embedded chat parameters
<config>/models/              default model directory
<config>/bin/                 optional llama-server location
```

| Platform | Directory |
|---|---|
| Linux | `$XDG_CONFIG_HOME/llamapulse`, else `~/.config/llamapulse` |
| macOS | `~/Library/Application Support/LlamaPulse` |
| Windows | `%APPDATA%\LlamaPulse` |

Set `LLAMA_PULSE_CONFIG_DIR` to an absolute path to override the platform
location.

## `llama-server` discovery

`serve`, `status` and the dashboard resolve the executable in this order:

1. `server.yaml`'s `binaryPath`
2. `LLAMA_PULSE_SERVER` (absolute path, path containing a separator, or a bare
   name looked up on `PATH`)
3. `<exeDir>/data/llama-server`
4. `<exeDir>/llama-server`
5. `<config>/bin/llama-server`
6. `PATH`

On Windows the name is `llama-server.exe`. The version comes from
`llama-server --version`; the supported floor is build `b4000`. A build below
`b4000` warns with `supported: false`. An unknown or unreadable version reports
`supported: true` with a warning (`unsupported or unknown llama.cpp build;
supported from b4000`, or `could not read llama-server --version`). Neither
blocks a start. Builds `b10875` and newer (and unknown builds) get
`--load-mode`; older builds get `--mlock`/`--no-mmap`.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success; `status` only when running and healthy; `stop` also when nothing was running |
| 1 | Unexpected failure, any non-running `status`, `serve` when a server is already recorded, `engineUnavailable` without `--stub` |
| 2 | Invalid arguments, invalid values, or a server configuration that failed validation |
| 3 | The requested model file was not found or is not a readable `.gguf` file |
| 130 | Interrupted by SIGINT (`serve`, `logs --follow`, a generation) |

## Help

```
$ llamapulse --help
$ llamapulse server --help
$ llamapulse server set --help
$ llamapulse serve --help
$ llamapulse status --help
$ llamapulse stop --help
$ llamapulse logs --help
```
