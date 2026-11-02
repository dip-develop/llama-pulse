#!/usr/bin/env bash
#
# Build a relocatable Linux bundle of the desktop app and, optionally, one
# installed managed runtime.
#
# Usage:
#   tool/package_linux.sh
#   tool/package_linux.sh --runtime v0.8.0 cuda13
#   tool/package_linux.sh --skip-build --bundle apps/llama_pulse/build/linux/x64/debug/bundle
#
# The runtime is copied from <config>/runtime/<tag>/<backend>/ (the same layout
# the app installs into) to <bundle>/runtime/<tag>/<backend>/, which both
# loaders resolve beside the executable before falling back to a runtime the
# user installed later. See docs/packaging.md.

set -euo pipefail

usage() {
    cat <<'EOF'
usage: tool/package_linux.sh [options]

  --runtime <tag> <backend>  bundle an installed runtime, for example
                             `--runtime v0.8.0 cuda13`
  --config-dir <dir>         config directory to read the runtime from
                             (default: $LLAMA_PULSE_CONFIG_DIR,
                             $XDG_CONFIG_HOME/llamapulse, or ~/.config/llamapulse)
  --out <dir>                output directory (default: <repo>/dist)
  --bundle <dir>             bundle to package (default: the release build)
  --skip-build               do not run `flutter build linux --release`
  -h, --help                 show this help

The archive is written to <out>/llama-pulse-<version>-linux-x64.tar.gz and the
staging tree stays next to it.
EOF
}

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(sed -n 's/^version: *//p' "$repo_root/apps/llama_pulse/pubspec.yaml" \
    | head -n 1 | cut -d+ -f1)
if [ -z "$version" ]; then
    echo "could not read the app version from apps/llama_pulse/pubspec.yaml" >&2
    exit 1
fi

runtime_tag=""
runtime_backend=""
config_dir="${LLAMA_PULSE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/llamapulse}"
out_dir="$repo_root/dist"
bundle_dir="$repo_root/apps/llama_pulse/build/linux/x64/release/bundle"
build=1

while [ $# -gt 0 ]; do
    case "$1" in
        --runtime)
            if [ $# -lt 3 ]; then
                echo "--runtime needs a tag and a backend" >&2
                exit 2
            fi
            runtime_tag=$2
            runtime_backend=$3
            shift 3
            ;;
        --config-dir)
            if [ $# -lt 2 ]; then
                echo "--config-dir needs a path" >&2
                exit 2
            fi
            config_dir=$2
            shift 2
            ;;
        --out)
            if [ $# -lt 2 ]; then
                echo "--out needs a path" >&2
                exit 2
            fi
            out_dir=$2
            shift 2
            ;;
        --bundle)
            if [ $# -lt 2 ]; then
                echo "--bundle needs a path" >&2
                exit 2
            fi
            bundle_dir=$2
            shift 2
            ;;
        --skip-build)
            build=0
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ -n "$runtime_tag" ]; then
    # The values become path segments and are copied recursively; refuse
    # anything that is not a plain tag or backend id.
    case "$runtime_tag" in
        *[!A-Za-z0-9._-]* | . | ..)
            echo "invalid runtime tag: $runtime_tag" >&2
            exit 2
            ;;
    esac
    case "$runtime_backend" in
        *[!a-z0-9]* | "")
            echo "invalid runtime backend: $runtime_backend" >&2
            exit 2
            ;;
    esac
fi

if [ "$build" -eq 1 ]; then
    (
        cd "$repo_root/apps/llama_pulse"
        flutter build linux --release
    )
fi

if [ ! -d "$bundle_dir" ]; then
    echo "no bundle at $bundle_dir; build it or pass --bundle" >&2
    exit 1
fi

stage_name="llama-pulse-$version-linux-x64"
stage="$out_dir/$stage_name"
bundle_root="$stage"

mkdir -p "$out_dir"
rm -rf "$stage"
cp -a "$bundle_dir" "$stage"
cp "$repo_root/README.md" "$repo_root/LICENSE" "$stage/"

if [ -n "$runtime_tag" ]; then
    source_dir="$config_dir/runtime/$runtime_tag/$runtime_backend"
    if [ ! -f "$source_dir/llama-server" ]; then
        echo "no llama-server in $source_dir; install the runtime first:" >&2
        echo "  llamapulse runtime install --backend $runtime_backend" >&2
        exit 1
    fi
    mkdir -p "$stage/runtime/$runtime_tag"
    cp -a "$source_dir" "$stage/runtime/$runtime_tag/$runtime_backend"
    echo "bundled runtime $runtime_tag/$runtime_backend from $source_dir"
fi

archive="$out_dir/$stage_name.tar.gz"
rm -f "$archive"
tar -C "$out_dir" -czf "$archive" "$stage_name"
tar -tzf "$archive" >/dev/null

echo "created $archive"
du -h "$archive" | awk '{ print "size: " $1 }'
echo "run: $bundle_root/llama_pulse"
