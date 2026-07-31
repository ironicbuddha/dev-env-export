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
RUNTIME_LIB="$SCRIPT_DIR/lib/runtime-environment.sh"
JSON_MERGE_LIB="$SCRIPT_DIR/lib/json-merge.sh"
MANAGED_ARTIFACT_LIB="$SCRIPT_DIR/lib/managed-artifact.sh"
CLAUDE_EXPORT="$EXPORT_DIR/claude"
CLAUDE_HOME="$HOME/.claude"
CODEX_EXPORT="$EXPORT_DIR/codex"
CODEX_HOME="$HOME/.codex"
BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"

# shellcheck disable=SC1090
source "$RUNTIME_LIB"
# shellcheck disable=SC1090
source "$JSON_MERGE_LIB"
# shellcheck disable=SC1090
source "$MANAGED_ARTIFACT_LIB"

echo "Source: $CLAUDE_EXPORT"
echo "Target: $CLAUDE_HOME"
echo ""

merge_codex_yolo_defaults() {
    local destination="$CODEX_HOME/config.toml"
    local python_bin=""

    if [ ! -e "$destination" ]; then
        bootstrap_managed_artifact_install_exact "$CODEX_EXPORT/config.toml" "$destination" "$BACKUP_DIR"
        echo "  [COPY] Codex portable defaults"
        return
    fi

    if [ -L "$destination" ] || [ ! -f "$destination" ]; then
        echo "ERROR: Refusing to modify non-regular Codex config: $destination" >&2
        return 1
    fi

    if ! python_bin="$(bootstrap_resolve_python_bin)"; then
        echo "ERROR: python3 is required to validate existing Codex TOML." >&2
        return 1
    fi
    BOOTSTRAP_MANAGED_ARTIFACT_VALIDATOR_BIN="$python_bin"

    if bootstrap_managed_artifact_apply_versioned_transform \
            "codex-yolo-defaults-v1" "$destination" "$BACKUP_DIR" \
            codex_yolo_defaults_candidate bootstrap_managed_artifact_toml_is_valid; then
        :
    else
        return $?
    fi
    echo "  [OK] Codex portable defaults are present"
}

codex_yolo_defaults_candidate() {
    local candidate_path="$1"
    local rewritten_path="${candidate_path}.rewritten"

    awk '
        /^[[:space:]]*approval_policy[[:space:]]*=/ {
            print "approval_policy = \"never\""
            approval_seen = 1
            next
        }
        /^[[:space:]]*sandbox_mode[[:space:]]*=/ {
            print "sandbox_mode = \"danger-full-access\""
            sandbox_seen = 1
            next
        }
        !inserted && /^[[]/ {
            if (!approval_seen) print "approval_policy = \"never\""
            if (!sandbox_seen) print "sandbox_mode = \"danger-full-access\""
            inserted = 1
        }
        { print }
        END {
            if (!inserted) {
                if (!approval_seen) print "approval_policy = \"never\""
                if (!sandbox_seen) print "sandbox_mode = \"danger-full-access\""
            }
        }
    ' "$candidate_path" > "$rewritten_path" || return 1
    mv "$rewritten_path" "$candidate_path"
}

echo "Applying Codex portable defaults..."
merge_codex_yolo_defaults
echo ""

copy_with_backup() {
    local src="$1"
    local dest="$2"

    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        echo "  [SKIP] $(basename "$dest") is unchanged"
        return
    fi

    if ! bootstrap_managed_artifact_install_exact "$src" "$dest" "$BACKUP_DIR"; then
        return 1
    fi

    echo "  [COPY] $(basename "$dest")"
}

merge_json_with_backup() {
    local src="$1"
    local dest="$2"
    local label="$3"
    if ! PYTHON_BIN="$(bootstrap_resolve_python_bin)"; then
        echo "  [WARN] python3 not available; preserving existing $label"
        return
    fi
    bootstrap_managed_artifact_merge_overlay json "$src" "$dest" "$BACKUP_DIR" "$PYTHON_BIN" || return 1
    echo "  [MERGE] $label"
}

normalize_legacy_claude_home_paths() {
    local candidate_path="$1"

    "$PYTHON_BIN" - "$candidate_path" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
value = json.loads(path.read_text())

def normalize(item):
    if isinstance(item, dict):
        return {key: normalize(value) for key, value in item.items()}
    if isinstance(item, list):
        return [normalize(value) for value in item]
    if isinstance(item, str):
        return item.replace("/home/carlo/", "$HOME/")
    return item

path.write_text(json.dumps(normalize(value), indent=2) + "\n")
PY
}

# -----------------------------------------------------------------------------
# Create Claude Code directories
# -----------------------------------------------------------------------------
echo "Creating Claude Code directories..."

bootstrap_managed_artifact_ensure_safe_directory "$CLAUDE_HOME"
bootstrap_managed_artifact_ensure_safe_directory "$CLAUDE_HOME/commands"
bootstrap_managed_artifact_ensure_safe_directory "$CLAUDE_HOME/commands/consider"

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
        if ! PYTHON_BIN="$(bootstrap_resolve_python_bin)"; then
            echo "ERROR: python3 is required to migrate legacy Claude paths." >&2
            exit 1
        fi
        bootstrap_managed_artifact_apply_versioned_transform \
            "claude-home-path-v1" "$CLAUDE_HOME/settings.json" "$BACKUP_DIR" \
            normalize_legacy_claude_home_paths bootstrap_managed_artifact_json_is_valid || exit 1
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
