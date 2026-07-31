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
    local app_path="$case_root/1Password.app"
    local state=""

    mkdir -p "$home_dir" "$fake_bin"
    printf 'sentinel\n' > "$home_dir/preserved.txt"

    for state in absent-app absent-cli signed-out signed-in query-failure; do
        rm -f "$fake_bin/op"
        rm -rf "$app_path"
        : > "$call_log"
        case "$state" in
            absent-app)
                printf '#!/bin/bash\nprintf "%s %s\\n" "${1:-}" "${2:-}" >> "$OP_CALL_LOG"\n[ "${1:-}" = "--version" ] && { printf "2.0.0\\n"; exit 0; }\n[ "${1:-}" = "account" ] && [ "${2:-}" = "list" ] && exit 0\nexit 1\n' > "$fake_bin/op"
                chmod +x "$fake_bin/op"
                ;;
            absent-cli)
                mkdir -p "$app_path"
                ;;
            signed-out|query-failure)
                mkdir -p "$app_path"
                printf '#!/bin/bash\nprintf "%s %s\\n" "${1:-}" "${2:-}" >> "$OP_CALL_LOG"\n[ "${1:-}" = "--version" ] && { printf "2.0.0\\n"; exit 0; }\nexit 1\n' > "$fake_bin/op"
                chmod +x "$fake_bin/op"
                ;;
            signed-in)
                mkdir -p "$app_path"
                printf '#!/bin/bash\nprintf "%s %s\\n" "${1:-}" "${2:-}" >> "$OP_CALL_LOG"\n[ "${1:-}" = "--version" ] && { printf "2.0.0\\n"; exit 0; }\n[ "${1:-}" = "account" ] && [ "${2:-}" = "list" ] && exit 0\nexit 1\n' > "$fake_bin/op"
                chmod +x "$fake_bin/op"
                ;;
        esac

        find "$home_dir" -type f -exec shasum -a 256 {} \; | sort > "$before_path"
        PATH="$fake_bin:/usr/bin:/bin" HOME="$home_dir" OP_CALL_LOG="$call_log" \
            DEV_ENV_1PASSWORD_APP_PATH="$app_path" \
            /bin/bash "$REPO_ROOT/scripts/07-setup-1password.sh" > "$output_path" 2>&1 || true
        find "$home_dir" -type f -exec shasum -a 256 {} \; | sort > "$after_path"
        cmp -s "$before_path" "$after_path" ||
            fail "1Password $state diagnosis wrote to HOME"
        if grep -Eq '^(signin|item|vault) ' "$call_log"; then
            fail "1Password $state diagnosis attempted an auth or credential operation"
        fi
    done
}

test_configuration_entrypoints_refuse_symlinked_managed_directories() {
    local case_root="$TEST_TMP_ROOT/symlinked-directory"
    local home_dir="$case_root/home"
    local external_claude="$case_root/external-claude"
    local external_gemini="$case_root/external-gemini"
    local fake_bin="$case_root/fake-bin"
    local output_path="$case_root/output.txt"

    mkdir -p "$home_dir" "$external_claude" "$external_gemini" "$fake_bin" \
        "$home_dir/.local/share/dev-env-bootstrap/python/bin"
    command -v python3 >/dev/null 2>&1 || fail "test requires python3"
    ln -s "$external_claude" "$home_dir/.claude"
    ln -s "$external_gemini" "$home_dir/.gemini"
    ln -s "$(command -v python3)" \
        "$home_dir/.local/share/dev-env-bootstrap/python/bin/python"
    printf '#!/bin/bash\nprintf "1.0.0\\n"\n' > "$fake_bin/gemini"
    chmod +x "$fake_bin/gemini"

    if HOME="$home_dir" /bin/bash "$REPO_ROOT/scripts/06-setup-claude.sh" \
            > "$output_path" 2>&1; then
        fail "Claude setup followed a symlinked configuration directory"
    fi
    [ -z "$(find "$external_claude" -mindepth 1 -print -quit)" ] ||
        fail "Claude setup wrote through a symlinked configuration directory"

    if PATH="$fake_bin:/usr/bin:/bin" HOME="$home_dir" \
            /bin/bash "$REPO_ROOT/scripts/08-setup-gemini.sh" > "$output_path" 2>&1; then
        fail "Gemini setup followed a symlinked configuration directory"
    fi
    [ -z "$(find "$external_gemini" -mindepth 1 -print -quit)" ] ||
        fail "Gemini setup wrote through a symlinked configuration directory"
}

test_claude_preserves_malformed_codex_toml() {
    local case_root="$TEST_TMP_ROOT/malformed-codex-toml"
    local home_dir="$case_root/home"
    local config_path="$home_dir/.codex/config.toml"
    local before_path="$case_root/before.toml"

    command -v python3 >/dev/null 2>&1 || fail "test requires python3"
    mkdir -p "$(dirname "$config_path")"
    printf '[unclosed\n' > "$config_path"
    cp "$config_path" "$before_path"

    if HOME="$home_dir" /bin/bash "$REPO_ROOT/scripts/06-setup-claude.sh" >/dev/null 2>&1; then
        fail "Claude setup promoted malformed Codex TOML"
    fi
    cmp -s "$before_path" "$config_path" ||
        fail "Claude setup changed malformed Codex TOML"
}

test_dotfiles_keeps_earlier_promotions_when_a_later_target_is_unsafe() {
    local case_root="$TEST_TMP_ROOT/dotfiles-partial-failure"
    local home_dir="$case_root/home"
    local zed_settings="$home_dir/Library/Application Support/Zed/settings.json"
    local external_settings="$case_root/external-settings.json"
    local output_path="$case_root/output.txt"
    local backup_count=0

    mkdir -p "$(dirname "$zed_settings")"
    printf 'export KEEP_ZPROFILE=1\n' > "$home_dir/.zprofile"
    printf 'export KEEP_ZSHRC=1\n' > "$home_dir/.zshrc"
    printf '{"external":true}\n' > "$external_settings"
    ln -s "$external_settings" "$zed_settings"

    if HOME="$home_dir" DEV_ENV_BOOTSTRAP_RUN_ID="dotfiles-partial-failure" \
            /bin/bash "$REPO_ROOT/scripts/05-setup-dotfiles.sh" > "$output_path" 2>&1; then
        fail "dotfiles setup accepted a later symlinked target"
    fi
    grep -Fq '# BEGIN DEV ENV CARLO HOMEBREW' "$home_dir/.zprofile" ||
        fail "dotfiles setup did not retain an earlier valid promotion"
    grep -Fq '# BEGIN DEV ENV CARLO RUNTIME PATHS' "$home_dir/.zshrc" ||
        fail "dotfiles setup did not retain an earlier valid promotion"
    backup_count="$(find "$home_dir" -type f -name '*.backup.*' | wc -l | tr -d ' ')"
    [ "$backup_count" -ge 2 ] ||
        fail "dotfiles setup did not retain unique backups for earlier promotions"
    cmp -s "$external_settings" <(printf '{"external":true}\n') ||
        fail "dotfiles setup changed the unsafe external target"
}

run_test test_claude_legacy_path_migration_is_recovery_safe_and_convergent
run_test test_gemini_agent_migration_is_recovery_safe_and_convergent
run_test test_1password_diagnosis_never_writes_home_or_invokes_signin
run_test test_configuration_entrypoints_refuse_symlinked_managed_directories
run_test test_claude_preserves_malformed_codex_toml
run_test test_dotfiles_keeps_earlier_promotions_when_a_later_target_is_unsafe

echo "1..$TEST_COUNT"
