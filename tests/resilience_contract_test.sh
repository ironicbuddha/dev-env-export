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

assert_file_does_not_contain() {
    local file="$1"
    local unexpected="$2"

    if grep -Fq "$unexpected" "$file"; then
        fail "$file unexpectedly contains: $unexpected"
    fi
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

assert_array_excludes() {
    local unwanted="$1"
    shift
    local item=""

    for item in "$@"; do
        [ "$item" = "$unwanted" ] && fail "array unexpectedly contains $unwanted"
    done

    return 0
}

test_profile_expectations_are_complete() {
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-expectations.sh"

    bootstrap_load_expectations carlo-baseline

    assert_array_contains "bun" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
    assert_array_contains "vercel" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
    assert_array_contains "corepack" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
    assert_array_excludes "pnpm" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
    assert_array_excludes "openspec" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
    assert_array_excludes "gsd" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
    assert_array_excludes "taproom" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
    assert_array_excludes "docker" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
    assert_array_excludes "BetterDisplay.app" "${BOOTSTRAP_REQUIRED_APP_BUNDLES[@]}"
    assert_array_excludes "Obsidian.app" "${BOOTSTRAP_REQUIRED_APP_BUNDLES[@]}"
    assert_array_excludes "Docker.app" "${BOOTSTRAP_REQUIRED_APP_BUNDLES[@]}"
    assert_array_excludes "Firefox.app" "${BOOTSTRAP_REQUIRED_APP_BUNDLES[@]}"

    bootstrap_load_expectations shared-baseline
    assert_array_excludes "bun" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
    assert_array_excludes "vercel" "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"
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
    cp "$REPO_ROOT/scripts/lib/skill-hub-projection.sh" "$fixture_root/scripts/lib/skill-hub-projection.sh"
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
    assert_file_contains "$output_file" "Refusing to rewrite symlink shell file"
    assert_file_contains "$external_file" "external value"
}

test_dotfiles_entrypoint_preserves_shell_and_skips_identity_configuration() {
    local fixture_root="$TEST_TMP_ROOT/dotfiles-managed-shell"
    local home_dir="$fixture_root/home"
    local output_file="$fixture_root/output.txt"

    mkdir -p "$home_dir"
    printf 'export UNRELATED_SHELL_SETTING=1\n' > "$home_dir/.zshrc"
    printf 'export UNRELATED_LOGIN_SETTING=1\n' > "$home_dir/.zprofile"
    printf '[user]\n  name = Existing User\n  email = existing@example.com\n' > "$home_dir/.gitconfig"

    HOME="$home_dir" /bin/bash "$REPO_ROOT/scripts/05-setup-dotfiles.sh" \
        > "$output_file" 2>&1

    assert_file_contains "$home_dir/.zshrc" "export UNRELATED_SHELL_SETTING=1"
    assert_file_contains "$home_dir/.zshrc" "# BEGIN DEV ENV CARLO RUNTIME PATHS"
    assert_file_contains "$home_dir/.zshrc" "# BEGIN DEV ENV CARLO SHELL"
    assert_file_contains "$home_dir/.zprofile" "export UNRELATED_LOGIN_SETTING=1"
    assert_file_contains "$home_dir/.zprofile" "# BEGIN DEV ENV CARLO HOMEBREW"
    assert_file_contains "$home_dir/.gitconfig" "name = Existing User"
    assert_file_contains "$home_dir/.gitconfig" "email = existing@example.com"
    if grep -Fq "Carlo Kruger" "$home_dir/.gitconfig"; then
        fail "dotfiles entrypoint copied a personal Git identity"
    fi
    [ ! -e "$home_dir/.aws/config" ] || fail "dotfiles entrypoint copied named cloud profiles"
    assert_file_contains "$output_file" "First-Run Configuration Step"
}

test_smoke_test_loads_startup_files_and_skips_named_cloud_profiles() {
    local smoke_test="$REPO_ROOT/scripts/12-smoke-test.sh"

    assert_file_contains "$smoke_test" 'zsh -ilc "$ZSH_PROBE"'
    assert_file_does_not_contain "$smoke_test" 'zsh -dilc "$ZSH_PROBE"'
    assert_file_does_not_contain "$smoke_test" 'check_file "$HOME/.aws/config"'
}

test_baseline_reports_non_invasive_shell_and_node_policy() {
    local brew_install="$REPO_ROOT/scripts/01-install-brew.sh"
    local cli_install="$REPO_ROOT/scripts/02-install-cli-tools.sh"

    assert_file_contains "$brew_install" "macOS /bin/zsh is the Carlo Baseline default"
    assert_file_contains "$brew_install" "does not change your login shell"
    assert_file_does_not_contain "$brew_install" 'chsh -s "$TARGET_SHELL"'
    assert_file_does_not_contain "$brew_install" '    zsh'
    assert_file_contains "$cli_install" "Homebrew Node is installed but is not the Carlo Baseline runtime"
    assert_file_contains "$cli_install" "bootstrap never removes existing Homebrew packages"
    assert_file_contains "$cli_install" "brew uses --installed node"
    assert_file_does_not_contain "$cli_install" "brew uninstall node"
}

test_bun_uses_homebrew_core_without_a_third_party_tap() {
    local cli_install="$REPO_ROOT/scripts/02-install-cli-tools.sh"

    assert_file_does_not_contain "$cli_install" "oven-sh/bun/bun"
    assert_file_does_not_contain "$cli_install" 'brew tap "$tap"'
    assert_file_does_not_contain "$cli_install" "ensure_homebrew_taps"
    assert_file_contains "$cli_install" 'brew install "$tool"'
    assert_file_contains "$cli_install" "install_bun_fallback || exit 1"
}

test_gemini_uses_nvm_managed_npm() {
    local brew_manifest="$REPO_ROOT/manifest/homebrew-packages.sh"
    local npm_globals="$REPO_ROOT/scripts/03-install-npm-globals.sh"
    local path_check="$REPO_ROOT/scripts/10-check-paths.sh"
    local smoke_test="$REPO_ROOT/scripts/12-smoke-test.sh"

    assert_file_does_not_contain "$brew_manifest" "gemini-cli"
    assert_file_contains "$npm_globals" "@google/gemini-cli"
    assert_file_contains "$path_check" "gemini is owned by nvm"
    assert_file_contains "$smoke_test" "gemini is owned by nvm"
}

test_dotfiles_entrypoint_refuses_shared_profile() {
    local fixture_root="$TEST_TMP_ROOT/dotfiles-shared-profile"
    local output_file="$fixture_root/output.txt"
    local status=0

    mkdir -p "$fixture_root/home"
    if HOME="$fixture_root/home" DEV_ENV_BOOTSTRAP_PROFILE=shared-baseline \
            /bin/bash "$REPO_ROOT/scripts/05-setup-dotfiles.sh" > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    [ "$status" -eq 2 ] || fail "dotfiles entrypoint accepted shared profile, got $status"
    assert_file_contains "$output_file" "Shared Baseline uses 15-setup-shared-shell.sh"
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
    assert_file_contains "$fixture_root/home/.zshrc" "DEV_ENV_UV_ENV_DIR"
    assert_file_contains "$fixture_root/home/.zshrc" "nvm use --silent default"
    if grep -Fq "ZSH_THEME" "$fixture_root/home/.zshrc"; then
        fail "shared shell setup installed Carlo shell preferences"
    fi
}

test_op_inject_refuses_symlink_output() {
    local fixture_root="$TEST_TMP_ROOT/op-inject-symlink"
    local fake_bin="$fixture_root/bin"
    local template="$fixture_root/template.env.tpl"
    local external_file="$fixture_root/external.env"
    local output_file="$fixture_root/.env"
    local command_output="$fixture_root/output.txt"
    local status=0

    mkdir -p "$fake_bin"
    printf 'VALUE=op://Private/item/field\n' > "$template"
    printf 'external value\n' > "$external_file"
    ln -s "$external_file" "$output_file"
    printf '#!/bin/bash\nexit 0\n' > "$fake_bin/op"
    chmod +x "$fake_bin/op"

    if PATH="$fake_bin:$PATH" /bin/bash "$REPO_ROOT/scripts/08-op-inject-template.sh" \
            --in-file "$template" --out-file "$output_file" --force > "$command_output" 2>&1; then
        status=0
    else
        status=$?
    fi

    [ "$status" -ne 0 ] || fail "op inject followed a symlink output"
    assert_file_contains "$command_output" "Refusing to replace symlink destination"
    assert_file_contains "$external_file" "external value"
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
run_test test_dotfiles_entrypoint_preserves_shell_and_skips_identity_configuration
run_test test_smoke_test_loads_startup_files_and_skips_named_cloud_profiles
run_test test_baseline_reports_non_invasive_shell_and_node_policy
run_test test_bun_uses_homebrew_core_without_a_third_party_tap
run_test test_gemini_uses_nvm_managed_npm
run_test test_dotfiles_entrypoint_refuses_shared_profile
run_test test_shared_shell_entrypoint_preserves_file_before_atomic_replace
run_test test_op_inject_refuses_symlink_output

echo "1..$TEST_COUNT"
