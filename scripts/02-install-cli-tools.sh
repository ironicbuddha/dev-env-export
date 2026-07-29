#!/bin/bash
# =============================================================================
# 02-install-cli-tools.sh - Install Development CLI Tools
# =============================================================================
# Bootstrap script for current macOS workflow
# Target: macOS with Homebrew
#
# This script installs development tools, cloud CLIs, and applications.
# Safe to run multiple times (idempotent).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST_FILE="$REPO_ROOT/manifest/homebrew-packages.sh"
PROFILE_LIB="$SCRIPT_DIR/lib/bootstrap-profile.sh"
PREREQUISITES_LIB="$SCRIPT_DIR/lib/bootstrap-prerequisites.sh"
RUNTIME_LIB="$SCRIPT_DIR/lib/runtime-environment.sh"
EXPECTATIONS_LIB="$SCRIPT_DIR/lib/bootstrap-expectations.sh"
APP_BUNDLE_LIB="$SCRIPT_DIR/lib/app-bundle.sh"
CASK_STATE_LIB="$SCRIPT_DIR/lib/cask-state.sh"
NPM_CONFIGURATION_LIB="$SCRIPT_DIR/lib/npm-configuration.sh"
HOMEBREW_OPERATIONS_LIB="$SCRIPT_DIR/lib/homebrew-operations.sh"
REMOTE_INSTALLER_LIB="$SCRIPT_DIR/lib/remote-installer.sh"
BUN_FALLBACK_LIB="$SCRIPT_DIR/lib/bun-fallback.sh"
BOOTSTRAP_PROFILE=""

# shellcheck disable=SC1090
source "$PROFILE_LIB"
# shellcheck disable=SC1090
source "$PREREQUISITES_LIB"
# shellcheck disable=SC1090
source "$RUNTIME_LIB"
# shellcheck disable=SC1090
source "$EXPECTATIONS_LIB"
# shellcheck disable=SC1090
source "$APP_BUNDLE_LIB"
# shellcheck disable=SC1090
source "$CASK_STATE_LIB"
# shellcheck disable=SC1090
source "$NPM_CONFIGURATION_LIB"
# shellcheck disable=SC1090
source "$HOMEBREW_OPERATIONS_LIB"
# shellcheck disable=SC1090
source "$REMOTE_INSTALLER_LIB"
# shellcheck disable=SC1090
source "$BUN_FALLBACK_LIB"

usage() {
    cat <<'EOF'
Usage: ./scripts/02-install-cli-tools.sh --profile PROFILE

Installs Homebrew CLI tools and cask apps for the selected Bootstrap Profile.

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

echo "========================================"
echo "Step 2: Installing Development CLI Tools"
echo "========================================"
echo ""
echo "Bootstrap profile: $(bootstrap_profile_label "$BOOTSTRAP_PROFILE") ($BOOTSTRAP_PROFILE)"
echo ""

if ! bootstrap_ensure_apple_silicon; then
    exit 1
fi

# Ensure Homebrew is available (self-heal by running step 1 if needed)
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Bootstrapping via 01-install-brew.sh..."
    if [ -x "$SCRIPT_DIR/01-install-brew.sh" ]; then
        "$SCRIPT_DIR/01-install-brew.sh"
    else
        bash "$SCRIPT_DIR/01-install-brew.sh"
    fi

    # Load Homebrew into the current shell if step 1 just installed it.
    bootstrap_load_homebrew || true
fi

if ! command -v brew &> /dev/null; then
    echo "ERROR: Homebrew is still not available after bootstrap."
    exit 1
fi

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "ERROR: Homebrew manifest not found: $MANIFEST_FILE"
    exit 1
fi

# shellcheck disable=SC1090
source "$MANIFEST_FILE"

CLI_TOOLS=("${COMMON_BREW_PACKAGES[@]}")
CASK_APPS=("${COMMON_CASK_APPS[@]}")

case "$BOOTSTRAP_PROFILE" in
    carlo-baseline)
        CLI_TOOLS+=("${CARLO_BASELINE_BREW_PACKAGES[@]}")
        CASK_APPS+=("${CARLO_BASELINE_CASK_APPS[@]}")
        ;;
    shared-baseline)
        if [ "${#SHARED_BASELINE_BREW_PACKAGES[@]}" -gt 0 ]; then
            CLI_TOOLS+=("${SHARED_BASELINE_BREW_PACKAGES[@]}")
        fi
        if [ "${#SHARED_BASELINE_CASK_APPS[@]}" -gt 0 ]; then
            CASK_APPS+=("${SHARED_BASELINE_CASK_APPS[@]}")
        fi
        ;;
esac

bootstrap_load_expectations "$BOOTSTRAP_PROFILE"
CASK_APPS=("${BOOTSTRAP_REQUIRED_CASKS[@]}")

manifest_includes_tool() {
    local wanted="$1"
    local tool=""

    for tool in "${CLI_TOOLS[@]}"; do
        if [ "$tool" = "$wanted" ]; then
            return 0
        fi
    done

    return 1
}

# -----------------------------------------------------------------------------
# Install Xcode Command Line Tools (provides build-essential equivalent)
# -----------------------------------------------------------------------------
if bootstrap_ensure_xcode_clt; then
    :
else
    status=$?
    exit "$status"
fi

# -----------------------------------------------------------------------------
# CLI Tools via Homebrew
# -----------------------------------------------------------------------------
echo ""
echo "Installing CLI tools via Homebrew..."
echo ""

for tool in "${CLI_TOOLS[@]}"; do
    if [ "$tool" = "bun" ] && command -v bun >/dev/null 2>&1; then
        echo "  [SKIP] $tool is already available -> $(command -v bun)"
    else
        if ! bootstrap_homebrew_ensure_formula "$tool"; then
            if [ "$tool" = "bun" ]; then
                bootstrap_ensure_bun_fallback || exit 1
            else
                exit 1
            fi
        fi
    fi
done

# -----------------------------------------------------------------------------
# Cask Applications (GUI apps and Docker)
# -----------------------------------------------------------------------------
echo ""
echo "Installing applications via Homebrew Cask..."
echo ""

for app in "${CASK_APPS[@]}"; do
    bootstrap_homebrew_ensure_cask "$app" || exit 1
done

# -----------------------------------------------------------------------------
# Set up NVM
# -----------------------------------------------------------------------------
echo ""
echo "Setting up NVM..."
bootstrap_ensure_nvm_compatible_npm_configuration \
    "$HOME/.npmrc" "$HOME/.dev-env-npmrc-backups"

if ! bootstrap_load_nvm; then
    echo "ERROR: nvm could not be loaded after installation."
    echo "       Homebrew owns nvm in this repo, and nvm owns the Node runtime."
    exit 1
fi

# Install the pinned Node.js LTS, default alias, and active runtime through
# independently verified nvm operations.
if ! bootstrap_ensure_nvm_node_runtime "$BOOTSTRAP_NODE_VERSION"; then
    echo "ERROR: Could not activate exact nvm-managed Node $BOOTSTRAP_NODE_VERSION."
    exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    echo "ERROR: Node.js is still not available after nvm setup."
    exit 1
fi

NODE_PATH="$(command -v node)"
if [[ "$NODE_PATH" != "$NVM_DIR"/versions/node/* ]]; then
    echo "ERROR: Active Node is not coming from nvm: $NODE_PATH"
    echo "       This repo expects nvm to own the Node runtime."
    exit 1
fi

if brew list node >/dev/null 2>&1; then
    echo "  [INFO] Homebrew Node is installed but is not the Carlo Baseline runtime."
    echo "         It is retained: bootstrap never removes existing Homebrew packages."
    echo "         Node and npm above are verified as nvm-owned."
    echo "         To review dependents before an optional manual removal: brew uses --installed node"
fi

# -----------------------------------------------------------------------------
# Install Oh My Zsh
# -----------------------------------------------------------------------------
echo ""
echo "Checking for Oh My Zsh..."
if [ "$BOOTSTRAP_PROFILE" = "shared-baseline" ]; then
    echo "  [SKIP] Oh My Zsh is Carlo Baseline shell customization."
else
    bootstrap_ensure_oh_my_zsh || exit 1
fi

echo ""
echo "========================================"
echo "Step 2 Complete: Development tools installed"
echo "========================================"
echo ""
PYTHON_VERSION="not in PATH yet"
if PYTHON_BIN="$(bootstrap_resolve_python_bin 2>/dev/null)"; then
    PYTHON_VERSION="$("$PYTHON_BIN" --version 2>/dev/null || echo 'not in PATH yet')"
fi

echo "Installed tools:"
echo "  - Node.js (via nvm): $(node --version 2>/dev/null || echo 'not in PATH yet')"
echo "  - npm: $(npm --version 2>/dev/null || echo 'not in PATH yet')"
echo "  - Python: $PYTHON_VERSION"
echo "  - GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'not in PATH yet')"
echo "  - Raycast: $(bootstrap_cask_status raycast)"
echo "  - Hidden Bar: $(bootstrap_cask_status hiddenbar)"
echo "  - Hammerspoon: $(bootstrap_cask_status hammerspoon)"
echo "  - GitHub Desktop: $(bootstrap_cask_status github)"
if [ "$BOOTSTRAP_PROFILE" = "carlo-baseline" ]; then
    echo "  - AWS CLI: $(aws --version 2>/dev/null | cut -d' ' -f1 || echo 'not in PATH yet')"
    echo "  - 1Password CLI: $(op --version 2>/dev/null || echo 'not in PATH yet')"
    echo "  - 1Password app: $(bootstrap_cask_status 1password)"
fi
echo ""
echo "Node runtime policy: Homebrew installs nvm; nvm installs and owns Node."
echo ""
echo "Optional CLI review bucket (not installed by default): ${OPTIONAL_CLI_TOOLS[*]}"
echo "Optional manual casks (not installed by default): ${OPTIONAL_MANUAL_CASKS[*]}"
echo "Review bucket (not installed by default): ${REVIEW_CASK_APPS[*]}"
echo ""
echo "Note: You may need to restart your terminal for all tools to be available."
echo ""
echo "Next: Run 03-install-npm-globals.sh"
