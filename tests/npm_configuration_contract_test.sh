#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-npm-configuration-tests.XXXXXX")"
TEST_COUNT=0

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    return 1
}

test_npm_configuration_refuses_symlink_without_reading_or_logging_target() {
    local case_root="$TEST_TMP_ROOT/symlink"
    local external_file="$case_root/external-npmrc"
    local npmrc_path="$case_root/home/.npmrc"
    local backup_dir="$case_root/backups"
    local output_file="$case_root/output.txt"
    local secret_value="never-log-this-token"
    local status=0

    mkdir -p "$(dirname "$npmrc_path")"
    printf '//registry.example.test/:_authToken=%s\n' "$secret_value" > "$external_file"
    ln -s "$external_file" "$npmrc_path"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/npm-configuration.sh"

    if bootstrap_ensure_nvm_compatible_npm_configuration \
            "$npmrc_path" "$backup_dir" > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    [ "$status" -ne 0 ] || fail "symlink .npmrc should be refused"
    [ -L "$npmrc_path" ] || fail "symlink .npmrc was replaced"
    grep -Fq "$secret_value" "$external_file" ||
        fail "external symlink target was changed"
    if grep -Fq "$secret_value" "$output_file"; then
        fail "diagnostic leaked symlink target contents"
    fi
    if find "$backup_dir" -type f -print -quit 2>/dev/null | grep -q .; then
        fail "refused symlink should not create a backup"
    fi
}

test_npm_configuration_removes_only_owned_assignments_with_unique_backup() {
    local case_root="$TEST_TMP_ROOT/regular-file"
    local npmrc_path="$case_root/home/.npmrc"
    local before_file="$case_root/before"
    local expected_file="$case_root/expected"
    local backup_dir="$case_root/backups"
    local output_file="$case_root/output.txt"
    local secret_value="preserve-this-token"
    local backup_path=""

    mkdir -p "$(dirname "$npmrc_path")"
    printf '%s' \
        "# keep this comment
 prefix = /tmp/wrong-prefix
registry=https://registry.example.test/
; globalconfig=/commented/value
globalconfig = /tmp/wrong-globalconfig
//registry.example.test/:_authToken=$secret_value
save-exact = true" > "$npmrc_path"
    cp "$npmrc_path" "$before_file"
    printf '%s' \
        "# keep this comment
registry=https://registry.example.test/
; globalconfig=/commented/value
//registry.example.test/:_authToken=$secret_value
save-exact = true" > "$expected_file"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/npm-configuration.sh"

    DEV_ENV_BOOTSTRAP_RUN_ID="same-second-run" \
        bootstrap_ensure_nvm_compatible_npm_configuration \
        "$npmrc_path" "$backup_dir" > "$output_file" 2>&1 ||
        fail "regular .npmrc should converge"

    cmp -s "$expected_file" "$npmrc_path" ||
        fail "adapter changed unrelated .npmrc bytes"
    backup_path="$(find "$backup_dir" -type f -print -quit)"
    [ -n "$backup_path" ] || fail "changed .npmrc should retain a backup"
    cmp -s "$before_file" "$backup_path" ||
        fail "backup did not preserve the original .npmrc"
    case "$(basename "$backup_path")" in
        *same-second-run*) ;;
        *) fail "backup identity does not include the bootstrap run id" ;;
    esac
    if grep -Fq "$secret_value" "$output_file"; then
        fail "diagnostic leaked secret-bearing .npmrc content"
    fi
}

test_step_02_converges_npm_configuration_before_loading_nvm() {
    local case_root="$TEST_TMP_ROOT/step-02"
    local home_dir="$case_root/home"
    local fake_bin="$case_root/fake-bin"
    local node_bin="$home_dir/.nvm/versions/node/v24.18.0/bin"
    local nvm_prefix="$case_root/nvm"
    local python_prefix="$case_root/python"
    local applications_dir="$case_root/applications"
    local output_file="$case_root/output.txt"
    local secret_value="entrypoint-secret-token"
    local bundle=""

    mkdir -p \
        "$fake_bin" \
        "$node_bin" \
        "$nvm_prefix" \
        "$python_prefix/bin" \
        "$applications_dir"
    for bundle in \
        "Warp.app" \
        "Zed.app" \
        "Raycast.app" \
        "Hidden Bar.app" \
        "Hammerspoon.app" \
        "GitHub Desktop.app"; do
        mkdir -p "$applications_dir/$bundle/Contents/MacOS"
        printf '<plist/>\n' > "$applications_dir/$bundle/Contents/Info.plist"
        printf '#!/bin/bash\nexit 0\n' \
            > "$applications_dir/$bundle/Contents/MacOS/app"
        chmod +x "$applications_dir/$bundle/Contents/MacOS/app"
    done

    printf '%s\n' \
        '#!/bin/bash' \
        'case "${1:-}" in' \
        '  --prefix)' \
        '    case "${2:-}" in' \
        '      nvm) printf "%s\n" "$TEST_NVM_PREFIX" ;;' \
        '      python@3.14) printf "%s\n" "$TEST_PYTHON_PREFIX" ;;' \
        '      *) exit 1 ;;' \
        '    esac' \
        '    ;;' \
        '  list) exit 0 ;;' \
        '  *) exit 0 ;;' \
        'esac' > "$fake_bin/brew"
    printf '%s\n' \
        '#!/bin/bash' \
        'case "${1:-}" in' \
        '  -m) printf "%s\n" arm64 ;;' \
        '  *) printf "%s\n" Darwin ;;' \
        'esac' > "$fake_bin/uname"
    printf '%s\n' \
        '#!/bin/bash' \
        '[ "${1:-}" = "-p" ] && printf "%s\n" /Library/Developer/CommandLineTools' \
        > "$fake_bin/xcode-select"
    printf '%s\n' \
        '#!/bin/bash' \
        '[ "${1:-}" = "--find" ] && [ "${2:-}" = "clang" ] && printf "%s\n" "$TEST_FAKE_BIN/clang"' \
        > "$fake_bin/xcrun"
    printf '#!/bin/bash\nexit 0\n' > "$fake_bin/clang"
    chmod +x "$fake_bin/brew" "$fake_bin/uname" "$fake_bin/xcode-select" \
        "$fake_bin/xcrun" "$fake_bin/clang"

    printf '%s\n' \
        'nvm() {' \
        '    if grep -Eq "^[[:space:]]*(prefix|globalconfig)[[:space:]]*=" "$HOME/.npmrc"; then' \
        '        return 86' \
        '    fi' \
        '    case "${1:-}" in' \
        '        ls|alias) return 0 ;;' \
        '        use)' \
        '            NVM_BIN="$TEST_FAKE_NODE_BIN"' \
        '            export NVM_BIN' \
        '            return 0' \
        '            ;;' \
        '    esac' \
        '    return 1' \
        '}' > "$nvm_prefix/nvm.sh"
    printf '#!/bin/bash\n[ "${1:-}" = "--version" ] && printf "v24.18.0\\n"\n' \
        > "$node_bin/node"
    printf '%s\n' \
        '#!/bin/bash' \
        'case "${1:-}" in' \
        '  --version) printf "%s\n" 11.16.0 ;;' \
        '  config) exit 0 ;;' \
        '  *) exit 0 ;;' \
        'esac' > "$node_bin/npm"
    printf '#!/bin/bash\nprintf "Python 3.14.0\\n"\n' \
        > "$python_prefix/bin/python3.14"
    chmod +x "$node_bin/node" "$node_bin/npm" "$python_prefix/bin/python3.14"

    printf '%s' \
        "prefix=/tmp/wrong
//registry.example.test/:_authToken=$secret_value" > "$home_dir/.npmrc"

    if PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
            HOME="$home_dir" \
            NVM_DIR="$home_dir/.nvm" \
            BOOTSTRAP_APPLICATIONS_DIR="$applications_dir" \
            TEST_FAKE_BIN="$fake_bin" \
            TEST_FAKE_NODE_BIN="$node_bin" \
            TEST_NVM_PREFIX="$nvm_prefix" \
            TEST_PYTHON_PREFIX="$python_prefix" \
            DEV_ENV_BOOTSTRAP_RUN_ID="step-02-entrypoint-run" \
            /bin/bash "$REPO_ROOT/scripts/02-install-cli-tools.sh" \
            --profile shared-baseline > "$output_file" 2>&1; then
        :
    else
        sed 's/^/  | /' "$output_file" >&2
        fail "step 02 fixture should complete"
    fi

    if grep -Eq '^[[:space:]]*(prefix|globalconfig)[[:space:]]*=' \
            "$home_dir/.npmrc"; then
        fail "step 02 left an nvm-incompatible npm assignment"
    fi
    grep -Fq "$secret_value" "$home_dir/.npmrc" ||
        fail "step 02 removed unrelated secret-bearing npm configuration"
    if grep -Fq "$secret_value" "$output_file"; then
        fail "step 02 diagnostics leaked npm configuration contents"
    fi
    find "$home_dir/.dev-env-npmrc-backups" -type f -print -quit |
        grep -q . || fail "step 02 should retain the original .npmrc"
}

test_npm_configuration_absent_exact_and_non_file_states_are_non_destructive() {
    local case_root="$TEST_TMP_ROOT/state-matrix"
    local absent_path="$case_root/absent/.npmrc"
    local exact_path="$case_root/exact/.npmrc"
    local non_file_path="$case_root/non-file/.npmrc"
    local backup_dir="$case_root/backups"
    local inode_before=""

    mkdir -p "$(dirname "$exact_path")" "$non_file_path"
    printf 'registry=https://registry.example.test/\n' > "$exact_path"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/npm-configuration.sh"

    bootstrap_ensure_nvm_compatible_npm_configuration \
        "$absent_path" "$backup_dir" ||
        fail "absent .npmrc should be satisfied"
    [ ! -e "$absent_path" ] || fail "absent .npmrc should remain absent"

    inode_before="$(ls -di "$exact_path" | awk '{print $1}')"
    bootstrap_ensure_nvm_compatible_npm_configuration \
        "$exact_path" "$backup_dir" ||
        fail "compatible .npmrc should be satisfied"
    [ "$inode_before" = "$(ls -di "$exact_path" | awk '{print $1}')" ] ||
        fail "compatible .npmrc was rewritten"

    if bootstrap_ensure_nvm_compatible_npm_configuration \
            "$non_file_path" "$backup_dir" >/dev/null 2>&1; then
        fail "non-file .npmrc should be refused"
    fi
    [ -d "$non_file_path" ] || fail "non-file .npmrc was replaced"
    if find "$backup_dir" -type f -print -quit 2>/dev/null | grep -q .; then
        fail "non-mutating states should not create backups"
    fi
}

test_npm_configuration_retains_empty_file_and_immediate_repeat_is_unchanged() {
    local case_root="$TEST_TMP_ROOT/empty-repeat"
    local npmrc_path="$case_root/home/.npmrc"
    local backup_dir="$case_root/backups"
    local inode_before=""
    local backup_count=0

    mkdir -p "$(dirname "$npmrc_path")"
    printf 'prefix=/tmp/wrong' > "$npmrc_path"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/npm-configuration.sh"

    DEV_ENV_BOOTSTRAP_RUN_ID="empty-repeat-run" \
        bootstrap_ensure_nvm_compatible_npm_configuration \
        "$npmrc_path" "$backup_dir" >/dev/null ||
        fail "owned-only .npmrc should converge"
    [ -f "$npmrc_path" ] || fail "empty user-owned .npmrc should be retained"
    [ ! -s "$npmrc_path" ] || fail "owned-only .npmrc should become empty"

    inode_before="$(ls -di "$npmrc_path" | awk '{print $1}')"
    backup_count="$(find "$backup_dir" -type f | wc -l | tr -d ' ')"
    DEV_ENV_BOOTSTRAP_RUN_ID="empty-repeat-run" \
        bootstrap_ensure_nvm_compatible_npm_configuration \
        "$npmrc_path" "$backup_dir" >/dev/null ||
        fail "immediate .npmrc repeat should succeed"
    [ "$inode_before" = "$(ls -di "$npmrc_path" | awk '{print $1}')" ] ||
        fail "immediate .npmrc repeat rewrote the file"
    [ "$backup_count" = "$(find "$backup_dir" -type f | wc -l | tr -d ' ')" ] ||
        fail "immediate .npmrc repeat created a backup"
}

test_npm_configuration_same_run_mutations_keep_distinct_immutable_backups() {
    local case_root="$TEST_TMP_ROOT/backup-collision"
    local npmrc_path="$case_root/home/.npmrc"
    local first_before="$case_root/first-before"
    local second_before="$case_root/second-before"
    local backup_dir="$case_root/backups"
    local first_backup=""
    local second_backup=""

    mkdir -p "$(dirname "$npmrc_path")"
    printf 'prefix=/tmp/first\nregistry=one\n' > "$npmrc_path"
    cp "$npmrc_path" "$first_before"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/npm-configuration.sh"

    DEV_ENV_BOOTSTRAP_RUN_ID="same-second-run" \
        bootstrap_ensure_nvm_compatible_npm_configuration \
        "$npmrc_path" "$backup_dir" >/dev/null ||
        fail "first same-run mutation should converge"
    first_backup="$(find "$backup_dir" -type f -print -quit)"

    printf 'globalconfig=/tmp/second\nregistry=two\n' > "$npmrc_path"
    cp "$npmrc_path" "$second_before"
    DEV_ENV_BOOTSTRAP_RUN_ID="same-second-run" \
        bootstrap_ensure_nvm_compatible_npm_configuration \
        "$npmrc_path" "$backup_dir" >/dev/null ||
        fail "second same-run mutation should converge"
    second_backup="$(find "$backup_dir" -type f ! -path "$first_backup" -print -quit)"

    [ -n "$first_backup" ] && [ -n "$second_backup" ] ||
        fail "same-run mutations should create two distinct backups"
    [ "$first_backup" != "$second_backup" ] ||
        fail "same-run mutations collided on one backup path"
    cmp -s "$first_before" "$first_backup" ||
        fail "first backup was overwritten"
    cmp -s "$second_before" "$second_backup" ||
        fail "second backup does not preserve its original"
}

test_npm_configuration_faults_preserve_or_restore_original_without_leaks() {
    local case_root="$TEST_TMP_ROOT/faults"
    local npmrc_path="$case_root/home/.npmrc"
    local before_file="$case_root/before"
    local backup_dir="$case_root/backups"
    local output_file="$case_root/output.txt"
    local secret_value="fault-secret-token"
    local status=0

    mkdir -p "$(dirname "$npmrc_path")"
    printf '%s\n' \
        'prefix=/tmp/wrong' \
        "//registry.example.test/:_authToken=$secret_value" > "$npmrc_path"
    cp "$npmrc_path" "$before_file"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/npm-configuration.sh"

    if DEV_ENV_TEST_FAIL_BEFORE_PROMOTION=1 \
            DEV_ENV_BOOTSTRAP_RUN_ID="fault-run" \
            bootstrap_ensure_nvm_compatible_npm_configuration \
            "$npmrc_path" "$backup_dir" > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi
    [ "$status" -eq 97 ] ||
        fail "pre-promotion fault should return 97, got $status"
    cmp -s "$before_file" "$npmrc_path" ||
        fail "pre-promotion fault changed the original"
    if find "$backup_dir" -type f -print -quit 2>/dev/null | grep -q .; then
        fail "pre-promotion fault should not create a backup"
    fi

    if DEV_ENV_TEST_FAIL_POST_VERIFICATION=1 \
            DEV_ENV_BOOTSTRAP_RUN_ID="fault-run" \
            bootstrap_ensure_nvm_compatible_npm_configuration \
            "$npmrc_path" "$backup_dir" > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi
    [ "$status" -eq 98 ] ||
        fail "post-verification fault should return 98, got $status"
    cmp -s "$before_file" "$npmrc_path" ||
        fail "post-verification fault did not restore the original"
    find "$backup_dir" -type f -print -quit | grep -q . ||
        fail "post-verification fault should retain the backup"
    if find "$(dirname "$npmrc_path")" -type f \
            -name '.npmrc.candidate.*' -print -quit | grep -q .; then
        fail "fault path left a run-owned candidate"
    fi
    if grep -Fq "$secret_value" "$output_file"; then
        fail "fault diagnostic leaked secret-bearing npm content"
    fi
}

test_npm_configuration_refuses_malformed_content_without_mutation() {
    local case_root="$TEST_TMP_ROOT/malformed"
    local npmrc_path="$case_root/home/.npmrc"
    local before_file="$case_root/before"
    local backup_dir="$case_root/backups"

    mkdir -p "$(dirname "$npmrc_path")"
    {
        printf 'prefix=/tmp/wrong\n'
        printf 'registry=broken\000value\n'
    } > "$npmrc_path"
    cp "$npmrc_path" "$before_file"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/npm-configuration.sh"

    if bootstrap_ensure_nvm_compatible_npm_configuration \
            "$npmrc_path" "$backup_dir" >/dev/null 2>&1; then
        fail "malformed .npmrc should be refused"
    fi
    cmp -s "$before_file" "$npmrc_path" ||
        fail "malformed .npmrc was changed"
    if find "$backup_dir" -type f -print -quit 2>/dev/null | grep -q .; then
        fail "malformed .npmrc should not create a backup"
    fi
}

run_test() {
    local name="$1"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - ${name#test_}"
}

run_test test_npm_configuration_refuses_symlink_without_reading_or_logging_target
run_test test_npm_configuration_removes_only_owned_assignments_with_unique_backup
run_test test_step_02_converges_npm_configuration_before_loading_nvm
run_test test_npm_configuration_absent_exact_and_non_file_states_are_non_destructive
run_test test_npm_configuration_retains_empty_file_and_immediate_repeat_is_unchanged
run_test test_npm_configuration_same_run_mutations_keep_distinct_immutable_backups
run_test test_npm_configuration_faults_preserve_or_restore_original_without_leaks
run_test test_npm_configuration_refuses_malformed_content_without_mutation

echo "1..$TEST_COUNT"
