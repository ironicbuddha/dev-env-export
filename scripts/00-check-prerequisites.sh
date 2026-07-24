#!/bin/bash
# Verify manual macOS prerequisites before any Homebrew operation begins.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREREQUISITES_LIB="$SCRIPT_DIR/lib/bootstrap-prerequisites.sh"

# shellcheck disable=SC1090
source "$PREREQUISITES_LIB"

if ! bootstrap_ensure_apple_silicon; then
    exit 1
fi

if bootstrap_ensure_xcode_clt; then
    exit 0
else
    status=$?
    exit "$status"
fi
