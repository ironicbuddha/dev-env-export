#!/bin/bash
# =============================================================================
# 01-install-brew.sh - Install Homebrew and Core CLI Tools
# =============================================================================
# Exported from Ubuntu VM on 2026-01-17
# Target: macOS with Apple Silicon (arm64)
#
# This script installs Homebrew and essential CLI tools needed for development.
# Safe to run multiple times (idempotent).
# =============================================================================

set -e  # Exit on any error

echo "========================================"
echo "Step 1: Installing Homebrew and Core CLI Tools"
echo "========================================"
echo ""

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: This script is intended for macOS only."
    exit 1
fi

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    echo "Adding Homebrew to PATH..."
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew is already installed."
    brew update
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
