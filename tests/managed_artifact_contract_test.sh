#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-managed-artifact-tests.XXXXXX")"
TEST_COUNT=0

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    return 1
}

test_exact_file_installs_absent_target_and_immediate_repeat_is_unchanged() {
    local case_root="$TEST_TMP_ROOT/exact-file"
    local source_file="$case_root/source/settings.json"
    local target_file="$case_root/home/settings.json"
    local backup_dir="$case_root/backups"
    local inode_before=""

    mkdir -p "$(dirname "$source_file")"
    printf '{"enabled":true}\n' > "$source_file"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/managed-artifact.sh"

    DEV_ENV_BOOTSTRAP_RUN_ID="exact-file-run" \
        bootstrap_managed_artifact_install_exact \
        "$source_file" "$target_file" "$backup_dir" ||
        fail "absent exact-file target should be installed"
    cmp -s "$source_file" "$target_file" ||
        fail "installed exact-file target differs from source"
    if find "$backup_dir" -type f -print -quit 2>/dev/null | grep -q .; then
        fail "absent target should not create a backup"
    fi

    inode_before="$(ls -di "$target_file" | awk '{print $1}')"
    DEV_ENV_BOOTSTRAP_RUN_ID="exact-file-run" \
        bootstrap_managed_artifact_install_exact \
        "$source_file" "$target_file" "$backup_dir" ||
        fail "immediate exact-file repeat should succeed"
    [ "$inode_before" = "$(ls -di "$target_file" | awk '{print $1}')" ] ||
        fail "immediate exact-file repeat rewrote the target"
    if find "$backup_dir" -type f -print -quit 2>/dev/null | grep -q .; then
        fail "immediate exact-file repeat should not create a backup"
    fi
}

test_managed_block_preserves_unrelated_content_and_backs_up_original() {
    local case_root="$TEST_TMP_ROOT/managed-block"
    local target_file="$case_root/home/.zshrc"
    local before_file="$case_root/before"
    local backup_dir="$case_root/backups"
    local backup_path=""

    mkdir -p "$(dirname "$target_file")"
    printf 'export UNRELATED=1\n' > "$target_file"
    cp "$target_file" "$before_file"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/managed-artifact.sh"

    DEV_ENV_BOOTSTRAP_RUN_ID="managed-block-run" \
        bootstrap_managed_artifact_replace_managed_block \
        "$target_file" "# BEGIN TEST" "# END TEST" "$backup_dir" <<'EOF' ||
        fail "managed block should be installed"
# BEGIN TEST
export MANAGED=1
# END TEST
EOF

    grep -Fq 'export UNRELATED=1' "$target_file" ||
        fail "managed block replacement lost unrelated content"
    grep -Fq 'export MANAGED=1' "$target_file" ||
        fail "managed block replacement did not install the block"
    backup_path="$(find "$backup_dir" -type f -print -quit)"
    [ -n "$backup_path" ] || fail "managed block change should create a backup"
    cmp -s "$before_file" "$backup_path" ||
        fail "managed block backup differs from original"
}

test_json_overlay_merges_defaults_through_recovery_safe_promotion() {
    local case_root="$TEST_TMP_ROOT/json-overlay"
    local incoming_file="$case_root/repo/settings.json"
    local target_file="$case_root/home/settings.json"
    local before_file="$case_root/before"
    local expected_file="$case_root/expected.json"
    local backup_dir="$case_root/backups"
    local backup_path=""

    mkdir -p "$(dirname "$incoming_file")" "$(dirname "$target_file")"
    printf '%s\n' \
        '{"theme":"default","tools":["one","two"],"nested":{"add":true}}' \
        > "$incoming_file"
    printf '%s\n' \
        '{"theme":"custom","tools":["one"],"nested":{"keep":true}}' \
        > "$target_file"
    cp "$target_file" "$before_file"
    printf '%s\n' \
        '{' \
        '  "theme": "default",' \
        '  "tools": [' \
        '    "one",' \
        '    "two"' \
        '  ],' \
        '  "nested": {' \
        '    "keep": true,' \
        '    "add": true' \
        '  }' \
        '}' > "$expected_file"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/managed-artifact.sh"

    DEV_ENV_BOOTSTRAP_RUN_ID="json-overlay-run" \
        bootstrap_managed_artifact_merge_overlay \
        json "$incoming_file" "$target_file" "$backup_dir" \
        "$(command -v python3)" ||
        fail "JSON overlay should merge"

    cmp -s "$expected_file" "$target_file" ||
        fail "JSON overlay result differs from the declared merge"
    backup_path="$(find "$backup_dir" -type f -print -quit)"
    [ -n "$backup_path" ] || fail "JSON overlay should back up user state"
    cmp -s "$before_file" "$backup_path" ||
        fail "JSON overlay backup differs from original"
}

test_versioned_migration_is_observable_and_does_not_repeat() {
    local case_root="$TEST_TMP_ROOT/versioned-migration"
    local migrated_source="$case_root/repo/agent.md"
    local target_file="$case_root/home/agent.md"
    local before_file="$case_root/before"
    local backup_dir="$case_root/backups"
    local backup_path=""
    local backup_count=0

    mkdir -p "$(dirname "$migrated_source")" "$(dirname "$target_file")"
    printf '%s\n' \
        '---' \
        'name: helper' \
        '---' \
        'Body' > "$migrated_source"
    printf '%s\n' \
        '---' \
        'name: helper' \
        'skills:' \
        '  - legacy-skill' \
        '---' \
        'Body' > "$target_file"
    cp "$target_file" "$before_file"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/managed-artifact.sh"

    DEV_ENV_BOOTSTRAP_RUN_ID="migration-run" \
        bootstrap_managed_artifact_apply_versioned_migration \
        "agent-frontmatter-v2" \
        "$migrated_source" "$target_file" "$backup_dir" ||
        fail "versioned migration should apply"

    cmp -s "$migrated_source" "$target_file" ||
        fail "versioned migration did not promote migrated content"
    backup_path="$(find "$backup_dir" -type f -print -quit)"
    [ -n "$backup_path" ] || fail "versioned migration should create a backup"
    cmp -s "$before_file" "$backup_path" ||
        fail "versioned migration backup differs from original"
    case "$(basename "$backup_path")" in
        *agent-frontmatter-v2*) ;;
        *) fail "migration backup does not identify the migration version" ;;
    esac

    backup_count="$(find "$backup_dir" -type f | wc -l | tr -d ' ')"
    DEV_ENV_BOOTSTRAP_RUN_ID="migration-run" \
        bootstrap_managed_artifact_apply_versioned_migration \
        "agent-frontmatter-v2" \
        "$migrated_source" "$target_file" "$backup_dir" ||
        fail "completed versioned migration should be a no-op"
    [ "$backup_count" = "$(find "$backup_dir" -type f | wc -l | tr -d ' ')" ] ||
        fail "completed versioned migration created another backup"
}

test_exact_file_faults_preserve_or_restore_original_and_clean_candidates() {
    local case_root="$TEST_TMP_ROOT/exact-faults"
    local source_file="$case_root/repo/config"
    local target_file="$case_root/home/config"
    local before_file="$case_root/before"
    local backup_dir="$case_root/backups"
    local status=0

    mkdir -p "$(dirname "$source_file")" "$(dirname "$target_file")"
    printf 'desired\n' > "$source_file"
    printf 'original\n' > "$target_file"
    cp "$target_file" "$before_file"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/managed-artifact.sh"

    if DEV_ENV_TEST_FAIL_BEFORE_PROMOTION=1 \
            DEV_ENV_BOOTSTRAP_RUN_ID="exact-fault-run" \
            bootstrap_managed_artifact_install_exact \
            "$source_file" "$target_file" "$backup_dir"; then
        status=0
    else
        status=$?
    fi
    [ "$status" -eq 97 ] ||
        fail "exact pre-promotion fault should return 97, got $status"
    cmp -s "$before_file" "$target_file" ||
        fail "exact pre-promotion fault changed the original"
    if find "$backup_dir" -type f -print -quit 2>/dev/null | grep -q .; then
        fail "exact pre-promotion fault should not create a backup"
    fi

    if DEV_ENV_TEST_FAIL_POST_VERIFICATION=1 \
            DEV_ENV_BOOTSTRAP_RUN_ID="exact-fault-run" \
            bootstrap_managed_artifact_install_exact \
            "$source_file" "$target_file" "$backup_dir"; then
        status=0
    else
        status=$?
    fi
    [ "$status" -eq 98 ] ||
        fail "exact post-verification fault should return 98, got $status"
    cmp -s "$before_file" "$target_file" ||
        fail "exact post-verification fault did not restore the original"
    find "$backup_dir" -type f -print -quit | grep -q . ||
        fail "exact post-verification fault should retain a backup"
    if find "$(dirname "$target_file")" -type f \
            -name '.config.candidate.*' -print -quit | grep -q .; then
        fail "exact fault left a run-owned candidate"
    fi
}

test_managed_block_refuses_malformed_markers_without_mutation() {
    local case_root="$TEST_TMP_ROOT/malformed-block"
    local target_file="$case_root/home/.zshrc"
    local before_file="$case_root/before"
    local backup_dir="$case_root/backups"

    mkdir -p "$(dirname "$target_file")"
    printf '%s\n' \
        'export BEFORE=1' \
        '# BEGIN TEST' \
        'export BROKEN=1' > "$target_file"
    cp "$target_file" "$before_file"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/managed-artifact.sh"

    if bootstrap_managed_artifact_replace_managed_block \
            "$target_file" "# BEGIN TEST" "# END TEST" "$backup_dir" \
            >/dev/null 2>&1 <<'EOF'; then
# BEGIN TEST
export MANAGED=1
# END TEST
EOF
        fail "malformed existing markers should be refused"
    fi
    cmp -s "$before_file" "$target_file" ||
        fail "malformed managed block target was changed"
    if find "$backup_dir" -type f -print -quit 2>/dev/null | grep -q .; then
        fail "malformed managed block should not create a backup"
    fi
}

test_json_overlay_refuses_malformed_state_without_mutation() {
    local case_root="$TEST_TMP_ROOT/malformed-overlay"
    local incoming_file="$case_root/repo/settings.json"
    local target_file="$case_root/home/settings.json"
    local before_file="$case_root/before"
    local backup_dir="$case_root/backups"

    mkdir -p "$(dirname "$incoming_file")" "$(dirname "$target_file")"
    printf '{"enabled":true}\n' > "$incoming_file"
    printf '{"broken":\n' > "$target_file"
    cp "$target_file" "$before_file"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/managed-artifact.sh"

    if bootstrap_managed_artifact_merge_overlay \
            json "$incoming_file" "$target_file" "$backup_dir" \
            "$(command -v python3)" >/dev/null 2>&1; then
        fail "malformed JSON target should be refused"
    fi
    cmp -s "$before_file" "$target_file" ||
        fail "malformed JSON target was changed"
    if find "$backup_dir" -type f -print -quit 2>/dev/null | grep -q .; then
        fail "malformed JSON target should not create a backup"
    fi
}

run_test() {
    local name="$1"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - ${name#test_}"
}

run_test test_exact_file_installs_absent_target_and_immediate_repeat_is_unchanged
run_test test_managed_block_preserves_unrelated_content_and_backs_up_original
run_test test_json_overlay_merges_defaults_through_recovery_safe_promotion
run_test test_versioned_migration_is_observable_and_does_not_repeat
run_test test_exact_file_faults_preserve_or_restore_original_and_clean_candidates
run_test test_managed_block_refuses_malformed_markers_without_mutation
run_test test_json_overlay_refuses_malformed_state_without_mutation

echo "1..$TEST_COUNT"
