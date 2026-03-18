#!/bin/bash
# =============================================================================
# run_markdownlint_repo.sh - Run markdownlint Across Tracked Repo Markdown
# =============================================================================
# Applies or checks markdownlint against tracked .md files in a target repo.
# Prefers markdownlint-cli2, falls back to npx markdownlint-cli2, and then to
# markdownlint-cli when needed.
# =============================================================================

set -euo pipefail

MODE=""
TARGET_REPO="${2:-}"

usage() {
    cat <<'EOF'
Usage: ./scripts/run_markdownlint_repo.sh --fix [repo_path]
       ./scripts/run_markdownlint_repo.sh --check [repo_path]

Examples:
  ./scripts/run_markdownlint_repo.sh --fix
  ./scripts/run_markdownlint_repo.sh --check
  ./scripts/run_markdownlint_repo.sh --fix /path/to/repo
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage >&2
    exit 1
fi

case "$1" in
    --fix)
        MODE="fix"
        ;;
    --check)
        MODE="check"
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

if [[ -z "$TARGET_REPO" ]]; then
    TARGET_REPO="$(pwd)"
fi

if ! REPO_ROOT="$(git -C "$TARGET_REPO" rev-parse --show-toplevel 2>/dev/null)"; then
    echo "ERROR: Not a git repository: $TARGET_REPO" >&2
    exit 1
fi

CONFIG_ARGS=()
if [[ -f "$REPO_ROOT/.markdownlint.json" ]]; then
    CONFIG_ARGS+=("--config" "$REPO_ROOT/.markdownlint.json")
elif [[ -f "$REPO_ROOT/.markdownlint.yaml" ]]; then
    CONFIG_ARGS+=("--config" "$REPO_ROOT/.markdownlint.yaml")
elif [[ -f "$REPO_ROOT/.markdownlint.yml" ]]; then
    CONFIG_ARGS+=("--config" "$REPO_ROOT/.markdownlint.yml")
fi

IGNORE_ARGS=()
if [[ -f "$REPO_ROOT/.markdownlintignore" ]]; then
    IGNORE_ARGS+=("--ignore-path" "$REPO_ROOT/.markdownlintignore")
fi

MARKDOWN_FILES=()
while IFS= read -r markdown_file; do
    MARKDOWN_FILES+=("$markdown_file")
done < <(git -C "$REPO_ROOT" ls-files '*.md')

if [[ "${#MARKDOWN_FILES[@]}" -eq 0 ]]; then
    echo "No tracked Markdown files found in $REPO_ROOT"
    exit 0
fi

run_markdownlint_cli2() {
    local runner=("$@")

    (
        cd "$REPO_ROOT"
        if [[ "$MODE" = "fix" ]]; then
            "${runner[@]}" --fix "${MARKDOWN_FILES[@]}"
        else
            "${runner[@]}" "${MARKDOWN_FILES[@]}"
        fi
    )
}

run_markdownlint_cli1() {
    (
        cd "$REPO_ROOT"
        if [[ "$MODE" = "fix" ]]; then
            markdownlint \
                --fix \
                "${CONFIG_ARGS[@]}" \
                "${IGNORE_ARGS[@]}" \
                "${MARKDOWN_FILES[@]}"
        else
            markdownlint \
                "${CONFIG_ARGS[@]}" \
                "${IGNORE_ARGS[@]}" \
                "${MARKDOWN_FILES[@]}"
        fi
    )
}

echo "========================================"
echo "Markdown Lint Repo Runner"
echo "========================================"
echo ""
echo "Repo: $REPO_ROOT"
echo "Mode: $MODE"
echo "Tracked Markdown files: ${#MARKDOWN_FILES[@]}"
echo ""

if command -v markdownlint-cli2 >/dev/null 2>&1; then
    echo "Using global markdownlint-cli2"
    run_markdownlint_cli2 markdownlint-cli2
elif npx --yes markdownlint-cli2 --version >/dev/null 2>&1; then
    echo "Using npx markdownlint-cli2"
    run_markdownlint_cli2 npx --yes markdownlint-cli2
elif command -v markdownlint >/dev/null 2>&1; then
    echo "Using global markdownlint-cli fallback"
    run_markdownlint_cli1
else
    echo "ERROR: No markdownlint runner is available." >&2
    echo "Install markdownlint-cli2, or ensure npx can fetch it, or install markdownlint." >&2
    exit 1
fi

if [[ "$MODE" = "fix" ]]; then
    echo ""
    echo "Re-checking Markdown after fixes..."
    "$0" --check "$REPO_ROOT"
fi
