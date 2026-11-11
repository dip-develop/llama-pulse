# Building llama.cpp v0.8.0

The runtime gate accepts exactly `0.8.0` from `llama_version()`, so build the
pinned tag with the development suffix disabled. From the directory that should
contain the checkout:

```sh
git clone --depth 1 --branch v0.8.0 https://github.com/ggml-org/llama.cpp
cmake -S llama.cpp -B llama.cpp/build -G Ninja -DBUILD_SHARED_LIBS=ON -DLLAMA_BUILD_IS_DEV=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_APP=OFF -DGGML_NATIVE=ON
cmake --build llama.cpp/build -j
```

`tool/build_llama_cpp.sh` runs exactly these steps in one command
(`tool/build_llama_cpp.sh [tag]`, default `v0.8.0`) and builds into
`build/llama.cpp-<tag>`; keep the two in sync. For the pinned tag the script
does not trust the tag alone: it reads the commit from `LlamaVersionPin`,
checks the checkout out at that commit (fetching it if needed) and fails when it
cannot, so a moved tag cannot silently build different source.

`-DLLAMA_BUILD_IS_DEV=OFF` makes `llama_version()` return exactly `0.8.0`.
A default build reports `0.8.0-dev`; `LlamaVersionPin.matches` compares the
string exactly, so that build is rejected with a
`libraryVersionMismatch` failure and the reported version in `details`.

`-DLLAMA_BUILD_APP=OFF` is required. Without it the build fails with
`app/llama.cpp:1:10: fatal error: build-info.h: No such file or directory`:
upstream `v0.8.0` defaults `LLAMA_BUILD_APP` to standalone even when tools and
examples are off, so the app target is configured without its generated
headers. That is an upstream packaging bug, not a LlamaPulse one.

`-DGGML_NATIVE=ON` builds for the host CPU. Use `-DGGML_NATIVE=OFF` only when
the library must run on a different machine than it was built on.

## Output

The build writes the shared libraries to `llama.cpp/build/bin`:

- `libllama.so`, `libllama.so.0`, `libllama.so.0.8.0`
- `libggml.so*`, `libggml-base.so*`, `libggml-cpu.so*`

`libllama.so` links the sibling `libggml*` libraries. The session pre-opens
those siblings before `libllama`, and they must be next to it or reachable
through the loader path.

## Verified

- Date: 2026-11-01.
- Upstream tag `v0.8.0`, commit `8642541b255bfb5dc39cd351a178be09013a55d6`,
  bundled ggml `0.28.0`.
- CPU-only build for 6 cores (`-DGGML_NATIVE=ON`), no GPU backend.
- Shared library layout as listed above: `libllama.so` → `libllama.so.0` →
  `libllama.so.0.8.0`; `strings libllama.so.0.8.0` contains `0.8.0`.
- Model: `Mellum2.1-12B-A2.5B-Thinking-Q8_0.gguf` (12.04 GiB) at
  `<hf-cache>/…/Mellum2.1-12B-A2.5B-Thinking-Q8_0.gguf`, context 512, two
  threads.
- `native_integration_test.dart`: passed in about 5.5 s wall time, including a
  second load (reload), with 12.8 GB peak RSS.
- CLI `run` smoke test: 16 tokens in 825 ms (19.4 tok/s); repeated runs measured
  23.9–24.3 tok/s.
- UTF-8 accented characters, leading spaces, newlines and code indentation
  round-trip through the tokenizer and detokenizer unchanged.

## Pointing at the build

For the embedded engine and its integration test, set the absolute path:

```sh
export LLAMA_PULSE_LIB=/abs/path/to/llama.cpp/build/bin/libllama.so
export LLAMA_PULSE_MODEL=/abs/path/to/model.gguf
```

`LLAMA_PULSE_LIB` is read inside the worker, and the same path may be passed to
the CLI with `--lib`.

`libllama.so` has a `DT_RUNPATH` for its own directory, but that is not enough
on hosts where another ggml build is already installed. This host has
`/opt/llama.cpp-rocm` with ggml `0.27.0`; without help, `libllama.so` can bind
`libggml.so.0` from there instead of the matching `0.28.0` beside it, and the
loader happily mixes the two. The session mitigates this inside the app by
pre-opening the sibling `libggml*` files by absolute path, but a compiled CLI or
any other binary still depends on the search path.

The rule is therefore: keep `libllama.so` and `libggml*.so` together, in one
directory, and make that directory the one the loader searches.

- Inside the app bundle, put both sets in `<exeDir>/lib`; the bundle links them
  with `$ORIGIN/lib` and the resolution order finds them there.
- Outside a bundle, export the directory that contains both:

```sh
export LD_LIBRARY_PATH=/abs/path/to/llama.cpp/build/bin:$LD_LIBRARY_PATH
```

Do not copy only `libllama.so`: it will find some other `libggml` and fail at
load time or crash in inference.

Run the opt-in integration test with:

```sh
cd packages/llama_pulse_core
dart test test/data/inference/native/native_integration_test.dart
```

It is skipped unless both `LLAMA_PULSE_LIB` and `LLAMA_PULSE_MODEL` are set, so
the normal `melos test` run stays fast and needs no native library.

## Local fork is rejected

The local `/opt/llama.cpp-rocm` build is an Unsloth fork that reports
`0.7.0-dev`. The version gate rejects it, so it cannot be used for this
integration test. Build upstream `v0.8.0` as shown above instead.
