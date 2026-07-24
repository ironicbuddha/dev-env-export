#!/bin/bash
# =============================================================================
# 10-check-paths.sh - Verify Post-Bootstrap CLI Visibility
# =============================================================================
# Loads the intended Homebrew and nvm environment, then checks whether the key
# CLI tools expected by this repo are actually available.
# =============================================================================

set -euo pipefail

FAILURES=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_LIB="$SCRIPT_DIR/lib/bootstrap-profile.sh"
RUNTIME_LIB="$SCRIPT_DIR/lib/runtime-environment.sh"
EXPECTATIONS_LIB="$SCRIPT_DIR/lib/bootstrap-expectations.sh"
APP_BUNDLE_LIB="$SCRIPT_DIR/lib/app-bundle.sh"
BOOTSTRAP_PROFILE=""

# shellcheck disable=SC1090
source "$PROFILE_LIB"
# shellcheck disable=SC1090
source "$RUNTIME_LIB"
# shellcheck disable=SC1090
source "$EXPECTATIONS_LIB"
# shellcheck disable=SC1090
source "$APP_BUNDLE_LIB"

usage() {
    cat <<'EOF'
Usage: ./scripts/10-check-paths.sh --profile PROFILE

Checks CLI visibility for the selected Bootstrap Profile.

Options:
  --profile PROFILE   Required unless DEV_ENV_BOOTSTRAP_PROFILE is set
  -h, --help          Show this help

Valid profiles:
EOF
    bootstrap_print_profiles
}

PROFILE_INPUT="${DEV_ENV_BOOTSTRAP_PROFILE:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            if [ $# -lt 2 ]; then
                echo "ERROR: --profile requires a value." >&2
                usage >&2
                exit 2
            fi
            PROFILE_INPUT="${2:-}"
            shift 2
            ;;
        --profile=*)
            PROFILE_INPUT="${1#--profile=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ -z "$PROFILE_INPUT" ]; then
    echo "ERROR: Missing required Bootstrap Profile." >&2
    usage >&2
    exit 2
fi

if ! BOOTSTRAP_PROFILE="$(bootstrap_normalize_profile "$PROFILE_INPUT")"; then
    echo "ERROR: Unknown Bootstrap Profile: $PROFILE_INPUT" >&2
    usage >&2
    exit 2
fi

export DEV_ENV_BOOTSTRAP_PROFILE="$BOOTSTRAP_PROFILE"

bootstrap_load_expectations "$BOOTSTRAP_PROFILE"

check_cmd() {
    local label="$1"
    local cmd="$2"
    local hint="$3"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[OK]   $label -> $(command -v "$cmd")"
    else
        echo "[MISS] $label"
        echo "       $hint"
        FAILURES=$((FAILURES + 1))
    fi
}

echo "========================================"
echo "Dev Environment CLI Path Check"
echo "========================================"
echo ""
echo "Bootstrap profile: $(bootstrap_profile_label "$BOOTSTRAP_PROFILE") ($BOOTSTRAP_PROFILE)"
echo ""

bootstrap_load_homebrew || true
if bootstrap_load_nvm; then
    if ! bootstrap_activate_nvm_node "$BOOTSTRAP_NODE_VERSION"; then
        echo "[MISS] exact Node $BOOTSTRAP_NODE_VERSION could not be activated with nvm"
        FAILURES=$((FAILURES + 1))
    fi
else
    echo "[MISS] nvm could not be loaded"
    FAILURES=$((FAILURES + 1))
fi

echo "Checking CLI visibility in the intended bootstrap shell environment..."
echo ""

for required_command in "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"; do
    check_cmd "$required_command" "$required_command" \
        "Re-run the bootstrap step responsible for $required_command."
done

echo ""
if command -v node >/dev/null 2>&1; then
    NODE_PATH="$(command -v node)"
    if [[ "$NODE_PATH" == "$HOME/.nvm/versions/node/"* ]]; then
        echo "[OK]   node is owned by nvm -> $NODE_PATH"
    else
        echo "[MISS] node is not coming from nvm -> $NODE_PATH"
        echo "       Re-run scripts/02-install-cli-tools.sh or exec zsh to restore nvm precedence."
        FAILURES=$((FAILURES + 1))
    fi
fi

if command -v npm >/dev/null 2>&1; then
    NPM_PATH="$(command -v npm)"
    if [[ "$NPM_PATH" == "$HOME/.nvm/versions/node/"* ]]; then
        echo "[OK]   npm is owned by nvm -> $NPM_PATH"
    else
        echo "[MISS] npm is not coming from nvm -> $NPM_PATH"
        echo "       Re-run scripts/02-install-cli-tools.sh or exec zsh to restore nvm precedence."
        FAILURES=$((FAILURES + 1))
    fi
fi

echo ""
if [ "$BOOTSTRAP_PROFILE" = "carlo-baseline" ]; then
    if [ -L "$HOME/.agents/skills" ] && [ -L "$HOME/.codex/skills" ] && [ -L "$HOME/.claude/skills" ]; then
        echo "[OK]   Skill Hub projection links all agent harnesses"
    else
        echo "[WARN] Skill Hub projection is unavailable"
        echo "       Re-run scripts/14-install-codex-skills.sh after resolving any Hub warning."
    fi
fi

if PYTHON_BIN="$(bootstrap_resolve_python_bin 2>/dev/null)"; then
    echo "[OK]   baseline python -> $PYTHON_BIN"
else
    echo "[MISS] baseline python"
    echo "       Python 3.14 should come from scripts/02-install-cli-tools.sh."
    FAILURES=$((FAILURES + 1))
fi

echo ""
for required_bundle in "${BOOTSTRAP_REQUIRED_APP_BUNDLES[@]}"; do
    if bootstrap_app_bundle_usable "/Applications/$required_bundle"; then
        echo "[OK]   $required_bundle -> /Applications/$required_bundle"
    else
        echo "[MISS] $required_bundle is missing or unusable"
        echo "       Re-run scripts/02-install-cli-tools.sh."
        FAILURES=$((FAILURES + 1))
    fi
done

echo ""
echo "Notes:"
echo "- This script loads Homebrew and nvm the same way the repo expects your shell to."
echo "- If this script succeeds but your interactive shell still misses tools, run: exec zsh"
echo "- Gemini auth is usually completed by launching gemini once and following the OAuth flow."
echo "- OCR should be a fallback path after native parsers or PDF text extraction, not the default."
echo "- playwright is intentionally not checked here because this repo expects project-local usage via npx."

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "Path check passed."
    exit 0
fi

echo "Path check failed with $FAILURES required issue(s)."
exit 1
