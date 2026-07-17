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

# shellcheck disable=SC1090
source "$PREREQUISITES_LIB"

echo "========================================"
echo "Step 1: Installing Homebrew and Core CLI Tools"
echo "========================================"
echo ""

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: This script is intended for macOS only."
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
    if [ "${DEV_ENV_REFRESH_BREW:-0}" = "1" ]; then
        echo "Refreshing Homebrew metadata because DEV_ENV_REFRESH_BREW=1..."
        brew update
    else
        echo "  [SKIP] brew update (set DEV_ENV_REFRESH_BREW=1 to refresh formulas)"
    fi
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
    zsh
)

for tool in "${CORE_TOOLS[@]}"; do
    if brew list "$tool" &> /dev/null; then
        echo "  [SKIP] $tool is already installed"
    else
        echo "  [INSTALL] Installing $tool..."
        brew install "$tool"
    fi
done

# Set zsh as default shell
echo ""
echo "Configuring default shell..."
TARGET_SHELL="$(brew --prefix)/bin/zsh"
if [ ! -x "$TARGET_SHELL" ]; then
    TARGET_SHELL="$(command -v zsh)"
fi

if [ -n "$TARGET_SHELL" ] && [ "$SHELL" != "$TARGET_SHELL" ]; then
    if grep -qx "$TARGET_SHELL" /etc/shells; then
        if chsh -s "$TARGET_SHELL"; then
            echo "  [OK] Default shell set to $TARGET_SHELL"
        else
            echo "  [WARN] Could not set default shell automatically. Run: chsh -s $TARGET_SHELL"
        fi
    else
        echo "  [WARN] $TARGET_SHELL is not listed in /etc/shells."
        echo "         Add it first, then run: chsh -s $TARGET_SHELL"
    fi
else
    echo "  [SKIP] zsh is already the default shell"
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
echo "  - zsh ($(zsh --version | cut -d' ' -f2))"
echo ""
echo "Next: Run 02-install-cli-tools.sh"
