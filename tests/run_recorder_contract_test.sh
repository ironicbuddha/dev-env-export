#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-run-recorder-tests.XXXXXX")"
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

    grep -Fq "$expected" "$file" ||
        fail "$file does not contain: $expected"
}

assert_tree_does_not_contain() {
    local root="$1"
    local unexpected="$2"

    if grep -R -Fq "$unexpected" "$root"; then
        fail "$root unexpectedly contains: $unexpected"
    fi
}

test_run_start_is_durable_and_incomplete_until_finalized() {
    local case_root="$TEST_TMP_ROOT/run-start"
    local run_dir="$case_root/logs/bootstrap-test-run"

    mkdir -p "$run_dir" "$case_root/source"
    printf 'fixture source\n' > "$case_root/source/bootstrap-source.txt"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-run-recorder.sh"

    bootstrap_recorder_begin_run \
        "$run_dir" \
        "bootstrap-test-run" \
        "shared-baseline" \
        "$case_root/source" \
        "/bin/bash scripts/00-bootstrap.sh --profile shared-baseline"

    assert_file_contains "$run_dir/events.tsv" $'1\trun_start\t'
    assert_file_contains "$run_dir/current-state.txt" "schema_version=1"
    assert_file_contains "$run_dir/current-state.txt" "outcome=interrupted_incomplete"
    assert_file_contains "$run_dir/current-state.txt" "privacy=local-sensitive"
    assert_file_contains "$run_dir/current-state.txt" "source_kind=zip"
    assert_file_contains "$run_dir/current-state.txt" "source_identity=zip-tree-sha256:"
    assert_equals \
        "bootstrap-test-run" \
        "$(cat "$case_root/logs/latest-run.txt")" \
        "latest-run discovery should use the portable run-directory name"

    if find "$run_dir" -maxdepth 1 -name '.current-state.*' -print -quit |
            grep -q .; then
        fail "atomic current-state staging was not cleaned up"
    fi
}

test_step_operation_and_final_transitions_are_durable() {
    local case_root="$TEST_TMP_ROOT/transitions"
    local run_dir="$case_root/logs/bootstrap-transition-run"

    mkdir -p "$run_dir" "$case_root/source"
    printf 'fixture source\n' > "$case_root/source/bootstrap-source.txt"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-run-recorder.sh"

    bootstrap_recorder_begin_run \
        "$run_dir" \
        "bootstrap-transition-run" \
        "carlo-baseline" \
        "$case_root/source" \
        "/bin/bash scripts/00-bootstrap.sh --profile carlo-baseline"
    bootstrap_recorder_set_step_plan first.sh second.sh
    bootstrap_recorder_begin_step first.sh first.log
    assert_file_contains "$run_dir/current-state.txt" "current_step=first.sh"
    assert_file_contains "$run_dir/current-state.txt" "remaining_steps=first.sh,second.sh"

    bootstrap_recorder_begin_operation execute_step first.sh first.log
    assert_file_contains "$run_dir/current-state.txt" "current_operation=execute_step"
    assert_file_contains "$run_dir/current-state.txt" "current_target=first.sh"
    assert_file_contains "$run_dir/events.tsv" $'\toperation_start\t'

    bootstrap_recorder_end_operation \
        satisfied \
        none \
        step_completed \
        0 \
        none \
        "Step command completed." \
        first.log
    bootstrap_recorder_end_step \
        first.sh \
        satisfied \
        none \
        step_completed \
        0 \
        none \
        "Step completed." \
        first.log
    assert_file_contains "$run_dir/current-state.txt" "current_step=none"
    bootstrap_recorder_finalize completed 0

    assert_file_contains "$run_dir/current-state.txt" "outcome=completed"
    assert_file_contains "$run_dir/current-state.txt" "completed_steps=first.sh"
    assert_file_contains "$run_dir/current-state.txt" "remaining_steps=second.sh"
    assert_file_contains "$run_dir/current-state.txt" "uncertain_work=none"
    assert_file_contains "$run_dir/events.tsv" $'\tstep_end\t'
    assert_file_contains "$run_dir/events.tsv" $'\trun_end\t'
}

test_child_operation_failure_becomes_the_step_failure_context() {
    local case_root="$TEST_TMP_ROOT/child-operation-failure"
    local run_dir="$case_root/logs/bootstrap-child-operation-failure"

    mkdir -p "$run_dir" "$case_root/source"
    printf 'fixture source\n' > "$case_root/source/bootstrap-source.txt"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-run-recorder.sh"
    bootstrap_recorder_begin_run \
        "$run_dir" \
        "bootstrap-child-operation-failure" \
        "shared-baseline" \
        "$case_root/source" \
        "/bin/bash scripts/00-bootstrap.sh --profile shared-baseline"
    bootstrap_recorder_set_step_plan 02-install-cli-tools.sh
    bootstrap_recorder_begin_step 02-install-cli-tools.sh 02-install-cli-tools.log
    bootstrap_recorder_begin_operation execute_step 02-install-cli-tools.sh 02-install-cli-tools.log
    printf '%s\n' \
        $'2\toperation_end\t2026-07-29T00:00:00Z\terror\trequired_failure\tintegrity_failure\tintegrity_failure\t02-install-cli-tools.sh\tformula_install\tgit\t1\tdo_not_retry\tFormula install failed.\t02-install-cli-tools.log' \
        >> "$BOOTSTRAP_RECORDER_EVENTS_FILE"

    bootstrap_recorder_adopt_last_child_failure ||
        fail "child failure context should be available"
    assert_equals "formula_install" "$BOOTSTRAP_RECORDER_CURRENT_OPERATION" \
        "child operation should replace the wrapper operation"
    assert_equals "integrity_failure" "$BOOTSTRAP_RECORDER_FAILURE_CLASS" \
        "child failure class should be retained"
    bootstrap_recorder_end_operation \
        required_failure "$BOOTSTRAP_RECORDER_FAILURE_CLASS" \
        "$BOOTSTRAP_RECORDER_FAILURE_CODE" "$BOOTSTRAP_RECORDER_RAW_STATUS" \
        "$BOOTSTRAP_RECORDER_RECOVERY" "Child operation failed." 02-install-cli-tools.log
    bootstrap_recorder_end_step \
        02-install-cli-tools.sh required_failure "$BOOTSTRAP_RECORDER_FAILURE_CLASS" \
        "$BOOTSTRAP_RECORDER_FAILURE_CODE" "$BOOTSTRAP_RECORDER_RAW_STATUS" \
        "$BOOTSTRAP_RECORDER_RECOVERY" "Child operation failed." 02-install-cli-tools.log
    bootstrap_recorder_finalize required_failure 1

    assert_file_contains "$run_dir/current-state.txt" "failed_operation=formula_install"
    assert_file_contains "$run_dir/current-state.txt" "failure_class=integrity_failure"
    assert_file_contains "$run_dir/current-state.txt" "failure_code=integrity_failure"
}

test_child_manual_action_retains_its_disposition() {
    local case_root="$TEST_TMP_ROOT/child-manual-action"
    local run_dir="$case_root/logs/bootstrap-child-manual-action"

    mkdir -p "$run_dir" "$case_root/source"
    printf 'fixture source\n' > "$case_root/source/bootstrap-source.txt"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-run-recorder.sh"
    bootstrap_recorder_begin_run \
        "$run_dir" "bootstrap-child-manual-action" "shared-baseline" "$case_root/source" \
        "/bin/bash scripts/00-bootstrap.sh --profile shared-baseline"
    bootstrap_recorder_begin_step 02-install-cli-tools.sh 02-install-cli-tools.log
    bootstrap_recorder_begin_operation execute_step 02-install-cli-tools.sh 02-install-cli-tools.log
    printf '%s\n' \
        $'2\toperation_end\t2026-07-29T00:00:00Z\terror\tmanual_action\tmanual_action\tinteractive_vendor_action\t02-install-cli-tools.sh\tformula_install\tgit\t1\tmanual_then_retry\tHomebrew requested interaction.\t02-install-cli-tools.log' \
        >> "$BOOTSTRAP_RECORDER_EVENTS_FILE"

    bootstrap_recorder_adopt_last_child_failure || fail "child manual action should be available"
    assert_equals "manual_action" "$BOOTSTRAP_RECORDER_CHILD_DISPOSITION" \
        "child manual action disposition should be retained"
    bootstrap_recorder_end_operation \
        "$BOOTSTRAP_RECORDER_CHILD_DISPOSITION" "$BOOTSTRAP_RECORDER_FAILURE_CLASS" \
        "$BOOTSTRAP_RECORDER_FAILURE_CODE" "$BOOTSTRAP_RECORDER_RAW_STATUS" \
        "$BOOTSTRAP_RECORDER_RECOVERY" "Child operation requested manual action." 02-install-cli-tools.log
    bootstrap_recorder_end_step \
        02-install-cli-tools.sh "$BOOTSTRAP_RECORDER_CHILD_DISPOSITION" \
        "$BOOTSTRAP_RECORDER_FAILURE_CLASS" "$BOOTSTRAP_RECORDER_FAILURE_CODE" \
        "$BOOTSTRAP_RECORDER_RAW_STATUS" "$BOOTSTRAP_RECORDER_RECOVERY" \
        "Child operation requested manual action." 02-install-cli-tools.log
    bootstrap_recorder_finalize manual_action_required 1

    assert_file_contains "$run_dir/current-state.txt" "outcome=manual_action_required"
    assert_file_contains "$run_dir/current-state.txt" "failed_operation=formula_install"
    assert_file_contains "$run_dir/current-state.txt" "failure_code=interactive_vendor_action"
}

test_shareable_bundle_is_deterministic_and_excludes_local_sensitive_evidence() {
    local case_root="$TEST_TMP_ROOT/shareable"
    local run_dir="$case_root/logs/bootstrap-shareable-run"
    local output_one="$case_root/shareable-one"
    local output_two="$case_root/shareable-two"
    local sensitive_user="private-user"
    local sensitive_host="private-host"
    local sensitive_home="/Users/private-user"
    local sensitive_token="token-super-secret"
    local sensitive_git_file="private-client-name.txt"

    mkdir -p "$run_dir" "$case_root/source"
    printf 'fixture source\n' > "$case_root/source/bootstrap-source.txt"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-run-recorder.sh"
    bootstrap_recorder_begin_run \
        "$run_dir" \
        "bootstrap-shareable-run" \
        "shared-baseline" \
        "$case_root/source" \
        "/bin/bash scripts/00-bootstrap.sh --profile shared-baseline"
    bootstrap_recorder_set_step_plan first.sh
    bootstrap_recorder_begin_step first.sh first.log
    bootstrap_recorder_begin_operation execute_step first.sh first.log
    bootstrap_recorder_end_operation \
        required_failure \
        local_precondition \
        fixture_failed \
        42 \
        retry_profile \
        "Sensitive $sensitive_user $sensitive_host $sensitive_home $sensitive_token $sensitive_git_file" \
        first.log
    bootstrap_recorder_end_step \
        first.sh \
        required_failure \
        local_precondition \
        fixture_failed \
        42 \
        retry_profile \
        "Sensitive step failure." \
        first.log
    bootstrap_recorder_finalize required_failure 1

    printf '%s\n' \
        "user=$sensitive_user" \
        "hostname=$sensitive_host" \
        "home=$sensitive_home" \
        "git_file=$sensitive_git_file" > "$run_dir/environment.txt"
    printf 'credential=%s\n' "$sensitive_token" > "$run_dir/bootstrap.log"

    /bin/bash "$REPO_ROOT/scripts/create-shareable-bootstrap-bundle.sh" \
        --run-dir "$run_dir" \
        --output-dir "$output_one"
    /bin/bash "$REPO_ROOT/scripts/create-shareable-bootstrap-bundle.sh" \
        --run-dir "$run_dir" \
        --output-dir "$output_two"

    diff -r "$output_one" "$output_two" >/dev/null ||
        fail "sanitized exports from unchanged input should be deterministic"
    assert_file_contains "$output_one/summary.txt" "privacy=shareable-sanitized"
    assert_file_contains "$output_one/summary.txt" "failure_code=fixture_failed"
    assert_file_contains "$output_one/events.tsv" $'\toperation_end\t'
    assert_file_contains "$output_one/redactions.txt" "Raw transcripts and environment snapshots are excluded."
    assert_tree_does_not_contain "$output_one" "$sensitive_user"
    assert_tree_does_not_contain "$output_one" "$sensitive_host"
    assert_tree_does_not_contain "$output_one" "$sensitive_home"
    assert_tree_does_not_contain "$output_one" "$sensitive_token"
    assert_tree_does_not_contain "$output_one" "$sensitive_git_file"
}

test_git_source_identity_includes_commit_and_tree_digest() {
    local case_root="$TEST_TMP_ROOT/git-source"
    local run_dir="$case_root/logs/bootstrap-git-run"
    local expected_commit=""

    mkdir -p "$run_dir"
    expected_commit="$(git -C "$REPO_ROOT" rev-parse HEAD)"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-run-recorder.sh"
    bootstrap_recorder_begin_run \
        "$run_dir" \
        "bootstrap-git-run" \
        "shared-baseline" \
        "$REPO_ROOT" \
        "/bin/bash scripts/00-bootstrap.sh --profile shared-baseline"

    assert_file_contains "$run_dir/current-state.txt" "source_kind=git"
    assert_file_contains "$run_dir/current-state.txt" "source_identity=git:$expected_commit:"
    assert_file_contains "$run_dir/current-state.txt" ":tree-sha256:"
}

run_test() {
    local name="$1"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - ${name#test_}"
}

run_test test_run_start_is_durable_and_incomplete_until_finalized
run_test test_step_operation_and_final_transitions_are_durable
run_test test_child_operation_failure_becomes_the_step_failure_context
run_test test_child_manual_action_retains_its_disposition
run_test test_shareable_bundle_is_deterministic_and_excludes_local_sensitive_evidence
run_test test_git_source_identity_includes_commit_and_tree_digest

echo "1..$TEST_COUNT"
