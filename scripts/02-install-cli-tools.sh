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

set -e  # Exit on any error

echo "========================================"
echo "Step 2: Installing Development CLI Tools"
echo "========================================"
echo ""

# Ensure Homebrew is available (self-heal by running step 1 if needed)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

CLI_TOOLS=(
    # Development tools (Both VMs)
    node           # Node.js (includes npm)
    nvm            # Node Version Manager
    python@3.13    # Python 3.13

    # Cloud & Infrastructure (VM1 only)
    awscli         # AWS CLI v2
    terraform      # Infrastructure as code
    gh             # GitHub CLI

    # Build tools (Both VMs)
    make           # GNU Make (macOS has BSD make)
    gcc            # GNU Compiler Collection
)

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
    # Current primary tools
    1password     # 1Password desktop app
    1password-cli # 1Password CLI (op)
    warp           # Warp terminal
    zed            # Zed editor

    # Quality-of-life mac utilities
    raycast        # Launcher, snippets, clipboard, shortcuts
    betterdisplay  # Display control and virtual display management
    hiddenbar      # Menu bar cleanup
    hammerspoon    # Keyboard automation and window scripting
    github         # GitHub Desktop
    obsidian       # Notes and local knowledge base

    # Supporting tools
    docker         # Docker Desktop for Mac (VM1)
    chromium       # Chromium browser (Both VMs)
    firefox        # Firefox browser (Both VMs)

    # Optional supporting tools
    sublime-text   # Legacy editor currently referenced by gitconfig
    gitkraken      # Legacy Git GUI from earlier VM export
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
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"

# Source nvm if Homebrew installed it
if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    source "/opt/homebrew/opt/nvm/nvm.sh"

    # Install Node.js v22 via nvm (matches Linux environment)
    if ! nvm ls 22 &> /dev/null; then
        echo "Installing Node.js v22 via nvm..."
        nvm install 22
    else
        echo "  [SKIP] Node.js v22 already installed via nvm"
    fi
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
echo "  - Terraform: $(terraform version 2>/dev/null | head -1 || echo 'not in PATH yet')"
echo "  - GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'not in PATH yet')"
echo "  - 1Password CLI: $(op --version 2>/dev/null || echo 'not in PATH yet')"
echo "  - Raycast: $(brew list --cask raycast >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo "  - BetterDisplay: $(brew list --cask betterdisplay >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo "  - Hidden Bar: $(brew list --cask hiddenbar >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo "  - Hammerspoon: $(brew list --cask hammerspoon >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo "  - GitHub Desktop: $(brew list --cask github >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo "  - Obsidian: $(brew list --cask obsidian >/dev/null 2>&1 && echo 'installed' || echo 'not in PATH yet')"
echo ""
echo "Note: You may need to restart your terminal for all tools to be available."
echo ""
echo "Next: Run 03-install-npm-globals.sh"
