#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-homebrew-operations-tests.XXXXXX")"
TEST_COUNT=0

cleanup() { rm -rf "$TEST_TMP_ROOT"; }
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

assert_equals() {
    [ "$1" = "$2" ] || fail "$3 (expected '$1', got '$2')"
}

assert_file_contains() {
    grep -Fq "$2" "$1" || fail "$1 does not contain: $2"
}

assert_events_have_recorder_shape() {
    awk -F '\t' 'NF != 14 { exit 1 }' "$1" ||
        fail "$1 contains an event outside the recorder schema"
}

assert_manual_action_terminal_event() {
    awk -F '\t' '$2 == "operation_end" && $5 == "manual_action" &&
        $6 == "manual_action" && $7 == "homebrew_curl_policy_conflict" { found = 1 }
        END { exit !found }' "$1" ||
        fail "$1 has no terminal manual curl-policy conflict event"
}

configure_case() {
    local case_root="$1"

    mkdir -p "$case_root/bin" "$case_root/state"
    BOOTSTRAP_OPERATION_EVENT_FILE="$case_root/events.tsv"
    BOOTSTRAP_OPERATION_STEP="02-install-cli-tools.sh"
    TEST_BREW_STATE_DIR="$case_root/state"
    TEST_BREW_CALL_LOG="$case_root/calls.log"
    TEST_BREW_CURLRC_LOG="$case_root/curlrc.log"
    DEV_ENV_OPERATION_POLL_SECONDS=0
    export BOOTSTRAP_OPERATION_EVENT_FILE BOOTSTRAP_OPERATION_STEP DEV_ENV_OPERATION_POLL_SECONDS
    export TEST_BREW_STATE_DIR TEST_BREW_CALL_LOG TEST_BREW_CURLRC_LOG
    PATH="$case_root/bin:$PATH"
    export PATH

    cp "$REPO_ROOT/tests/fakes/homebrew.sh" "$case_root/bin/brew"
    chmod +x "$case_root/bin/brew"
}

test_present_formula_never_refreshes_or_installs() {
    local case_root="$TEST_TMP_ROOT/present-formula"

    configure_case "$case_root"
    : > "$case_root/state/formula-git.present"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
    bootstrap_homebrew_ensure_formula git || fail "present formula should satisfy the adapter"

    assert_file_contains "$case_root/calls.log" "list --formula git"
    if grep -Eq '(^| )(update|install)( |$)' "$case_root/calls.log"; then
        fail "present formula accessed metadata or mutated Homebrew"
    fi
    assert_file_contains "$case_root/events.tsv" $'operation_end\t'
    assert_file_contains "$case_root/events.tsv" "satisfied"
    assert_events_have_recorder_shape "$case_root/events.tsv"
}

test_step_one_uses_the_adapter_for_present_core_formulae() {
    local case_root="$TEST_TMP_ROOT/step-one-present"
    local command_name=""
    local output_file="$case_root/output.txt"

    configure_case "$case_root"
    for command_name in git git-lfs jq curl wget; do
        : > "$case_root/state/formula-$command_name.present"
        printf '#!/bin/bash\nexit 0\n' > "$case_root/bin/$command_name"
        chmod +x "$case_root/bin/$command_name"
    done
    cp "$REPO_ROOT/tests/fixtures/uname-stub.sh" "$case_root/bin/uname"
    cp "$REPO_ROOT/tests/fixtures/sysctl-stub.sh" "$case_root/bin/sysctl"
    cp "$REPO_ROOT/tests/fixtures/xcode-select-stub.sh" "$case_root/bin/xcode-select"
    cp "$REPO_ROOT/tests/fixtures/xcrun-stub.sh" "$case_root/bin/xcrun"
    cp "$REPO_ROOT/tests/fixtures/clang-stub.sh" "$case_root/bin/clang"
    chmod +x "$case_root/bin/uname" "$case_root/bin/sysctl" \
        "$case_root/bin/xcode-select" "$case_root/bin/xcrun" "$case_root/bin/clang"

    TEST_CLT_STATE=usable TEST_UNAME_MACHINE=arm64 TEST_HW_OPTIONAL_ARM64=1 \
        TEST_FAKE_CLANG="$case_root/bin/clang" SHELL=/bin/zsh \
        /bin/bash "$REPO_ROOT/scripts/01-install-brew.sh" > "$output_file" 2>&1 ||
        fail "step 01 should retain all present core formulae"

    if grep -Eq '(^| )(update|install)( |$)' "$case_root/calls.log"; then
        fail "step 01 mutated Homebrew for present core formulae"
    fi
    assert_file_contains "$case_root/events.tsv" "formula_ensure"
}

test_transient_formula_failure_retries_once_after_absence_probe() {
    local case_root="$TEST_TMP_ROOT/transient-formula"

    configure_case "$case_root"
    printf '%s\n' fail_once > "$case_root/state/install-git.mode"
    printf '%s\n' 'curl: (56) Recv failure: Connection reset by peer' > "$case_root/state/install-git.stderr"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
    bootstrap_homebrew_ensure_formula git || fail "safe transient retry should recover"

    assert_equals 2 "$(cat "$case_root/state/install-git.calls")" \
        "transient formula install should retry exactly once"
    assert_file_contains "$case_root/events.tsv" "transient_external"
    assert_file_contains "$case_root/events.tsv" "retry_operation"
}

test_formula_retry_refuses_existing_vendor_prefix() {
    local case_root="$TEST_TMP_ROOT/formula-prefix-conflict"

    configure_case "$case_root"
    : > "$case_root/state/prefix-formula-git.exists"
    printf '%s\n' always_fail > "$case_root/state/install-git.mode"
    printf '%s\n' 'curl: (56) Recv failure: Connection reset by peer' > "$case_root/state/install-git.stderr"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
    if bootstrap_homebrew_ensure_formula git; then
        fail "an unregistered formula with a vendor prefix must not be retried"
    fi

    assert_equals 1 "$(cat "$case_root/state/install-git.calls")" \
        "formula prefix conflict must prevent automatic retry"
    assert_file_contains "$case_root/events.tsv" "ambiguous_post_failure_state"
}

test_permanent_formula_failure_does_not_retry() {
    local case_root="$TEST_TMP_ROOT/permanent-formula"

    configure_case "$case_root"
    printf '%s\n' always_fail > "$case_root/state/install-git.mode"
    printf '%s\n' 'Error: 403 Forbidden' > "$case_root/state/install-git.stderr"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
    if bootstrap_homebrew_ensure_formula git; then
        fail "permanent formula failure must remain gating"
    fi

    assert_equals 1 "$(cat "$case_root/state/install-git.calls")" \
        "permanent formula install must not retry"
    assert_file_contains "$case_root/events.tsv" "permanent_http_failure"
}

test_integrity_failure_wins_over_corrupt_vendor_output() {
    local case_root="$TEST_TMP_ROOT/integrity-formula"

    configure_case "$case_root"
    printf '%s\n' always_fail > "$case_root/state/install-git.mode"
    printf '%s\n' 'Error: corrupt archive: checksum mismatch' > "$case_root/state/install-git.stderr"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
    if bootstrap_homebrew_ensure_formula git; then
        fail "integrity failure must remain gating"
    fi

    assert_equals 1 "$(cat "$case_root/state/install-git.calls")" \
        "integrity failure must not retry"
    assert_file_contains "$case_root/events.tsv" $'integrity_failure\tintegrity_failure'
}

test_explicit_metadata_refresh_retries_read_only_work_three_times() {
    local case_root="$TEST_TMP_ROOT/metadata-refresh"

    configure_case "$case_root"
    printf '%s\n' always_fail > "$case_root/state/update-metadata.mode"
    printf '%s\n' 'curl: (56) Recv failure: Connection reset by peer' > "$case_root/state/update-metadata.stderr"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
    if DEV_ENV_REFRESH_BREW=1 bootstrap_homebrew_refresh_metadata; then
        fail "exhausted metadata refresh retries must remain gating"
    fi

    assert_equals 3 "$(cat "$case_root/state/update-metadata.calls")" \
        "explicit metadata refresh should make three read-only attempts"
    assert_file_contains "$case_root/events.tsv" "metadata_retry"
    assert_file_contains "$case_root/curlrc.log" "connect-timeout = 15"
    assert_file_contains "$case_root/curlrc.log" "max-time = 120"
}

test_existing_homebrew_curl_configuration_requires_manual_timeout_policy() {
    local case_root="$TEST_TMP_ROOT/existing-curlrc"
    local existing_curlrc="$case_root/existing-curlrc"

    configure_case "$case_root"
    printf '%s\n' 'proxy = "https://proxy.example.test"' > "$existing_curlrc"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
    if HOMEBREW_CURLRC="$existing_curlrc" bootstrap_homebrew_ensure_formula git; then
        fail "formula install must not bypass the required timeout policy"
    fi

    [ ! -f "$case_root/state/install-git.calls" ] ||
        fail "existing Homebrew curl config must block mutation until manual policy setup"
    assert_file_contains "$case_root/events.tsv" "homebrew_mutation_curl_timeouts_conflict"
    assert_file_contains "$case_root/events.tsv" "homebrew_curl_policy_conflict"
    assert_file_contains "$case_root/events.tsv" "manual_then_retry"
    assert_manual_action_terminal_event "$case_root/events.tsv"
}

test_metadata_refresh_curl_configuration_conflict_is_manual_action() {
    local case_root="$TEST_TMP_ROOT/metadata-curlrc-conflict"
    local existing_curlrc="$case_root/existing-curlrc"

    configure_case "$case_root"
    printf '%s\n' 'proxy = "https://proxy.example.test"' > "$existing_curlrc"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
    if DEV_ENV_REFRESH_BREW=1 HOMEBREW_CURLRC="$existing_curlrc" \
        bootstrap_homebrew_refresh_metadata; then
        fail "metadata refresh must not bypass the required timeout policy"
    fi

    [ ! -f "$case_root/state/update-metadata.calls" ] ||
        fail "existing Homebrew curl config must block metadata refresh"
    assert_file_contains "$case_root/events.tsv" "homebrew_metadata_curl_timeouts_conflict"
    assert_manual_action_terminal_event "$case_root/events.tsv"
}

test_registered_cask_is_not_retried_after_a_transient_repair_failure() {
    local case_root="$TEST_TMP_ROOT/registered-cask"

    configure_case "$case_root"
    : > "$case_root/state/cask-test-app.present"
    : > "$case_root/state/prefix-cask-test-app.owned"
    printf '%s\n' always_fail > "$case_root/state/reinstall-test-app.mode"
    printf '%s\n' 'curl: (56) Recv failure: Connection reset by peer' > "$case_root/state/reinstall-test-app.stderr"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
    bootstrap_cask_install_satisfied() { return 1; }
    if bootstrap_homebrew_ensure_cask test-app; then
        fail "registered cask repair failure must remain gating"
    fi

    assert_equals 1 "$(cat "$case_root/state/reinstall-test-app.calls")" \
        "registered cask must not retry an ambiguous repair"
    assert_file_contains "$case_root/events.tsv" "ambiguous_post_failure_state"
}

test_registered_cask_without_receipt_is_preserved() {
    local case_root="$TEST_TMP_ROOT/unowned-cask"

    configure_case "$case_root"
    : > "$case_root/state/cask-test-app.present"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
    bootstrap_cask_install_satisfied() { return 1; }
    if bootstrap_homebrew_ensure_cask test-app; then
        fail "an unowned registered cask must not be repaired"
    fi

    [ ! -f "$case_root/state/reinstall-test-app.calls" ] ||
        fail "unproven cask ownership must not invoke reinstall"
    assert_file_contains "$case_root/events.tsv" "cask_repair_ownership_unproven"
}

test_failure_matrix_drives_distinct_adapter_outcomes() {
    local case_root="$TEST_TMP_ROOT/adapter-failure-matrix"
    local label="" output="" expected_class="" expected_code=""
    local expected_calls="" expected_recovery=""

    while IFS='|' read -r label output expected_class expected_code expected_calls expected_recovery; do
        [ -n "$label" ] || continue
        configure_case "$case_root/$label"
        printf '%s\n' always_fail > "$case_root/$label/state/install-git.mode"
        printf '%s\n' "$output" > "$case_root/$label/state/install-git.stderr"

        # shellcheck disable=SC1091
        source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"
        if bootstrap_homebrew_ensure_formula git; then
            fail "$label failure must remain gating"
        fi

        assert_equals "$expected_calls" "$(cat "$case_root/$label/state/install-git.calls")" \
            "$label must use the intended retry count"
        assert_file_contains "$case_root/$label/events.tsv" \
            "$expected_class"
        assert_file_contains "$case_root/$label/events.tsv" \
            "$expected_code"
        assert_file_contains "$case_root/$label/events.tsv" \
            "$expected_recovery"
    done <<'EOF'
retry_after|Error: HTTP 429 Retry-After: 3|transient_external|http_retry_after|2|retry_operation
permission|Error: Permission denied|local_precondition|permission_denied|1|do_not_retry
interactive|Press return to continue|manual_action|interactive_vendor_action|1|manual_then_retry
partial|Error: partial download|managed_state_invalid|partial_vendor_state|1|do_not_retry
ambiguous|Error: vendor unexpectedly exited|internal_failure|ambiguous_vendor_state|1|do_not_retry
EOF
}

test_failure_matrix_and_policy_observation_are_classified() {
    local case_root="$TEST_TMP_ROOT/failure-matrix"
    local label="" output="" expected=""

    configure_case "$case_root"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/homebrew-operations.sh"

    while IFS='|' read -r label output expected; do
        [ -n "$label" ] || continue
        printf '%s\n' "$output" > "$case_root/$label.log"
        assert_equals "$expected" "$(bootstrap_homebrew_failure_code "$case_root/$label.log")" \
            "$label must retain its distinct stable code"
    done <<'EOF'
retry_after|Error: HTTP 429 Retry-After: 3|http_retry_after
integrity|Error: checksum mismatch|integrity_failure
permission|Error: Permission denied|permission_denied
interactive|Press return to continue|interactive_vendor_action
partial|Error: partial download|partial_vendor_state
ambiguous|Error: vendor unexpectedly exited|ambiguous_vendor_state
EOF

    printf '%s\n' 2 > "$case_root/state/install-git.delay"
    DEV_ENV_OPERATION_HEARTBEAT_SECONDS=1 DEV_ENV_OPERATION_DEADLINE_SECONDS=1 \
        DEV_ENV_OPERATION_POLL_SECONDS=1 \
        bootstrap_homebrew_ensure_formula git ||
        fail "observed successful install should pass"
    assert_file_contains "$case_root/events.tsv" "homebrew_mutation_curl_timeouts"
    assert_file_contains "$case_root/events.tsv" "homebrew_mutation_heartbeat"
    assert_file_contains "$case_root/events.tsv" "homebrew_mutation_deadline_observed"
    assert_file_contains "$case_root/curlrc.log" "connect-timeout = 15"
    assert_file_contains "$case_root/curlrc.log" "speed-limit = 1"
    assert_file_contains "$case_root/curlrc.log" "speed-time = 120"
}

run_test() {
    TEST_COUNT=$((TEST_COUNT + 1))
    "$1"
    echo "ok $TEST_COUNT - ${1#test_}"
}

run_test test_present_formula_never_refreshes_or_installs
run_test test_step_one_uses_the_adapter_for_present_core_formulae
run_test test_transient_formula_failure_retries_once_after_absence_probe
run_test test_formula_retry_refuses_existing_vendor_prefix
run_test test_permanent_formula_failure_does_not_retry
run_test test_integrity_failure_wins_over_corrupt_vendor_output
run_test test_explicit_metadata_refresh_retries_read_only_work_three_times
run_test test_existing_homebrew_curl_configuration_requires_manual_timeout_policy
run_test test_metadata_refresh_curl_configuration_conflict_is_manual_action
run_test test_registered_cask_is_not_retried_after_a_transient_repair_failure
run_test test_registered_cask_without_receipt_is_preserved
run_test test_failure_matrix_drives_distinct_adapter_outcomes
run_test test_failure_matrix_and_policy_observation_are_classified

echo "1..$TEST_COUNT"
