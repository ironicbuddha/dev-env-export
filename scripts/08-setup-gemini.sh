#!/bin/bash
# =============================================================================
# 08-setup-gemini.sh - Set Up Gemini CLI Configuration
# =============================================================================
# Bootstrap script for current macOS workflow
#
# This script:
# 1. Copies the tracked Gemini buddy-mode persona
# 2. Merges portable repo defaults into ~/.gemini/settings.json
# 3. Applies a narrow migration for legacy Gemini agent files with unsupported
#    `skills:` frontmatter. Skill Hub owns shared skill projection separately.
# =============================================================================

set -euo pipefail

echo "========================================"
echo "Step 8: Setting Up Gemini CLI"
echo "========================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(dirname "$SCRIPT_DIR")"
RUNTIME_LIB="$SCRIPT_DIR/lib/runtime-environment.sh"
JSON_MERGE_LIB="$SCRIPT_DIR/lib/json-merge.sh"
FILE_SAFETY_LIB="$SCRIPT_DIR/lib/file-safety.sh"
MANAGED_ARTIFACT_LIB="$SCRIPT_DIR/lib/managed-artifact.sh"
GEMINI_EXPORT="$EXPORT_DIR/gemini"
GEMINI_HOME="$HOME/.gemini"
GEMINI_SETTINGS="$GEMINI_HOME/settings.json"
GEMINI_PERSONA="$GEMINI_HOME/GEMINI.md"
GEMINI_AGENTS_DIR="$GEMINI_HOME/agents"
BACKUP_DIR="$HOME/.gemini-backup-$(date +%Y%m%d-%H%M%S)"

# shellcheck disable=SC1090
source "$RUNTIME_LIB"
# shellcheck disable=SC1090
source "$JSON_MERGE_LIB"
# shellcheck disable=SC1090
source "$FILE_SAFETY_LIB"
# shellcheck disable=SC1090
source "$MANAGED_ARTIFACT_LIB"

if ! command -v gemini >/dev/null 2>&1; then
    echo "ERROR: Gemini CLI is not installed or not in PATH."
    echo "       Run 03-install-npm-globals.sh so nvm installs @google/gemini-cli."
    exit 1
fi

echo "Gemini version: $(gemini --version 2>/dev/null || echo unknown)"
echo "Source: $GEMINI_EXPORT"
echo "Target: $GEMINI_HOME"
echo ""

backup_target_for() {
    local dest="$1"
    local relative_path="${dest#"$HOME"/}"

    if [ "$relative_path" = "$dest" ]; then
        relative_path="$(basename "$dest")"
    fi

    printf '%s/%s' "$BACKUP_DIR" "$relative_path"
}

copy_with_backup() {
    local src="$1"
    local dest="$2"
    local backup_target
    local dest_dir

    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        echo "  [SKIP] $(basename "$dest") is unchanged"
        return
    fi

    backup_target="$(backup_target_for "$dest")"
    if ! bootstrap_copy_file_with_backup "$src" "$dest" "$BACKUP_DIR" "$backup_target"; then
        return 1
    fi

    if [ -f "$backup_target" ]; then
        echo "  [BACKUP] $dest"
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

gemini_agent_skills_frontmatter_removed() {
    local candidate_path="$1"

    "$PYTHON_BIN" - "$candidate_path" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
match = re.match(r'(?ms)\A---\n(.*?)\n---\n', text)
if not match:
    raise SystemExit(0)
frontmatter = match.group(1)
repaired = re.sub(r'(?m)^skills:\n(?:^[ ]{2}- .*(?:\n|$))+', '', frontmatter)
if repaired != frontmatter:
    path.write_text(f"---\n{repaired.rstrip()}\n---\n{text[match.end():]}")
PY
}

gemini_agent_has_legacy_skills_frontmatter() {
    local agent_path="$1"

    awk '
        NR == 1 && $0 == "---" { in_frontmatter = 1; next }
        in_frontmatter && $0 == "---" { closed = 1; exit }
        in_frontmatter && $0 ~ /^skills:[[:space:]]*$/ { found = 1 }
        END { exit(in_frontmatter && closed && found ? 0 : 1) }
    ' "$agent_path"
}

repair_legacy_agent_frontmatter() {
    if [ ! -d "$GEMINI_AGENTS_DIR" ]; then
        echo "  [SKIP] No Gemini agents directory found"
        return
    fi

    if ! PYTHON_BIN="$(bootstrap_resolve_python_bin)"; then
        echo "  [WARN] python3 not available; skipping legacy agent repair"
        return
    fi

    local agent_path=""
    local fixed=0

    for agent_path in "$GEMINI_AGENTS_DIR"/*.md; do
        [ -f "$agent_path" ] || continue
        if ! gemini_agent_has_legacy_skills_frontmatter "$agent_path"; then
            continue
        fi
        bootstrap_managed_artifact_apply_versioned_transform \
            "gemini-agent-skills-v1" "$agent_path" "$BACKUP_DIR" \
            gemini_agent_skills_frontmatter_removed || return 1
        echo "  [FIXED] $(basename "$agent_path")"
        fixed=$((fixed + 1))
    done

    if [ "$fixed" -eq 0 ]; then
        echo "  [SKIP] No legacy skills frontmatter found in Gemini agents"
    fi
}

echo "Creating Gemini directories..."
mkdir -p "$GEMINI_HOME"
echo "  [CREATE] ~/.gemini"

echo ""
echo "Copying Gemini persona..."
copy_with_backup "$GEMINI_EXPORT/GEMINI.md" "$GEMINI_PERSONA"

echo ""
echo "Merging Gemini settings..."
merge_json_with_backup "$GEMINI_EXPORT/settings.json" "$GEMINI_SETTINGS" "settings.json"

echo ""
echo "Repairing legacy Gemini agent frontmatter..."
repair_legacy_agent_frontmatter

echo ""
echo "========================================"
echo "Step 8 Complete: Gemini CLI configured"
echo "========================================"
echo ""
echo "Next: Run 09-inventory-ai-tooling.sh"
