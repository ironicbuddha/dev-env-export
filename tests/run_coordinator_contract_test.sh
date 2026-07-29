#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-run-coordinator-tests.XXXXXX")"
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

    grep -Fq "$expected" "$file" ||
        fail "$file does not contain: $expected"
}

test_lock_lifecycle_requires_durable_final_state() {
    local case_root="$TEST_TMP_ROOT/lock-lifecycle"
    local log_parent="$case_root/logs"
    local run_dir="$log_parent/bootstrap-current"
    local lock_dir=""

    mkdir -p "$run_dir"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-run-coordinator.sh"
    bootstrap_coordinator_configure "$log_parent" "$run_dir" "bootstrap-current"
    bootstrap_coordinator_acquire_lock || fail "fresh coordinator lock should be acquired"

    lock_dir="$BOOTSTRAP_COORDINATOR_LOCK_DIR"
    assert_file_contains "$lock_dir/owner.txt" "pid=$$"
    assert_file_contains "$lock_dir/owner.txt" "run_dir=$run_dir"

    if bootstrap_coordinator_release_lock_after_finalization "$run_dir/current-state.txt"; then
        fail "lock must survive until a durable final state exists"
    fi
    [ -d "$lock_dir" ] || fail "lock was removed before finalization"

    printf '%s\n' "outcome=completed" "ended_at=2026-07-29T00:00:00Z" > "$run_dir/current-state.txt"
    bootstrap_coordinator_release_lock_after_finalization "$run_dir/current-state.txt" ||
        fail "finalized run should release its lock"
    [ ! -e "$lock_dir" ] || fail "lock remained after durable finalization"
}

test_live_lock_rejects_a_second_run() {
    local case_root="$TEST_TMP_ROOT/live-lock"
    local log_parent="$case_root/logs"
    local run_dir="$log_parent/bootstrap-current"
    local output_file="$case_root/second-run.txt"
    local status=0

    mkdir -p "$run_dir"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-run-coordinator.sh"
    bootstrap_coordinator_configure "$log_parent" "$run_dir" "bootstrap-current"
    bootstrap_coordinator_acquire_lock || fail "first run should own the lock"

    if /bin/bash -c '
        source "$1"
        bootstrap_coordinator_configure "$2" "$3" bootstrap-second
        bootstrap_coordinator_acquire_lock
    ' _ "$REPO_ROOT/scripts/lib/bootstrap-run-coordinator.sh" "$log_parent" "$run_dir" \
            > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    [ "$status" -eq 75 ] || fail "live lock should reject a second run with status 75, got $status"
    assert_file_contains "$output_file" "Bootstrap run already active"

    printf '%s\n' "outcome=completed" "ended_at=2026-07-29T00:00:00Z" > "$run_dir/current-state.txt"
    bootstrap_coordinator_release_lock_after_finalization "$run_dir/current-state.txt"
}

test_stale_lock_is_archived_before_a_new_lock_is_acquired() {
    local case_root="$TEST_TMP_ROOT/stale-lock"
    local log_parent="$case_root/logs"
    local previous_run="$log_parent/bootstrap-previous"
    local current_run="$log_parent/bootstrap-current"
    local archive_dir=""

    mkdir -p "$log_parent/bootstrap-mutation.lock" "$previous_run" "$current_run"
    printf '%s\n' "outcome=interrupted_incomplete" > "$previous_run/current-state.txt"
    printf '%s\n' \
        "pid=99999999" \
        "run_id=bootstrap-previous" \
        "run_dir=$previous_run" \
        "started_at=2026-07-28T00:00:00Z" \
        > "$log_parent/bootstrap-mutation.lock/owner.txt"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-run-coordinator.sh"
    bootstrap_coordinator_configure "$log_parent" "$current_run" "bootstrap-current"
    bootstrap_coordinator_acquire_lock || fail "proven stale lock should be replaced"

    archive_dir="$BOOTSTRAP_COORDINATOR_STALE_LOCK_ARCHIVE"
    [ -d "$archive_dir" ] || fail "stale lock was not archived"
    assert_file_contains "$archive_dir/owner.txt" "run_dir=$previous_run"
    assert_file_contains "$BOOTSTRAP_COORDINATOR_LOCK_DIR/owner.txt" "run_id=bootstrap-current"
    bootstrap_coordinator_prior_run_is_incomplete ||
        fail "next run did not recognize the incomplete prior run"

    printf '%s\n' "outcome=completed" "ended_at=2026-07-29T00:00:00Z" > "$current_run/current-state.txt"
    bootstrap_coordinator_release_lock_after_finalization "$current_run/current-state.txt"
}

test_unverifiable_lock_is_preserved_for_manual_recovery() {
    local case_root="$TEST_TMP_ROOT/unverifiable-lock"
    local log_parent="$case_root/logs"
    local run_dir="$log_parent/bootstrap-current"
    local output_file="$case_root/error.txt"
    local status=0

    mkdir -p "$log_parent/bootstrap-mutation.lock" "$run_dir"
    printf '%s\n' "run_id=unknown" > "$log_parent/bootstrap-mutation.lock/owner.txt"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-run-coordinator.sh"
    bootstrap_coordinator_configure "$log_parent" "$run_dir" "bootstrap-current"
    if bootstrap_coordinator_acquire_lock > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    [ "$status" -eq 76 ] || fail "unverifiable lock should require manual recovery"
    assert_file_contains "$output_file" "no verifiable owner pid"
    [ -d "$log_parent/bootstrap-mutation.lock" ] ||
        fail "unverifiable lock was destructively archived"
}

run_test() {
    local name="$1"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - ${name#test_}"
}

run_test test_lock_lifecycle_requires_durable_final_state
run_test test_live_lock_rejects_a_second_run
run_test test_stale_lock_is_archived_before_a_new_lock_is_acquired
run_test test_unverifiable_lock_is_preserved_for_manual_recovery

echo "1..$TEST_COUNT"
