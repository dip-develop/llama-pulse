The llama.cpp headers under `v0.8.0/` come from upstream llama.cpp and are
distributed under the MIT license (see `v0.8.0/LICENSE`). They are vendored for
ABI pinning: the hand-written FFI bindings in
`packages/llama_pulse_core/lib/src/data/inference/native/llama_bindings.dart`
are the source of truth derived from them, and `v0.8.0/abi_check.c` includes
them to print the struct sizes and field offsets the ABI test compares.

The headers are not linked into the app and are not compiled by the Flutter
build; no native llama.cpp binary ships with LlamaPulse. Build a matching shared
library yourself with [`v0.8.0/BUILD.md`](v0.8.0/BUILD.md). `v0.8.0/PIN.md`
records the tag, commit and vendored file list, and
`sha256sum -c third_party/llama_cpp/v0.8.0/SHA256SUMS` verifies them from the
repository root.
