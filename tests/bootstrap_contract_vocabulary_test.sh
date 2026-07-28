#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-contract-vocabulary-tests.XXXXXX")"
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

test_published_vocabulary_matches_the_settled_contract() {
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bootstrap-contracts.sh"

    assert_equals "1" "$BOOTSTRAP_CONTRACT_SCHEMA_VERSION" \
        "contract schema should start at the published version"
    assert_equals \
        $'absent\nvalid_exact\nvalid_compatible\nmanaged_version_drift\nmanaged_invalid\nforeign_conflict\nunknown\ninterrupted' \
        "$(bootstrap_contract_values state)" \
        "state vocabulary drifted"
    assert_equals \
        $'changed\nsatisfied\nsatisfied_compatible\noptional_skipped\noptional_degraded\nmanual_action\nrequired_failure\ninterrupted\nlogging_failure' \
        "$(bootstrap_contract_values disposition)" \
        "disposition vocabulary drifted"
    assert_equals \
        $'transient_external\nmanual_action\nlocal_precondition\nmanaged_state_invalid\nforeign_state_conflict\nintegrity_failure\ninterrupted\nconcurrent_run\ninternal_failure\noptional_degraded' \
        "$(bootstrap_contract_values failure_class)" \
        "failure-class vocabulary drifted"
    assert_equals $'present\nrange\nexact' "$(bootstrap_contract_values package_requirement)" \
        "package-requirement vocabulary drifted"
    assert_equals $'required\noptional' "$(bootstrap_contract_values gating)" \
        "gating vocabulary drifted"
    assert_equals \
        $'retry_operation\nretry_profile\nmanual_then_retry\nresolve_conflict\ndo_not_retry\nnone' \
        "$(bootstrap_contract_values recovery)" \
        "recovery vocabulary drifted"
}

test_known_contract_values_round_trip_in_stock_bash() {
    local output_file="$TEST_TMP_ROOT/known-output.txt"
    local status=0

    if PATH=/nonexistent /bin/bash -c '
        source "$1"
        bootstrap_contract_validate state valid_exact
        bootstrap_contract_validate disposition changed
        bootstrap_contract_validate failure_class transient_external
        bootstrap_contract_validate package_requirement exact
        bootstrap_contract_validate gating optional
        bootstrap_contract_validate recovery retry_profile
    ' _ "$REPO_ROOT/scripts/lib/bootstrap-contracts.sh" > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    assert_equals "0" "$status" "known values should validate with shell builtins only"
    assert_equals \
        $'valid_exact\nchanged\ntransient_external\nexact\noptional\nretry_profile' \
        "$(cat "$output_file")" \
        "known values should round-trip without prose parsing"
}

test_unknown_contract_value_is_an_internal_failure() {
    local output_file="$TEST_TMP_ROOT/unknown-output.txt"
    local status=0

    if PATH=/nonexistent /bin/bash -c '
        source "$1"
        bootstrap_contract_validate state surprising_state
    ' _ "$REPO_ROOT/scripts/lib/bootstrap-contracts.sh" > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    assert_equals "1" "$status" "unknown contract values must fail"
    assert_file_contains "$output_file" "failure_class=internal_failure"
    assert_file_contains "$output_file" "code=contract_value_unknown"
    assert_file_contains "$output_file" "dimension=state"
}

test_unknown_contract_dimension_is_an_internal_failure() {
    local output_file="$TEST_TMP_ROOT/unknown-dimension-output.txt"
    local status=0

    if PATH=/nonexistent /bin/bash -c '
        source "$1"
        bootstrap_contract_validate invented_dimension exact
    ' _ "$REPO_ROOT/scripts/lib/bootstrap-contracts.sh" > "$output_file" 2>&1; then
        status=0
    else
        status=$?
    fi

    assert_equals "1" "$status" "unknown contract dimensions must fail"
    assert_file_contains "$output_file" "failure_class=internal_failure"
    assert_file_contains "$output_file" "code=contract_dimension_unknown"
    assert_file_contains "$output_file" "dimension=invented_dimension"
}

run_test() {
    local name="$1"

    TEST_COUNT=$((TEST_COUNT + 1))
    "$name"
    echo "ok $TEST_COUNT - ${name#test_}"
}

run_test test_published_vocabulary_matches_the_settled_contract
run_test test_known_contract_values_round_trip_in_stock_bash
run_test test_unknown_contract_value_is_an_internal_failure
run_test test_unknown_contract_dimension_is_an_internal_failure

echo "1..$TEST_COUNT"
