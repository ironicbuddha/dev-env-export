#!/bin/bash

set -euo pipefail

last_argument="${!#}"
step_log_name="${TEST_FAIL_TEE_STEP:-}"
step_log_name="${step_log_name%.sh}.log"

if [ -n "${TEST_FAIL_TEE_STEP:-}" ] && [ "$(basename "$last_argument")" = "$step_log_name" ]; then
    /bin/cat >/dev/null
    exit 23
fi

exec "$TEST_REAL_TEE" "$@"
