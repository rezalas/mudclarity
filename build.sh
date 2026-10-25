#!/usr/bin/env bash
# Build, run and test Mud Clarity on macOS and Linux. The commands live in
# tools/build/build.odin (shared with build.bat on Windows):
#   ./build.sh help
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
exec odin run tools/build -out:build/build-tool -- "$@"
