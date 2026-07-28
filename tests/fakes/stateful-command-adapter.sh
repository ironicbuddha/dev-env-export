#!/bin/bash

set -euo pipefail

command_name="$(basename "$0")"
state_dir="${BOOTSTRAP_TEST_STATE_DIR:?BOOTSTRAP_TEST_STATE_DIR is required}"
call_log="${BOOTSTRAP_TEST_CALL_LOG:?BOOTSTRAP_TEST_CALL_LOG is required}"
state_prefix="$state_dir/$command_name"
mode="success"
failure_status=1
call_count=0

if [ -f "$state_prefix.mode" ]; then
    mode="$(cat "$state_prefix.mode")"
fi
if [ -f "$state_prefix.failure-status" ]; then
    failure_status="$(cat "$state_prefix.failure-status")"
fi
if [ -f "$state_prefix.calls" ]; then
    call_count="$(cat "$state_prefix.calls")"
fi

call_count=$((call_count + 1))
printf '%s\n' "$call_count" > "$state_prefix.calls"
printf '%s\t%s\t%s\n' "$command_name" "$call_count" "$*" >> "$call_log"

if [ -f "$state_prefix.stdout" ]; then
    cat "$state_prefix.stdout"
fi
if [ -f "$state_prefix.stderr" ]; then
    cat "$state_prefix.stderr" >&2
fi

case "$mode" in
    success)
        exit 0
        ;;
    fail_once)
        if [ "$call_count" -eq 1 ]; then
            exit "$failure_status"
        fi
        exit 0
        ;;
    always_fail)
        exit "$failure_status"
        ;;
    *)
        echo "Unknown stateful fake mode: $mode" >&2
        exit 64
        ;;
esac
