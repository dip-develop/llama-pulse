# llama.cpp pin

| | |
|---|---|
| Tag | `v0.8.0` |
| Commit | `8642541b255bfb5dc39cd351a178be09013a55d6` |
| ggml | `v0.28.0` |
| Upstream repo | https://github.com/ggml-org/llama.cpp |

The pin is authoritative; never resolve `latest` at build time.

## Vendored files

All files were downloaded from the tag with `curl -fsSL`:

- `include/llama.h` — https://raw.githubusercontent.com/ggml-org/llama.cpp/v0.8.0/include/llama.h
- `include/ggml.h` — https://raw.githubusercontent.com/ggml-org/llama.cpp/v0.8.0/ggml/include/ggml.h
- `include/ggml-cpu.h` — https://raw.githubusercontent.com/ggml-org/llama.cpp/v0.8.0/ggml/include/ggml-cpu.h
- `include/ggml-backend.h` — https://raw.githubusercontent.com/ggml-org/llama.cpp/v0.8.0/ggml/include/ggml-backend.h
- `include/ggml-alloc.h` — https://raw.githubusercontent.com/ggml-org/llama.cpp/v0.8.0/ggml/include/ggml-alloc.h
- `include/ggml-opt.h` — https://raw.githubusercontent.com/ggml-org/llama.cpp/v0.8.0/ggml/include/ggml-opt.h
- `include/gguf.h` — https://raw.githubusercontent.com/ggml-org/llama.cpp/v0.8.0/ggml/include/gguf.h
- `LICENSE` — https://raw.githubusercontent.com/ggml-org/llama.cpp/v0.8.0/LICENSE
- `source/arg.cpp` — https://raw.githubusercontent.com/ggml-org/llama.cpp/v0.8.0/common/arg.cpp

The ggml headers live under `ggml/include/` in this tag; only `llama.h` is at
the repository root's `include/`.

`source/arg.cpp` is vendored for one purpose: it is the source of truth for the
`llama-server` command-line parameter catalog. `dart run
tool/args/generate_catalog.dart` parses its `add_opt(common_arg(...))` blocks;
the parser and the coverage test fail if a server-visible flag is not accounted
for. It is not compiled and does not take part in the native build.

### Why `arg.cpp` is vendored

The catalog must be reproducible offline and reviewable in a diff. Parsing the
file at runtime would need a network clone of the tag, and generating it from a
local checkout would make the digest depend on the machine. The vendored file
pins the exact bytes: `SHA256SUMS` covers it, the catalog records its hash as
`source.sha256`, and `parameter_coverage_test.dart` re-parses it so a flag
cannot silently disappear from the catalog.

The generated outputs are
`packages/llama_pulse_core/catalog/llama_args.v0.8.0.yaml` and
`packages/llama_pulse_core/lib/src/domain/parameters/parameter_catalog.generated.dart`.
The only hand-edited input is
`packages/llama_pulse_core/catalog/llama_args.v0.8.0.overrides.yaml`.
`dart run melos run gen:catalog:check` fails when either generated file is
stale. See [docs/parameters.md](../../../docs/parameters.md) for the workflow.

This file is the `llama-server` surface only. The embedded shared library is
pinned separately by `include/llama.h` and `LlamaVersionPin`; moving one pin
does not automatically move the other.

`ggml-alloc.h` and `ggml-opt.h` are not used by the bindings directly, but
`llama.h` includes them (`ggml-backend.h` pulls in `ggml-alloc.h`, and
`llama_opt_*` needs `ggml-opt.h`), so `abi_check.c` cannot compile the header
without them. Keep the set complete: a missing header breaks the ABI check.

## Checksums

```
d114067f9099c4a0e2bbc0625c676d4894d9cf0ea27168ee072c7de0e71bb51d  include/ggml-alloc.h
0e5e8e1f16d11ebbf501e38bc6705d79eee819b5f0b17476533f2100ed9674e2  include/ggml-backend.h
316279e004cdeb8e6ef78599acb602bf79a8abdf897fed9fd1914808c1518c6e  include/ggml-cpu.h
3586de1bc8a934b5c72339e2b6937b0641e8f149b512231e666f67de0736eea2  include/ggml-opt.h
2b4dd92fa992cb4ef484917a6c62fef5097698744160ccc09214fd0c459c92c7  include/ggml.h
e56714aab702e5ce62ee587a409643c08f7e93e8fbb77f48ef7cc85075f96fa4  include/gguf.h
c0854771d3760a41642c4e59429c5b3b9fc774887c59d37eeadc4527681732cd  include/llama.h
94f29bbed6a22c35b992c5c6ebf0e7c92f13b836b90f36f461c9cf2f0f1d010d  LICENSE
fc09d12abd18c08a879c98a472e27ec80688c97b8c52720552112fe2c548f2ed  source/arg.cpp
```

`SHA256SUMS` repeats the same list with paths relative to the repository root,
so `sha256sum -c third_party/llama_cpp/v0.8.0/SHA256SUMS` works from there.

## Correction to the earlier assumption

An earlier note claimed that upstream does not carry the `load_mode`,
`lazy_mode` and `load_mtp` model fields, nor the `n_rs_seq`, `n_outputs_max`,
`n_outputs_max_per_seq`, `ctx_type`, `moe_cache_size` and `ctx_other` context
fields, and that those existed only in the local fork. That is wrong: all of
them are present in upstream `v0.8.0`'s `llama.h`. Conversely `use_mmap`,
`use_mlock`, `use_direct_io` and `logits_all` are gone from the v0.8.0 structs.
Bind against the vendored header, not the fork.
