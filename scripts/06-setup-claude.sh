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

set -e  # Exit on any error

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
    copy_with_backup "$CLAUDE_EXPORT/settings/settings.json" "$CLAUDE_HOME/settings.json"
fi

if [ -f "$CLAUDE_EXPORT/settings/settings.local.json" ]; then
    copy_with_backup "$CLAUDE_EXPORT/settings/settings.local.json" "$CLAUDE_HOME/settings.local.json"
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
echo "  (Merged from both VMs: 24 main commands + 12 consider commands)"

# Copy main commands (VM1 + VM2 merged)
if [ -d "$CLAUDE_EXPORT/commands" ]; then
    for cmd in "$CLAUDE_EXPORT/commands"/*.md; do
        if [ -f "$cmd" ]; then
            copy_with_backup "$cmd" "$CLAUDE_HOME/commands/$(basename "$cmd")"
        fi
    done
fi

# Copy consider subdirectory commands (VM2 only - thinking frameworks)
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

# The settings.json uses $HOME which should work, but let's verify
if [ -f "$CLAUDE_HOME/settings.json" ]; then
    # Check if path uses hardcoded Linux path
    if grep -q "/home/carlo" "$CLAUDE_HOME/settings.json"; then
        # Replace with $HOME variable
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
echo "   Add only the plugins you actually use."
echo ""
echo "3. Verify statusline works:"
echo "   The statusline script requires 'jq' (should be installed)"
