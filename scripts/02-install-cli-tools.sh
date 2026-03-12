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

echo "========================================"
echo "Step 2: Installing Development CLI Tools"
echo "========================================"
echo ""

# Ensure Homebrew is available (self-heal by running step 1 if needed)
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Bootstrapping via 01-install-brew.sh..."
    if [ -x "$SCRIPT_DIR/01-install-brew.sh" ]; then
        "$SCRIPT_DIR/01-install-brew.sh"
    else
        bash "$SCRIPT_DIR/01-install-brew.sh"
    fi

    # Load Homebrew into current shell if installed by step 1
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
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

strip_npmrc_conflicts() {
    local npmrc_path="$HOME/.npmrc"
    local tmp_path=""

    if [ ! -f "$npmrc_path" ]; then
        return
    fi

    tmp_path="$(mktemp)"
    awk '
        /^[[:space:]]*prefix[[:space:]]*=/ { next }
        /^[[:space:]]*globalconfig[[:space:]]*=/ { next }
        { print }
    ' "$npmrc_path" > "$tmp_path"

    if ! cmp -s "$tmp_path" "$npmrc_path"; then
        mv "$tmp_path" "$npmrc_path"
        echo "  [UPDATE] Removed nvm-incompatible prefix/globalconfig from ~/.npmrc"
    else
        rm -f "$tmp_path"
    fi

    if [ -f "$npmrc_path" ] && [ ! -s "$npmrc_path" ]; then
        rm -f "$npmrc_path"
        echo "  [CLEANUP] Removed empty ~/.npmrc"
    fi
}

load_nvm() {
    local nvm_prefix=""

    export NVM_DIR="$HOME/.nvm"
    mkdir -p "$NVM_DIR"

    if command -v brew >/dev/null 2>&1; then
        nvm_prefix="$(brew --prefix nvm 2>/dev/null || true)"
        if [ -n "$nvm_prefix" ] && [ -s "$nvm_prefix/nvm.sh" ]; then
            # shellcheck disable=SC1090
            . "$nvm_prefix/nvm.sh"
            return 0
        fi
    fi

    if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "/opt/homebrew/opt/nvm/nvm.sh"
        return 0
    fi

    if [ -s "/usr/local/opt/nvm/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "/usr/local/opt/nvm/nvm.sh"
        return 0
    fi

    return 1
}

# -----------------------------------------------------------------------------
# Install Xcode Command Line Tools (provides build-essential equivalent)
# -----------------------------------------------------------------------------
echo "Checking for Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Please complete the installation dialog, then re-run this script."
    exit 0
else
    echo "  [SKIP] Xcode Command Line Tools already installed"
fi

# -----------------------------------------------------------------------------
# CLI Tools via Homebrew
# -----------------------------------------------------------------------------
echo ""
echo "Installing CLI tools via Homebrew..."
echo ""

for tool in "${CLI_TOOLS[@]}"; do
    if brew list "$tool" &> /dev/null; then
        echo "  [SKIP] $tool is already installed"
    else
        echo "  [INSTALL] Installing $tool..."
        brew install "$tool"
    fi
done

# -----------------------------------------------------------------------------
# Cask Applications (GUI apps and Docker)
# -----------------------------------------------------------------------------
echo ""
echo "Installing applications via Homebrew Cask..."
echo ""

CASK_APPS=(
    "${PRIMARY_CASK_APPS[@]}"
    "${UTILITY_CASK_APPS[@]}"
    "${SUPPORTING_CASK_APPS[@]}"
)

for app in "${CASK_APPS[@]}"; do
    if brew list --cask "$app" &> /dev/null 2>&1; then
        echo "  [SKIP] $app is already installed"
    else
        echo "  [INSTALL] Installing $app..."
        brew install --cask "$app" || echo "  [WARN] Failed to install $app (may require manual install)"
    fi
done

# -----------------------------------------------------------------------------
# Set up NVM
# -----------------------------------------------------------------------------
echo ""
echo "Setting up NVM..."
strip_npmrc_conflicts

if load_nvm; then
    # Install Node.js v22 via nvm and make it the default CLI runtime.
    if ! nvm ls 22 &> /dev/null; then
        echo "Installing Node.js v22 via nvm..."
        nvm install 22
    else
        echo "  [SKIP] Node.js v22 already installed via nvm"
        nvm use 22 >/dev/null 2>&1 || true
    fi
    nvm alias default 22 >/dev/null 2>&1 || true
else
    echo "  [WARN] nvm is installed but could not be loaded in this shell"
fi

# -----------------------------------------------------------------------------
# Install Oh My Zsh
# -----------------------------------------------------------------------------
echo ""
echo "Checking for Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "  [SKIP] Oh My Zsh already installed"
fi

echo ""
echo "========================================"
echo "Step 2 Complete: Development tools installed"
echo "========================================"
echo ""
echo "Installed tools:"
echo "  - Node.js: $(node --version 2>/dev/null || echo 'not in PATH yet')"
echo "  - npm: $(npm --version 2>/dev/null || echo 'not in PATH yet')"
echo "  - Python: $(python3 --version 2>/dev/null || echo 'not in PATH yet')"
echo "  - AWS CLI: $(aws --version 2>/dev/null | cut -d' ' -f1 || echo 'not in PATH yet')"
echo "  - GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'not in PATH yet')"
echo "  - 1Password CLI: $(op --version 2>/dev/null || echo 'not in PATH yet')"
echo "  - Raycast: $(brew list --cask raycast >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo "  - BetterDisplay: $(brew list --cask betterdisplay >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo "  - Hidden Bar: $(brew list --cask hiddenbar >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo "  - Hammerspoon: $(brew list --cask hammerspoon >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo "  - GitHub Desktop: $(brew list --cask github >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo "  - Obsidian: $(brew list --cask obsidian >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo ""
echo "Optional CLI review bucket (not installed by default): ${OPTIONAL_CLI_TOOLS[*]}"
echo "Review bucket (not installed by default): ${REVIEW_CASK_APPS[*]}"
echo ""
echo "Note: You may need to restart your terminal for all tools to be available."
echo ""
echo "Next: Run 03-install-npm-globals.sh"
