#!/bin/bash

set -euo pipefail

step_order_file="$1"
signal_name="$2"
shift 2

(
    attempts=0
    while ! grep -Fq "01-install-brew.sh" "$step_order_file" 2>/dev/null; do
        attempts=$((attempts + 1))
        [ "$attempts" -lt 100 ] || exit 1
        sleep 0.05
    done
    kill -"$signal_name" "$$"
) &

exec "$@"
