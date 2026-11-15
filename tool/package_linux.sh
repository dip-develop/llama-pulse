#!/usr/bin/env bash
#
# Compatibility shim. The Linux packager lives in the cross-platform Dart tool
# packages/llama_pulse_core/tool/package_app.dart, which packages Linux, Windows
# and macOS bundles. This script keeps the old entry point working for docs and
# CI: it resolves the repository root from its own location, changes there and
# runs the tool for the Linux target, forwarding every argument and the exit
# code (usage errors still exit 2).
#
# Usage:
#   tool/package_linux.sh
#   tool/package_linux.sh --runtime v0.8.0 cuda13
#   tool/package_linux.sh --skip-build --bundle apps/llama_pulse/build/linux/x64/debug/bundle
#
# See docs/packaging.md.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

exec dart run packages/llama_pulse_core/tool/package_app.dart --os linux "$@"
