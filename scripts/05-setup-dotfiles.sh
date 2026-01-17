#!/bin/bash
# =============================================================================
# 05-setup-dotfiles.sh - Copy Dotfiles to Home Directory
# =============================================================================
# Exported from Ubuntu VM on 2026-01-17
# Target: macOS with Apple Silicon (arm64)
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

# Function to copy file with backup
copy_with_backup() {
    local src="$1"
    local dest="$2"
    local dest_dir="$(dirname "$dest")"

    # Create destination directory if needed
    mkdir -p "$dest_dir"

    # Backup existing file if it exists
    if [ -f "$dest" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$dest" "$BACKUP_DIR/$(basename "$dest")"
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
echo ""
echo "IMPORTANT: Review ~/.zshrc for the OPENAI_API_KEY"
echo "           You should rotate this key after migration!"
echo ""
echo "Next: Run 06-setup-claude.sh"
