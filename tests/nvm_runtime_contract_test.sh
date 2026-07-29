#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-nvm-runtime-tests.XXXXXX")"
TEST_COUNT=0

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run_test() {
    local name="$1"

    "$name"
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "ok $TEST_COUNT - $name"
}

make_fake_node() {
    local node_bin="$1"

    mkdir -p "$node_bin"
    cat > "$node_bin/node" <<'EOF'
#!/bin/bash
printf 'v%s\n' "$TEST_NVM_NODE_VERSION"
EOF
    chmod +x "$node_bin/node"
}

load_runtime_fixture() {
    local fixture_root="$1"

    mkdir -p "$fixture_root/home/.nvm" "$fixture_root/bin"
    make_fake_node "$fixture_root/home/.nvm/versions/node/v24.18.0/bin"
    export HOME="$fixture_root/home"
    export NVM_DIR="$HOME/.nvm"
    export TEST_NVM_STATE="$fixture_root/nvm-state"
    export TEST_NVM_LOG="$fixture_root/nvm.log"
    export TEST_NVM_NODE_VERSION="24.18.0"
    export PATH="$fixture_root/bin:$PATH"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/tests/fakes/stateful-nvm.sh"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/runtime-environment.sh"
}

test_absent_runtime_installs_then_sets_and_activates_exact_default() {
    local fixture_root="$TEST_TMP_ROOT/absent"

    load_runtime_fixture "$fixture_root"
    bootstrap_ensure_nvm_node_runtime "24.18.0" || fail "absent exact runtime should converge"

    grep -Fxq 'install 24.18.0' "$TEST_NVM_LOG" || fail "missing runtime must be installed"
    grep -Fxq 'alias default 24.18.0' "$TEST_NVM_LOG" || fail "default alias must target exact runtime"
    grep -Fxq 'use 24.18.0' "$TEST_NVM_LOG" || fail "exact runtime must be activated"
    [ "$(cat "$TEST_NVM_STATE/runtime")" = "24.18.0" ] || fail "installed runtime state must be exact"
    [ "$(cat "$TEST_NVM_STATE/default")" = "24.18.0" ] || fail "default alias state must be exact"
}

test_existing_exact_runtime_is_reused_without_install_or_alias_mutation() {
    local fixture_root="$TEST_TMP_ROOT/existing"

    load_runtime_fixture "$fixture_root"
    mkdir -p "$TEST_NVM_STATE"
    printf '24.18.0\n' > "$TEST_NVM_STATE/runtime"
    printf '24.18.0\n' > "$TEST_NVM_STATE/default"

    bootstrap_ensure_nvm_node_runtime "24.18.0" || fail "existing exact runtime should remain valid"

    if grep -Eq '^(install|alias default) ' "$TEST_NVM_LOG"; then
        fail "existing exact runtime and default must not be mutated"
    fi
    grep -Fxq 'use 24.18.0' "$TEST_NVM_LOG" || fail "existing exact runtime must still be activated"
}

test_wrong_default_is_repaired_without_reinstalling_exact_runtime() {
    local fixture_root="$TEST_TMP_ROOT/wrong-default"

    load_runtime_fixture "$fixture_root"
    mkdir -p "$TEST_NVM_STATE"
    printf '24.18.0\n' > "$TEST_NVM_STATE/runtime"
    printf '22.0.0\n' > "$TEST_NVM_STATE/default"

    bootstrap_ensure_nvm_node_runtime "24.18.0" || fail "wrong default should be repaired"

    if grep -Fxq 'install 24.18.0' "$TEST_NVM_LOG"; then
        fail "exact installed runtime must not be reinstalled"
    fi
    grep -Fxq 'alias default 24.18.0' "$TEST_NVM_LOG" || fail "wrong default must be repaired"
}

test_wrong_activated_node_fails_verification() {
    local fixture_root="$TEST_TMP_ROOT/wrong-node"

    load_runtime_fixture "$fixture_root"
    mkdir -p "$TEST_NVM_STATE"
    printf '24.18.0\n' > "$TEST_NVM_STATE/runtime"
    printf '24.18.0\n' > "$TEST_NVM_STATE/default"
    export TEST_NVM_NODE_VERSION="24.17.0"

    if bootstrap_ensure_nvm_node_runtime "24.18.0"; then
        fail "wrong activated Node version must fail verification"
    fi
}

run_test test_absent_runtime_installs_then_sets_and_activates_exact_default
run_test test_existing_exact_runtime_is_reused_without_install_or_alias_mutation
run_test test_wrong_default_is_repaired_without_reinstalling_exact_runtime
run_test test_wrong_activated_node_fails_verification

echo "1..$TEST_COUNT"
