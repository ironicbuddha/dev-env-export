#!/bin/bash
# =============================================================================
# 10-check-paths.sh - Verify Post-Bootstrap CLI Visibility
# =============================================================================
# Loads the intended Homebrew and nvm environment, then checks whether the key
# CLI tools expected by this repo are actually available.
# =============================================================================

set -euo pipefail

load_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        eval "$(brew shellenv)"
    elif [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
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

check_cmd() {
    local label="$1"
    local cmd="$2"
    local hint="$3"

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[OK]   $label -> $(command -v "$cmd")"
    else
        echo "[MISS] $label"
        echo "       $hint"
    fi
}

echo "========================================"
echo "Dev Environment CLI Path Check"
echo "========================================"
echo ""

load_homebrew
if load_nvm; then
    nvm use 22 >/dev/null 2>&1 || nvm use default >/dev/null 2>&1 || true
fi

echo "Checking CLI visibility in the intended bootstrap shell environment..."
echo ""

check_cmd "brew" "brew" "Homebrew should be installed by scripts/01-install-brew.sh."
check_cmd "gh" "gh" "GitHub CLI should come from scripts/02-install-cli-tools.sh."
check_cmd "aws" "aws" "AWS CLI should come from scripts/02-install-cli-tools.sh."
check_cmd "gws" "gws" "Google Workspace CLI should come from scripts/02-install-cli-tools.sh via googleworkspace-cli."
check_cmd "python3" "python3" "Python should come from scripts/02-install-cli-tools.sh."
check_cmd "uv" "uv" "uv should come from scripts/02-install-cli-tools.sh."
check_cmd "bun" "bun" "bun should come from scripts/02-install-cli-tools.sh."
check_cmd "docker" "docker" "Docker CLI should come from scripts/02-install-cli-tools.sh via the docker formula."
check_cmd "pandoc" "pandoc" "Pandoc should come from scripts/02-install-cli-tools.sh for document conversions."
check_cmd "pdftotext" "pdftotext" "poppler should come from scripts/02-install-cli-tools.sh for PDF text extraction."
check_cmd "pdftoppm" "pdftoppm" "poppler should come from scripts/02-install-cli-tools.sh for PDF page rendering."
check_cmd "tesseract" "tesseract" "Tesseract should come from scripts/02-install-cli-tools.sh for OCR fallback."
check_cmd "magick" "magick" "ImageMagick should come from scripts/02-install-cli-tools.sh for image preprocessing."
check_cmd "op" "op" "1Password CLI should come from scripts/02-install-cli-tools.sh."
check_cmd "zed" "zed" "Install the Zed CLI from inside Zed with Cmd+Shift+P -> cli: install."
check_cmd "codex" "codex" "Codex CLI should come from scripts/03-install-npm-globals.sh under nvm."
check_cmd "claude" "claude" "Claude CLI should come from scripts/03-install-npm-globals.sh under nvm."
check_cmd "vercel" "vercel" "Vercel CLI should come from scripts/03-install-npm-globals.sh under nvm."
check_cmd "node" "node" "Node should come from nvm in scripts/02-install-cli-tools.sh."
check_cmd "npm" "npm" "npm should come with the active nvm-managed Node runtime."

echo ""
if [ -d "/Applications/Warp.app" ]; then
    echo "[OK]   Warp.app -> /Applications/Warp.app"
else
    echo "[MISS] Warp.app"
    echo "       Warp should come from scripts/02-install-cli-tools.sh."
fi

echo ""
echo "Notes:"
echo "- This script loads Homebrew and nvm the same way the repo expects your shell to."
echo "- If this script succeeds but your interactive shell still misses tools, run: exec zsh"
echo "- OCR should be a fallback path after native parsers or PDF text extraction, not the default."
echo "- playwright is intentionally not checked here because this repo expects project-local usage via npx."
