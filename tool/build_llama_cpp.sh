#!/usr/bin/env bash
#
# Build the pinned llama.cpp release as shared libraries for LlamaPulse.
#
#   tool/build_llama_cpp.sh [tag]
#
# The tag defaults to v0.8.0. The checkout and its build tree go to
# $BUILD_DIR/llama.cpp-<tag>, where BUILD_DIR defaults to $PWD/build. The
# configuration flags are the ones documented in
# third_party/llama_cpp/v0.8.0/BUILD.md; keep the two in sync.

set -euo pipefail

TAG="${1:-v0.8.0}"
if [[ $# -gt 1 ]]; then
  echo "usage: $(basename "$0") [tag]" >&2
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="${BUILD_DIR:-$PWD/build}"
SRC_DIR="$BUILD_ROOT/llama.cpp-$TAG"
BIN_DIR="$SRC_DIR/build/bin"
PIN_FILE="$REPO_ROOT/packages/llama_pulse_core/lib/src/data/inference/llama_version_pin.dart"
UPSTREAM_URL="https://github.com/ggml-org/llama.cpp"

# Canonical flag list. Keep identical to BUILD.md and README.md.
CMAKE_FLAGS=(
  -G Ninja
  -DBUILD_SHARED_LIBS=ON
  -DLLAMA_BUILD_IS_DEV=OFF
  -DLLAMA_BUILD_TESTS=OFF
  -DLLAMA_BUILD_EXAMPLES=OFF
  -DLLAMA_BUILD_TOOLS=OFF
  -DLLAMA_BUILD_APP=OFF
  -DGGML_NATIVE=ON
)

if [[ "$TAG" != v* ]]; then
  echo "error: tag '$TAG' does not look like an upstream release tag (expected vX.Y.Z)" >&2
  exit 64
fi
VERSION="${TAG#v}"

# The runtime gate accepts one exact version. Warn, do not fail: a newer tag is
# still useful for a local experiment, but the engine will reject it at load.
if [[ ! -f "$PIN_FILE" ]]; then
  echo "warning: pin file not found at $PIN_FILE; cannot check the tag" >&2
elif ! grep -q "version = '$VERSION'" "$PIN_FILE"; then
  echo "warning: tag $TAG does not match LlamaVersionPin" >&2
  echo "         pinned: $(grep -m1 "version = '" "$PIN_FILE" | sed "s/.*version = '\(.*\)'.*/\1/")" >&2
  echo "         requested: $VERSION" >&2
  echo "         the engine accepts only the pinned version at load time" >&2
else
  echo "==> tag $TAG matches LlamaVersionPin ($VERSION)"
fi

if [[ -d "$SRC_DIR/.git" ]]; then
  echo "==> reusing checkout $SRC_DIR"
else
  echo "==> cloning $UPSTREAM_URL at $TAG into $SRC_DIR"
  mkdir -p "$BUILD_ROOT"
  git clone --depth 1 --branch "$TAG" "$UPSTREAM_URL" "$SRC_DIR"
fi

echo "==> configuring"
cmake -S "$SRC_DIR" -B "$SRC_DIR/build" "${CMAKE_FLAGS[@]}"

JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)"
echo "==> building with $JOBS jobs"
cmake --build "$SRC_DIR/build" -j"$JOBS"

REAL_LIB="$BIN_DIR/libllama.so.$VERSION"
for required in "$BIN_DIR/libllama.so" "$BIN_DIR/libllama.so.0" "$REAL_LIB"; do
  if [[ ! -e "$required" ]]; then
    echo "error: expected build output missing: $required" >&2
    exit 1
  fi
done

echo
echo "Output:"
echo "  $BIN_DIR/libllama.so"
echo "  $BIN_DIR/libllama.so.0"
echo "  $REAL_LIB"
echo "  $BIN_DIR/libggml*.so* (siblings, must stay next to libllama)"

if ! strings "$REAL_LIB" | grep -qx "$VERSION"; then
  echo "warning: $VERSION not found in $REAL_LIB; the version gate may reject it" >&2
fi

cat <<EOF

Point the engine at the build:

  export LLAMA_PULSE_LIB="$BIN_DIR/libllama.so"
  export LLAMA_PULSE_MODEL=/abs/path/to/model.gguf
  export LD_LIBRARY_PATH="$BIN_DIR:\${LD_LIBRARY_PATH:-}"

LD_LIBRARY_PATH matters outside an app bundle: another ggml build earlier on the
search path (for example an /opt install) can otherwise satisfy libggml.so.0.
The bundle itself resolves both libraries from <exeDir>/lib.
EOF
