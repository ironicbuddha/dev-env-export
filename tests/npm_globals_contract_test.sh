#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_BASE="${TMPDIR:-/tmp}"
TEST_TMP_ROOT="$(mktemp -d "${TEST_TMP_BASE%/}/dev-env-npm-globals-tests.XXXXXX")"
FIXTURE_ROOT="$TEST_TMP_ROOT/fixture"
NODE_BIN="$FIXTURE_ROOT/home/.nvm/versions/node/v24.18.0/bin"
OUTPUT_FILE="$FIXTURE_ROOT/output.txt"
ACTION_LOG="$FIXTURE_ROOT/actions.log"
NPM_PREFIX="$FIXTURE_ROOT/home/.nvm/versions/node/v24.18.0"
NPM_GLOBAL_ROOT="$NPM_PREFIX/lib/node_modules"
NPMRC_BEFORE="$FIXTURE_ROOT/npmrc-before"
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
cp "$REPO_ROOT/scripts/lib/npm-global-operations.sh" "$FIXTURE_ROOT/scripts/lib/npm-global-operations.sh"
cp "$REPO_ROOT/tests/fixtures/nvm-stub.sh" "$FIXTURE_ROOT/nvm/nvm.sh"

for tool in brew node npm corepack codex claude gemini vercel; do
    cp "$REPO_ROOT/tests/fixtures/npm-globals-tool-stub.sh" "$NODE_BIN/$tool"
    chmod +x "$NODE_BIN/$tool"
done

printf '%s\n' \
    'prefix=/tmp/step-03-must-not-own' \
    '//registry.example.test/:_authToken=preserve-step-03-token' \
    > "$FIXTURE_ROOT/home/.npmrc"
cp "$FIXTURE_ROOT/home/.npmrc" "$NPMRC_BEFORE"

if PATH="$NODE_BIN:/usr/bin:/bin" \
        HOME="$FIXTURE_ROOT/home" \
        NVM_DIR="$FIXTURE_ROOT/home/.nvm" \
        TEST_ACTION_LOG="$ACTION_LOG" \
        TEST_NPM_GLOBAL_ROOT="$NPM_GLOBAL_ROOT" \
        TEST_FAKE_NODE_BIN="$NODE_BIN" \
        TEST_NVM_PREFIX="$FIXTURE_ROOT/nvm" \
        /bin/bash "$FIXTURE_ROOT/scripts/03-install-npm-globals.sh" \
        --profile carlo-baseline > "$OUTPUT_FILE" 2>&1; then
    STATUS=0
else
    STATUS=$?
fi

if [ "$STATUS" -ne 0 ]; then
    sed 's/^/  | /' "$OUTPUT_FILE" >&2
    fail "npm globals fixture should complete, got exit $STATUS"
fi

ENABLE_LINE="$(grep -n -F 'corepack enable' "$ACTION_LOG" | cut -d: -f1 || true)"

[ -n "$ENABLE_LINE" ] || fail "step 3 did not enable Corepack"

if grep -Fq 'corepack install --global pnpm@latest' "$ACTION_LOG"; then
    fail "step 3 must not pre-provision a machine-wide pnpm version"
fi

if grep -Fq 'pnpm --version' "$ACTION_LOG"; then
    fail "step 3 must not invoke pnpm before a project pins its version"
fi

if ! grep -Fq 'npm install -g @google/gemini-cli' "$ACTION_LOG"; then
    fail "Carlo Baseline must install Gemini CLI through nvm-managed npm"
fi

if [ "$(grep -Fc 'npm list -g @google/gemini-cli' "$ACTION_LOG")" -ne 1 ]; then
    fail "each installed npm global must be re-verified after installation"
fi

cmp -s "$NPMRC_BEFORE" "$FIXTURE_ROOT/home/.npmrc" ||
    fail "step 3 must not claim or mutate npm configuration"
if [ -e "$FIXTURE_ROOT/home/.dev-env-npmrc-backups" ]; then
    fail "step 3 must not create npm configuration backups"
fi

if ! PATH="$NODE_BIN:/usr/bin:/bin" \
        HOME="$FIXTURE_ROOT/home" \
        NVM_DIR="$FIXTURE_ROOT/home/.nvm" \
        TEST_ACTION_LOG="$ACTION_LOG" \
        TEST_NPM_GLOBAL_ROOT="$NPM_GLOBAL_ROOT" \
        TEST_FAKE_NODE_BIN="$NODE_BIN" \
        TEST_NVM_PREFIX="$FIXTURE_ROOT/nvm" \
        /bin/bash "$FIXTURE_ROOT/scripts/03-install-npm-globals.sh" \
        --profile carlo-baseline >> "$OUTPUT_FILE" 2>&1; then
    fail "an unchanged npm-global rerun should complete"
fi

if [ "$(grep -Fc 'corepack enable' "$ACTION_LOG")" -ne 1 ]; then
    fail "an unchanged rerun must retain verified Corepack shims without enabling again"
fi

for package in corepack @openai/codex @anthropic-ai/claude-code @google/gemini-cli vercel; do
    if [ "$(grep -Fc "npm install -g $package" "$ACTION_LOG")" -ne 1 ]; then
        fail "an unchanged rerun must retain the verified $package global package"
    fi
done

if PATH="$NODE_BIN:/usr/bin:/bin" \
        HOME="$FIXTURE_ROOT/home" \
        NVM_DIR="$FIXTURE_ROOT/home/.nvm" \
        TEST_ACTION_LOG="$ACTION_LOG" \
        TEST_NPM_GLOBAL_ROOT="$NPM_GLOBAL_ROOT" \
        TEST_COREPACK_VERSION_FAIL=1 \
        TEST_FAKE_NODE_BIN="$NODE_BIN" \
        TEST_NVM_PREFIX="$FIXTURE_ROOT/nvm" \
        /bin/bash "$FIXTURE_ROOT/scripts/03-install-npm-globals.sh" \
        --profile carlo-baseline >> "$OUTPUT_FILE" 2>&1; then
    fail "a broken Corepack executable must stop for manual recovery"
fi

if [ "$(grep -Fc 'corepack enable' "$ACTION_LOG")" -ne 1 ]; then
    fail "a broken Corepack executable must not re-enable over existing shims"
fi

if PATH="$NODE_BIN:/usr/bin:/bin" \
        HOME="$FIXTURE_ROOT/home" \
        NVM_DIR="$FIXTURE_ROOT/home/.nvm" \
        TEST_ACTION_LOG="$ACTION_LOG" \
        TEST_NPM_GLOBAL_ROOT="$FIXTURE_ROOT/foreign/lib/node_modules" \
        TEST_FAKE_NODE_BIN="$NODE_BIN" \
        TEST_NVM_PREFIX="$FIXTURE_ROOT/nvm" \
        /bin/bash "$FIXTURE_ROOT/scripts/03-install-npm-globals.sh" \
        --profile carlo-baseline >> "$OUTPUT_FILE" 2>&1; then
    fail "a foreign npm global root must stop for manual recovery"
fi

if [ "$(grep -Fc 'npm install -g corepack' "$ACTION_LOG")" -ne 1 ]; then
    fail "a foreign npm global root must not receive an install"
fi

if PATH="$NODE_BIN:/usr/bin:/bin" \
        HOME="$FIXTURE_ROOT/home" \
        NVM_DIR="$FIXTURE_ROOT/home/.nvm" \
        TEST_ACTION_LOG="$ACTION_LOG" \
        TEST_NPM_GLOBAL_ROOT="$NPM_GLOBAL_ROOT" \
        TEST_NPM_LIST_FAIL_PACKAGE="@google/gemini-cli" \
        TEST_FAKE_NODE_BIN="$NODE_BIN" \
        TEST_NVM_PREFIX="$FIXTURE_ROOT/nvm" \
        /bin/bash "$FIXTURE_ROOT/scripts/03-install-npm-globals.sh" \
        --profile carlo-baseline >> "$OUTPUT_FILE" 2>&1; then
    fail "an existing but invalid npm global must stop for manual recovery"
fi

if [ "$(grep -Fc 'npm install -g @google/gemini-cli' "$ACTION_LOG")" -ne 1 ]; then
    fail "an unknown npm lifecycle residue must not trigger a second install"
fi

rmdir "$NPM_GLOBAL_ROOT/vercel"
if PATH="$NODE_BIN:/usr/bin:/bin" \
        HOME="$FIXTURE_ROOT/home" \
        NVM_DIR="$FIXTURE_ROOT/home/.nvm" \
        TEST_ACTION_LOG="$ACTION_LOG" \
        TEST_NPM_GLOBAL_ROOT="$NPM_GLOBAL_ROOT" \
        TEST_NPM_INSTALL_FAIL_PACKAGE=vercel \
        TEST_NPM_INSTALL_LEAVES_RESIDUE=1 \
        TEST_FAKE_NODE_BIN="$NODE_BIN" \
        TEST_NVM_PREFIX="$FIXTURE_ROOT/nvm" \
        /bin/bash "$FIXTURE_ROOT/scripts/03-install-npm-globals.sh" \
        --profile carlo-baseline >> "$OUTPUT_FILE" 2>&1; then
    fail "a failed npm install with lifecycle residue must stop for manual recovery"
fi

if [ "$(grep -Fc 'npm install -g @openai/codex' "$ACTION_LOG")" -ne 1 ]; then
    fail "a later failed npm install must retain earlier verified global packages"
fi
if [ "$(grep -Fc 'npm install -g vercel' "$ACTION_LOG")" -ne 2 ]; then
    fail "a failed npm install must attempt only its missing package"
fi

echo "ok 1 - npm_globals_uses_nvm_without_claiming_npm_configuration"
echo "1..1"
