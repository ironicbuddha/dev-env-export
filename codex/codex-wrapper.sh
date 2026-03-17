#!/bin/bash
# Small launcher that attaches status metadata to a Codex session and can
# preview the matching statusline before exec'ing Codex.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_FORMAT="pretty"
PREVIEW_STATUS=0

usage() {
    cat <<'EOF'
Usage: codex-wrapper.sh [wrapper options] [--] [codex args...]

Wrapper options:
  --task <label>           Set CODEX_STATUS_TASK
  --check <summary>        Set CODEX_STATUS_LAST_CHECK
  --cmd <summary>          Set CODEX_STATUS_LAST_CMD
  --root <path>            Set CODEX_STATUS_ROOT
  --preview-status         Print status before launching Codex
  --status-format <mode>   pretty or compact
  -h, --help               Show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --task)
            shift
            CODEX_STATUS_TASK="${1:-}"
            ;;
        --check)
            shift
            CODEX_STATUS_LAST_CHECK="${1:-}"
            ;;
        --cmd)
            shift
            CODEX_STATUS_LAST_CMD="${1:-}"
            ;;
        --root)
            shift
            CODEX_STATUS_ROOT="${1:-}"
            ;;
        --preview-status)
            PREVIEW_STATUS=1
            ;;
        --status-format)
            shift
            STATUS_FORMAT="${1:-}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
    shift
done

if [ "$STATUS_FORMAT" != "pretty" ] && [ "$STATUS_FORMAT" != "compact" ]; then
    echo "Invalid status format: $STATUS_FORMAT" >&2
    exit 2
fi

export CODEX_STATUS_ROOT="${CODEX_STATUS_ROOT:-$PWD}"
export CODEX_STATUS_TASK="${CODEX_STATUS_TASK:-}"
export CODEX_STATUS_LAST_CHECK="${CODEX_STATUS_LAST_CHECK:-}"
export CODEX_STATUS_LAST_CMD="${CODEX_STATUS_LAST_CMD:-}"

if [ "$PREVIEW_STATUS" -eq 1 ]; then
    "$SCRIPT_DIR/statusline-context.sh" --format "$STATUS_FORMAT"
fi

exec codex "$@"
