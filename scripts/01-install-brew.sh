#!/bin/bash
# =============================================================================
# 01-install-brew.sh - Install Homebrew and Core CLI Tools
# =============================================================================
# Bootstrap script for current macOS workflow
# Target: macOS with Homebrew
#
# This script installs Homebrew and essential CLI tools needed for development.
# Safe to run multiple times (idempotent).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREREQUISITES_LIB="$SCRIPT_DIR/lib/bootstrap-prerequisites.sh"
HOMEBREW_OPERATIONS_LIB="$SCRIPT_DIR/lib/homebrew-operations.sh"

# shellcheck disable=SC1090
source "$PREREQUISITES_LIB"
# shellcheck disable=SC1090
source "$HOMEBREW_OPERATIONS_LIB"

echo "========================================"
echo "Step 1: Installing Homebrew and Core CLI Tools"
echo "========================================"
echo ""

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: This script is intended for macOS only."
    exit 1
fi

if ! bootstrap_ensure_apple_silicon; then
    exit 1
fi

if bootstrap_ensure_xcode_clt; then
    :
else
    status=$?
    exit "$status"
fi

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    BREW_BIN=""

    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [ -x "/opt/homebrew/bin/brew" ]; then
        BREW_BIN="/opt/homebrew/bin/brew"
    elif [ -x "/usr/local/bin/brew" ]; then
        BREW_BIN="/usr/local/bin/brew"
    fi

    if [ -z "$BREW_BIN" ]; then
        echo "ERROR: Homebrew installation completed but brew was not found."
        exit 1
    fi

    # Load Homebrew for this bootstrap process. Persistent shell setup belongs
    # to the selected profile's shell-configuration step.
    eval "$("$BREW_BIN" shellenv)"
else
    echo "Homebrew is already installed."
    bootstrap_homebrew_refresh_metadata
fi

echo ""
echo "Installing core CLI tools..."
echo ""

# Core development tools (Both VMs)
CORE_TOOLS=(
    git
    git-lfs
    jq
    curl
    wget
)

for tool in "${CORE_TOOLS[@]}"; do
    bootstrap_homebrew_ensure_formula "$tool"
done

# Login-shell policy
echo ""
echo "Login shell policy: macOS /bin/zsh is the Carlo Baseline default."
if [ "$SHELL" = "/bin/zsh" ]; then
    echo "  [INFO] macOS zsh is already the login shell."
else
    echo "  [INFO] Carlo Baseline does not change your login shell."
    echo "         To choose macOS zsh explicitly, run: chsh -s /bin/zsh"
fi

# Initialize Git LFS
echo ""
echo "Initializing Git LFS..."
git lfs install

echo ""
echo "========================================"
echo "Step 1 Complete: Homebrew and core tools installed"
echo "========================================"
echo ""
echo "Installed tools:"
echo "  - git ($(git --version | cut -d' ' -f3))"
echo "  - git-lfs"
echo "  - jq ($(jq --version))"
echo "  - curl ($(curl --version | head -1 | cut -d' ' -f2))"
echo "  - wget"
echo "  - macOS zsh ($(/bin/zsh --version | cut -d' ' -f2))"
echo ""
echo "Next: Run 02-install-cli-tools.sh"
