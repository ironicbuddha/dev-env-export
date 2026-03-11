#!/bin/bash
# =============================================================================
# 05-setup-dotfiles.sh - Copy User Configuration Files
# =============================================================================
# Bootstrap script for current macOS workflow
# Target: macOS with Homebrew
#
# This script copies configuration files to their proper locations.
# Backs up existing files before overwriting.
# Safe to run multiple times (idempotent).
# =============================================================================

set -e  # Exit on any error

echo "========================================"
echo "Step 5: Setting Up Dotfiles"
echo "========================================"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(dirname "$SCRIPT_DIR")"

# Backup directory
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Turn a destination path into a stable backup path under BACKUP_DIR.
backup_target_for() {
    local dest="$1"
    local relative_path="${dest#"$HOME"/}"

    if [ "$relative_path" = "$dest" ]; then
        relative_path="$(basename "$dest")"
    fi

    printf "%s/%s" "$BACKUP_DIR" "$relative_path"
}

# Function to copy file with backup
copy_with_backup() {
    local src="$1"
    local dest="$2"
    local dest_dir="$(dirname "$dest")"
    local backup_target

    # Create destination directory if needed
    mkdir -p "$dest_dir"

    # Backup existing file if it exists
    if [ -f "$dest" ]; then
        backup_target="$(backup_target_for "$dest")"
        mkdir -p "$(dirname "$backup_target")"
        cp "$dest" "$backup_target"
        echo "  [BACKUP] Backed up existing $dest"
    fi

    # Copy the new file
    cp "$src" "$dest"
    echo "  [COPY] $src -> $dest"
}

echo "Export directory: $EXPORT_DIR"
echo "Backup directory: $BACKUP_DIR"
echo ""

# -----------------------------------------------------------------------------
# Shell Configuration
# -----------------------------------------------------------------------------
echo "Setting up shell configuration..."

if [ -f "$EXPORT_DIR/shell/zshrc" ]; then
    copy_with_backup "$EXPORT_DIR/shell/zshrc" "$HOME/.zshrc"
fi

if [ -f "$EXPORT_DIR/shell/zprofile" ]; then
    copy_with_backup "$EXPORT_DIR/shell/zprofile" "$HOME/.zprofile"
fi

# -----------------------------------------------------------------------------
# Git Configuration
# -----------------------------------------------------------------------------
echo ""
echo "Setting up Git configuration..."

if [ -f "$EXPORT_DIR/dotfiles/gitconfig" ]; then
    copy_with_backup "$EXPORT_DIR/dotfiles/gitconfig" "$HOME/.gitconfig"
fi

if [ -f "$EXPORT_DIR/dotfiles/gitignore_global" ]; then
    copy_with_backup "$EXPORT_DIR/dotfiles/gitignore_global" "$HOME/.gitignore_global"
fi

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------
echo ""
echo "Setting up AWS configuration..."

if [ -f "$EXPORT_DIR/dotfiles/aws-config" ]; then
    mkdir -p "$HOME/.aws"
    copy_with_backup "$EXPORT_DIR/dotfiles/aws-config" "$HOME/.aws/config"
fi

# -----------------------------------------------------------------------------
# GitHub CLI Configuration
# -----------------------------------------------------------------------------
echo ""
echo "Setting up GitHub CLI configuration..."

if [ -f "$EXPORT_DIR/dotfiles/gh-config.yml" ]; then
    mkdir -p "$HOME/.config/gh"
    copy_with_backup "$EXPORT_DIR/dotfiles/gh-config.yml" "$HOME/.config/gh/config.yml"
fi

# -----------------------------------------------------------------------------
# Codex Configuration
# -----------------------------------------------------------------------------
echo ""
echo "Setting up Codex configuration..."

CODEX_CONFIG_DIR="$HOME/.codex"
mkdir -p "$CODEX_CONFIG_DIR"

if [ -f "$EXPORT_DIR/codex/config.toml" ]; then
    copy_with_backup "$EXPORT_DIR/codex/config.toml" "$CODEX_CONFIG_DIR/config.toml"
fi

# -----------------------------------------------------------------------------
# Zed Configuration
# -----------------------------------------------------------------------------
echo ""
echo "Setting up Zed configuration..."

ZED_CONFIG_DIR="$HOME/Library/Application Support/Zed"
mkdir -p "$ZED_CONFIG_DIR"

if [ -f "$EXPORT_DIR/zed/settings.json" ]; then
    copy_with_backup "$EXPORT_DIR/zed/settings.json" "$ZED_CONFIG_DIR/settings.json"
fi

if [ -f "$EXPORT_DIR/zed/keymap.json" ]; then
    copy_with_backup "$EXPORT_DIR/zed/keymap.json" "$ZED_CONFIG_DIR/keymap.json"
fi

# -----------------------------------------------------------------------------
# Warp Configuration
# -----------------------------------------------------------------------------
echo ""
echo "Setting up Warp configuration..."

WARP_CONFIG_DIR="$HOME/.warp"
WARP_LAUNCH_DIR="$WARP_CONFIG_DIR/launch_configurations"
mkdir -p "$WARP_LAUNCH_DIR"

if [ -d "$EXPORT_DIR/warp/launch_configurations" ]; then
    for launch_config in "$EXPORT_DIR/warp/launch_configurations"/*.yaml "$EXPORT_DIR/warp/launch_configurations"/*.yml; do
        if [ -f "$launch_config" ]; then
            copy_with_backup "$launch_config" "$WARP_LAUNCH_DIR/$(basename "$launch_config")"
        fi
    done
fi

# -----------------------------------------------------------------------------
# Create necessary directories
# -----------------------------------------------------------------------------
echo ""
echo "Creating necessary directories..."

mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.npm-global/bin"
mkdir -p "$HOME/.tmp"
mkdir -p "$HOME/bin"

echo "  [CREATE] ~/.local/bin"
echo "  [CREATE] ~/.npm-global/bin"
echo "  [CREATE] ~/.tmp"
echo "  [CREATE] ~/bin"

echo ""
echo "========================================"
echo "Step 5 Complete: Dotfiles installed"
echo "========================================"
echo ""

if [ -d "$BACKUP_DIR" ]; then
    echo "Backed up files are in: $BACKUP_DIR"
    echo ""
fi

echo "Files installed:"
echo "  - ~/.zshrc (shell configuration)"
echo "  - ~/.zprofile (login shell configuration)"
echo "  - ~/.gitconfig (Git configuration)"
echo "  - ~/.gitignore_global (Global git ignore)"
echo "  - ~/.aws/config (AWS profiles)"
echo "  - ~/.config/gh/config.yml (GitHub CLI config)"
echo "  - ~/.codex/config.toml (Codex config, if tracked in repo)"
echo "  - ~/Library/Application Support/Zed/* (if tracked in repo)"
echo "  - ~/.warp/launch_configurations/* (if tracked in repo)"
echo ""
echo "Next: Run 06-setup-claude.sh"
