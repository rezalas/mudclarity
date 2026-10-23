#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

# Adjust this path so it points at the directory containing the
# `skald/` folder. For a sibling git clone called `skald`, it's `../skald`.
SKALD_ROOT="./vendor/skald"

odin build . \
    -collection:gui="${SKALD_ROOT}" \
    -debug \
    -out:build/mudclarity

if [[ "${1:-}" == "run" ]]; then
    exec ./build/mudclarity
fi