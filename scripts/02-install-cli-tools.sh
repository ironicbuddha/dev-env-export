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

load_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        eval "$(brew shellenv)"
        return 0
    fi

    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        return 0
    fi

    if [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
        return 0
    fi

    return 1
}

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

    # Load Homebrew into the current shell if step 1 just installed it.
    load_homebrew || true
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

manifest_includes_tool() {
    local wanted="$1"
    local tool=""

    for tool in "${CLI_TOOLS[@]}"; do
        if [ "$tool" = "$wanted" ]; then
            return 0
        fi
    done

    return 1
}

brew_formula_ref() {
    local tool="$1"

    case "$tool" in
        bun)
            printf '%s\n' "oven-sh/bun/bun"
            ;;
        taproom)
            printf '%s\n' "gromgit/brewtils/taproom"
            ;;
        *)
            printf '%s\n' "$tool"
            ;;
    esac
}

brew_required_tap() {
    local tool="$1"

    case "$tool" in
        bun)
            printf '%s\n' "oven-sh/bun"
            ;;
        taproom)
            printf '%s\n' "gromgit/brewtils"
            ;;
        *)
            return 1
            ;;
    esac
}

ensure_homebrew_taps() {
    local tool=""
    local tap=""

    for tool in "${CLI_TOOLS[@]}"; do
        if tap="$(brew_required_tap "$tool" 2>/dev/null)"; then
            if brew tap | grep -qx "$tap"; then
                echo "  [SKIP] Homebrew tap $tap already configured"
            else
                echo "  [INSTALL] Adding Homebrew tap $tap for $tool..."
                brew tap "$tap"
            fi
        fi
    done
}

resolve_python_bin() {
    local brew_prefix=""

    if command -v brew >/dev/null 2>&1; then
        brew_prefix="$(brew --prefix python@3.13 2>/dev/null || true)"
        if [ -n "$brew_prefix" ] && [ -x "$brew_prefix/bin/python3.13" ]; then
            printf '%s\n' "$brew_prefix/bin/python3.13"
            return
        fi
        if [ -n "$brew_prefix" ] && [ -x "$brew_prefix/libexec/bin/python3" ]; then
            printf '%s\n' "$brew_prefix/libexec/bin/python3"
            return
        fi
    fi

    if command -v python3.13 >/dev/null 2>&1; then
        command -v python3.13
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        command -v python3
        return
    fi

    return 1
}

cask_app_present() {
    local app="$1"
    local app_bundle=""

    while IFS= read -r app_bundle; do
        if [ -n "$app_bundle" ] && [ -d "/Applications/$app_bundle" ]; then
            return 0
        fi
    done < <(brew info --cask --json=v2 "$app" 2>/dev/null | jq -r '.casks[0].artifacts[]? | select(type == "object" and has("app")) | .app[0]')

    return 1
}

cask_status() {
    local app="$1"

    if brew list --cask "$app" >/dev/null 2>&1 || cask_app_present "$app"; then
        printf '%s\n' "installed"
    else
        printf '%s\n' "missing"
    fi
}

install_bun_fallback() {
    local bun_version=""
    local asset_arch=""
    local asset_name=""
    local archive_url=""
    local archive_path=""
    local tmp_dir=""
    local install_dir=""

    if command -v bun >/dev/null 2>&1; then
        echo "  [SKIP] bun is already available -> $(command -v bun)"
        return 0
    fi

    bun_version="$(brew info --json=v2 bun 2>/dev/null | jq -r '.formulae[0].versions.stable // empty')"
    if [ -z "$bun_version" ]; then
        echo "ERROR: Could not determine the current Bun release for fallback install."
        return 1
    fi

    case "$(uname -m)" in
        arm64|aarch64)
            asset_arch="aarch64"
            ;;
        x86_64)
            asset_arch="x64"
            ;;
        *)
            echo "ERROR: Unsupported architecture for Bun fallback: $(uname -m)"
            return 1
            ;;
    esac

    asset_name="bun-darwin-$asset_arch.zip"
    archive_url="https://github.com/oven-sh/bun/releases/download/bun-v${bun_version}/${asset_name}"
    install_dir="$(brew --prefix)/bin"

    if [ ! -w "$install_dir" ]; then
        install_dir="$HOME/.local/bin"
        mkdir -p "$install_dir"
    fi

    tmp_dir="$(mktemp -d)"
    archive_path="$tmp_dir/$asset_name"

    echo "  [FALLBACK] Homebrew could not install bun; downloading the official Bun binary..."
    echo "             $archive_url"

    if ! curl -fsSL -o "$archive_path" "$archive_url"; then
        rm -rf "$tmp_dir"
        echo "ERROR: Failed to download Bun fallback archive."
        return 1
    fi

    unzip -q "$archive_path" -d "$tmp_dir"
    install -m 755 "$tmp_dir/bun-darwin-$asset_arch/bun" "$install_dir/bun"
    rm -rf "$tmp_dir"

    echo "  [FALLBACK] Installed bun $bun_version -> $install_dir/bun"
    echo "             Update Command Line Tools later if you want Homebrew to own bun directly."
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

ensure_homebrew_taps

for tool in "${CLI_TOOLS[@]}"; do
    tool_ref="$(brew_formula_ref "$tool")"

    if [ "$tool" = "bun" ] && command -v bun >/dev/null 2>&1; then
        echo "  [SKIP] $tool is already available -> $(command -v bun)"
    elif brew list "$tool" &> /dev/null || brew list "$tool_ref" &> /dev/null; then
        echo "  [SKIP] $tool is already installed"
    else
        if [ "$tool_ref" = "$tool" ]; then
            echo "  [INSTALL] Installing $tool..."
        else
            echo "  [INSTALL] Installing $tool via $tool_ref..."
        fi
        if ! brew install "$tool_ref"; then
            if [ "$tool" = "bun" ]; then
                install_bun_fallback || exit 1
            else
                exit 1
            fi
        fi
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
    elif cask_app_present "$app"; then
        echo "  [PRESERVE] $app app bundle already exists in /Applications"
    else
        if [ "$app" = "docker" ]; then
            echo "  [INSTALL] Installing $app app bundle without cask-managed binaries..."
            echo "            Docker CLI is provided by the docker formula to avoid sudo-only cask symlink steps."
            brew install --cask --no-binaries "$app" || echo "  [WARN] Failed to install $app (may require manual install)"
        else
            echo "  [INSTALL] Installing $app..."
            brew install --cask "$app" || echo "  [WARN] Failed to install $app (may require manual install)"
        fi
    fi
done

# -----------------------------------------------------------------------------
# Set up NVM
# -----------------------------------------------------------------------------
echo ""
echo "Setting up NVM..."
strip_npmrc_conflicts

if ! load_nvm; then
    echo "ERROR: nvm could not be loaded after installation."
    echo "       Homebrew owns nvm in this repo, and nvm owns the Node runtime."
    exit 1
fi

# Install Node.js v22 via nvm and make it the default CLI runtime.
if ! nvm ls 22 &> /dev/null; then
    echo "Installing Node.js v22 via nvm..."
    nvm install 22
else
    echo "  [SKIP] Node.js v22 already installed via nvm"
fi

nvm alias default 22 >/dev/null 2>&1 || true
nvm use 22 >/dev/null 2>&1 || nvm use default >/dev/null 2>&1

if ! command -v node >/dev/null 2>&1; then
    echo "ERROR: Node.js is still not available after nvm setup."
    exit 1
fi

NODE_PATH="$(command -v node)"
if [[ "$NODE_PATH" != "$NVM_DIR"/versions/node/* ]]; then
    echo "ERROR: Active Node is not coming from nvm: $NODE_PATH"
    echo "       This repo expects nvm to own the Node runtime."
    exit 1
fi

if brew list node >/dev/null 2>&1; then
    echo "  [WARN] Homebrew node is still installed."
    echo "         This repo no longer uses Homebrew to own the Node runtime."
    echo "         Consider removing it with: brew uninstall node"
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
PYTHON_VERSION="not in PATH yet"
if PYTHON_BIN="$(resolve_python_bin 2>/dev/null)"; then
    PYTHON_VERSION="$("$PYTHON_BIN" --version 2>/dev/null || echo 'not in PATH yet')"
fi

echo "Installed tools:"
echo "  - Node.js (via nvm): $(node --version 2>/dev/null || echo 'not in PATH yet')"
echo "  - npm: $(npm --version 2>/dev/null || echo 'not in PATH yet')"
echo "  - Python: $PYTHON_VERSION"
echo "  - AWS CLI: $(aws --version 2>/dev/null | cut -d' ' -f1 || echo 'not in PATH yet')"
echo "  - GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'not in PATH yet')"
echo "  - 1Password CLI: $(op --version 2>/dev/null || echo 'not in PATH yet')"
echo "  - Raycast: $(cask_status raycast)"
echo "  - BetterDisplay: $(cask_status betterdisplay)"
echo "  - Hidden Bar: $(cask_status hiddenbar)"
echo "  - Hammerspoon: $(cask_status hammerspoon)"
echo "  - GitHub Desktop: $(cask_status github)"
echo "  - Obsidian: $(cask_status obsidian)"
echo ""
echo "Node runtime policy: Homebrew installs nvm; nvm installs and owns Node."
echo ""
echo "Optional CLI review bucket (not installed by default): ${OPTIONAL_CLI_TOOLS[*]}"
echo "Review bucket (not installed by default): ${REVIEW_CASK_APPS[*]}"
echo ""
echo "Note: You may need to restart your terminal for all tools to be available."
echo ""
echo "Next: Run 03-install-npm-globals.sh"
