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

set -euo pipefail

echo "========================================"
echo "Step 5: Setting Up Dotfiles"
echo "========================================"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_CODEX_SKILLS_SCRIPT="$SCRIPT_DIR/14-install-codex-skills.sh"
FILE_SAFETY_LIB="$SCRIPT_DIR/lib/file-safety.sh"

# shellcheck disable=SC1090
source "$FILE_SAFETY_LIB"

# Backup directory (created lazily only if a file actually changes)
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

# Function to copy file with backup only when content changes
copy_with_backup() {
    local src="$1"
    local dest="$2"
    local dest_dir="$(dirname "$dest")"
    local backup_target
    local had_existing=0

    # Create destination directory if needed
    mkdir -p "$dest_dir"

    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        echo "  [SKIP] $(basename "$dest") is unchanged"
        return
    fi

    if [ -f "$dest" ]; then
        had_existing=1
        backup_target="$(backup_target_for "$dest")"
    else
        backup_target=""
    fi

    bootstrap_copy_file_with_backup "$src" "$dest" "$BACKUP_DIR" "$backup_target"

    if [ "$had_existing" -eq 1 ]; then
        echo "  [BACKUP] Backed up existing $dest"
    fi

    echo "  [COPY] $src -> $dest"
}

resolve_python_bin() {
    local brew_prefix=""

    if command -v brew >/dev/null 2>&1; then
        brew_prefix="$(brew --prefix python@3.14 2>/dev/null || true)"
        if [ -n "$brew_prefix" ] && [ -x "$brew_prefix/bin/python3.14" ]; then
            printf '%s\n' "$brew_prefix/bin/python3.14"
            return
        fi
        if [ -n "$brew_prefix" ] && [ -x "$brew_prefix/libexec/bin/python3" ]; then
            printf '%s\n' "$brew_prefix/libexec/bin/python3"
            return
        fi
    fi

    if command -v python3.14 >/dev/null 2>&1; then
        command -v python3.14
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        command -v python3
        return
    fi

    if [ -x "/usr/bin/python3" ]; then
        printf '%s\n' "/usr/bin/python3"
        return
    fi

    return 1
}

merge_toml_with_backup() {
    local src="$1"
    local dest="$2"
    local label="$3"
    local backup_target
    local tmp_file

    mkdir -p "$(dirname "$dest")"

    if [ -L "$dest" ]; then
        echo "ERROR: Refusing to merge into symlink destination: $dest" >&2
        echo "       Replace or remove the link explicitly, then rerun." >&2
        return 1
    fi

    if [ ! -f "$dest" ]; then
        cp "$src" "$dest"
        echo "  [COPY] $label"
        return
    fi

    if cmp -s "$src" "$dest"; then
        echo "  [SKIP] $label is unchanged"
        return
    fi

    if ! PYTHON_BIN="$(resolve_python_bin)"; then
        echo "  [WARN] python3 not available; preserving existing $label"
        return
    fi

    tmp_file="$(mktemp)"
    "$PYTHON_BIN" - "$dest" "$src" "$tmp_file" <<'PY'
import json
import pathlib
import re
import sys
import tomllib
from datetime import date, datetime, time

dest_path = pathlib.Path(sys.argv[1])
src_path = pathlib.Path(sys.argv[2])
out_path = pathlib.Path(sys.argv[3])

existing = tomllib.loads(dest_path.read_text())
incoming = tomllib.loads(src_path.read_text())


def merge(existing_value, incoming_value):
    if isinstance(existing_value, dict) and isinstance(incoming_value, dict):
        merged = dict(existing_value)
        for key, value in incoming_value.items():
            if key in merged:
                merged[key] = merge(merged[key], value)
            else:
                merged[key] = value
        return merged

    return incoming_value


def format_key(key):
    if re.fullmatch(r"[A-Za-z0-9_-]+", key):
        return key
    return json.dumps(key)


def format_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (datetime, date, time)):
        return value.isoformat()
    if isinstance(value, dict):
        items = []
        for key, item in value.items():
            items.append(f"{format_key(key)} = {format_value(item)}")
        return "{ " + ", ".join(items) + " }"
    if isinstance(value, list):
        return "[" + ", ".join(format_value(item) for item in value) + "]"
    raise TypeError(f"Unsupported TOML value: {value!r}")


lines = []


def emit_table(table, path=None):
    scalar_items = []
    table_items = []

    for key, value in table.items():
        if isinstance(value, dict):
            table_items.append((key, value))
        else:
            scalar_items.append((key, value))

    if path:
        lines.append(f"[{'.'.join(format_key(part) for part in path)}]")

    for key, value in scalar_items:
        lines.append(f"{format_key(key)} = {format_value(value)}")

    if scalar_items and table_items:
        lines.append("")

    for index, (key, value) in enumerate(table_items):
        emit_table(value, [*(path or []), key])
        if index != len(table_items) - 1:
            lines.append("")


merged = merge(existing, incoming)
emit_table(merged)
out_path.write_text("\n".join(lines).rstrip() + "\n")
PY

    if cmp -s "$tmp_file" "$dest"; then
        rm -f "$tmp_file"
        echo "  [SKIP] $label already includes repo defaults"
        return
    fi

    backup_target="$(backup_target_for "$dest")"
    mkdir -p "$(dirname "$backup_target")"
    cp "$dest" "$backup_target"
    echo "  [BACKUP] Backed up existing $dest"

    mv "$tmp_file" "$dest"
    echo "  [MERGE] $label"
}

echo "Export directory: $EXPORT_DIR"
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
    merge_toml_with_backup "$EXPORT_DIR/codex/config.toml" "$CODEX_CONFIG_DIR/config.toml" "Codex config"
fi

echo ""
echo "Installing repo-vendored Codex skills..."

if [ -x "$INSTALL_CODEX_SKILLS_SCRIPT" ]; then
    "$INSTALL_CODEX_SKILLS_SCRIPT"
else
    echo "  [WARN] Codex skill installer is missing or not executable: $INSTALL_CODEX_SKILLS_SCRIPT"
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
mkdir -p "$HOME/.tmp"
mkdir -p "$HOME/bin"

echo "  [CREATE] ~/.local/bin"
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
else
    echo "No changed files needed backups."
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
echo "  - ~/.codex/skills/* (repo-vendored Codex skills, if tracked in repo)"
echo "  - ~/Library/Application Support/Zed/* (if tracked in repo)"
echo "  - ~/.warp/launch_configurations/* (if tracked in repo)"
echo ""
echo "Next: Run 06-setup-claude.sh"
