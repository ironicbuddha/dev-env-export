#!/bin/bash
# =============================================================================
# 06-setup-claude.sh - Set Up Claude Code Configuration
# =============================================================================
# Exported from Ubuntu VM on 2026-01-17
# Target: macOS with Apple Silicon (arm64)
#
# This script sets up Claude Code configuration files and custom commands.
# Safe to run multiple times (idempotent).
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

echo "Source: $CLAUDE_EXPORT"
echo "Target: $CLAUDE_HOME"
echo ""

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
    cp "$CLAUDE_EXPORT/settings/settings.json" "$CLAUDE_HOME/settings.json"
    echo "  [COPY] settings.json"
fi

if [ -f "$CLAUDE_EXPORT/settings/settings.local.json" ]; then
    cp "$CLAUDE_EXPORT/settings/settings.local.json" "$CLAUDE_HOME/settings.local.json"
    echo "  [COPY] settings.local.json"
fi

# -----------------------------------------------------------------------------
# Copy statusline script
# -----------------------------------------------------------------------------
echo ""
echo "Copying statusline script..."

if [ -f "$CLAUDE_EXPORT/statusline-command.sh" ]; then
    cp "$CLAUDE_EXPORT/statusline-command.sh" "$CLAUDE_HOME/statusline-command.sh"
    chmod +x "$CLAUDE_HOME/statusline-command.sh"
    echo "  [COPY] statusline-command.sh (made executable)"
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
            cp "$cmd" "$CLAUDE_HOME/commands/"
            echo "  [COPY] $(basename "$cmd")"
        fi
    done
fi

# Copy consider subdirectory commands (VM2 only - thinking frameworks)
if [ -d "$CLAUDE_EXPORT/commands/consider" ]; then
    for cmd in "$CLAUDE_EXPORT/commands/consider"/*.md; do
        if [ -f "$cmd" ]; then
            cp "$cmd" "$CLAUDE_HOME/commands/consider/"
            echo "  [COPY] consider/$(basename "$cmd")"
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
echo "   Then enable the plugins listed in INVENTORY.md"
echo ""
echo "3. Verify statusline works:"
echo "   The statusline script requires 'jq' (should be installed)"
echo ""
echo "Enabled plugins from original config:"
echo "  - taches-cc-resources"
echo "  - frontend-design"
echo "  - github"
echo "  - feature-dev"
echo "  - context7"
echo "  - code-review"
echo "  - typescript-lsp"
echo "  - security-guidance"
echo "  - playwright"
echo "  - pyright-lsp"
echo "  - vercel"
echo "  - code-simplifier"
echo "  - ralph-loop"
