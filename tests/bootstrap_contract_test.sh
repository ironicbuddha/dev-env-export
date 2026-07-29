#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-bootstrap-tests.XXXXXX")"
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

assert_file_does_not_contain() {
    local file="$1"
    local unexpected="$2"

    if grep -Fq "$unexpected" "$file"; then
        fail "$file unexpectedly contains: $unexpected"
    fi
}

expected_step_sequence() {
    local canonical_profile="$1"

    case "$canonical_profile" in
        carlo-baseline)
            printf '%s\n' \
                00-check-prerequisites.sh \
                01-install-brew.sh \
                02-install-cli-tools.sh \
                03-install-npm-globals.sh \
                04-install-pip-packages.sh \
                05-setup-dotfiles.sh \
                06-setup-claude.sh \
                07-setup-1password.sh \
                08-setup-gemini.sh \
                14-install-codex-skills.sh \
                10-check-paths.sh \
                12-smoke-test.sh
            ;;
        shared-baseline)
            printf '%s\n' \
                00-check-prerequisites.sh \
                01-install-brew.sh \
                02-install-cli-tools.sh \
                03-install-npm-globals.sh \
                04-install-pip-packages.sh \
                15-setup-shared-shell.sh \
                10-check-paths.sh \
                12-smoke-test.sh
            ;;
        *)
            fail "unknown canonical profile in expected sequence: $canonical_profile"
            ;;
    esac
}

expected_step_invocations() {
    local canonical_profile="$1"

    printf '%s\tprofile=%s\targs=%s\n' \
        01-install-brew.sh "$canonical_profile" ""
    printf '%s\tprofile=%s\targs=%s\n' \
        02-install-cli-tools.sh "$canonical_profile" "--profile $canonical_profile"
    printf '%s\tprofile=%s\targs=%s\n' \
        03-install-npm-globals.sh "$canonical_profile" "--profile $canonical_profile"
    printf '%s\tprofile=%s\targs=%s\n' \
        04-install-pip-packages.sh "$canonical_profile" "--profile $canonical_profile"

    case "$canonical_profile" in
        carlo-baseline)
            printf '%s\tprofile=%s\targs=%s\n' \
                05-setup-dotfiles.sh "$canonical_profile" ""
            printf '%s\tprofile=%s\targs=%s\n' \
                06-setup-claude.sh "$canonical_profile" ""
            printf '%s\tprofile=%s\targs=%s\n' \
                07-setup-1password.sh "$canonical_profile" ""
            printf '%s\tprofile=%s\targs=%s\n' \
                08-setup-gemini.sh "$canonical_profile" ""
            printf '%s\tprofile=%s\targs=%s\n' \
                14-install-codex-skills.sh "$canonical_profile" ""
            ;;
        shared-baseline)
            printf '%s\tprofile=%s\targs=%s\n' \
                15-setup-shared-shell.sh "$canonical_profile" ""
            ;;
    esac

    printf '%s\tprofile=%s\targs=%s\n' \
        10-check-paths.sh "$canonical_profile" "--profile $canonical_profile"
    printf '%s\tprofile=%s\targs=%s\n' \
        12-smoke-test.sh "$canonical_profile" "--profile $canonical_profile"
}

make_fixture() {
    local fixture_root="$1"
    local script_name=""

    bootstrap_test_case_init "$fixture_root"
    mkdir -p "$fixture_root/scripts/lib"
    cp "$REPO_ROOT/scripts/00-bootstrap.sh" "$fixture_root/scripts/00-bootstrap.sh"
    cp "$REPO_ROOT/scripts/lib/bootstrap-profile.sh" "$fixture_root/scripts/lib/bootstrap-profile.sh"
    cp "$REPO_ROOT/scripts/lib/bootstrap-run-recorder.sh" "$fixture_root/scripts/lib/bootstrap-run-recorder.sh"
    cp "$REPO_ROOT/scripts/lib/bootstrap-run-coordinator.sh" "$fixture_root/scripts/lib/bootstrap-run-coordinator.sh"

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
        14-install-codex-skills.sh \
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
    cp "$REPO_ROOT/tests/fixtures/sysctl-stub.sh" "$fixture_root/fake-bin/sysctl"
    cp "$REPO_ROOT/tests/fixtures/tee-stub.sh" "$fixture_root/fake-bin/tee"
    chmod +x "$fixture_root/fake-bin/"* "$fixture_root/scripts/"*.sh
}

run_bootstrap() {
    local fixture_root="$1"
    local log_parent="$2"
    local output_file="$3"
    local profile_input="${4:-shared-baseline}"

    run_bootstrap_with_args \
        "$fixture_root" \
        "$log_parent" \
        "$output_file" \
        --profile \
        "$profile_input"
}

run_bootstrap_with_args() {
    local fixture_root="$1"
    local log_parent="$2"
    local output_file="$3"
    local status=0
    local real_tee=""
    local env_args=()
    shift 3

    real_tee="$(command -v tee)"
    env_args=(
        "TEST_ACTION_LOG=$fixture_root/actions.log"
        "TEST_STEP_ORDER=$fixture_root/steps.log"
        "TEST_STEP_INVOCATION_LOG=$fixture_root/step-invocations.log"
        "TEST_RUN_ID_LOG=$fixture_root/run-ids.log"
        "TEST_FAKE_CLANG=$fixture_root/fake-bin/clang"
        "TEST_REAL_TEE=$real_tee"
        "TEST_CLT_STATE=${TEST_CLT_STATE:-usable}"
        "TEST_FAIL_STEP=${TEST_FAIL_STEP:-}"
        "TEST_FAIL_STATUS=${TEST_FAIL_STATUS:-1}"
        "TEST_FAIL_TEE_STEP=${TEST_FAIL_TEE_STEP:-}"
        "TEST_WARN_STEP=${TEST_WARN_STEP:-}"
        "TEST_RUN_MARKER=${TEST_RUN_MARKER:-}"
        "TEST_UNAME_MACHINE=${TEST_UNAME_MACHINE:-arm64}"
        "TEST_HW_OPTIONAL_ARM64=${TEST_HW_OPTIONAL_ARM64:-1}"
        "DEV_ENV_TEST_POSTFLIGHT_FAIL=${DEV_ENV_TEST_POSTFLIGHT_FAIL:-0}"
        "DEV_ENV_TRACE_STEPS=${DEV_ENV_TRACE_STEPS:-0}"
    )
    if [ -n "$log_parent" ]; then
        env_args+=("DEV_ENV_LOG_DIR=$log_parent")
    fi

    if bootstrap_test_run_with_env \
            "$fixture_root" \
            "$output_file" \
            "${env_args[@]}" \
            -- \
            /bin/bash "$fixture_root/scripts/00-bootstrap.sh" "$@"; then
        status=0
    else
        status=$?
    fi

    return "$status"
}

run_bootstrap_with_signal() {
    local fixture_root="$1"
    local log_parent="$2"
    local output_file="$3"
    local signal_name="$4"
    local status=0
    local real_tee=""

    real_tee="$(command -v tee)"
    if bootstrap_test_run_with_env \
            "$fixture_root" \
            "$output_file" \
            "TEST_ACTION_LOG=$fixture_root/actions.log" \
            "TEST_STEP_ORDER=$fixture_root/steps.log" \
            "TEST_STEP_INVOCATION_LOG=$fixture_root/step-invocations.log" \
            "TEST_RUN_ID_LOG=$fixture_root/run-ids.log" \
            "TEST_FAKE_CLANG=$fixture_root/fake-bin/clang" \
            "TEST_REAL_TEE=$real_tee" \
            "TEST_CLT_STATE=usable" \
            "TEST_STEP_SLEEP=01-install-brew.sh" \
            "TEST_SLEEP_SECONDS=30" \
            "DEV_ENV_LOG_DIR=$log_parent" \
            -- \
            /bin/bash "$REPO_ROOT/tests/fixtures/bootstrap-interrupt-launcher.sh" \
            "$fixture_root/steps.log" \
            "$signal_name" \
            /bin/bash "$fixture_root/scripts/00-bootstrap.sh" --profile shared-baseline; then
        status=0
    else
        status=$?
    fi

    return "$status"
}

run_direct_entrypoint() {
    local fixture_root="$1"
    local script_name="$2"
    local output_file="$3"
    local status=0

    if bootstrap_test_run_with_env \
            "$fixture_root" \
            "$output_file" \
            "TEST_ACTION_LOG=$fixture_root/actions.log" \
            "TEST_UNAME_MACHINE=${TEST_UNAME_MACHINE:-arm64}" \
            "TEST_HW_OPTIONAL_ARM64=${TEST_HW_OPTIONAL_ARM64:-1}" \
            -- \
            /bin/bash "$fixture_root/scripts/$script_name"; then
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
    assert_file_contains "$run_dir/summary.txt" "failure_class=manual_action"
    assert_file_contains "$run_dir/summary.txt" "failure_code=xcode_clt_manual_action"
    assert_file_contains "$run_dir/summary.txt" "recovery=manual_then_retry"
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
    assert_file_contains "$run_dir/summary.txt" "source_kind=zip"
    assert_file_contains "$run_dir/summary.txt" "source_identity=zip-tree-sha256:"
    assert_file_contains "$run_dir/summary.txt" "log_dir=."
    assert_file_does_not_contain "$run_dir/summary.txt" "$log_parent"
    assert_file_does_not_contain "$run_dir/step-status.tsv" "$log_parent"
    assert_file_contains "$run_dir/step-status.tsv" $'00-check-prerequisites.sh\t0\tok'
    assert_file_contains "$run_dir/step-status.tsv" $'12-smoke-test.sh\t0\tok'
}

test_bootstrap_exports_one_unique_run_id_to_every_step() {
    local fixture_root="$TEST_TMP_ROOT/exported-run-id"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""
    local summary_run_id=""
    local child_run_ids=""

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    TEST_CLT_STATE=usable \
        run_bootstrap "$fixture_root" "$log_parent" "$output_file" ||
        fail "run-id fixture should complete"

    run_dir="$(single_run_dir "$log_parent")"
    summary_run_id="$(sed -n 's/^run_id=//p' "$run_dir/summary.txt")"
    [ -n "$summary_run_id" ] || fail "summary should record a run id"
    child_run_ids="$(cut -f2 "$fixture_root/run-ids.log" | sort -u)"
    assert_equals \
        "$summary_run_id" \
        "$child_run_ids" \
        "every step should receive the summary run id"
    case "$summary_run_id" in
        *-*-*) ;;
        *) fail "run id should include time and unique entropy" ;;
    esac
    printf '%s\n' "$summary_run_id" |
        grep -Eq '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' ||
        fail "run id should include a globally unique UUID"
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
    assert_file_contains "$run_dir/summary.txt" "outcome=required_failure"
    assert_file_contains "$run_dir/summary.txt" "failed_step=03-install-npm-globals.sh"
    assert_file_contains "$run_dir/summary.txt" "failed_operation=execute_step"
    assert_file_contains "$run_dir/summary.txt" "failure_class=internal_failure"
    assert_file_contains "$run_dir/summary.txt" "failure_code=step_command_failed"
    assert_file_contains "$run_dir/summary.txt" "raw_status=1"
    assert_file_contains "$run_dir/summary.txt" "relevant_log=03-install-npm-globals.log"
    assert_file_contains "$output_file" "remaining_steps:"
    assert_file_contains "$output_file" "rerun_command:"
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
    assert_file_contains "$run_dir/summary.txt" "outcome=logging_failure"
    assert_file_contains "$run_dir/summary.txt" "failed_step=01-install-brew.sh"
    assert_file_contains "$run_dir/summary.txt" "failure_code=step_log_write_failed"
    assert_file_contains "$run_dir/step-status.tsv" $'01-install-brew.sh\t23\tlogging_failed(script=0 tee=23)'
}

test_optional_warning_changes_the_final_outcome() {
    local fixture_root="$TEST_TMP_ROOT/optional-warning"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    TEST_CLT_STATE=usable TEST_WARN_STEP=15-setup-shared-shell.sh \
        run_bootstrap "$fixture_root" "$log_parent" "$output_file" ||
        fail "a non-gating warning should not fail the bootstrap"

    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$run_dir/summary.txt" "outcome=completed_with_warnings"
    assert_file_contains "$run_dir/summary.txt" "warning_count=1"
    assert_file_contains "$run_dir/step-status.tsv" \
        $'15-setup-shared-shell.sh\t0\tcompleted_with_warning(1)'
    assert_file_contains "$run_dir/events.tsv" \
        $'\toptional_degraded\toptional_degraded\tstep_reported_warning\t'
}

test_postflight_failure_preserves_final_state() {
    local fixture_root="$TEST_TMP_ROOT/postflight-failure"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    DEV_ENV_TEST_POSTFLIGHT_FAIL=1 TEST_CLT_STATE=usable \
        run_bootstrap "$fixture_root" "$log_parent" "$output_file" ||
        fail "postflight evidence degradation should not erase a completed run"

    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$run_dir/current-state.txt" "outcome=completed_with_warnings"
    assert_file_contains "$run_dir/current-state.txt" "ended_at="
    assert_file_contains "$run_dir/events.tsv" "postflight_probe_failed"
    assert_file_contains "$run_dir/summary.txt" "warning_count=1"
}

test_trace_mode_warns_without_shell_argument_expansion() {
    local fixture_root="$TEST_TMP_ROOT/trace-privacy"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    DEV_ENV_TRACE_STEPS=1 TEST_CLT_STATE=usable \
        run_bootstrap "$fixture_root" "$log_parent" "$output_file" ||
        fail "trace metadata should not fail the bootstrap"

    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$output_file" "Trace metadata is local-sensitive"
    assert_file_contains "$run_dir/events.tsv" "trace_is_local_sensitive"
    if grep -Eq '^\\+ .*bootstrap-step-stub|^\\+ .*--profile' "$run_dir/bootstrap.log"; then
        fail "trace mode invoked bash xtrace and captured expanded arguments"
    fi
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
        assert_file_contains "$run_dir/summary.txt" "log_dir=."
        if grep -Fq "fixture marker: first-run" "$run_dir/bootstrap.log"; then
            assert_file_contains "$run_dir/summary.txt" "outcome=required_failure"
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

test_live_lock_rejects_second_bootstrap_and_interruption_stops_later_steps() {
    local fixture_root="$TEST_TMP_ROOT/live-lock-and-interruption"
    local log_parent="$fixture_root/logs"
    local first_output="$fixture_root/first-output.txt"
    local second_output="$fixture_root/second-output.txt"
    local first_pid=0
    local bootstrap_pid=0
    local first_status=0
    local second_status=0
    local run_dir=""
    local candidate_run_dir=""
    local attempts=0

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    env -i \
        HOME="$fixture_root/home" \
        PATH="$fixture_root/fake-bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        SHELL="/bin/bash" \
        TMPDIR="$fixture_root/tmp" \
        LANG="C" \
        BOOTSTRAP_TEST_HARNESS=1 \
        BOOTSTRAP_TEST_STATE_DIR="$fixture_root/state" \
        BOOTSTRAP_TEST_CALL_LOG="$fixture_root/calls.log" \
        TEST_ACTION_LOG="$fixture_root/actions.log" \
        TEST_STEP_ORDER="$fixture_root/steps.log" \
        TEST_STEP_INVOCATION_LOG="$fixture_root/step-invocations.log" \
        TEST_RUN_ID_LOG="$fixture_root/run-ids.log" \
        TEST_FAKE_CLANG="$fixture_root/fake-bin/clang" \
        TEST_REAL_TEE="$(command -v tee)" \
        TEST_CLT_STATE=usable \
        TEST_STEP_SLEEP=01-install-brew.sh \
        TEST_SLEEP_SECONDS=30 \
        DEV_ENV_LOG_DIR="$log_parent" \
        BOOTSTRAP_TEST_CHILD_PID_FILE="$fixture_root/bootstrap-child.pid" \
        /bin/bash -c '
            set -m
            "$@" &
            child_pid=$!
            printf "%s\n" "$child_pid" > "$BOOTSTRAP_TEST_CHILD_PID_FILE"
            wait "$child_pid"
        ' _ /bin/bash "$fixture_root/scripts/00-bootstrap.sh" --profile shared-baseline \
        > "$first_output" 2>&1 &
    first_pid=$!

    while ! grep -Fq "01-install-brew.sh" "$fixture_root/steps.log" 2>/dev/null; do
        attempts=$((attempts + 1))
        [ "$attempts" -lt 100 ] || fail "first bootstrap did not reach its active child"
        sleep 0.05
    done
    bootstrap_pid="$(cat "$fixture_root/bootstrap-child.pid")"

    if TEST_CLT_STATE=usable run_bootstrap "$fixture_root" "$log_parent" "$second_output"; then
        second_status=0
    else
        second_status=$?
    fi
    assert_equals "75" "$second_status" "a live run must reject a second bootstrap before mutation"
    assert_file_contains "$second_output" "Bootstrap run already active"

    kill -TERM "$bootstrap_pid"
    if wait "$first_pid"; then
        first_status=0
    else
        first_status=$?
    fi
    if [ "$first_status" -ne 143 ]; then
        cat "$first_output" >&2
        fail "SIGTERM must preserve the conventional interruption status (expected 143, got $first_status)"
    fi

    for candidate_run_dir in "$log_parent"/bootstrap-*; do
        if grep -Fq "signal_term" "$candidate_run_dir/events.tsv" 2>/dev/null; then
            run_dir="$candidate_run_dir"
            break
        fi
    done
    [ -n "$run_dir" ] || fail "interrupted run was not recorded"
    assert_file_contains "$run_dir/current-state.txt" "outcome=interrupted"
    assert_file_contains "$run_dir/current-state.txt" "ended_at="
    assert_file_contains "$run_dir/events.tsv" "signal_term"
    assert_file_contains "$run_dir/events.tsv" "run_interrupted"
    if grep -Fq "02-install-cli-tools.sh" "$fixture_root/steps.log"; then
        fail "a later step ran after interruption"
    fi
    [ ! -e "$log_parent/bootstrap-mutation.lock" ] ||
        fail "finalized interrupted run did not release its lock"
}

test_hup_and_int_forward_to_the_active_child_with_conventional_statuses() {
    local signal_name=""
    local expected_status=0
    local fixture_root=""
    local log_parent=""
    local output_file=""
    local run_dir=""
    local status=0
    local signal_code=""

    for signal_name in HUP INT; do
        case "$signal_name" in
            HUP) expected_status=129 ;;
            INT) expected_status=130 ;;
        esac
        signal_code="$(printf '%s' "$signal_name" | tr '[:upper:]' '[:lower:]')"
        fixture_root="$TEST_TMP_ROOT/signal-$signal_code"
        log_parent="$fixture_root/logs"
        output_file="$fixture_root/output.txt"
        make_fixture "$fixture_root"
        mkdir -p "$log_parent"

        if run_bootstrap_with_signal \
                "$fixture_root" "$log_parent" "$output_file" "$signal_name"; then
            status=0
        else
            status=$?
        fi
        assert_equals "$expected_status" "$status" "$signal_name must preserve its conventional status"
        run_dir="$(single_run_dir "$log_parent")"
        assert_file_contains "$run_dir/current-state.txt" "outcome=interrupted"
        assert_file_contains "$run_dir/events.tsv" "signal_$signal_code"
        if grep -Fq "02-install-cli-tools.sh" "$fixture_root/steps.log"; then
            fail "$signal_name allowed a later step to start"
        fi
    done
}

test_default_log_parent_is_durable_user_log_directory() {
    local fixture_root="$TEST_TMP_ROOT/default-log-parent"
    local output_file="$fixture_root/output.txt"
    local log_parent="$fixture_root/home/Library/Logs/dev-env-bootstrap"
    local run_dir=""
    local status=0

    make_fixture "$fixture_root"

    if TEST_CLT_STATE=usable run_bootstrap "$fixture_root" "" "$output_file"; then
        status=0
    else
        status=$?
    fi

    assert_equals "0" "$status" "the default durable log parent should support a successful run"
    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$run_dir/environment.txt" "dev_env_log_dir_override=unset"
}

test_direct_entrypoints_reject_intel_before_side_effects() {
    local fixture_root="$TEST_TMP_ROOT/intel-direct-entrypoints"
    local prerequisites_output="$fixture_root/prerequisites-output.txt"
    local brew_output="$fixture_root/brew-output.txt"
    local status=0

    make_fixture "$fixture_root"
    cp "$REPO_ROOT/scripts/01-install-brew.sh" "$fixture_root/scripts/01-install-brew.sh"
    chmod +x "$fixture_root/scripts/01-install-brew.sh"

    if TEST_UNAME_MACHINE=x86_64 run_direct_entrypoint \
            "$fixture_root" "00-check-prerequisites.sh" "$prerequisites_output"; then
        status=0
    else
        status=$?
    fi
    assert_equals "1" "$status" "the prerequisite entrypoint must reject Intel Macs"

    if TEST_UNAME_MACHINE=x86_64 run_direct_entrypoint \
            "$fixture_root" "01-install-brew.sh" "$brew_output"; then
        status=0
    else
        status=$?
    fi
    assert_equals "1" "$status" "the Homebrew entrypoint must reject Intel Macs"

    if [ -e "$fixture_root/actions.log" ]; then
        fail "direct entrypoints touched Xcode or Homebrew before rejecting Intel"
    fi
}

test_intel_mac_is_rejected_before_bootstrap_steps() {
    local fixture_root="$TEST_TMP_ROOT/intel-rejected"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""
    local status=0

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    if TEST_UNAME_MACHINE=x86_64 TEST_HW_OPTIONAL_ARM64=0 TEST_CLT_STATE=usable \
            run_bootstrap "$fixture_root" "$log_parent" "$output_file"; then
        status=0
    else
        status=$?
    fi

    assert_equals "1" "$status" "Intel Macs are outside the bootstrap contract"
    if [ -s "$fixture_root/steps.log" ]; then
        fail "bootstrap ran steps on an unsupported Intel Mac"
    fi

    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$run_dir/summary.txt" "outcome=required_failure"
    assert_file_contains "$output_file" "Apple Silicon Macs only"
}

assert_profile_contract() {
    local fixture_name="$1"
    local profile_input="$2"
    local canonical_profile="$3"
    local fixture_root="$TEST_TMP_ROOT/$fixture_name"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local run_dir=""
    local status=0

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    if TEST_CLT_STATE=usable \
            run_bootstrap "$fixture_root" "$log_parent" "$output_file" "$profile_input"; then
        status=0
    else
        status=$?
    fi

    assert_equals "0" "$status" "$profile_input should complete"
    run_dir="$(single_run_dir "$log_parent")"
    assert_file_contains "$run_dir/summary.txt" "bootstrap_profile=$canonical_profile"
    assert_equals \
        "$(expected_step_sequence "$canonical_profile")" \
        "$(tail -n +2 "$run_dir/step-status.tsv" | cut -f4)" \
        "$profile_input should run the exact $canonical_profile step sequence"
    assert_equals \
        "$(expected_step_invocations "$canonical_profile")" \
        "$(cat "$fixture_root/step-invocations.log")" \
        "$profile_input should forward only canonical profile arguments"
}

test_carlo_baseline_runs_exact_profile_contract() {
    assert_profile_contract carlo-canonical carlo-baseline carlo-baseline
}

test_carlo_alias_runs_exact_profile_contract() {
    assert_profile_contract carlo-alias carlo carlo-baseline
}

test_shared_baseline_runs_exact_profile_contract() {
    assert_profile_contract shared-canonical shared-baseline shared-baseline
}

test_shared_alias_runs_exact_profile_contract() {
    assert_profile_contract shared-alias shared shared-baseline
}

assert_invalid_profile_starts_no_child() {
    local fixture_name="$1"
    shift
    local fixture_root="$TEST_TMP_ROOT/$fixture_name"
    local log_parent="$fixture_root/logs"
    local output_file="$fixture_root/output.txt"
    local status=0

    make_fixture "$fixture_root"
    mkdir -p "$log_parent"

    if run_bootstrap_with_args "$fixture_root" "$log_parent" "$output_file" "$@"; then
        status=0
    else
        status=$?
    fi

    assert_equals "2" "$status" "invalid profile input should fail before setup"
    if [ -s "$fixture_root/steps.log" ] ||
            [ -s "$fixture_root/step-invocations.log" ] ||
            [ -s "$fixture_root/actions.log" ]; then
        fail "invalid profile input started a bootstrap child or prerequisite probe"
    fi
    if find "$log_parent" -mindepth 1 -print -quit | grep -q .; then
        fail "invalid profile input created a run directory"
    fi
}

test_missing_profile_starts_no_child() {
    assert_invalid_profile_starts_no_child missing-profile
}

test_unknown_profile_starts_no_child() {
    assert_invalid_profile_starts_no_child unknown-profile --profile not-a-profile
}

run_test() {
    local name="$1"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - ${name#test_}"
}

run_test test_clt_missing_exits_before_homebrew
run_test test_success_checks_clt_before_homebrew
run_test test_bootstrap_exports_one_unique_run_id_to_every_step
run_test test_selected_but_broken_clt_exits_before_homebrew
run_test test_child_failure_records_failed_step
run_test test_tee_failure_is_not_reported_as_success
run_test test_reused_log_parent_keeps_runs_isolated
run_test test_live_lock_rejects_second_bootstrap_and_interruption_stops_later_steps
run_test test_hup_and_int_forward_to_the_active_child_with_conventional_statuses
run_test test_default_log_parent_is_durable_user_log_directory
run_test test_optional_warning_changes_the_final_outcome
run_test test_postflight_failure_preserves_final_state
run_test test_trace_mode_warns_without_shell_argument_expansion
run_test test_intel_mac_is_rejected_before_bootstrap_steps
run_test test_direct_entrypoints_reject_intel_before_side_effects
run_test test_carlo_baseline_runs_exact_profile_contract
run_test test_carlo_alias_runs_exact_profile_contract
run_test test_shared_baseline_runs_exact_profile_contract
run_test test_shared_alias_runs_exact_profile_contract
run_test test_missing_profile_starts_no_child
run_test test_unknown_profile_starts_no_child

echo "1..$TEST_COUNT"
