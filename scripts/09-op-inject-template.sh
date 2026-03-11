#!/bin/bash
# =============================================================================
# 09-op-inject-template.sh - Render a Secret Template with 1Password CLI
# =============================================================================
# Renders a template file containing 1Password secret references into a local
# output file using `op inject`.
# =============================================================================

set -euo pipefail

IN_FILE=""
OUT_FILE=""
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --in-file)
            IN_FILE="${2:-}"
            shift 2
            ;;
        --out-file)
            OUT_FILE="${2:-}"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        -h|--help)
            cat <<'EOF'
Usage: ./scripts/09-op-inject-template.sh --in-file FILE --out-file FILE [--force]

Examples:
  ./scripts/09-op-inject-template.sh \
    --in-file onepassword/examples/project.env.tpl \
    --out-file .env

  ./scripts/09-op-inject-template.sh \
    --in-file config/app.yml.tpl \
    --out-file config/app.yml \
    --force
EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$IN_FILE" || -z "$OUT_FILE" ]]; then
    echo "ERROR: --in-file and --out-file are required"
    exit 1
fi

if ! command -v op >/dev/null 2>&1; then
    echo "ERROR: 1Password CLI (op) is not installed or not in PATH"
    exit 1
fi

if [[ ! -f "$IN_FILE" ]]; then
    echo "ERROR: Input template not found: $IN_FILE"
    exit 1
fi

if [[ -f "$OUT_FILE" && "$FORCE" -ne 1 ]]; then
    echo "ERROR: Output file already exists: $OUT_FILE"
    echo "       Re-run with --force to overwrite it."
    exit 1
fi

mkdir -p "$(dirname "$OUT_FILE")"
op inject --in-file "$IN_FILE" --out-file "$OUT_FILE"

echo "Rendered $IN_FILE -> $OUT_FILE"
