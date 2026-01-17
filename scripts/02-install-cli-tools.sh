#!/bin/bash
# =============================================================================
# 02-install-cli-tools.sh - Install Development CLI Tools
# =============================================================================
# Exported from Ubuntu VM on 2026-01-17
# Target: macOS with Apple Silicon (arm64)
#
# This script installs development tools, cloud CLIs, and applications.
# Safe to run multiple times (idempotent).
# =============================================================================

set -e  # Exit on any error

echo "========================================"
echo "Step 2: Installing Development CLI Tools"
echo "========================================"
echo ""

# Ensure Homebrew is available
if ! command -v brew &> /dev/null; then
    echo "ERROR: Homebrew not found. Run 01-install-brew.sh first."
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
    docker         # Docker Desktop for Mac (VM1)
    vscodium       # VSCodium (open-source VS Code) (Both VMs)
    chromium       # Chromium browser (Both VMs)
    firefox        # Firefox browser (Both VMs)
    sublime-text   # Sublime Text editor (used in gitconfig) (VM1)
    gitkraken      # GitKraken Git GUI client (VM2)
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
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
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
echo ""
echo "Note: You may need to restart your terminal for all tools to be available."
echo ""
echo "Next: Run 03-install-npm-globals.sh"
