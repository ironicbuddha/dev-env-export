#!/bin/bash
# Compact Codex statusline for tmux, Warp, or narrow status bars.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NO_COLOR=1 "$SCRIPT_DIR/statusline-context.sh" --format compact "$@"
