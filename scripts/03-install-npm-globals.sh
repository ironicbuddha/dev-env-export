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

echo "========================================"
echo "Step 3: Installing Global npm Packages"
echo "========================================"
echo ""

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

strip_npmrc_conflicts

if load_nvm; then
    nvm use default >/dev/null 2>&1 || nvm use 22 >/dev/null 2>&1 || true
fi

# Ensure Node.js is available after loading nvm
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js not found. Run 02-install-cli-tools.sh first."
    exit 1
fi

echo "Using Node.js: $(node --version)"
echo "Using npm: $(npm --version)"
echo ""

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
echo "Note: These CLIs are installed under the active nvm-managed Node version."
echo "      If they are not found in a new shell, make sure nvm loads correctly."
echo ""
echo "Next: Run 04-install-pip-packages.sh"
