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
    local backup_target
    local tmp_file

    if [ -L "$dest" ]; then
        echo "ERROR: Refusing to replace symlink destination: $dest" >&2
        return 1
    fi

    if [ -e "$dest" ] && [ ! -f "$dest" ]; then
        echo "ERROR: Refusing to replace non-file destination: $dest" >&2
        return 1
    fi

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

    if ! PYTHON_BIN="$(bootstrap_resolve_python_bin)"; then
        echo "  [WARN] python3 not available; preserving existing $label"
        return
    fi

    tmp_file="$(mktemp)"
    bootstrap_merge_json "$dest" "$src" "$tmp_file" "$PYTHON_BIN"

    if cmp -s "$tmp_file" "$dest"; then
        rm -f "$tmp_file"
        echo "  [SKIP] $label already includes repo defaults"
        return
    fi

    backup_target="$(backup_target_for "$dest")"
    mkdir -p "$(dirname "$backup_target")"
    cp "$dest" "$backup_target"
    echo "  [BACKUP] $dest"

    mv "$tmp_file" "$dest"
    echo "  [MERGE] $label"
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

    "$PYTHON_BIN" - "$GEMINI_AGENTS_DIR" <<'PY'
import pathlib
import re
import sys

agents_dir = pathlib.Path(sys.argv[1])
pattern = re.compile(r'(?ms)\A---\n(.*?)\n---\n')
skills_block = re.compile(r'(?m)^skills:\n(?:^[ ]{2}- .*\n)+')
fixed = 0

for path in sorted(agents_dir.glob("*.md")):
    text = path.read_text()
    match = pattern.match(text)
    if not match:
        continue
    frontmatter = match.group(1)
    repaired = skills_block.sub("", frontmatter)
    if repaired == frontmatter:
        continue
    new_text = f"---\n{repaired.rstrip()}\n---\n{text[match.end():]}"
    path.write_text(new_text)
    print(f"  [FIXED] {path.name}")
    fixed += 1

if fixed == 0:
    print("  [SKIP] No legacy skills frontmatter found in Gemini agents")
PY
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
