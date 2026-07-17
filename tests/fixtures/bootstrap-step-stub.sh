#!/bin/bash

set -euo pipefail

script_name="$(basename "$0")"
echo "$script_name" >> "$TEST_STEP_ORDER"
echo "step:$script_name" >> "$TEST_ACTION_LOG"
echo "fixture step: $script_name"
if [ -n "${TEST_RUN_MARKER:-}" ]; then
    echo "fixture marker: $TEST_RUN_MARKER"
fi

if [ "${TEST_FAIL_STEP:-}" = "$script_name" ]; then
    exit "${TEST_FAIL_STATUS:-1}"
fi
