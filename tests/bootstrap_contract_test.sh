#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-bootstrap-tests.XXXXXX")"
TEST_COUNT=0

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

make_fixture() {
    local fixture_root="$1"
    local script_name=""

    mkdir -p "$fixture_root/scripts/lib" "$fixture_root/fake-bin" "$fixture_root/home"
    cp "$REPO_ROOT/scripts/00-bootstrap.sh" "$fixture_root/scripts/00-bootstrap.sh"
    cp "$REPO_ROOT/scripts/lib/bootstrap-profile.sh" "$fixture_root/scripts/lib/bootstrap-profile.sh"

    if [ -f "$REPO_ROOT/scripts/00-check-prerequisites.sh" ]; then
        cp "$REPO_ROOT/scripts/00-check-prerequisites.sh" "$fixture_root/scripts/00-check-prerequisites.sh"
    fi
    if [ -f "$REPO_ROOT/scripts/lib/bootstrap-prerequisites.sh" ]; then
        cp "$REPO_ROOT/scripts/lib/bootstrap-prerequisites.sh" "$fixture_root/scripts/lib/bootstrap-prerequisites.sh"
    fi

    for script_name in \
        01-install-brew.sh \
        02-install-cli-tools.sh \
        03-install-npm-globals.sh \
        04-install-pip-packages.sh \
        05-setup-dotfiles.sh \
        06-setup-claude.sh \
        07-setup-1password.sh \
        08-setup-gemini.sh \
        10-check-paths.sh \
        12-smoke-test.sh \
        15-setup-shared-shell.sh
    do
        cp "$REPO_ROOT/tests/fixtures/bootstrap-step-stub.sh" "$fixture_root/scripts/$script_name"
    done

    cp "$REPO_ROOT/tests/fixtures/uname-stub.sh" "$fixture_root/fake-bin/uname"
    cp "$REPO_ROOT/tests/fixtures/xcode-select-stub.sh" "$fixture_root/fake-bin/xcode-select"
    cp "$REPO_ROOT/tests/fixtures/xcrun-stub.sh" "$fixture_root/fake-bin/xcrun"
    cp "$REPO_ROOT/tests/fixtures/clang-stub.sh" "$fixture_root/fake-bin/clang"
    cp "$REPO_ROOT/tests/fixtures/tee-stub.sh" "$fixture_root/fake-bin/tee"
    chmod +x "$fixture_root/fake-bin/"* "$fixture_root/scripts/"*.sh
}

run_bootstrap() {
    local fixture_root="$1"
    local log_parent="$2"
    local output_file="$3"
    local status=0
    local real_tee=""

    real_tee="$(command -v tee)"

    if PATH="$fixture_root/fake-bin:$PATH" \
            HOME="$fixture_root/home" \
            DEV_ENV_LOG_DIR="$log_parent" \
            TEST_ACTION_LOG="$fixture_root/actions.log" \
            TEST_STEP_ORDER="$fixture_root/steps.log" \
            TEST_FAKE_CLANG="$fixture_root/fake-bin/clang" \
            TEST_REAL_TEE="$real_tee" \
            /bin/bash "$fixture_root/scripts/00-bootstrap.sh" --profile shared-baseline \
            > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    return "$status"
}

single_run_dir() {
    local log_parent="$1"
    local run_dir=""
    local count=0

    for run_dir in "$log_parent"/bootstrap-*; do
        if [ -d "$run_dir" ]; then
            count=$((count + 1))
            printf '%s\n' "$run_dir"
        fi
    done

    if [ "$count" -ne 1 ]; then
        fail "expected one run directory under $log_parent, found $count"
    fi
}

test_clt_missing_exits_before_homebrew() {
    local fixture_root="$TEST_TMP_ROOT/clt-missing"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""
    local status=0

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    if TEST_CLT_STATE=missing run_bootstrap "$fixture_root" "$log_parent" "$output_file"; then
        status=0
    else
        status=$?
    fi

    assert_equals "20" "$status" "missing CLT must use the manual-action exit contract"
    if [ -s "$fixture_root/steps.log" ]; then
        fail "Homebrew or a later bootstrap step ran before the CLT prerequisite passed"
    fi

    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$run_dir/summary.txt" "outcome=manual_action_required"
    assert_file_contains "$run_dir/summary.txt" "exit_status=20"
    assert_file_contains "$run_dir/step-status.tsv" $'00-check-prerequisites.sh\t20\tmanual_action_required(20)'
    assert_file_contains "$fixture_root/actions.log" "xcode-select --install"
}

test_success_checks_clt_before_homebrew() {
    local fixture_root="$TEST_TMP_ROOT/success"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""
    local status=0
    local clt_line=0
    local homebrew_line=0

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    if TEST_CLT_STATE=usable run_bootstrap "$fixture_root" "$log_parent" "$output_file"; then
        status=0
    else
        status=$?
    fi

    assert_equals "0" "$status" "usable CLT fixture should complete"
    clt_line="$(grep -n -F 'clang --version' "$fixture_root/actions.log" | head -n 1 | cut -d: -f1)"
    homebrew_line="$(grep -n -F 'step:01-install-brew.sh' "$fixture_root/actions.log" | head -n 1 | cut -d: -f1)"
    if [ "$clt_line" -ge "$homebrew_line" ]; then
        fail "Homebrew ran before the CLT usability probe completed"
    fi

    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$run_dir/summary.txt" "outcome=completed"
    assert_file_contains "$run_dir/summary.txt" "exit_status=0"
    assert_file_contains "$run_dir/step-status.tsv" $'00-check-prerequisites.sh\t0\tok'
    assert_file_contains "$run_dir/step-status.tsv" $'12-smoke-test.sh\t0\tok'
}

test_selected_but_broken_clt_exits_before_homebrew() {
    local fixture_root="$TEST_TMP_ROOT/clt-broken"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""
    local status=0

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    if TEST_CLT_STATE=broken run_bootstrap "$fixture_root" "$log_parent" "$output_file"; then
        status=0
    else
        status=$?
    fi

    assert_equals "20" "$status" "a selected but unusable CLT must use the manual-action exit contract"
    if [ -s "$fixture_root/steps.log" ]; then
        fail "Homebrew or a later bootstrap step ran with an unusable CLT"
    fi

    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$run_dir/summary.txt" "outcome=manual_action_required"
    assert_file_contains "$run_dir/step-status.tsv" $'00-check-prerequisites.sh\t20\tmanual_action_required(20)'
}

test_child_failure_records_failed_step() {
    local fixture_root="$TEST_TMP_ROOT/child-failure"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""
    local status=0

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    if TEST_CLT_STATE=usable TEST_FAIL_STEP=03-install-npm-globals.sh \
            run_bootstrap "$fixture_root" "$log_parent" "$output_file"; then
        status=0
    else
        status=$?
    fi

    assert_equals "1" "$status" "a failed child step must fail the bootstrap"
    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$run_dir/summary.txt" "outcome=failed"
    assert_file_contains "$run_dir/summary.txt" "failed_step=03-install-npm-globals.sh"
    assert_file_contains "$run_dir/step-status.tsv" $'03-install-npm-globals.sh\t1\tfailed(1)'
    if grep -Fq "04-install-pip-packages.sh" "$fixture_root/steps.log"; then
        fail "bootstrap continued after a failed child step"
    fi
}

test_tee_failure_is_not_reported_as_success() {
    local fixture_root="$TEST_TMP_ROOT/tee-failure"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""
    local status=0

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    if TEST_CLT_STATE=usable TEST_FAIL_TEE_STEP=01-install-brew.sh \
            run_bootstrap "$fixture_root" "$log_parent" "$output_file"; then
        status=0
    else
        status=$?
    fi

    assert_equals "1" "$status" "a step-log tee failure must fail the bootstrap"
    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$run_dir/summary.txt" "outcome=failed"
    assert_file_contains "$run_dir/summary.txt" "failed_step=01-install-brew.sh"
    assert_file_contains "$run_dir/step-status.tsv" $'01-install-brew.sh\t23\tlogging_failed(script=0 tee=23)'
}

test_reused_log_parent_keeps_runs_isolated() {
    local fixture_root="$TEST_TMP_ROOT/rerun"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local status=0
    local run_dir=""
    local run_dirs=()

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    if TEST_CLT_STATE=usable TEST_RUN_MARKER=first-run TEST_FAIL_STEP=03-install-npm-globals.sh \
            run_bootstrap "$fixture_root" "$log_parent" "$output_file"; then
        status=0
    else
        status=$?
    fi
    assert_equals "1" "$status" "first isolated run should record its injected failure"

    if TEST_CLT_STATE=usable TEST_RUN_MARKER=second-run \
            run_bootstrap "$fixture_root" "$log_parent" "$output_file"; then
        status=0
    else
        status=$?
    fi
    assert_equals "0" "$status" "second isolated run should complete"

    run_dirs=("$log_parent"/bootstrap-*)
    assert_equals "2" "${#run_dirs[@]}" "the reused parent must contain two run directories"

    for run_dir in "${run_dirs[@]}"; do
        assert_file_contains "$run_dir/summary.txt" "log_dir=$run_dir"
        if grep -Fq "fixture marker: first-run" "$run_dir/bootstrap.log"; then
            assert_file_contains "$run_dir/summary.txt" "outcome=failed"
            if grep -Fq "fixture marker: second-run" "$run_dir/bootstrap.log"; then
                fail "$run_dir/bootstrap.log mixes first and second run output"
            fi
        elif grep -Fq "fixture marker: second-run" "$run_dir/bootstrap.log"; then
            assert_file_contains "$run_dir/summary.txt" "outcome=completed"
            if grep -Fq "fixture marker: first-run" "$run_dir/bootstrap.log"; then
                fail "$run_dir/bootstrap.log mixes second and first run output"
            fi
        else
            fail "$run_dir/bootstrap.log contains neither run marker"
        fi
    done
}

run_test() {
    local name="$1"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - ${name#test_}"
}

run_test test_clt_missing_exits_before_homebrew
run_test test_success_checks_clt_before_homebrew
run_test test_selected_but_broken_clt_exits_before_homebrew
run_test test_child_failure_records_failed_step
run_test test_tee_failure_is_not_reported_as_success
run_test test_reused_log_parent_keeps_runs_isolated

echo "1..$TEST_COUNT"
