# Parameters

LlamaPulse exposes the command-line parameters of the pinned llama.cpp
`llama-server`. There is one catalog for both the supervised server and the
embedded native session, and the CLI and the desktop app read it at runtime.

The catalog is generated from the vendored upstream source. It is not a
hand-written list of flags, and the generated files are never edited by hand.

## One source of truth

`ParameterCatalog.v080` in
`packages/llama_pulse_core/lib/src/domain/parameters/parameter_catalog.dart`
is the only description of a parameter. Every consumer reads the same
`ParameterSpec`:

- the GUI labels, summaries and tooltips;
- `llamapulse params catalog` and `params describe`;
- the validation messages of `--param`, `params set`, `server set` and `serve`;
- the two argument builders that emit the real command lines.

Change a summary or a description in the overrides file and regenerate; do not
duplicate text in the CLI, the app or a README. A second copy of a description
is a bug, because the CLI help and the GUI tooltip would eventually disagree.

## What the catalog contains

The pinned catalog is `llama.cpp` `v0.8.0`
(commit `8642541b255bfb5dc39cd351a178be09013a55d6`, `common/arg.cpp`
SHA-256 `fc09d12a…f2ed`). It holds **362 parameters in 12 groups**:

| Exposure | Count | Meaning |
|---|---|---|
| `configurable` | 210 | The user may set the value. |
| `managed` | 14 | LlamaPulse owns the value and always passes it. |
| `unsupported` | 132 | `llama-server` accepts the flag, LlamaPulse does not expose it. |
| `removed` | 6 | Upstream removed the flag; kept to explain the replacement. |

The four sets are disjoint and cover every entry. Of the 362, **10 are
catalogued for the embedded native session**; the rest of the configurable and
managed entries are server-only. Seven of the 10 are wired into
`NativeLlamaSession` today: the six typed fields
(`ctx-size`, `threads`, `gpu-layers`, `temp`, `top-k`, `top-p`) and the
`chat-template`. `seed`, `min-p` and `batch-size` are validated, stored and
exported by `params export`, but the session still uses its fixed seed
(`LLAMA_DEFAULT_SEED`), min-p `0.05` and a batch size derived from the context.

Groups, in display order:

| Group id | Name |
|---|---|
| `essentials` | Model & context |
| `memory` | Memory & loading |
| `threads` | Threads & CPU |
| `gpu` | GPU & offload |
| `batching` | Batching & cache |
| `sampling` | Sampling & penalties |
| `grammar` | Grammar & constraints |
| `lora` | LoRA, control vectors, multimodal |
| `server` | Server, network & security |
| `logging` | Logging & diagnostics |
| `managed` | Managed by LlamaPulse (read-only container) |
| `unsupported` | Not available (read-only container) |

`essentials` and `sampling` open by default in the GUI. `managed` and
`unsupported` are container groups the panel renders at the bottom; the panel
builds the locked containers from the exposure, so a managed entry appears
there regardless of its catalog group.

## Surfaces

A parameter belongs to one or both surfaces:

- **server** — the supervised `llama-server` child. Values are stored in
  `server.yaml` or set for one run with `serve`.
- **embedded** — the native `LlamaSession` inside the worker isolate (the Chat
  tab and CLI `run`/`bench`). Values are stored in `params.yaml` or passed with
  `--param` for one run.

Only these 10 ids apply to the embedded surface:

`ctx-size`, `threads`, `gpu-layers`, `temp`, `top-k`, `top-p`, `min-p`, `seed`,
`batch-size`, `chat-template`.

`ctx-size`, `threads`, `gpu-layers`, `temp`, `top-k`, `top-p` and
`chat-template` have a typed `ModelParams` field. `seed`, `min-p` and
`batch-size` live in the catalog map. The catalog marks the six typed ids that
also back a server setting (`ctx-size`, `threads`, `gpu-layers`, `temp`,
`top-k`, `top-p`) as `managed`, because the typed field is the only storage
location; `--param` writes that field instead of a duplicate map entry.
`chat-template` is configurable with no catalog owner, but the embedded CLI and
GUI still write `ModelParams.chatTemplate` rather than a map entry.

A parameter with no surface cannot be applied anywhere: that is what
`unsupported` and `removed` mean.

## Managed parameters

LlamaPulse owns these 14 ids and passes them itself. They cannot be stored in
the `params:` map:

| Id | Owner |
|---|---|
| `model` | `ServerConfig.modelPath` |
| `host` | `ServerConfig.host` |
| `port` | `ServerConfig.port` |
| `ctx-size` | `ServerConfig.contextSize` |
| `threads` | `ServerConfig.threads` |
| `gpu-layers` | `ServerConfig.gpuLayers` |
| `parallel` | `ServerConfig.parallelSlots` |
| `alias` | `ServerConfig.modelAlias` |
| `api-key` | `ServerConfig.apiKey` |
| `flash-attn` | `ServerConfig.flashAttention` |
| `extra-args` | `ServerConfig.extraArgs` |
| `load-mode` | supervisor: derived from the detected build |
| `metrics` | supervisor: always passed |
| `slots` | supervisor: always passed |

The eleven with a typed owner can be changed through the typed field; a
`--param` id that names such an owner is an alias for the typed flag
(`--param threads=8` is `--threads 8`). `load-mode`, `metrics` and `slots` have
no owner, so any attempt to set them is rejected with exit `2`. The same rule
keeps a hand-edited document honest: a managed id inside `params:` is reported
by the validator and never reaches a command line.

## Unsupported and removed parameters

Nothing is silently dropped. `llama-server` accepts 132 flags that LlamaPulse
does not expose, because they belong to another llama.cpp tool (perplexity,
imatrix, tokenize, diffusion, TTS, training), are download or fixture
shortcuts, exit the process, or are interactive/per-request CLI concerns. Each
entry carries a `reason`; `params describe <id>` prints it.

Six flags were removed upstream and are kept so a stale document is explained
instead of ignored: `defrag-thold`, `draft`, `draft-min`, `spec-ngram-size-n`,
`spec-ngram-size-m` and `spec-ngram-min-hits`. Where upstream named a
replacement, the catalog records it (for example `draft` →
`--spec-draft-n-max` or `--spec-ngram-mod-n-max`).

Policies:

- `params catalog` hides them by default; `--include-unsupported` lists them.
- `params describe <id>` always answers, including the reason and replacement.
- Setting one is an error with exit `2`, and the message names the reason.
- The GUI shows them in locked groups without a control.

## The catalog workflow

### Files

| Path | Role |
|---|---|
| `third_party/llama_cpp/v0.8.0/source/arg.cpp` | Vendored upstream source of truth. |
| `packages/llama_pulse_core/catalog/llama_args.v0.8.0.overrides.yaml` | Reviewed overrides; the only file to edit. |
| `packages/llama_pulse_core/catalog/llama_args.v0.8.0.yaml` | Generated catalog document; do not edit. |
| `packages/llama_pulse_core/lib/src/data/catalog/upstream_arg_parser.dart` | Parser for `add_opt(common_arg(...))` blocks. |
| `packages/llama_pulse_core/lib/src/domain/parameters/parameter_catalog.dart` | Const runtime API; `parameter_catalog.generated.dart` is its part. |
| `packages/llama_pulse_core/lib/src/data/catalog/catalog_digest.dart` | Canonical body and SHA-256 digest helper. |
| `packages/llama_pulse_core/lib/src/domain/entities/parameter_spec.dart` | `ParameterSpec`, `ParameterGroupSpec` and their enums. |
| `packages/llama_pulse_core/tool/args/generate_catalog.dart` | Generator (`--check` for CI). |

`arg.cpp` is vendored only for the catalog. It is not compiled, does not take
part in the native build, and does not ship.

### Regenerating

From the workspace root:

```sh
dart run melos run gen:catalog        # rewrite both generated files
dart run melos run gen:catalog:check  # fail when either file is stale
```

`gen:catalog` runs the generator inside `packages/llama_pulse_core`. It reads
the vendored `arg.cpp`, parses every `add_opt(common_arg(...))` block with a
brace/paren-aware scanner (strings, raw strings, comments and nested lambdas
included), keeps the definitions that `llama-server` can see, applies the
overrides, and writes:

1. the YAML catalog;
2. the const Dart catalog, formatted with the SDK formatter.

Generation is deterministic: parameters keep upstream declaration order, groups
are sorted by `order`, the YAML writer is byte-stable, and the digest covers the
body without timestamps or local paths. A definition the parser cannot
interpret fails generation with the line number; nothing is skipped silently.

`gen:catalog:check` regenerates in memory and exits `1` when a generated file
differs, so a stale catalog cannot merge. It runs in `melos run check` and is
part of the definition of done.

### The overrides file

The overrides file is the only hand-edited catalog input. It sets:

- **groups** — the presentation groups and their order/default expansion;
- **exposure** — `managed` (with `managedBy` and `reason`), `unsupported`
  (with `reason`) and `removed` (with `reason` and, when it exists, a
  `replacement`); `configurable` is the default;
- **groupMap** — the functional group of every configurable and managed id;
- **curated text** — `displayName`, `summary` and `description` for the most
  important ~25 parameters; everything else is generated from the upstream
  help;
- **ranges, allow-lists, item types, owners, `type`, `requiresExistingPath`,
  `advanced`, `deprecated`, `warning` and `reason`** — corrections the raw help
  cannot express. `negatedFlag` and `envVar` come from the parsed upstream
  definition.

The generator fails when a server-visible definition is unclassified, when a
managed entry lacks `managedBy`/`reason`, when an unsupported or removed entry
lacks a reason, when a parameter is missing from `groupMap`, or when an id is
declared twice.

### The digest

`digest` is `sha256:<hex>` over the canonical body (`schemaVersion`, `source`,
`groups`, `parameters`). The canonical form is a length-prefixed tree with
sorted map keys, so YAML quoting, key order and platform newlines cannot change
it. `parameter_catalog_digest_test.dart` recomputes the digest from the
checked-in YAML and compares it with the generated Dart constant.
`source.sha256` is the SHA-256 of the vendored `arg.cpp`.

The current digest is
`sha256:1838d6c821cbe8873dd77724cb27b1c8f50edf04189723134f89b5f8a8bdadb8`.

`package:crypto` is a **dev dependency** of `llama_pulse_core`. It is used by
the generator, the catalog tests and the vendored-file integrity test, never by
runtime code.

### Bumping the pin

The catalog pin and the native shared-library pin are separate constants even
though both currently name `v0.8.0`. Move them together only when the plan is
to move both; the catalog can be regenerated for a newer `llama-server` while
the embedded library stays on `v0.8.0`.

1. Vendor the new tag: copy `common/arg.cpp` and the headers, create
   `third_party/llama_cpp/<tag>/`, recompute the SHA-256 sums and update
   `PIN.md`/`SHA256SUMS` (`sha256sum -c` must pass).
2. Rename the overrides and catalog documents to the new tag
   (`llama_args.<tag>.overrides.yaml`, `llama_args.<tag>.yaml`) and update the
   `_tag`/`_sourceRelative`/`_catalogRelative`/`_overridesRelative` constants in
   `generate_catalog.dart`.
3. Update `ParameterCatalog.v080` (or add a new constant) and the digest test's
   expected tag/commit.
4. Run the generator. It fails with the line of every definition that is not
   classified.
5. Classify the new and changed ids in the overrides file and regenerate.
6. Run `gen:catalog:check`, the catalog tests and the full gate.

Never hand-edit `llama_args.v0.8.0.yaml` or
`parameter_catalog.generated.dart`; the check would overwrite or reject the
change.

## Types and validation

A `ParameterSpec` records how a value is stored and validated, not how upstream
happens to parse it:

| Type | Stored as | Canonical form |
|---|---|---|
| `bool` | `true` / `false` | accepts `true`, `false`, `1`, `0`, `on`, `off` |
| `int` | decimal integer | `int.parse` and back to string |
| `double` | finite decimal | `double.parse` and back to string (`0.80` → `0.8`) |
| `enum` | one allow-listed string | must appear in `allowed` |
| `path` | string | trimmed, validated on start when `requiresExistingPath` |
| `string` | string | as typed, up to 4096 characters |

Other fields that affect a value:

- `arity` is `0` for switches, `1` for most options and `2` for
  `--control-vector-layer-range`. An arity-2 value is two lines.
- `repeatable` values keep one entry per line; a non-repeatable id may appear
  at most once in `--param`.
- A list type with `itemType` but no `repeatable` is comma-separated.
- `min`/`max`/`step` bound and step the numeric editors and validation.
- `allowed` is the dropdown and the validation allow-list for `enum`.
- `defaultValue` is a literal only. A dynamic default (derived from the model,
  the hardware or another flag) is `null`; `params describe` prints `-` and the
  GUI tooltip says `dynamic`.

An empty value means **unset**: `llama.cpp` applies its own default. Clearing a
field in the GUI, `--param id=` and a missing key all mean the same thing.
Validation rejects control characters (newlines are allowed only as list/pair
separators) and values longer than 4096 characters. Path existence is checked
only when a start is being prepared, because the domain layer never touches the
filesystem.

The same canonicalization runs on every write path, so `0.80`, `0.8` and a
stored `0.8` compare equal, and "modified" means "differs from the catalog
default in canonical form".

## CLI

The catalog is browsable and every configurable id can be set with `--param`.

```console
$ llamapulse params catalog --group sampling
Sampling & penalties (sampling)
  seed  -s --seed  int  default=-1  configurable
  temp  --temp --temperature  double  default=0.8  configurable
  top-k  --top-k  int  default=40  configurable
  ...

$ llamapulse params catalog --surface embedded --include-unsupported --json
$ llamapulse params describe min-p
id: min-p
flags: --min-p
summary: Minimum probability relative to the most likely token
...
type: double
default: 0.05
range: 0..1
surfaces: server, embedded
exposure: configurable
```

`--surface` filters to `all` (default), `server` or `embedded`; `--group` is
repeatable; `--include-unsupported` adds the unsupported and removed entries.
`--json` prints `schemaVersion`, `type: "parameterCatalog"`, `surface`,
`upstreamTag`, `count`, `groups` and `parameters`, each parameter carrying the
full `ParameterSpec` field set. `params describe <id>` prints one entry as text
or JSON. An unknown group or id exits `2`.

`--param` is shared by the commands that touch a surface:

```console
$ llamapulse server set --param top-k=33 --param cont-batching=false
$ llamapulse server set --param cont-batching          # bare boolean = true
$ llamapulse server set --param top-k=                 # remove the stored id
$ llamapulse server set --param logit-bias=1=+2 --param logit-bias=3=-4
$ llamapulse server get --show-modified

$ llamapulse params set --param temp=0.7 --param seed=42
$ llamapulse params set --param chat-template=chatml
$ llamapulse params get --show-modified
$ llamapulse params export --param seed=42

$ llamapulse serve --param cont-batching=false
$ llamapulse run --stub --model /tmp/demo.gguf --prompt hi --param temp=0.2
$ llamapulse bench --param seed=7
```

`id=value` sets a value, `id=` removes it, and a bare `id` sets a boolean to
`true`. A repeatable id keeps every occurrence, one per line; repeating a
non-repeatable id is an error. A typed owner writes its field instead of the
`params` map, so `--param temp=0.7` stores `temperature: 0.7` and
`--param threads=8` stores `threads: 8`.

Conflict rules:

- When the typed flag and `--param` for the same id are both supplied, the
  canonical values must agree. Otherwise the command exits `2` with
  `--threads and --param threads disagree (4 vs 8)` and changes nothing.
- `--param` is validated before anything is written or loaded. An unknown,
  unsupported, removed, wrong-surface or ownerless managed id exits `2` with
  the catalog's message.
- `params set --reset`, `server set --reset` and `--param` are mutually
  exclusive.
- `run` and `bench` never persist `--param`; it applies to that invocation.

`params get --show-modified` and `server get --show-modified` print only the
ids whose effective value differs from the default, as `id: value` lines.
`--json` keeps the document and adds the same list under `modified`.
`params export` prints the `llama-cli`-shaped argument vector for the embedded
configuration without writing; `--json` prints
`{schemaVersion, type: "paramsExport", argv}`.

## Desktop GUI

Both surfaces use the same `ParameterPanel`, so the behaviour is identical; the
dashboard passes the server catalog and the Chat tab passes the embedded one.

- The panel sits under the essentials form for that surface: the server
  dashboard and the Chat tab.
- Groups are collapsible. The catalog's `defaultOpen` groups open first, plus
  any group with a modified value. The rows of a closed group are not built.
- Search matches, case-insensitively, the id, every flag token, the negated
  flag, the display name, the summary, the description and the group name. A
  non-empty query expands the matching groups temporarily; clearing it restores
  the stored expansion.
- A **Modified only** switch hides rows whose value equals the default. Locked
  containers are hidden in that mode because they hold no user edits.
- **Expand all** and **Collapse all** act on the visible groups.
- Each row has a reset action and a snackbar with **Undo**. Each header shows
  the group's modified count and a **Reset this group** action.
- The info icon shows a tooltip built from the same `ParameterSpec`: flags,
  negated flag, summary, description, type, default, range, environment
  variable, warning, note and replacement. This is the "one source of truth"
  rule in the UI.
- Controls follow the type: a switch for `bool`, a dropdown for `enum`, a text
  field (numeric keyboard for `int`/`double`, multiline for repeatable and pair
  values) otherwise, plus **Browse** for path parameters.
- Invalid text stays local to the row and is shown under the field; only a
  canonical, valid value is dispatched to the bloc.
- Managed, unsupported and removed rows are locked. Managed rows show their
  effective value when one exists and explain who owns it; unsupported and
  removed rows show the reason (and replacement) without a value or a control.
- The Chat panel additionally locks the ids the essentials form owns ("Set in
  the essentials form") and the server flags the embedded engine cannot honour
  ("Not available in the embedded engine").

Storage:

- `server.yaml` keeps a catalog value in `server.params`, and only when it is
  non-empty. An empty map removes the key entirely.
- `params.yaml` keeps a catalog value in `params.params` (the outer `params` is
  the `ModelParams` document), again only when it is non-empty, because
  `params.yaml` nests its entity under `params:`.
- A value writes back in catalog order, with unknown hand-edited ids kept
  sorted at the end so the validator can report them.
- Clear a field to remove it; the entity default is not copied into the file.

## Emitted command lines

Two builders turn values into argument vectors; they share the emission rules:

- `ServerArgumentBuilder` emits the managed server block first, then
  `ServerConfig.params` in catalog order, then `extraArgs`.
- `ModelArgumentBuilder` emits the typed `ModelParams` block first
  (`-m`, `-c`, `-t`, `-ngl`, `--temp`, `--top-k`, `--top-p`, `-b`), then the
  remaining embedded map entries in catalog order.

Rules that both builders follow:

- Iterate the catalog, not the map, so the vector does not depend on insertion
  order.
- Emit the flag and the value as two vector tokens: never `--flag=value`.
- A `true` boolean emits the flag; a `false` boolean emits the negated flag
  when upstream declares one, and the server builder warns when it does not.
- A repeatable value emits one flag/value pair per line; an arity-2 value emits
  the flag followed by its two lines.
- Skip ids that already have a typed field, ids with no server/embedded
  surface, and any managed, unsupported or removed entry. The validator is the
  normal gate; skipping here keeps a hand-edited document from launching an
  ambiguous process.
- Tokens are passed to the launcher as a vector. Nothing is shell-quoted.

## Tests

- `parameter_catalog_digest_test.dart` — digest, vendored hash, unique
  ids/flags, group integrity, owner fields and lookup helpers.
- `parameter_coverage_test.dart` — parses `arg.cpp` in the test, proves every
  server-visible flag is covered or explicitly ignored, checks exposure
  disjointness and the 10-entry embedded subset.
- `parameter_validator_test.dart` and `parameter_value_codec_test.dart` — every
  type, bound, allow-list, canonicalization and the managed/unsupported/removed
  messages.
- `parameter_values_test.dart` — map helpers, normalization, modified ids and
  typed-owner precedence.
- `server_argument_builder_test.dart` and `model_argument_builder_test.dart` —
  the emitted vectors and the rules above.
- `vendored_header_test.dart` — all nine vendored files match `SHA256SUMS`.

## Adding a parameter

1. If upstream changed: change the pin, vendor the new `arg.cpp`, update
   `SHA256SUMS` and `PIN.md`.
2. Run `gen:catalog`; it fails with the line of any unclassified definition.
3. Classify the new ids in the overrides file, add groups if needed, and
   regenerate.
4. Run `gen:catalog:check`, the catalog tests and the full gate.
5. If the id needs a typed field, add it to the entity, the validator, the YAML
   round-trip, the CLI flag and the GUI form as well; otherwise it is edited
   through the generic panel.
