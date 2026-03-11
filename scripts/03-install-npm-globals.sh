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

set -e  # Exit on any error

echo "========================================"
echo "Step 3: Installing Global npm Packages"
echo "========================================"
echo ""

# Ensure Node.js is available
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js not found. Run 02-install-cli-tools.sh first."
    exit 1
fi

# Source nvm if available to ensure correct Node version
export NVM_DIR="$HOME/.nvm"
if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    source "/opt/homebrew/opt/nvm/nvm.sh"
fi

echo "Using Node.js: $(node --version)"
echo "Using npm: $(npm --version)"
echo ""

# -----------------------------------------------------------------------------
# Set up npm global directory (avoids permission issues)
# -----------------------------------------------------------------------------
echo "Setting up npm global directory..."
NPM_GLOBAL_DIR="$HOME/.npm-global"
mkdir -p "$NPM_GLOBAL_DIR"
npm config set prefix "$NPM_GLOBAL_DIR"

# Ensure PATH includes npm global bin
if [[ ":$PATH:" != *":$NPM_GLOBAL_DIR/bin:"* ]]; then
    export PATH="$NPM_GLOBAL_DIR/bin:$PATH"
fi

# -----------------------------------------------------------------------------
# Install global npm packages
# -----------------------------------------------------------------------------
echo ""
echo "Installing global npm packages..."
echo ""

NPM_PACKAGES=(
    corepack                    # Package manager manager
    @anthropic-ai/claude-code   # Claude Code CLI
    @openai/codex              # Codex CLI
)

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
corepack enable || echo "  [WARN] corepack enable failed (may need sudo)"

echo ""
echo "========================================"
echo "Step 3 Complete: npm packages installed"
echo "========================================"
echo ""
echo "Installed packages:"
npm list -g --depth=0 2>/dev/null || true
echo ""
echo "Claude Code version: $(claude --version 2>/dev/null || echo 'not in PATH yet')"
echo "Codex version: $(codex --version 2>/dev/null || echo 'not in PATH yet')"
echo ""
echo "Note: If claude or codex is not found, ensure ~/.npm-global/bin is in your PATH"
echo "      This is configured in the exported zshrc file."
echo ""
echo "Next: Run 04-install-pip-packages.sh"
