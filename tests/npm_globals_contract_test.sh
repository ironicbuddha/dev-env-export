#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_BASE="${TMPDIR:-/tmp}"
TEST_TMP_ROOT="$(mktemp -d "${TEST_TMP_BASE%/}/dev-env-npm-globals-tests.XXXXXX")"
FIXTURE_ROOT="$TEST_TMP_ROOT/fixture"
NODE_BIN="$FIXTURE_ROOT/home/.nvm/versions/node/v24.18.0/bin"
OUTPUT_FILE="$FIXTURE_ROOT/output.txt"
ACTION_LOG="$FIXTURE_ROOT/actions.log"
STATUS=0

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$FIXTURE_ROOT/scripts/lib" "$FIXTURE_ROOT/nvm" "$NODE_BIN"
cp "$REPO_ROOT/scripts/03-install-npm-globals.sh" "$FIXTURE_ROOT/scripts/03-install-npm-globals.sh"
cp "$REPO_ROOT/scripts/lib/bootstrap-profile.sh" "$FIXTURE_ROOT/scripts/lib/bootstrap-profile.sh"
cp "$REPO_ROOT/scripts/lib/runtime-environment.sh" "$FIXTURE_ROOT/scripts/lib/runtime-environment.sh"
cp "$REPO_ROOT/tests/fixtures/nvm-stub.sh" "$FIXTURE_ROOT/nvm/nvm.sh"

for tool in brew node npm corepack pnpm codex vercel; do
    cp "$REPO_ROOT/tests/fixtures/npm-globals-tool-stub.sh" "$NODE_BIN/$tool"
    chmod +x "$NODE_BIN/$tool"
done

if PATH="$NODE_BIN:/usr/bin:/bin" \
        HOME="$FIXTURE_ROOT/home" \
        NVM_DIR="$FIXTURE_ROOT/home/.nvm" \
        TEST_ACTION_LOG="$ACTION_LOG" \
        TEST_FAKE_NODE_BIN="$NODE_BIN" \
        TEST_NVM_PREFIX="$FIXTURE_ROOT/nvm" \
        TEST_PNPM_MARKER="$FIXTURE_ROOT/pnpm-provisioned" \
        /bin/bash "$FIXTURE_ROOT/scripts/03-install-npm-globals.sh" \
        --profile shared-baseline > "$OUTPUT_FILE" 2>&1; then
    STATUS=0
else
    STATUS=$?
fi

if [ "$STATUS" -ne 0 ]; then
    sed 's/^/  | /' "$OUTPUT_FILE" >&2
    fail "npm globals fixture should complete, got exit $STATUS"
fi

INSTALL_LINE="$(grep -n -F 'corepack install --global pnpm@latest' "$ACTION_LOG" | cut -d: -f1 || true)"
VERSION_LINE="$(grep -n -F 'pnpm --version' "$ACTION_LOG" | cut -d: -f1 || true)"

[ -n "$INSTALL_LINE" ] || fail "step 3 did not explicitly provision pnpm"
[ -n "$VERSION_LINE" ] || fail "step 3 did not verify pnpm"
[ "$INSTALL_LINE" -lt "$VERSION_LINE" ] || fail "pnpm was invoked before Corepack provisioned it"

if grep -Fq 'corepack implicit download prompt' "$ACTION_LOG"; then
    fail "pnpm reached Corepack's implicit first-download prompt"
fi

grep -Fq 'pnpm version: 11.13.1' "$OUTPUT_FILE" || \
    fail "step 3 did not report the provisioned pnpm version"

echo "ok 1 - pnpm_is_provisioned_before_version_check"
echo "1..1"
