#!/bin/bash
# =============================================================================
# 11-create-1password-stubs.sh - Create 1Password Item Stubs From a Manifest
# =============================================================================
# Creates missing item shells in a chosen 1Password vault so the secrets model
# is scaffolded before real values are filled in.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="$REPO_ROOT/onepassword/stubs/core.tsv"
VAULT=""

usage() {
    cat <<'EOF'
Usage: ./scripts/11-create-1password-stubs.sh --vault VAULT [--manifest FILE]

Examples:
  ./scripts/11-create-1password-stubs.sh --vault Private
  ./scripts/11-create-1password-stubs.sh \
    --vault Private \
    --manifest onepassword/stubs/core.tsv
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vault)
            VAULT="${2:-}"
            shift 2
            ;;
        --manifest)
            MANIFEST_FILE="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$VAULT" ]]; then
    echo "ERROR: --vault is required" >&2
    usage >&2
    exit 1
fi

if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "ERROR: Manifest not found: $MANIFEST_FILE" >&2
    exit 1
fi

if ! command -v op >/dev/null 2>&1; then
    echo "ERROR: 1Password CLI (op) is not installed or not in PATH" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required for this script" >&2
    exit 1
fi

if ! op account list >/dev/null 2>&1; then
    echo "ERROR: 1Password CLI is not signed in yet" >&2
    echo "Run: op signin" >&2
    exit 1
fi

echo "========================================"
echo "Creating 1Password Item Stubs"
echo "========================================"
echo ""
echo "Vault: $VAULT"
echo "Manifest: $MANIFEST_FILE"
echo ""

items_json="$(op item list --vault "$VAULT" --format json)"
created=0
skipped=0

while IFS=$'\t' read -r category title tags; do
    if [[ -z "${category:-}" || "${category:0:1}" == "#" ]]; then
        continue
    fi

    if printf '%s' "$items_json" | jq -e --arg title "$title" '.[] | select(.title == $title)' >/dev/null; then
        echo "  [SKIP] $title"
        skipped=$((skipped + 1))
        continue
    fi

    args=(item create --category "$category" --title "$title" --vault "$VAULT")
    if [[ -n "${tags:-}" ]]; then
        args+=(--tags "$tags")
    fi

    op "${args[@]}" >/dev/null
    echo "  [CREATE] $title ($category)"
    created=$((created + 1))

    items_json="$(op item list --vault "$VAULT" --format json)"
done < "$MANIFEST_FILE"

echo ""
echo "Created: $created"
echo "Skipped: $skipped"
echo ""
echo "Next:"
echo "  - Open 1Password and fill in the created items"
echo "  - Use SECRETS-CHECKLIST.md to decide what values belong in each item"
