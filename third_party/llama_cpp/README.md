The llama.cpp headers under `v0.8.0/` come from upstream llama.cpp and are
distributed under the MIT license (see `v0.8.0/LICENSE`). They are vendored for
ABI pinning only: the FFI bindings and struct layouts are checked against this
exact tag. They are not linked into the app and are not compiled by the Flutter
build; no native llama.cpp binary ships with LlamaPulse.
