#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-resilience-tests.XXXXXX")"
TEST_COUNT=0

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file_contains() {
    local file="$1"
    local expected="$2"

    grep -Fq "$expected" "$file" || fail "$file does not contain: $expected"
}

assert_array_contains() {
    local wanted="$1"
    shift
    local item=""

    for item in "$@"; do
        [ "$item" = "$wanted" ] && return 0
    done

    fail "array does not contain: $wanted"
}

test_profile_expectations_are_complete() {
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-expectations.sh"

    bootstrap_load_expectations carlo-baseline

    assert_array_contains "openspec" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
    assert_array_contains "betterdisplay" "${BOOTSTRAP_REQUIRED_CASKS[@]}"
    assert_array_contains "obsidian" "${BOOTSTRAP_REQUIRED_CASKS[@]}"
    assert_array_contains "firefox" "${BOOTSTRAP_REQUIRED_CASKS[@]}"
    assert_array_contains "BetterDisplay.app" "${BOOTSTRAP_REQUIRED_APP_BUNDLES[@]}"
    assert_array_contains "Obsidian.app" "${BOOTSTRAP_REQUIRED_APP_BUNDLES[@]}"
    assert_array_contains "Firefox.app" "${BOOTSTRAP_REQUIRED_APP_BUNDLES[@]}"
}

test_runtime_activation_requires_exact_node() {
    local fake_bin="$TEST_TMP_ROOT/runtime-bin"

    mkdir -p "$fake_bin"
    printf '#!/bin/bash\nprintf "v%%s\\n" "${TEST_NODE_VERSION}"\n' > "$fake_bin/node"
    chmod +x "$fake_bin/node"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/runtime-environment.sh"

    nvm() {
        [ "$1" = "use" ] || return 1
        NVM_BIN="$fake_bin"
        export NVM_BIN
    }

    TEST_NODE_VERSION=24.18.0
    export TEST_NODE_VERSION
    bootstrap_activate_nvm_node 24.18.0 || fail "exact Node version should activate"

    TEST_NODE_VERSION=24.17.0
    export TEST_NODE_VERSION
    if bootstrap_activate_nvm_node 24.18.0; then
        fail "wrong Node version must not satisfy the runtime contract"
    fi
}

test_app_bundle_must_be_launchable() {
    local valid_app="$TEST_TMP_ROOT/Valid.app"
    local broken_app="$TEST_TMP_ROOT/Broken.app"

    mkdir -p "$valid_app/Contents/MacOS" "$broken_app/Contents/MacOS"
    printf '<plist/>\n' > "$valid_app/Contents/Info.plist"
    printf '<plist/>\n' > "$broken_app/Contents/Info.plist"
    printf '#!/bin/bash\nexit 0\n' > "$valid_app/Contents/MacOS/valid"
    chmod +x "$valid_app/Contents/MacOS/valid"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/app-bundle.sh"

    bootstrap_app_bundle_usable "$valid_app" || fail "valid app bundle was rejected"
    if bootstrap_app_bundle_usable "$broken_app"; then
        fail "bundle without an executable must be rejected"
    fi
}

test_required_cask_failure_is_gating_and_broken_bundle_repairs() {
    local applications_dir="$TEST_TMP_ROOT/applications"
    local app_path="$applications_dir/Test App.app"
    local cask_state="missing"

    mkdir -p "$applications_dir"
    BOOTSTRAP_APPLICATIONS_DIR="$applications_dir"
    export BOOTSTRAP_APPLICATIONS_DIR

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/app-bundle.sh"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/cask-state.sh"

    brew() {
        case "$1" in
            info)
                printf '%s\n' '{"casks":[{"artifacts":[{"app":["Test App.app"]}]}]}'
                ;;
            list)
                [ "$cask_state" = "registered" ]
                ;;
            install)
                return 42
                ;;
            reinstall)
                mkdir -p "$app_path/Contents/MacOS"
                printf '<plist/>\n' > "$app_path/Contents/Info.plist"
                printf '#!/bin/bash\nexit 0\n' > "$app_path/Contents/MacOS/test-app"
                chmod +x "$app_path/Contents/MacOS/test-app"
                ;;
            *)
                return 1
                ;;
        esac
    }

    if bootstrap_install_required_cask test-app >/dev/null; then
        fail "failed required cask install was treated as optional"
    fi

    cask_state="registered"
    bootstrap_install_required_cask test-app >/dev/null || \
        fail "registered broken app bundle was not repaired"
    bootstrap_app_bundle_usable "$app_path" || fail "repaired app bundle is unusable"
}

test_json_merge_preserves_existing_and_adds_defaults() {
    local existing="$TEST_TMP_ROOT/existing.json"
    local incoming="$TEST_TMP_ROOT/incoming.json"
    local output="$TEST_TMP_ROOT/merged.json"

    printf '%s\n' '{"theme":"custom","tools":["one"],"nested":{"keep":true}}' > "$existing"
    printf '%s\n' '{"theme":"default","tools":["one","two"],"nested":{"add":true}}' > "$incoming"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/json-merge.sh"

    bootstrap_merge_json "$existing" "$incoming" "$output" "$(command -v python3)"
    assert_file_contains "$output" '"theme": "default"'
    assert_file_contains "$output" '"two"'
    assert_file_contains "$output" '"keep": true'
    assert_file_contains "$output" '"add": true'
}

test_artifact_digest_rejects_tampering() {
    local artifact="$TEST_TMP_ROOT/artifact.zip"
    local digest=""

    printf 'trusted artifact\n' > "$artifact"
    digest="$(shasum -a 256 "$artifact" | awk '{print $1}')"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/artifact-integrity.sh"

    bootstrap_verify_sha256 "$artifact" "$digest" || fail "matching digest was rejected"
    printf 'tampered\n' >> "$artifact"
    if bootstrap_verify_sha256 "$artifact" "$digest"; then
        fail "tampered artifact satisfied the original digest"
    fi
}

test_copy_refuses_symlink_destination() {
    local source_file="$TEST_TMP_ROOT/source"
    local external_file="$TEST_TMP_ROOT/external"
    local destination="$TEST_TMP_ROOT/home/.zshrc"
    local backup_dir="$TEST_TMP_ROOT/backups"

    mkdir -p "$(dirname "$destination")"
    printf 'repo value\n' > "$source_file"
    printf 'external value\n' > "$external_file"
    ln -s "$external_file" "$destination"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/file-safety.sh"

    if bootstrap_copy_file_with_backup "$source_file" "$destination" "$backup_dir"; then
        fail "copy followed a destination symlink"
    fi
    assert_file_contains "$external_file" "external value"
    if grep -Fq "repo value" "$external_file"; then
        fail "external symlink target was overwritten"
    fi
}

test_managed_shell_write_is_atomic_and_backed_up() {
    local shell_file="$TEST_TMP_ROOT/managed-home/.zshrc"
    local backup_dir="$TEST_TMP_ROOT/shell-backups"
    local before="$TEST_TMP_ROOT/before"

    mkdir -p "$(dirname "$shell_file")"
    printf 'export ORIGINAL=1\n' > "$shell_file"
    cp "$shell_file" "$before"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/managed-shell-block.sh"

    if DEV_ENV_TEST_FAIL_BEFORE_REPLACE=1 bootstrap_write_managed_shell_block \
            "$shell_file" "# BEGIN TEST" "# END TEST" "$backup_dir" <<'EOF'
# BEGIN TEST
export MANAGED=1
# END TEST
EOF
    then
        fail "injected pre-replace failure unexpectedly succeeded"
    fi
    cmp -s "$before" "$shell_file" || fail "failed write changed the original shell file"

    bootstrap_write_managed_shell_block \
        "$shell_file" "# BEGIN TEST" "# END TEST" "$backup_dir" <<'EOF'
# BEGIN TEST
export MANAGED=1
# END TEST
EOF

    assert_file_contains "$shell_file" "export ORIGINAL=1"
    assert_file_contains "$shell_file" "export MANAGED=1"
    [ -f "$backup_dir/.zshrc" ] || fail "original shell file was not backed up"
}

test_path_check_returns_nonzero_for_required_miss() {
    local fixture_root="$TEST_TMP_ROOT/path-check"
    local output_file="$fixture_root/output.txt"
    local status=0

    mkdir -p "$fixture_root/scripts/lib" "$fixture_root/home"
    cp "$REPO_ROOT/scripts/10-check-paths.sh" "$fixture_root/scripts/10-check-paths.sh"
    cp "$REPO_ROOT/scripts/lib/bootstrap-profile.sh" "$fixture_root/scripts/lib/bootstrap-profile.sh"
    cp "$REPO_ROOT/scripts/lib/runtime-environment.sh" "$fixture_root/scripts/lib/runtime-environment.sh"
    cp "$REPO_ROOT/scripts/lib/app-bundle.sh" "$fixture_root/scripts/lib/app-bundle.sh"
    printf '%s\n' \
        'bootstrap_load_expectations() {' \
        '    BOOTSTRAP_REQUIRED_COMMANDS=(definitely-missing-bootstrap-command)' \
        '    BOOTSTRAP_REQUIRED_APP_BUNDLES=(Definitely-Missing.app)' \
        '}' > "$fixture_root/scripts/lib/bootstrap-expectations.sh"

    if HOME="$fixture_root/home" /bin/bash "$fixture_root/scripts/10-check-paths.sh" \
            --profile shared-baseline > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    [ "$status" -eq 1 ] || fail "required path miss should exit 1, got $status"
    assert_file_contains "$output_file" "[MISS] definitely-missing-bootstrap-command"
    assert_file_contains "$output_file" "Path check failed with"
}

test_dotfiles_entrypoint_refuses_external_symlink() {
    local fixture_root="$TEST_TMP_ROOT/dotfiles-entrypoint"
    local external_file="$fixture_root/external-zshrc"
    local destination="$fixture_root/home/.zshrc"
    local output_file="$fixture_root/output.txt"
    local status=0

    mkdir -p "$(dirname "$destination")"
    printf 'external value\n' > "$external_file"
    ln -s "$external_file" "$destination"

    if HOME="$fixture_root/home" /bin/bash "$REPO_ROOT/scripts/05-setup-dotfiles.sh" \
            > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    [ "$status" -ne 0 ] || fail "dotfiles entrypoint followed an external symlink"
    assert_file_contains "$output_file" "Refusing to replace symlink destination"
    assert_file_contains "$external_file" "external value"
}

test_shared_shell_entrypoint_preserves_file_before_atomic_replace() {
    local fixture_root="$TEST_TMP_ROOT/shared-shell-entrypoint"
    local shell_file="$fixture_root/home/.zprofile"
    local before="$fixture_root/before"
    local output_file="$fixture_root/output.txt"
    local status=0

    mkdir -p "$(dirname "$shell_file")"
    printf 'export ORIGINAL=1\n' > "$shell_file"
    cp "$shell_file" "$before"

    if HOME="$fixture_root/home" DEV_ENV_TEST_FAIL_BEFORE_REPLACE=1 \
            /bin/bash "$REPO_ROOT/scripts/15-setup-shared-shell.sh" \
            > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    [ "$status" -eq 97 ] || fail "injected atomic-write failure should exit 97, got $status"
    cmp -s "$before" "$shell_file" || fail "entrypoint changed shell file before atomic replace"

    HOME="$fixture_root/home" /bin/bash "$REPO_ROOT/scripts/15-setup-shared-shell.sh" \
        > "$output_file" 2>&1
    assert_file_contains "$shell_file" "export ORIGINAL=1"
    assert_file_contains "$shell_file" "# BEGIN DEV ENV SHARED HOMEBREW"
}

run_test() {
    local name="$1"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - ${name#test_}"
}

run_test test_profile_expectations_are_complete
run_test test_runtime_activation_requires_exact_node
run_test test_app_bundle_must_be_launchable
run_test test_required_cask_failure_is_gating_and_broken_bundle_repairs
run_test test_json_merge_preserves_existing_and_adds_defaults
run_test test_artifact_digest_rejects_tampering
run_test test_copy_refuses_symlink_destination
run_test test_managed_shell_write_is_atomic_and_backed_up
run_test test_path_check_returns_nonzero_for_required_miss
run_test test_dotfiles_entrypoint_refuses_external_symlink
run_test test_shared_shell_entrypoint_preserves_file_before_atomic_replace

echo "1..$TEST_COUNT"
