#!/bin/bash
# =============================================================================
# 03-install-npm-globals.sh - Install Global npm Packages
# =============================================================================
# Bootstrap script for current macOS workflow
# Target: macOS with Homebrew
#
# This script installs global npm packages for the current AI CLI workflow.
# Safe to run multiple times (idempotent).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_LIB="$SCRIPT_DIR/lib/bootstrap-profile.sh"
RUNTIME_LIB="$SCRIPT_DIR/lib/runtime-environment.sh"
BOOTSTRAP_PROFILE=""

# shellcheck disable=SC1090
source "$PROFILE_LIB"
# shellcheck disable=SC1090
source "$RUNTIME_LIB"

usage() {
    cat <<'EOF'
Usage: ./scripts/03-install-npm-globals.sh --profile PROFILE

Installs global npm packages for the selected Bootstrap Profile.

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
echo "Step 3: Installing Global npm Packages"
echo "========================================"
echo ""
echo "Bootstrap profile: $(bootstrap_profile_label "$BOOTSTRAP_PROFILE") ($BOOTSTRAP_PROFILE)"
echo ""

if ! bootstrap_load_nvm; then
    echo "ERROR: nvm is required for this step and could not be loaded."
    echo "       Run 02-install-cli-tools.sh first and make sure nvm installed cleanly."
    exit 1
fi

if ! bootstrap_activate_nvm_node "$BOOTSTRAP_NODE_VERSION"; then
    echo "ERROR: Exact Node.js $BOOTSTRAP_NODE_VERSION could not be activated under nvm."
    echo "       Run 02-install-cli-tools.sh first."
    exit 1
fi

# Ensure Node.js is available from nvm after loading it.
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js not found under nvm. Run 02-install-cli-tools.sh first."
    exit 1
fi

NODE_PATH="$(command -v node)"
if [[ "$NODE_PATH" != "$NVM_DIR"/versions/node/* ]]; then
    echo "ERROR: Active Node is not coming from nvm: $NODE_PATH"
    echo "       This step intentionally refuses to install globals into a non-nvm Node."
    exit 1
fi

echo "Using Node.js: $(node --version)"
echo "Using npm: $(npm --version)"
echo "Using Node binary: $NODE_PATH"
echo ""

# -----------------------------------------------------------------------------
# Install global npm packages
# -----------------------------------------------------------------------------
echo ""
echo "Installing global npm packages..."
echo ""

COMMON_NPM_PACKAGES=(
    corepack                    # Provides the pnpm/yarn shims; do not also install pnpm globally
    @openai/codex              # Codex CLI
)

SHARED_BASELINE_NPM_PACKAGES=(
)

CARLO_BASELINE_NPM_PACKAGES=(
    @anthropic-ai/claude-code   # Claude Code CLI
    @google/gemini-cli          # Gemini CLI
    vercel                     # Vercel CLI
)

NPM_PACKAGES=("${COMMON_NPM_PACKAGES[@]}")
case "$BOOTSTRAP_PROFILE" in
    carlo-baseline)
        NPM_PACKAGES+=("${CARLO_BASELINE_NPM_PACKAGES[@]}")
        ;;
    shared-baseline)
        if [ "${#SHARED_BASELINE_NPM_PACKAGES[@]}" -gt 0 ]; then
            NPM_PACKAGES+=("${SHARED_BASELINE_NPM_PACKAGES[@]}")
        fi
        ;;
esac

for package in "${NPM_PACKAGES[@]}"; do
    if npm list -g "$package" &> /dev/null; then
        echo "  [SKIP] $package is already installed"
    else
        echo "  [INSTALL] Installing $package..."
        npm install -g "$package"
    fi
done

# Enable corepack for pnpm/yarn support
echo ""
echo "Enabling corepack..."
if ! corepack enable; then
    echo "ERROR: corepack enable failed."
    exit 1
fi

echo ""
echo "========================================"
echo "Step 3 Complete: npm packages installed"
echo "========================================"
echo ""
echo "Installed packages:"
npm list -g --depth=0 2>/dev/null || true
echo ""
echo "Codex version: $(codex --version 2>/dev/null || echo 'not in PATH yet')"
if [ "$BOOTSTRAP_PROFILE" = "carlo-baseline" ]; then
    echo "Claude Code version: $(claude --version 2>/dev/null || echo 'not in PATH yet')"
    echo "Gemini CLI version: $(gemini --version 2>/dev/null || echo 'not in PATH yet')"
    echo "Vercel version: $(vercel --version 2>/dev/null | head -1 || echo 'not in PATH yet')"
fi
echo ""
echo "Note: These CLIs are installed under the active nvm-managed Node version."
echo "      If they are not found in a new shell, make sure nvm loads correctly."
echo "      Corepack is enabled; projects select pnpm through packageManager."
echo ""
echo "Next: Run 04-install-pip-packages.sh"
