#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-fresh-process-tests.XXXXXX")"
TEST_COUNT=0

# shellcheck disable=SC1091
source "$REPO_ROOT/tests/lib/fresh-process-harness.sh"

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$actual" != "$expected" ]; then
        fail "$message (expected '$expected', got '$actual')"
    fi
}

assert_file_contains() {
    local file="$1"
    local expected="$2"

    if ! grep -Fq "$expected" "$file"; then
        fail "$file does not contain: $expected"
    fi
}

test_case_runs_with_isolated_home_path_state_and_environment() {
    local case_root="$TEST_TMP_ROOT/isolated-case"
    local output_file=""
    local status=0

    bootstrap_test_case_init "$case_root"
    output_file="$case_root/output/environment.txt"
    export BOOTSTRAP_PARENT_ONLY_VALUE="must-not-leak"

    if bootstrap_test_run_with_env \
            "$case_root" \
            "$output_file" \
            BOOTSTRAP_EXPLICIT_TEST_VALUE=visible \
            -- \
            /bin/bash -c '
        printf "home=%s\n" "$HOME"
        printf "path=%s\n" "$PATH"
        printf "state=%s\n" "$BOOTSTRAP_TEST_STATE_DIR"
        printf "call_log=%s\n" "$BOOTSTRAP_TEST_CALL_LOG"
        printf "parent=%s\n" "${BOOTSTRAP_PARENT_ONLY_VALUE:-unset}"
        printf "explicit=%s\n" "$BOOTSTRAP_EXPLICIT_TEST_VALUE"
    '; then
        status=0
    else
        status=$?
    fi

    assert_equals "0" "$status" "isolated command should complete"
    assert_file_contains "$output_file" "home=$case_root/home"
    assert_file_contains "$output_file" "path=$case_root/fake-bin:"
    assert_file_contains "$output_file" "state=$case_root/state"
    assert_file_contains "$output_file" "call_log=$case_root/calls.log"
    assert_file_contains "$output_file" "parent=unset"
    assert_file_contains "$output_file" "explicit=visible"
}

test_stateful_fake_retains_calls_inside_one_case_only() {
    local first_case="$TEST_TMP_ROOT/first-case"
    local second_case="$TEST_TMP_ROOT/second-case"
    local first_output=""
    local second_output=""
    local status=0

    bootstrap_test_case_init "$first_case"
    bootstrap_test_install_stateful_fake "$first_case" example-tool
    bootstrap_test_configure_fake "$first_case" example-tool fail_once 73
    first_output="$first_case/output/example-tool.txt"

    if bootstrap_test_run "$first_case" "$first_output" example-tool first; then
        status=0
    else
        status=$?
    fi
    assert_equals "73" "$status" "fail-once fake should fail its first call"

    if bootstrap_test_run "$first_case" "$first_output" example-tool second; then
        status=0
    else
        status=$?
    fi
    assert_equals "0" "$status" "fail-once fake should succeed after its first call"
    assert_equals "2" "$(cat "$first_case/state/example-tool.calls")" \
        "one case should retain its adapter call count"
    assert_file_contains "$first_case/calls.log" $'example-tool\t1\tfirst'
    assert_file_contains "$first_case/calls.log" $'example-tool\t2\tsecond'

    bootstrap_test_case_init "$second_case"
    bootstrap_test_install_stateful_fake "$second_case" example-tool
    second_output="$second_case/output/example-tool.txt"

    if bootstrap_test_run "$second_case" "$second_output" example-tool isolated; then
        status=0
    else
        status=$?
    fi
    assert_equals "0" "$status" "a separate case should have independent adapter state"
    assert_equals "1" "$(cat "$second_case/state/example-tool.calls")" \
        "a separate case should start its own call count"
    assert_file_contains "$second_case/calls.log" $'example-tool\t1\tisolated'
}

run_test() {
    local name="$1"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - ${name#test_}"
}

run_test test_case_runs_with_isolated_home_path_state_and_environment
run_test test_stateful_fake_retains_calls_inside_one_case_only

echo "1..$TEST_COUNT"
