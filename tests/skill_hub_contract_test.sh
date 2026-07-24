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
BOOTSTRAP
        chmod +x "$hub_dir/scripts/bootstrap"
        ;;
    *"rev-parse --is-inside-work-tree") printf 'true\n' ;;
    *"remote get-url origin") printf '%s\n' 'https://github.com/ironicbuddha/skills-hub.git' ;;
    *"status --porcelain") ;;
    *"symbolic-ref --quiet --short refs/remotes/origin/HEAD") printf 'origin/main\n' ;;
    *"rev-parse --abbrev-ref HEAD") printf 'main\n' ;;
    *"fetch origin main") ;;
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
EOF
    chmod +x "$hub_dir/scripts/bootstrap"
}

test_existing_valid_hub_is_fast_forwarded_and_applied() {
    local home_dir="$TEST_TMP_ROOT/valid/home"
    local hub_dir="$home_dir/dev/skills-hub"
    local bin_dir="$TEST_TMP_ROOT/valid/bin"
    local output="$TEST_TMP_ROOT/valid/output"

    mkdir -p "$home_dir"
    make_hub_fixture "$hub_dir"
    make_git_stub "$bin_dir"

    HOME="$home_dir" PATH="$bin_dir:$PATH" TEST_GIT_LOG="$TEST_TMP_ROOT/valid/git.log" \
        TEST_HUB_BOOTSTRAP_LOG="$TEST_TMP_ROOT/valid/hub-bootstrap.log" \
        /bin/bash "$REPO_ROOT/scripts/14-install-codex-skills.sh" > "$output" 2>&1 || \
        fail "valid Hub projection should succeed"

    assert_file_contains "$TEST_TMP_ROOT/valid/git.log" "fetch origin main"
    assert_file_contains "$TEST_TMP_ROOT/valid/git.log" "merge --ff-only origin/main"
    assert_file_contains "$TEST_TMP_ROOT/valid/hub-bootstrap.log" "--profile carlo-baseline --no-input"
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
}

test_existing_valid_hub_is_fast_forwarded_and_applied
TEST_COUNT=$((TEST_COUNT + 1))
test_user_managed_hub_is_skipped_without_touching_skill_targets
TEST_COUNT=$((TEST_COUNT + 1))
test_dangling_hub_symlink_is_not_replaced
TEST_COUNT=$((TEST_COUNT + 1))
test_failed_first_clone_does_not_block_a_later_retry
TEST_COUNT=$((TEST_COUNT + 1))

echo "PASS: $TEST_COUNT Skill Hub contract tests"
