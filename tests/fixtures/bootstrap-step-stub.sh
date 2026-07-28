#!/bin/bash

set -euo pipefail

script_name="$(basename "$0")"
echo "$script_name" >> "$TEST_STEP_ORDER"
echo "step:$script_name" >> "$TEST_ACTION_LOG"
if [ -n "${TEST_STEP_INVOCATION_LOG:-}" ]; then
    printf '%s\tprofile=%s\targs=%s\n' \
        "$script_name" \
        "${DEV_ENV_BOOTSTRAP_PROFILE:-unset}" \
        "$*" >> "$TEST_STEP_INVOCATION_LOG"
fi
echo "fixture step: $script_name"
if [ -n "${TEST_RUN_MARKER:-}" ]; then
    echo "fixture marker: $TEST_RUN_MARKER"
fi

if [ "${TEST_FAIL_STEP:-}" = "$script_name" ]; then
    exit "${TEST_FAIL_STATUS:-1}"
fi
