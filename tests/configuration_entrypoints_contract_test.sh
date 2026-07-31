#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-configuration-entrypoint-tests.XXXXXX")"
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

test_claude_legacy_path_migration_is_recovery_safe_and_convergent() {
    local case_root="$TEST_TMP_ROOT/claude"
    local home_dir="$case_root/home"
    local settings_path="$home_dir/.claude/settings.json"
    local before_path="$case_root/before.json"
    local first_backup_count=0
    local second_backup_count=0

    mkdir -p "$(dirname "$settings_path")"
    printf '%s\n' '{"userSetting":"preserved","legacyPath":"/home/carlo/project"}' > "$settings_path"

    HOME="$home_dir" DEV_ENV_BOOTSTRAP_RUN_ID="claude-migration-first" \
        /bin/bash "$REPO_ROOT/scripts/06-setup-claude.sh" >/dev/null

    grep -Fq '"userSetting": "preserved"' "$settings_path" ||
        fail "Claude migration changed a user-owned JSON key"
    grep -Fq '$HOME/project' "$settings_path" ||
        fail "Claude migration did not normalize the legacy home path"
    find "$home_dir/.claude-backup-"* -type f -name '*claude-home-path-v1*' -print -quit |
        grep -q . || fail "Claude migration did not retain a versioned backup"
    cp "$settings_path" "$before_path"
    first_backup_count="$(find "$home_dir" -type f -name '*.backup.*' | wc -l | tr -d ' ')"

    HOME="$home_dir" DEV_ENV_BOOTSTRAP_RUN_ID="claude-migration-second" \
        /bin/bash "$REPO_ROOT/scripts/06-setup-claude.sh" >/dev/null

    cmp -s "$before_path" "$settings_path" ||
        fail "unchanged Claude configuration did not converge"
    second_backup_count="$(find "$home_dir" -type f -name '*.backup.*' | wc -l | tr -d ' ')"
    [ "$first_backup_count" = "$second_backup_count" ] ||
        fail "unchanged Claude configuration created another backup"
}

test_gemini_agent_migration_is_recovery_safe_and_convergent() {
    local case_root="$TEST_TMP_ROOT/gemini"
    local home_dir="$case_root/home"
    local fake_bin="$case_root/fake-bin"
    local agent_path="$home_dir/.gemini/agents/legacy.md"
    local before_path="$case_root/before.md"
    local first_backup_count=0
    local second_backup_count=0

    mkdir -p "$fake_bin" "$(dirname "$agent_path")" \
        "$home_dir/.local/share/dev-env-bootstrap/python/bin"
    printf '#!/bin/bash\nprintf "1.0.0\\n"\n' > "$fake_bin/gemini"
    chmod +x "$fake_bin/gemini"
    command -v python3 >/dev/null 2>&1 || fail "test requires python3"
    ln -s "$(command -v python3)" \
        "$home_dir/.local/share/dev-env-bootstrap/python/bin/python"
    printf '%s\n' \
        '---' \
        'name: legacy' \
        'skills:' \
        '  - obsolete-skill' \
        '---' \
        'Legacy agent body.' > "$agent_path"

    PATH="$fake_bin:/usr/bin:/bin" HOME="$home_dir" \
        DEV_ENV_BOOTSTRAP_RUN_ID="gemini-migration-first" \
        /bin/bash "$REPO_ROOT/scripts/08-setup-gemini.sh" >/dev/null

    if grep -Fq 'skills:' "$agent_path"; then
        fail "Gemini migration did not remove obsolete skills frontmatter"
    fi
    find "$home_dir/.gemini-backup-"* -type f -name '*gemini-agent-skills-v1*' -print -quit |
        grep -q . || fail "Gemini migration did not retain a versioned backup"
    cp "$agent_path" "$before_path"
    first_backup_count="$(find "$home_dir" -type f -name '*.backup.*' | wc -l | tr -d ' ')"

    PATH="$fake_bin:/usr/bin:/bin" HOME="$home_dir" \
        DEV_ENV_BOOTSTRAP_RUN_ID="gemini-migration-second" \
        /bin/bash "$REPO_ROOT/scripts/08-setup-gemini.sh" >/dev/null

    cmp -s "$before_path" "$agent_path" ||
        fail "unchanged Gemini agent migration did not converge"
    second_backup_count="$(find "$home_dir" -type f -name '*.backup.*' | wc -l | tr -d ' ')"
    [ "$first_backup_count" = "$second_backup_count" ] ||
        fail "unchanged Gemini agent migration created another backup"
}

test_1password_diagnosis_never_writes_home_or_invokes_signin() {
    local case_root="$TEST_TMP_ROOT/onepassword"
    local home_dir="$case_root/home"
    local fake_bin="$case_root/fake-bin"
    local before_path="$case_root/before.txt"
    local after_path="$case_root/after.txt"
    local output_path="$case_root/output.txt"
    local call_log="$case_root/op-calls.txt"
    local state=""

    mkdir -p "$home_dir" "$fake_bin"
    printf 'sentinel\n' > "$home_dir/preserved.txt"

    for state in absent-cli signed-out signed-in query-failure; do
        rm -f "$fake_bin/op"
        : > "$call_log"
        case "$state" in
            absent-cli)
                ;;
            signed-out|query-failure)
                printf '#!/bin/bash\nprintf "%s %s\\n" "${1:-}" "${2:-}" >> "$OP_CALL_LOG"\n[ "${1:-}" = "--version" ] && { printf "2.0.0\\n"; exit 0; }\nexit 1\n' > "$fake_bin/op"
                chmod +x "$fake_bin/op"
                ;;
            signed-in)
                printf '#!/bin/bash\nprintf "%s %s\\n" "${1:-}" "${2:-}" >> "$OP_CALL_LOG"\n[ "${1:-}" = "--version" ] && { printf "2.0.0\\n"; exit 0; }\n[ "${1:-}" = "account" ] && [ "${2:-}" = "list" ] && exit 0\nexit 1\n' > "$fake_bin/op"
                chmod +x "$fake_bin/op"
                ;;
        esac

        find "$home_dir" -type f -exec shasum -a 256 {} \; | sort > "$before_path"
        PATH="$fake_bin:/usr/bin:/bin" HOME="$home_dir" OP_CALL_LOG="$call_log" \
            /bin/bash "$REPO_ROOT/scripts/07-setup-1password.sh" > "$output_path" 2>&1 || true
        find "$home_dir" -type f -exec shasum -a 256 {} \; | sort > "$after_path"
        cmp -s "$before_path" "$after_path" ||
            fail "1Password $state diagnosis wrote to HOME"
        if grep -Eq '^(signin|item|vault) ' "$call_log"; then
            fail "1Password $state diagnosis attempted an auth or credential operation"
        fi
    done
}

run_test test_claude_legacy_path_migration_is_recovery_safe_and_convergent
run_test test_gemini_agent_migration_is_recovery_safe_and_convergent
run_test test_1password_diagnosis_never_writes_home_or_invokes_signin

echo "1..$TEST_COUNT"
