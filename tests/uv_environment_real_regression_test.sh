#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-real-uv-regression.XXXXXX")"
ENVIRONMENT_DIR="$TEST_TMP_ROOT/bootstrap-python"
FIRST_OUTPUT="$TEST_TMP_ROOT/first.txt"
SECOND_OUTPUT="$TEST_TMP_ROOT/second.txt"
PYTHON_BIN=""

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

if ! command -v uv >/dev/null 2>&1; then
    echo "ok 1 - valid_existing_environment_skips_real_uv_venv # SKIP uv unavailable"
    echo "1..1"
    exit 0
fi

if command -v python3.14 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3.14)"
elif command -v brew >/dev/null 2>&1; then
    PYTHON_PREFIX="$(brew --prefix python@3.14 2>/dev/null || true)"
    if [ -x "$PYTHON_PREFIX/bin/python3.14" ]; then
        PYTHON_BIN="$PYTHON_PREFIX/bin/python3.14"
    fi
fi

if [ -z "$PYTHON_BIN" ]; then
    echo "ok 1 - valid_existing_environment_skips_real_uv_venv # SKIP Python 3.14 unavailable"
    echo "1..1"
    exit 0
fi

/bin/bash "$REPO_ROOT/scripts/lib/managed-python-environment.sh" \
    ensure \
    --python "$PYTHON_BIN" \
    --environment "$ENVIRONMENT_DIR" \
    --profile shared-baseline \
    --source-id real-uv-regression \
    --run-id real-uv-first > "$FIRST_OUTPUT" 2>&1 ||
    fail "the real uv seam should create an owned environment"

MANIFEST_DIGEST_BEFORE="$(shasum -a 256 \
    "$ENVIRONMENT_DIR/.dev-env-bootstrap-owner" | awk '{print $1}')"
PYVENV_DIGEST_BEFORE="$(shasum -a 256 \
    "$ENVIRONMENT_DIR/pyvenv.cfg" | awk '{print $1}')"

/bin/bash "$REPO_ROOT/scripts/lib/managed-python-environment.sh" \
    ensure \
    --python "$PYTHON_BIN" \
    --environment "$ENVIRONMENT_DIR" \
    --profile shared-baseline \
    --source-id real-uv-regression \
    --run-id real-uv-second > "$SECOND_OUTPUT" 2>&1 ||
    fail "the real uv seam should reuse a valid existing environment"

grep -Fq "state=valid_exact disposition=satisfied" "$SECOND_OUTPUT" ||
    fail "the second real uv invocation should report exact reuse"
[ "$MANIFEST_DIGEST_BEFORE" = "$(shasum -a 256 \
    "$ENVIRONMENT_DIR/.dev-env-bootstrap-owner" | awk '{print $1}')" ] ||
    fail "exact reuse should not rewrite the ownership manifest"
[ "$PYVENV_DIGEST_BEFORE" = "$(shasum -a 256 \
    "$ENVIRONMENT_DIR/pyvenv.cfg" | awk '{print $1}')" ] ||
    fail "exact reuse should not rewrite the environment"

if find "$TEST_TMP_ROOT" -maxdepth 1 \
        -name 'bootstrap-python.staging.*' -print -quit | grep -q .; then
    fail "exact reuse should leave no staging directory"
fi

echo "ok 1 - valid_existing_environment_skips_real_uv_venv"
echo "1..1"
