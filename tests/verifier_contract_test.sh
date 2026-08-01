#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-verifier-tests.XXXXXX")"
TEST_COUNT=0

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_equals() {
    local expected="$1" actual="$2" message="$3"

    [ "$expected" = "$actual" ] || fail "$message (expected '$expected', got '$actual')"
}

make_verifier_fixture() {
    local fixture_root="$1" nvm_prefix="$1/nvm" python_prefix="$1/python" script_name=""

    mkdir -p "$fixture_root/scripts/lib" "$fixture_root/home/.nvm/versions/node/v24.18.0/bin" "$fixture_root/fake-bin" \
        "$nvm_prefix" "$python_prefix/bin"
    for script_name in 10-check-paths.sh 12-smoke-test.sh; do
        cp "$REPO_ROOT/scripts/$script_name" "$fixture_root/scripts/$script_name"
    done
    for script_name in bootstrap-profile.sh runtime-environment.sh bootstrap-expectations.sh \
        app-bundle.sh skill-hub-projection.sh operation-policy.sh; do
        cp "$REPO_ROOT/scripts/lib/$script_name" "$fixture_root/scripts/lib/$script_name"
    done

    cat > "$fixture_root/scripts/lib/bootstrap-expectations.sh" <<'EOF'
bootstrap_load_expectations() {
    BOOTSTRAP_NODE_VERSION=24.18.0
    BOOTSTRAP_REQUIRED_COMMANDS=(node)
    BOOTSTRAP_REQUIRED_APP_BUNDLES=(Verifier.app)
}
EOF
    mkdir -p "$fixture_root/Applications/Verifier.app/Contents/MacOS"
    printf '<plist/>\n' > "$fixture_root/Applications/Verifier.app/Contents/Info.plist"
    printf '#!/bin/bash\nexit 0\n' > "$fixture_root/Applications/Verifier.app/Contents/MacOS/verifier"
    : > "$fixture_root/home/.zshrc"
    : > "$fixture_root/home/.zprofile"
    cat > "$fixture_root/fake-bin/brew" <<EOF
#!/bin/bash
case "\$*" in
    shellenv) ;;
    '--prefix nvm') printf '%s\\n' '$nvm_prefix' ;;
    '--prefix python@3.14') printf '%s\\n' '$python_prefix' ;;
    *) exit 1 ;;
esac
EOF
    cat > "$nvm_prefix/nvm.sh" <<'EOF'
nvm() {
    case "$1" in
        use) NVM_BIN="$NVM_DIR/versions/node/v24.18.0/bin"; export NVM_BIN ;;
        *) return 1 ;;
    esac
}
EOF
    cat > "$fixture_root/fake-bin/node" <<'EOF'
#!/bin/bash
printf '%s\n' v24.18.0
EOF
    cat > "$fixture_root/fake-bin/npm" <<'EOF'
#!/bin/bash
exit 0
EOF
    cp "$fixture_root/fake-bin/node" "$fixture_root/home/.nvm/versions/node/v24.18.0/bin/node"
    cp "$fixture_root/fake-bin/npm" "$fixture_root/home/.nvm/versions/node/v24.18.0/bin/npm"
    cat > "$python_prefix/bin/python3.14" <<'EOF'
#!/bin/bash
exit 0
EOF
cat > "$fixture_root/fake-bin/zsh" <<'EOF'
#!/bin/bash
case "$1" in
    -n|-ilc) exit 0 ;;
    *) exit 64 ;;
esac
EOF
    chmod +x "$fixture_root/fake-bin/"* "$nvm_prefix/nvm.sh" "$python_prefix/bin/python3.14" \
        "$fixture_root/Applications/Verifier.app/Contents/MacOS/verifier" \
        "$fixture_root/home/.nvm/versions/node/v24.18.0/bin/"*
}

snapshot_home() {
    local home_dir="$1" snapshot="$2"

    find "$home_dir" -mindepth 1 -print | LC_ALL=C sort > "$snapshot"
}

run_verifier() {
    local fixture_root="$1" script_name="$2" output="$3"

    env -u NVM_DIR \
        HOME="$fixture_root/home" PATH="$fixture_root/fake-bin:/usr/bin:/bin" \
        BOOTSTRAP_APPLICATIONS_DIR="$fixture_root/Applications" \
        /bin/bash "$fixture_root/scripts/$script_name" --profile shared-baseline > "$output" 2>&1
}

test_verifiers_do_not_create_nvm_or_other_home_state() {
    local fixture_root="$TEST_TMP_ROOT/observational" before="$TEST_TMP_ROOT/before" after=""
    local script_name=""

    make_verifier_fixture "$fixture_root"
    snapshot_home "$fixture_root/home" "$before"

    for script_name in 10-check-paths.sh 12-smoke-test.sh; do
        run_verifier "$fixture_root" "$script_name" "$fixture_root/$script_name.out" ||
            fail "$script_name should pass a complete shared-baseline fixture: $(tr '\n' ' ' < "$fixture_root/$script_name.out")"
        after="$TEST_TMP_ROOT/after-${script_name}"
        snapshot_home "$fixture_root/home" "$after"
        cmp -s "$before" "$after" ||
            fail "$script_name created or changed state under HOME"
    done
}

test_verifiers_do_not_create_nvm_state_when_the_runtime_is_missing() {
    local fixture_root="$TEST_TMP_ROOT/missing-nvm" before="$TEST_TMP_ROOT/missing-before" after=""
    local script_name="" status=0

    make_verifier_fixture "$fixture_root"
    rm -rf "$fixture_root/home/.nvm"
    snapshot_home "$fixture_root/home" "$before"

    for script_name in 10-check-paths.sh 12-smoke-test.sh; do
        if run_verifier "$fixture_root" "$script_name" "$fixture_root/$script_name.out"; then
            status=0
        else
            status=$?
        fi
        [ "$status" -eq 1 ] || fail "$script_name should fail when the nvm runtime is absent"
        after="$TEST_TMP_ROOT/missing-after-${script_name}"
        snapshot_home "$fixture_root/home" "$after"
        cmp -s "$before" "$after" ||
            fail "$script_name created nvm or another HOME artifact while reporting a missing runtime"
    done
}

run_test() {
    local name="$1"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - ${name#test_}"
}

run_test test_verifiers_do_not_create_nvm_or_other_home_state
run_test test_verifiers_do_not_create_nvm_state_when_the_runtime_is_missing

echo "1..$TEST_COUNT"
