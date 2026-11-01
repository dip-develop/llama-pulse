# llama.cpp parameter catalog

LlamaPulse exposes every parameter that the pinned `llama-server` accepts. The
catalog is not typed by hand: it is generated from the vendored
`common/arg.cpp` and checked against it by a test.

## Files

| Path | Role |
|---|---|
| `third_party/llama_cpp/v0.8.0/source/arg.cpp` | Vendored upstream source of truth. |
| `catalog/llama_args.v0.8.0.overrides.yaml` | Reviewed overrides; the only file to edit. |
| `catalog/llama_args.v0.8.0.yaml` | Generated catalog document; do not edit. |
| `lib/src/data/catalog/upstream_arg_parser.dart` | Parser for `add_opt(common_arg(...))` blocks. |
| `lib/src/data/catalog/parameter_catalog.dart` | Const runtime API; `parameter_catalog.generated.dart` is its part. |
| `lib/src/data/catalog/catalog_digest.dart` | Canonical body and SHA-256 digest helper. |
| `lib/src/domain/entities/parameter_spec.dart` | `ParameterSpec`, `ParameterGroupSpec` and their enums. |
| `tool/args/generate_catalog.dart` | Generator (`--check` for CI). |

The catalog is generated, not compiled into the native build. `arg.cpp` is
present only so the parser and the coverage test can read the real declaration
order, flags, hints and help text.

## Regenerating

From the workspace root:

```sh
dart run melos run gen:catalog
dart run melos run gen:catalog:check
```

`gen:catalog:check` is part of `melos run check`. It regenerates in memory,
formats the Dart output, and exits 1 when either output file differs, so a
stale catalog cannot merge.

Generation is deterministic: parameters keep upstream declaration order,
groups are sorted by their `order`, the YAML writer is byte-stable, and the
digest covers the body without timestamps or local paths.

## What the generator does

1. Parses every `add_opt(common_arg(...))` block in `arg.cpp` with a
   brace/paren-aware scanner (strings, raw strings, comments and nested
   lambdas included). A block it cannot interpret fails generation with the
   line number; nothing is skipped silently.
2. Talks to `llama-server` only. A definition is server-visible when its
   `set_examples` set contains `SERVER` or inherits `COMMON`, and it is not
   excluded from `SERVER`. The `if (ex == SERVER)` branch of
   `-np/--parallel` is resolved in favour of the explicit server definition.
3. Applies this override file: exposure, group membership, curated text,
   ranges, allow-lists, owners, item types and surfaces.
4. Emits the YAML catalog and the const Dart catalog, then formats the Dart
   with the SDK formatter so a hand-run `dart format` never creates a diff.

The parser understands the named `initializer_list<enum llama_example>`
variables in the file (`mmproj_examples`), so multimodal options are classified
from the real example set.

## Overrides

### Groups

`groups` defines the presentation groups. `groupMap` lists every configurable
parameter and every managed parameter; a managed parameter keeps its functional
group (the model file stays under `essentials`). Unsupported and removed
parameters are placed in the `unsupported` group automatically.

### Exposure

* `configurable` — the default; the user may set the value.
* `managed` — LlamaPulse always passes the value; `managedBy` and `reason` are
  required, and `owner` names the `ServerConfig` field when one exists.
* `unsupported` — `llama-server` accepts the flag but LlamaPulse does not
  expose it. Entries are grouped by reason: other llama.cpp tools (perplexity,
  imatrix, tokenize, diffusion, TTS, training), download/fixture shortcuts,
  process-exiting actions, and interactive/per-request CLI concerns.
* `removed` — upstream removed the flag; the reason and, when one exists, the
  replacement are required.

The four sets are disjoint and cover every catalog entry. `surfaces` is empty
for unsupported and removed entries, because LlamaPulse cannot apply them
anywhere. `embedded` is only set for the ids the native session can honour:
`ctx-size`, `threads`, `gpu-layers`, `temp`, `top-k`, `top-p`, `min-p`, `seed`,
`batch-size` and `chat-template`.

### Curated entries

Only the 25 most important parameters carry hand-written `displayName`,
`summary` and `description` text. Everything else is generated from the
upstream help, with `%` placeholders replaced and defaults inferred only when
they are literal (`0`, `0.8`, `on`, `'auto'`). A bare word such as "unused" or
"empty" is prose, not a default, and is dropped. A few entries add a `type`
correction only (for example `lora-scaled`, whose hint is `FNAME:SCALE` but
whose value is not a path).

### Aliases

`negatedFlag` records the first negated spelling of a switch. Upstream
sometimes accepts more than one (`-no-kvu` and `--no-kv-unified`); the extra
tokens are listed in `ignoredFlags` with the reason "alternate negation". They
stay covered by the same catalog entry rather than becoming duplicate
parameters.

## Digest

`digest` is `sha256:<hex>` over the canonical body (`schemaVersion`, `source`,
`groups`, `parameters`). The canonical form is a length-prefixed tree with
sorted map keys, so YAML quoting and key order cannot change it. The test
recomputes it from the checked-in YAML and compares it with the generated Dart
constant. `source.sha256` is the SHA-256 of the vendored `arg.cpp`.

`package:crypto` is a dev dependency of `llama_pulse_core`: it is used by the
generator, the catalog tests and the vendored-file integrity test only, never
by runtime code.

## Tests

* `test/data/catalog/parameter_catalog_digest_test.dart` — digest, vendored
  hash, unique ids/flags, group integrity, owner fields, lookup helpers.
* `test/data/catalog/parameter_coverage_test.dart` — parses `arg.cpp` in the
  test, proves every server-visible flag is covered or explicitly ignored,
  checks exposure disjointness and the embedded subset.
* `test/data/inference/native/vendored_header_test.dart` — all nine vendored
  files match `SHA256SUMS`.

## Adding a parameter

1. Change the pin, vendor the new `arg.cpp`, update `SHA256SUMS` and `PIN.md`.
2. Run the generator; it fails with the line of any unclassified definition.
3. Classify the new ids in the overrides file, add groups if needed, and run
   the generator again.
4. Run `melos run gen:catalog:check` and the catalog tests.
