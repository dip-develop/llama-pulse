# Building llama.cpp v0.8.0

The runtime gate accepts exactly `0.8.0` from `llama_version()`, so build the
pinned tag with the development suffix disabled. From the directory that should
contain the checkout:

```sh
git clone --depth 1 --branch v0.8.0 https://github.com/ggml-org/llama.cpp
cmake -S llama.cpp -B llama.cpp/build -G Ninja -DBUILD_SHARED_LIBS=ON -DLLAMA_BUILD_IS_DEV=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TOOLS=OFF
cmake --build llama.cpp/build -j
```

`-DLLAMA_BUILD_IS_DEV=OFF` makes `llama_version()` return exactly `0.8.0`.
A default build reports `0.8.0-dev`; `LlamaVersionPin.matches` compares the
string exactly, so that build is rejected with a
`libraryVersionMismatch` failure and the reported version in `details`.

## Output

The build writes the shared libraries to `llama.cpp/build/bin`:

- `libllama.so`, `libllama.so.0`, `libllama.so.0.8.0`
- `libggml.so*`, `libggml-base.so*`, `libggml-cpu.so*`

`libllama.so` links the sibling `libggml*` libraries. The session pre-opens
those siblings before `libllama`, and they must be next to it or reachable
through the loader path.

## Pointing at the build

For the embedded engine and its integration test, set the absolute path:

```sh
export LLAMA_PULSE_LIB=/abs/path/to/llama.cpp/build/bin/libllama.so
export LLAMA_PULSE_MODEL=/abs/path/to/model.gguf
```

`LLAMA_PULSE_LIB` is read inside the worker, and the same path may be passed to
the CLI with `--lib`.

When running the compiled CLI, add the library directory so the dynamic loader
finds the sibling ggml libraries:

```sh
export LD_LIBRARY_PATH=/abs/path/to/llama.cpp/build/bin:$LD_LIBRARY_PATH
```

The Linux app bundle resolves `<exeDir>/lib/libllama.so` and links its bundle
libraries with `$ORIGIN/lib`; copy `libllama.so*` and `libggml*.so*` into that
`lib` directory for a self-contained bundle.

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
