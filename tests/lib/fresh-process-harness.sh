#!/bin/bash
# Fresh-process fixture harness for public bootstrap entrypoints.

BOOTSTRAP_TEST_HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_TEST_STATEFUL_FAKE="$BOOTSTRAP_TEST_HARNESS_DIR/../fakes/stateful-command-adapter.sh"

bootstrap_test_case_init() {
    local case_root="$1"

    mkdir -p \
        "$case_root/home" \
        "$case_root/fake-bin" \
        "$case_root/state" \
        "$case_root/output" \
        "$case_root/tmp"
    : > "$case_root/calls.log"
}

bootstrap_test_install_stateful_fake() {
    local case_root="$1"
    local command_name="$2"
    local destination="$case_root/fake-bin/$command_name"

    cp "$BOOTSTRAP_TEST_STATEFUL_FAKE" "$destination"
    chmod +x "$destination"
}

bootstrap_test_configure_fake() {
    local case_root="$1"
    local command_name="$2"
    local mode="$3"
    local failure_status="${4:-1}"
    local state_prefix="$case_root/state/$command_name"

    case "$mode" in
        success|fail_once|always_fail)
            ;;
        *)
            echo "FAIL: Unknown stateful fake mode: $mode" >&2
            return 1
            ;;
    esac

    printf '%s\n' "$mode" > "$state_prefix.mode"
    printf '%s\n' "$failure_status" > "$state_prefix.failure-status"
}

bootstrap_test_run() {
    local case_root="$1"
    local output_file="$2"
    shift 2

    bootstrap_test_run_with_env "$case_root" "$output_file" -- "$@"
}

bootstrap_test_run_with_env() {
    local case_root="$1"
    local output_file="$2"
    local explicit_env=("BOOTSTRAP_TEST_HARNESS=1")
    shift 2

    while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
        explicit_env+=("$1")
        shift
    done
    if [ "$#" -eq 0 ]; then
        echo "FAIL: bootstrap_test_run_with_env requires -- before the command" >&2
        return 1
    fi
    shift

    env -i \
        HOME="$case_root/home" \
        PATH="$case_root/fake-bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        SHELL="/bin/bash" \
        TMPDIR="$case_root/tmp" \
        LANG="C" \
        BOOTSTRAP_TEST_STATE_DIR="$case_root/state" \
        BOOTSTRAP_TEST_CALL_LOG="$case_root/calls.log" \
        "${explicit_env[@]}" \
        "$@" > "$output_file" 2>&1
}
