#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-shared-shell-tests.XXXXXX")"
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
    echo "ok $TEST_COUNT - ${name#test_}"
}

test_shared_shell_writes_only_its_two_blocks_and_repeat_creates_no_backup_artifacts() {
    local case_root="$TEST_TMP_ROOT/two-blocks"
    local home_dir="$case_root/home"
    local fake_bin="$case_root/fake-bin"
    local output_file="$case_root/output.txt"
    local backup_count_before=0
    local backup_count_after=0
    local zprofile_inode_before=""
    local zshrc_inode_before=""

    mkdir -p "$home_dir" "$fake_bin"
    printf '%s\n' \
        'export USER_ZPROFILE=preserved' \
        > "$home_dir/.zprofile"
    printf '%s\n' \
        'export USER_ZSHRC=preserved' \
        'alias ll="ls -la"' \
        > "$home_dir/.zshrc"
    printf '%s\n' \
        '#!/bin/bash' \
        '[ "${1:-}" = "-n" ] || exit 2' \
        'exit 0' \
        > "$fake_bin/zsh"
    chmod +x "$fake_bin/zsh"

    PATH="$fake_bin:/usr/bin:/bin" \
        HOME="$home_dir" \
        DEV_ENV_BOOTSTRAP_RUN_ID="shared-shell-first" \
        /bin/bash "$REPO_ROOT/scripts/15-setup-shared-shell.sh" > "$output_file" 2>&1 ||
        fail "shared shell setup should converge"

    grep -Fxq 'export USER_ZPROFILE=preserved' "$home_dir/.zprofile" ||
        fail "shared shell setup must preserve surrounding .zprofile content"
    grep -Fxq 'export USER_ZSHRC=preserved' "$home_dir/.zshrc" ||
        fail "shared shell setup must preserve surrounding .zshrc content"
    grep -Fxq 'alias ll="ls -la"' "$home_dir/.zshrc" ||
        fail "shared shell setup must not adopt personal shell configuration"
    [ "$(grep -Fc '# BEGIN DEV ENV SHARED HOMEBREW' "$home_dir/.zprofile")" -eq 1 ] ||
        fail "shared shell setup must write exactly one Homebrew block"
    [ "$(grep -Fc '# BEGIN DEV ENV SHARED RUNTIME PATHS' "$home_dir/.zshrc")" -eq 1 ] ||
        fail "shared shell setup must write exactly one runtime-path block"

    backup_count_before="$(find "$home_dir" -type f -name '*.backup.*' | wc -l | tr -d ' ')"
    [ "$backup_count_before" -eq 2 ] ||
        fail "initial changes should retain one backup for each modified shell file"
    zprofile_inode_before="$(ls -di "$home_dir/.zprofile" | awk '{print $1}')"
    zshrc_inode_before="$(ls -di "$home_dir/.zshrc" | awk '{print $1}')"

    PATH="$fake_bin:/usr/bin:/bin" \
        HOME="$home_dir" \
        DEV_ENV_BOOTSTRAP_RUN_ID="shared-shell-second" \
        /bin/bash "$REPO_ROOT/scripts/15-setup-shared-shell.sh" >> "$output_file" 2>&1 ||
        fail "unchanged shared shell setup should converge"

    backup_count_after="$(find "$home_dir" -type f -name '*.backup.*' | wc -l | tr -d ' ')"
    [ "$backup_count_after" -eq "$backup_count_before" ] ||
        fail "unchanged shared shell setup must not create backups"
    [ "$zprofile_inode_before" = "$(ls -di "$home_dir/.zprofile" | awk '{print $1}')" ] ||
        fail "unchanged shared shell setup must not rewrite .zprofile"
    [ "$zshrc_inode_before" = "$(ls -di "$home_dir/.zshrc" | awk '{print $1}')" ] ||
        fail "unchanged shared shell setup must not rewrite .zshrc"
    if find "$home_dir" -maxdepth 1 -type d -name '.shared-shell-backup-*' -print -quit | grep -q .; then
        fail "unchanged shared shell setup must not create per-run backup directories"
    fi
}

run_test test_shared_shell_writes_only_its_two_blocks_and_repeat_creates_no_backup_artifacts

echo "1..$TEST_COUNT"
