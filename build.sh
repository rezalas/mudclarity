#!/usr/bin/env bash
# Usage:
#   ./build.sh                    # debug build to build/mudclarity
#   ./build.sh run                # build and run
#   ./build.sh test               # vet the app and run the test suite
#   ./build.sh test <name>        # run one test, e.g. formats.test_room_basic_fields
#   ./build.sh debug-tests        # build each package's tests for a debugger,
#                                 # to build/<package>_test_debug
#   ./build.sh debug-tests <name> # build one test for a debugger,
#                                 # to build/single_test_debug
#
# Set RIFTSHADOW_AREA_DIR to a Riftshadow area/ directory to also parse
# every area in its area.lst during `test` and `debug-tests`.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

# Adjust this path so it points at the directory containing the
# `skald/` folder. For a sibling git clone called `skald`, it's `../skald`.
SKALD_ROOT="./vendor/skald"

TEST_PACKAGES=(formats validation clarity workspace)

CORPUS_DEFINE=()
if [[ -n "${RIFTSHADOW_AREA_DIR:-}" ]]; then
    CORPUS_DEFINE=(-define:MUDCLARITY_CORPUS_DIR="${RIFTSHADOW_AREA_DIR}")
fi

# The package of a test name ("formats.test_x" -> "formats"), checked
# against TEST_PACKAGES.
package_of() {
    local package="${1%%.*}"
    for known in "${TEST_PACKAGES[@]}"; do
        if [[ "${package}" == "${known}" && "$1" == *.* ]]; then
            echo "${package}"
            return
        fi
    done
    echo "not a test name: $1 (expected <package>.<test>, package one of ${TEST_PACKAGES[*]})" >&2
    exit 2
}

if [[ "${1:-}" == "debug-tests" ]]; then
    # One test thread keeps breakpoints in order. ODIN_TEST_NAMES and
    # ODIN_TEST_THREADS are compile-time settings, hence a rebuild.
    debug_build() { # <package> <out> [extra flags...]
        local package="$1" out="$2"
        shift 2
        odin build "${package}" \
            -build-mode:test \
            -collection:gui="${SKALD_ROOT}" \
            -debug \
            -define:ODIN_TEST_THREADS=1 \
            "${CORPUS_DEFINE[@]+"${CORPUS_DEFINE[@]}"}" \
            "$@" \
            -out:"${out}"
    }
    if [[ -n "${2:-}" ]]; then
        package="$(package_of "$2")"
        debug_build "${package}" build/single_test_debug -define:ODIN_TEST_NAMES="$2"
    else
        for package in "${TEST_PACKAGES[@]}"; do
            debug_build "${package}" "build/${package}_test_debug"
        done
    fi
    exit 0
fi

if [[ "${1:-}" == "test" ]]; then
    packages=("${TEST_PACKAGES[@]}")
    NAME_DEFINE=()
    if [[ -n "${2:-}" ]]; then
        packages=("$(package_of "$2")")
        NAME_DEFINE=(-define:ODIN_TEST_NAMES="$2")
    else
        odin check . -collection:gui="${SKALD_ROOT}" -vet -vet-style \
            -vet-packages:main,formats,models,validation,clarity,workspace
    fi

    for package in "${packages[@]}"; do
        odin test "${package}" \
            -collection:gui="${SKALD_ROOT}" \
            -vet -strict-style \
            "${CORPUS_DEFINE[@]+"${CORPUS_DEFINE[@]}"}" \
            "${NAME_DEFINE[@]+"${NAME_DEFINE[@]}"}" \
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
