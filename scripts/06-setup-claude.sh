#!/bin/bash
# =============================================================================
# 06-setup-claude.sh - Set Up Claude Code Configuration
# =============================================================================
# Bootstrap script for current macOS workflow
# Target: macOS with Homebrew
#
# This script sets up Claude Code configuration files and custom commands.
# It preserves previous files by backing them up before overwriting.
# =============================================================================

set -euo pipefail

echo "========================================"
echo "Step 6: Setting Up Claude Code"
echo "========================================"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_EXPORT="$EXPORT_DIR/claude"
CLAUDE_HOME="$HOME/.claude"
BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"

echo "Source: $CLAUDE_EXPORT"
echo "Target: $CLAUDE_HOME"
echo ""

backup_target_for() {
    local dest="$1"
    local relative_path="${dest#"$HOME"/}"

    if [ "$relative_path" = "$dest" ]; then
        relative_path="$(basename "$dest")"
    fi

    printf "%s/%s" "$BACKUP_DIR" "$relative_path"
}

copy_with_backup() {
    local src="$1"
    local dest="$2"
    local backup_target
    local dest_dir="$(dirname "$dest")"

    mkdir -p "$dest_dir"

    if [ -f "$dest" ] && ! cmp -s "$src" "$dest"; then
        backup_target="$(backup_target_for "$dest")"
        mkdir -p "$(dirname "$backup_target")"
        cp "$dest" "$backup_target"
        echo "  [BACKUP] $dest"
    fi

    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        echo "  [SKIP] $(basename "$dest") is unchanged"
        return
    fi

    cp "$src" "$dest"
    echo "  [COPY] $(basename "$dest")"
}

resolve_python_bin() {
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

merge_json_with_backup() {
    local src="$1"
    local dest="$2"
    local label="$3"
    local backup_target
    local tmp_file

    mkdir -p "$(dirname "$dest")"

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

    backup_target="$(backup_target_for "$dest")"
    mkdir -p "$(dirname "$backup_target")"
    cp "$dest" "$backup_target"
    echo "  [BACKUP] $dest"

    tmp_file="$(mktemp)"
    "$PYTHON_BIN" - "$dest" "$src" "$tmp_file" <<'PY'
import json
import pathlib
import sys

dest_path = pathlib.Path(sys.argv[1])
src_path = pathlib.Path(sys.argv[2])
out_path = pathlib.Path(sys.argv[3])

existing = json.loads(dest_path.read_text())
incoming = json.loads(src_path.read_text())

def merge(existing_value, incoming_value):
    if isinstance(existing_value, dict) and isinstance(incoming_value, dict):
        merged = dict(existing_value)
        for key, value in incoming_value.items():
            if key in merged:
                merged[key] = merge(merged[key], value)
            else:
                merged[key] = value
        return merged

    if isinstance(existing_value, list) and isinstance(incoming_value, list):
        merged = list(existing_value)
        for item in incoming_value:
            if item not in merged:
                merged.append(item)
        return merged

    return incoming_value

merged = merge(existing, incoming)
out_path.write_text(json.dumps(merged, indent=2) + "\n")
PY

    if cmp -s "$tmp_file" "$dest"; then
        rm -f "$tmp_file"
        echo "  [SKIP] $label already includes repo defaults"
        return
    fi

    mv "$tmp_file" "$dest"
    echo "  [MERGE] $label"
}

# -----------------------------------------------------------------------------
# Create Claude Code directories
# -----------------------------------------------------------------------------
echo "Creating Claude Code directories..."

mkdir -p "$CLAUDE_HOME"
mkdir -p "$CLAUDE_HOME/commands"
mkdir -p "$CLAUDE_HOME/commands/consider"

echo "  [CREATE] ~/.claude"
echo "  [CREATE] ~/.claude/commands"
echo "  [CREATE] ~/.claude/commands/consider"

# -----------------------------------------------------------------------------
# Copy settings files
# -----------------------------------------------------------------------------
echo ""
echo "Copying Claude Code settings..."

if [ -f "$CLAUDE_EXPORT/settings/settings.json" ]; then
    merge_json_with_backup "$CLAUDE_EXPORT/settings/settings.json" "$CLAUDE_HOME/settings.json" "settings.json"
fi

if [ -f "$CLAUDE_EXPORT/settings/settings.local.json" ]; then
    merge_json_with_backup "$CLAUDE_EXPORT/settings/settings.local.json" "$CLAUDE_HOME/settings.local.json" "settings.local.json"
fi

# -----------------------------------------------------------------------------
# Copy statusline script
# -----------------------------------------------------------------------------
echo ""
echo "Copying statusline script..."

if [ -f "$CLAUDE_EXPORT/statusline-command.sh" ]; then
    copy_with_backup "$CLAUDE_EXPORT/statusline-command.sh" "$CLAUDE_HOME/statusline-command.sh"
    chmod +x "$CLAUDE_HOME/statusline-command.sh"
    echo "  [UPDATE] statusline-command.sh permissions"
fi

# -----------------------------------------------------------------------------
# Copy custom commands
# -----------------------------------------------------------------------------
echo ""
echo "Copying custom commands..."
echo "  (Installing tracked main and consider command sets)"

# Copy main commands
if [ -d "$CLAUDE_EXPORT/commands" ]; then
    for cmd in "$CLAUDE_EXPORT/commands"/*.md; do
        if [ -f "$cmd" ]; then
            copy_with_backup "$cmd" "$CLAUDE_HOME/commands/$(basename "$cmd")"
        fi
    done
fi

# Copy consider subdirectory commands
if [ -d "$CLAUDE_EXPORT/commands/consider" ]; then
    for cmd in "$CLAUDE_EXPORT/commands/consider"/*.md; do
        if [ -f "$cmd" ]; then
            copy_with_backup "$cmd" "$CLAUDE_HOME/commands/consider/$(basename "$cmd")"
        fi
    done
fi

# -----------------------------------------------------------------------------
# Update settings.json path for macOS
# -----------------------------------------------------------------------------
echo ""
echo "Updating paths in settings.json for macOS..."

# Normalize legacy absolute home paths if they still appear in an existing file.
if [ -f "$CLAUDE_HOME/settings.json" ]; then
    if grep -q "/home/carlo" "$CLAUDE_HOME/settings.json"; then
        sed -i.bak 's|/home/carlo/|$HOME/|g' "$CLAUDE_HOME/settings.json"
        rm -f "$CLAUDE_HOME/settings.json.bak"
        echo "  [UPDATE] Fixed hardcoded paths in settings.json"
    else
        echo "  [OK] Paths in settings.json are portable"
    fi
fi

echo ""
echo "========================================"
echo "Step 6 Complete: Claude Code configured"
echo "========================================"
echo ""
if [ -d "$BACKUP_DIR" ]; then
    echo "Backups: $BACKUP_DIR"
    echo ""
fi
echo "Custom commands installed:"
ls -1 "$CLAUDE_HOME/commands/" 2>/dev/null | sed 's/^/  - /' || echo "  (none)"
echo ""
echo "IMPORTANT: Next steps for Claude Code:"
echo ""
echo "1. Authenticate with Claude:"
echo "   claude auth login"
echo ""
echo "2. Install plugins (run inside Claude Code):"
echo "   /plugins"
echo "   No plugins are enabled by default in the tracked settings."
echo "   Use claude/PLUGIN-MANIFEST.md as the curated install guide."
echo ""
echo "3. Verify statusline works:"
echo "   The statusline script requires 'jq' (should be installed)"
