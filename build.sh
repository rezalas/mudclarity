#!/usr/bin/env bash
# Usage:
#   ./build.sh          # debug build to build/mudclarity
#   ./build.sh run      # build and run
#   ./build.sh test     # vet the app and run the test suite
#
# Set RIFTSHADOW_AREA_DIR to a Riftshadow area/ directory to also parse
# every area in its area.lst during `test`.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

# Adjust this path so it points at the directory containing the
# `skald/` folder. For a sibling git clone called `skald`, it's `../skald`.
SKALD_ROOT="./vendor/skald"

if [[ "${1:-}" == "test" ]]; then
    odin check . -collection:gui="${SKALD_ROOT}" -vet -vet-style \
        -vet-packages:main,formats,models,validation,clarity,workspace

    CORPUS_DEFINE=()
    if [[ -n "${RIFTSHADOW_AREA_DIR:-}" ]]; then
        CORPUS_DEFINE=(-define:MUDCLARITY_CORPUS_DIR="${RIFTSHADOW_AREA_DIR}")
    fi
    for package in formats validation clarity workspace; do
        odin test "${package}" \
            -collection:gui="${SKALD_ROOT}" \
            -vet -strict-style \
            "${CORPUS_DEFINE[@]+"${CORPUS_DEFINE[@]}"}" \
            -out:"build/${package}_test"
    done
    exit 0
fi

odin build . \
    -collection:gui="${SKALD_ROOT}" \
    -debug \
    -out:build/mudclarity

if [[ "${1:-}" == "run" ]]; then
    exec ./build/mudclarity
fi
