#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-skill-hub-tests.XXXXXX")"
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
    grep -Fq -- "$expected" "$file" || fail "$file does not contain: $expected"
}

assert_projection_is_invalid() {
    local home_dir="$1"
    local expected_reason="$2"

    if skill_hub_projection_valid "$home_dir"; then
        fail "Skill Hub projection unexpectedly validated for $home_dir"
    fi
    [[ "$SKILL_HUB_PROJECTION_REASON" == *"$expected_reason"* ]] || \
        fail "projection reason did not contain: $expected_reason"
}

make_git_stub() {
    local bin_dir="$1"

    mkdir -p "$bin_dir"
    cat > "$bin_dir/git" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$TEST_GIT_LOG"
case "$*" in
    clone*)
        if [[ "${TEST_GIT_CLONE_FAIL:-}" = "1" ]]; then
            exit 1
        fi
        hub_dir="${!#}"
        mkdir -p "$hub_dir/profiles" "$hub_dir/scripts"
        printf '%s\n' '{"schema_version":1,"skills":["implement"],"destinations":["agents","claude","codex"]}' \
            > "$hub_dir/profiles/carlo-baseline.json"
        cat > "$hub_dir/scripts/bootstrap" <<'BOOTSTRAP'
#!/bin/bash
printf '%s\n' "$*" >> "$TEST_HUB_BOOTSTRAP_LOG"
if [[ "${TEST_HUB_BOOTSTRAP_INVALID:-0}" = 1 ]]; then
    exit 0
fi
mkdir -p "$HOME/.agents/skills/implement" "$HOME/.claude" "$HOME/.codex"
printf '%s\n' '---' 'name: implement' '---' > "$HOME/.agents/skills/implement/SKILL.md"
ln -sfn "$HOME/.agents/skills" "$HOME/.claude/skills"
ln -sfn "$HOME/.agents/skills" "$HOME/.codex/skills"
BOOTSTRAP
        chmod +x "$hub_dir/scripts/bootstrap"
        ;;
    *"rev-parse --is-inside-work-tree") printf 'true\n' ;;
    *"rev-parse HEAD") printf 'after-refresh\n' ;;
    *"remote get-url origin") printf '%s\n' 'https://github.com/ironicbuddha/skills-hub.git' ;;
    *"status --porcelain") ;;
    *"symbolic-ref --quiet --short refs/remotes/origin/HEAD") printf 'origin/main\n' ;;
    *"rev-parse --abbrev-ref HEAD") printf 'main\n' ;;
    *"fetch origin main") ;;
    *"merge-base --is-ancestor HEAD origin/main") ;;
    *"merge --ff-only origin/main") ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$bin_dir/git"
}

make_hub_fixture() {
    local hub_dir="$1"

    mkdir -p "$hub_dir/profiles" "$hub_dir/scripts"
    printf '%s\n' '{"schema_version":1,"skills":["implement"],"destinations":["agents","claude","codex"]}' \
        > "$hub_dir/profiles/carlo-baseline.json"
    cat > "$hub_dir/scripts/bootstrap" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$TEST_HUB_BOOTSTRAP_LOG"
if [[ "${TEST_HUB_BOOTSTRAP_INVALID:-0}" = 1 ]]; then
    exit 0
fi
mkdir -p "$HOME/.agents/skills/implement" "$HOME/.claude" "$HOME/.codex"
printf '%s\n' '---' 'name: implement' '---' > "$HOME/.agents/skills/implement/SKILL.md"
ln -sfn "$HOME/.agents/skills" "$HOME/.claude/skills"
ln -sfn "$HOME/.agents/skills" "$HOME/.codex/skills"
EOF
    chmod +x "$hub_dir/scripts/bootstrap"
}

test_existing_owned_hub_is_reused_and_applied_without_refresh() {
    local home_dir="$TEST_TMP_ROOT/valid/home"
    local hub_dir="$home_dir/dev/skills-hub"
    local bin_dir="$TEST_TMP_ROOT/valid/bin"
    local output="$TEST_TMP_ROOT/valid/output"

    mkdir -p "$home_dir"
    make_hub_fixture "$hub_dir"
    make_git_stub "$bin_dir"
    printf '%s\n' \
        'schema_version=1' \
        'repository=https://github.com/ironicbuddha/skills-hub.git' \
        'branch=main' \
        'checkout_commit=before-refresh' > "$hub_dir.bootstrap-owner"

    HOME="$home_dir" PATH="$bin_dir:$PATH" TEST_GIT_LOG="$TEST_TMP_ROOT/valid/git.log" \
        TEST_HUB_BOOTSTRAP_LOG="$TEST_TMP_ROOT/valid/hub-bootstrap.log" \
        /bin/bash "$REPO_ROOT/scripts/14-install-codex-skills.sh" > "$output" 2>&1 || \
        fail "valid Hub projection should succeed"

    if grep -Fq "fetch origin main" "$TEST_TMP_ROOT/valid/git.log"; then
        fail "ordinary reruns must not refresh the Hub source"
    fi
    if grep -Fq "merge --ff-only origin/main" "$TEST_TMP_ROOT/valid/git.log"; then
        fail "ordinary reruns must not merge moving upstream state"
    fi
    assert_file_contains "$TEST_TMP_ROOT/valid/hub-bootstrap.log" "--profile carlo-baseline --no-input"
}

test_explicit_refresh_fast_forwards_an_owned_clean_checkout() {
    local home_dir="$TEST_TMP_ROOT/refresh/home"
    local hub_dir="$home_dir/dev/skills-hub"
    local bin_dir="$TEST_TMP_ROOT/refresh/bin"
    local output="$TEST_TMP_ROOT/refresh/output"

    mkdir -p "$home_dir"
    make_hub_fixture "$hub_dir"
    make_git_stub "$bin_dir"
    printf '%s\n' \
        'schema_version=1' \
        'repository=https://github.com/ironicbuddha/skills-hub.git' \
        'branch=main' \
        'checkout_commit=before-refresh' > "$hub_dir.bootstrap-owner"

    HOME="$home_dir" PATH="$bin_dir:$PATH" TEST_GIT_LOG="$TEST_TMP_ROOT/refresh/git.log" \
        TEST_HUB_BOOTSTRAP_LOG="$TEST_TMP_ROOT/refresh/hub-bootstrap.log" \
        /bin/bash "$REPO_ROOT/scripts/14-install-codex-skills.sh" --refresh > "$output" 2>&1 || \
        fail "an owned clean checkout should refresh"

    assert_file_contains "$TEST_TMP_ROOT/refresh/git.log" "fetch origin main"
    assert_file_contains "$TEST_TMP_ROOT/refresh/git.log" "merge-base --is-ancestor HEAD origin/main"
    assert_file_contains "$TEST_TMP_ROOT/refresh/git.log" "merge --ff-only origin/main"
    assert_file_contains "$hub_dir.bootstrap-owner" 'checkout_commit=after-refresh'
}

test_unmarked_checkout_is_preserved_without_refreshing_or_applying() {
    local home_dir="$TEST_TMP_ROOT/unmarked/home"
    local hub_dir="$home_dir/dev/skills-hub"
    local bin_dir="$TEST_TMP_ROOT/unmarked/bin"
    local output="$TEST_TMP_ROOT/unmarked/output"

    mkdir -p "$home_dir"
    make_hub_fixture "$hub_dir"
    make_git_stub "$bin_dir"
    printf '%s\n' 'do not adopt' > "$hub_dir/sentinel"

    HOME="$home_dir" PATH="$bin_dir:$PATH" TEST_GIT_LOG="$TEST_TMP_ROOT/unmarked/git.log" \
        TEST_HUB_BOOTSTRAP_LOG="$TEST_TMP_ROOT/unmarked/hub-bootstrap.log" \
        /bin/bash "$REPO_ROOT/scripts/14-install-codex-skills.sh" > "$output" 2>&1 || \
        fail "an unmarked checkout must remain a non-gating warning"

    assert_file_contains "$output" "Refusing unowned Skill Hub checkout"
    assert_file_contains "$hub_dir/sentinel" "do not adopt"
    [[ ! -s "$TEST_TMP_ROOT/unmarked/hub-bootstrap.log" ]] || \
        fail "an unowned checkout must not apply a profile"
    if grep -Fq "fetch origin main" "$TEST_TMP_ROOT/unmarked/git.log"; then
        fail "an unowned checkout must not refresh"
    fi
}

test_invalid_profile_projection_is_reported_as_non_gating_degradation() {
    local home_dir="$TEST_TMP_ROOT/invalid-projection/home"
    local hub_dir="$home_dir/dev/skills-hub"
    local bin_dir="$TEST_TMP_ROOT/invalid-projection/bin"
    local output="$TEST_TMP_ROOT/invalid-projection/output"

    mkdir -p "$home_dir"
    make_hub_fixture "$hub_dir"
    make_git_stub "$bin_dir"
    printf '%s\n' \
        'schema_version=1' \
        'repository=https://github.com/ironicbuddha/skills-hub.git' \
        'branch=main' \
        'checkout_commit=before-refresh' > "$hub_dir.bootstrap-owner"

    HOME="$home_dir" PATH="$bin_dir:$PATH" TEST_GIT_LOG="$TEST_TMP_ROOT/invalid-projection/git.log" \
        TEST_HUB_BOOTSTRAP_LOG="$TEST_TMP_ROOT/invalid-projection/hub-bootstrap.log" \
        TEST_HUB_BOOTSTRAP_INVALID=1 \
        /bin/bash "$REPO_ROOT/scripts/14-install-codex-skills.sh" > "$output" 2>&1 || \
        fail "an invalid optional projection must not fail the wider bootstrap"

    assert_file_contains "$output" "Skill Hub profile did not produce a valid projection"
    assert_file_contains "$output" "rerun: ./scripts/14-install-codex-skills.sh --skill-selection carlo-baseline"
}

test_user_managed_hub_is_skipped_without_touching_skill_targets() {
    local home_dir="$TEST_TMP_ROOT/conflict/home"
    local hub_dir="$home_dir/dev/skills-hub"
    local output="$TEST_TMP_ROOT/conflict/output"

    mkdir -p "$hub_dir" "$home_dir/.agents/skills"
    printf '%s\n' 'user managed' > "$hub_dir/README.txt"
    printf '%s\n' 'keep me' > "$home_dir/.agents/skills/keep"

    HOME="$home_dir" /bin/bash "$REPO_ROOT/scripts/14-install-codex-skills.sh" > "$output" 2>&1 || \
        fail "a user-managed Hub must skip without failing bootstrap"

    assert_file_contains "$output" "Skipping Skill Hub installation"
    assert_file_contains "$home_dir/.agents/skills/keep" "keep me"
}

test_dangling_hub_symlink_is_not_replaced() {
    local home_dir="$TEST_TMP_ROOT/dangling-link/home"
    local hub_dir="$home_dir/dev/skills-hub"
    local output="$TEST_TMP_ROOT/dangling-link/output"

    mkdir -p "$(dirname "$hub_dir")"
    ln -s "$TEST_TMP_ROOT/dangling-link/missing-hub" "$hub_dir"

    HOME="$home_dir" /bin/bash "$REPO_ROOT/scripts/14-install-codex-skills.sh" > "$output" 2>&1 || \
        fail "a dangling Hub symlink must skip without failing bootstrap"

    [[ -L "$hub_dir" ]] || fail "a dangling Hub symlink must not be replaced"
    assert_file_contains "$output" "Refusing user-managed or invalid Skill Hub path"
}

test_failed_first_clone_does_not_block_a_later_retry() {
    local home_dir="$TEST_TMP_ROOT/retry/home"
    local hub_dir="$home_dir/dev/skills-hub"
    local bin_dir="$TEST_TMP_ROOT/retry/bin"
    local first_output="$TEST_TMP_ROOT/retry/first-output"
    local second_output="$TEST_TMP_ROOT/retry/second-output"

    mkdir -p "$home_dir"
    make_git_stub "$bin_dir"

    HOME="$home_dir" PATH="$bin_dir:$PATH" TEST_GIT_CLONE_FAIL=1 \
        TEST_GIT_LOG="$TEST_TMP_ROOT/retry/first-git.log" \
        TEST_HUB_BOOTSTRAP_LOG="$TEST_TMP_ROOT/retry/hub-bootstrap.log" \
        /bin/bash "$REPO_ROOT/scripts/14-install-codex-skills.sh" > "$first_output" 2>&1 || \
        fail "a failed first clone must not fail the broader bootstrap"

    [[ ! -e "$hub_dir" ]] || fail "a failed clone must not leave a Hub path behind"

    HOME="$home_dir" PATH="$bin_dir:$PATH" TEST_GIT_LOG="$TEST_TMP_ROOT/retry/second-git.log" \
        TEST_HUB_BOOTSTRAP_LOG="$TEST_TMP_ROOT/retry/hub-bootstrap.log" \
        /bin/bash "$REPO_ROOT/scripts/14-install-codex-skills.sh" > "$second_output" 2>&1 || \
        fail "a later clone retry should succeed"

    assert_file_contains "$TEST_TMP_ROOT/retry/second-git.log" "clone https://github.com/ironicbuddha/skills-hub.git"
    assert_file_contains "$TEST_TMP_ROOT/retry/hub-bootstrap.log" "--profile carlo-baseline --no-input"
    [[ -f "$hub_dir.bootstrap-owner" ]] || fail "a bootstrap clone must record its ownership"
}

test_canonical_projection_is_readable_through_every_harness() {
    local home_dir="$TEST_TMP_ROOT/canonical/home"

    mkdir -p "$home_dir/.agents/skills" "$home_dir/.claude" "$home_dir/.codex" "$home_dir/source/implement"
    printf '%s\n' '---' 'name: implement' '---' > "$home_dir/source/implement/SKILL.md"
    ln -s "$home_dir/source/implement" "$home_dir/.agents/skills/implement"
    ln -s "$home_dir/.agents/skills" "$home_dir/.claude/skills"
    ln -s "$home_dir/.agents/skills" "$home_dir/.codex/skills"

    skill_hub_projection_valid "$home_dir" || fail "$SKILL_HUB_PROJECTION_REASON"
}

test_broken_harness_projection_is_rejected() {
    local home_dir="$TEST_TMP_ROOT/broken-projection/home"

    mkdir -p "$home_dir/.agents/skills/implement" "$home_dir/.claude" "$home_dir/.codex"
    printf '%s\n' '---' 'name: implement' '---' > "$home_dir/.agents/skills/implement/SKILL.md"
    ln -s "$home_dir/.agents/skills" "$home_dir/.claude/skills"
    ln -s "$home_dir/.agents/missing-skills" "$home_dir/.codex/skills"

    assert_projection_is_invalid "$home_dir" "Codex skill projection is missing or broken"
}

test_missing_claude_projection_is_rejected() {
    local home_dir="$TEST_TMP_ROOT/missing-claude/home"

    mkdir -p "$home_dir/.agents/skills/implement" "$home_dir/.codex"
    printf '%s\n' '---' 'name: implement' '---' > "$home_dir/.agents/skills/implement/SKILL.md"
    ln -s "$home_dir/.agents/skills" "$home_dir/.codex/skills"

    assert_projection_is_invalid "$home_dir" "Claude skill projection is missing or broken"
}

# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/skill-hub-projection.sh"

run_test() {
    local evidence_class="$1"
    local name="$2"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - [evidence=$evidence_class] ${name#test_}"
}

run_test step test_existing_owned_hub_is_reused_and_applied_without_refresh
run_test step test_explicit_refresh_fast_forwards_an_owned_clean_checkout
run_test step test_unmarked_checkout_is_preserved_without_refreshing_or_applying
run_test step test_invalid_profile_projection_is_reported_as_non_gating_degradation
run_test step test_user_managed_hub_is_skipped_without_touching_skill_targets
run_test step test_dangling_hub_symlink_is_not_replaced
run_test step test_failed_first_clone_does_not_block_a_later_retry
run_test helper test_canonical_projection_is_readable_through_every_harness
run_test helper test_broken_harness_projection_is_rejected
run_test helper test_missing_claude_projection_is_rejected

echo "1..$TEST_COUNT"
