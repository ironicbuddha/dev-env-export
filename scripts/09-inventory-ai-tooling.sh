#!/bin/bash
# =============================================================================
# 09-inventory-ai-tooling.sh - Snapshot Local AI Tooling Without Secrets
# =============================================================================
# Generates a Markdown inventory of the current AI tooling layer on this
# machine. The report is intentionally limited to versions, counts, and
# non-secret inventories.
# =============================================================================

set -euo pipefail

OUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out-file)
            OUT_FILE="${2:-}"
            shift 2
            ;;
        -h|--help)
            cat <<'EOF'
Usage: ./scripts/09-inventory-ai-tooling.sh [--out-file FILE]

Examples:
  ./scripts/09-inventory-ai-tooling.sh
  ./scripts/09-inventory-ai-tooling.sh --out-file AI-INVENTORY.local.md
EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

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

emit() {
    if [[ -n "$OUT_FILE" ]]; then
        printf '%s\n' "$1" >> "$OUT_FILE"
    else
        printf '%s\n' "$1"
    fi
}

command_version() {
    local cmd="$1"
    shift

    if command -v "$cmd" >/dev/null 2>&1; then
        "$@" 2>/dev/null | head -n 1
    else
        echo "missing"
    fi
}

count_files() {
    local path="$1"
    local type="${2:-f}"

    if [[ -d "$path" ]]; then
        find "$path" -type "$type" 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

list_or_none() {
    local cmd="$1"
    local output
    output="$(eval "$cmd" 2>/dev/null || true)"

    if [[ -n "$output" ]]; then
        printf '%s\n' "$output"
    else
        echo "(none)"
    fi
}

python_parse() {
    "$PYTHON_BIN" - "$@"
}

if [[ -n "$OUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUT_FILE")"
    : > "$OUT_FILE"
fi

TODAY="$(date '+%Y-%m-%d %H:%M:%S %Z')"
HOME_DIR="$HOME"

if ! PYTHON_BIN="$(resolve_python_bin)"; then
    echo "ERROR: Python not found. Run scripts/02-install-cli-tools.sh first." >&2
    exit 1
fi

CODEX_CONFIG="$HOME_DIR/.codex/config.toml"
CLAUDE_SETTINGS="$HOME_DIR/.claude/settings.json"
GEMINI_SETTINGS="$HOME_DIR/.gemini/settings.json"
GEMINI_PERSONA="$HOME_DIR/.gemini/GEMINI.md"
ZED_SETTINGS="$HOME_DIR/Library/Application Support/Zed/settings.json"
ZED_EXTENSIONS="$HOME_DIR/Library/Application Support/Zed/extensions/index.json"
ZED_EXTERNAL_AGENTS="$HOME_DIR/Library/Application Support/Zed/external_agents"
OPENCODE_DIR="$HOME_DIR/.config/opencode"

CODEX_MODEL="unknown"
CODEX_REASONING="unknown"
CODEX_APPROVAL="unknown"
CODEX_SANDBOX="unknown"
CODEX_TRUSTED_PROJECTS="0"
CODEX_FEATURES="(none)"

if [[ -f "$CODEX_CONFIG" ]]; then
    IFS='|' read -r CODEX_MODEL CODEX_REASONING CODEX_APPROVAL CODEX_SANDBOX CODEX_TRUSTED_PROJECTS CODEX_FEATURES <<< "$(python_parse <<'PY'
import pathlib
import tomllib

p = pathlib.Path.home() / ".codex" / "config.toml"
data = tomllib.loads(p.read_text())
features = ",".join(sorted((data.get("features") or {}).keys())) or "(none)"
print("|".join([
    data.get("model", "unknown"),
    data.get("model_reasoning_effort", "unknown"),
    data.get("approval_policy", "unknown"),
    data.get("sandbox_mode", "unknown"),
    str(len(data.get("projects", {}))),
    features,
]))
PY
)"
fi

CLAUDE_PLUGINS="$(python_parse <<'PY'
import json
import pathlib

p = pathlib.Path.home() / ".claude" / "settings.json"
if not p.exists():
    print("(none)")
else:
    data = json.loads(p.read_text())
    plugins = sorted(k for k, v in (data.get("enabledPlugins") or {}).items() if v)
    print("\n".join(plugins) if plugins else "(none)")
PY
)"

CLAUDE_PLUGIN_COUNT="$(printf '%s\n' "$CLAUDE_PLUGINS" | awk 'NF && $0 != "(none)" {count++} END {print count+0}')"

GEMINI_AUTH_MODE="unknown"
if [[ -f "$GEMINI_SETTINGS" ]]; then
    GEMINI_AUTH_MODE="$(python_parse <<'PY'
import json
import pathlib

p = pathlib.Path.home() / ".gemini" / "settings.json"
data = json.loads(p.read_text())
print((((data.get("security") or {}).get("auth") or {}).get("selectedType")) or "unknown")
PY
)"
fi

ZED_EXT_LIST="$(python_parse <<'PY'
import json
import pathlib

p = pathlib.Path.home() / "Library" / "Application Support" / "Zed" / "extensions" / "index.json"
if not p.exists():
    print("(none)")
else:
    data = json.loads(p.read_text())
    exts = sorted((data.get("extensions") or {}).keys())
    print("\n".join(exts) if exts else "(none)")
PY
)"

ZED_EXT_COUNT="$(printf '%s\n' "$ZED_EXT_LIST" | awk 'NF && $0 != "(none)" {count++} END {print count+0}')"

ZED_AGENT_LIST="$(find "$ZED_EXTERNAL_AGENTS" -mindepth 2 -maxdepth 2 -type d ! -path "$ZED_EXTERNAL_AGENTS/registry/*" 2>/dev/null | sed "s|$ZED_EXTERNAL_AGENTS/||" | sort || true)"
if [[ -z "$ZED_AGENT_LIST" ]]; then
    ZED_AGENT_LIST="(none)"
fi
ZED_AGENT_COUNT="$(printf '%s\n' "$ZED_AGENT_LIST" | awk 'NF && $0 != "(none)" {count++} END {print count+0}')"

ZED_AGENT_MODEL="unknown"
ZED_TRUST_ALL_WORKTREES="unknown"
ZED_SINGLE_FILE_REVIEW="unknown"
ZED_THEME="unknown"

if [[ -f "$ZED_SETTINGS" ]]; then
    IFS='|' read -r ZED_AGENT_MODEL ZED_TRUST_ALL_WORKTREES ZED_SINGLE_FILE_REVIEW ZED_THEME <<< "$(python_parse <<'PY'
import json
import pathlib

p = pathlib.Path.home() / "Library" / "Application Support" / "Zed" / "settings.json"
lines = []
for line in p.read_text().splitlines():
    if line.lstrip().startswith("//"):
        continue
    lines.append(line)
data = json.loads("\n".join(lines))
agent = data.get("agent") or {}
default_model = agent.get("default_model") or {}
theme = data.get("theme", "unknown")
if isinstance(theme, dict):
    theme = theme.get("dark") or theme.get("light") or "unknown"
session = data.get("session") or {}
print("|".join([
    default_model.get("model", "unknown"),
    str(session.get("trust_all_worktrees", "unknown")),
    str(agent.get("single_file_review", "unknown")),
    str(theme),
]))
PY
)"
fi

OPENCODE_COMMAND_COUNT="$(count_files "$OPENCODE_DIR/command" f)"
OPENCODE_AGENT_COUNT="$(count_files "$OPENCODE_DIR/agents" f)"
OPENCODE_HOOK_COUNT="$(count_files "$OPENCODE_DIR/hooks" f)"
CODEX_SKILL_COUNT="$(find "$HOME_DIR/.codex/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
CODEX_AGENT_COUNT="$(count_files "$HOME_DIR/.codex/agents" f)"
GEMINI_AGENT_COUNT="$(count_files "$HOME_DIR/.gemini/agents" f)"
GEMINI_HOOK_COUNT="$(count_files "$HOME_DIR/.gemini/hooks" f)"
GEMINI_SKILL_COUNT="$(find -L "$HOME_DIR/.agents/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
CLAUDE_COMMAND_COUNT="$(count_files "$HOME_DIR/.claude/commands" f)"
CLAUDE_HOOK_COUNT="$(count_files "$HOME_DIR/.claude/hooks" f)"

emit "# AI Tooling Inventory"
emit ""
emit "Generated: $TODAY"
emit ""
emit "Python parser: $PYTHON_BIN"
emit ""
emit "## Versions"
emit ""
emit "- codex: $(command_version codex codex --version)"
emit "- claude: $(command_version claude claude --version)"
emit "- gemini: $(command_version gemini gemini --version)"
emit "- gsd: $(command_version gsd gsd --version)"
emit "- openspec: $(command_version openspec openspec --version)"
emit "- zed: $(command_version zed zed --version)"
emit "- op: $(command_version op op --version)"
emit "- gh: $(command_version gh gh --version)"
emit "- uv: $(command_version uv uv --version)"
emit "- pnpm: $(command_version pnpm pnpm --version)"
emit "- bun: $(command_version bun bun --version)"
emit "- playwright: $(command_version playwright playwright --version)"
emit "- vercel: $(command_version vercel vercel --version)"
emit "- docker: $(command_version docker docker --version)"
emit "- warp: $(command_version warp warp --version)"
emit ""
emit "## Codex"
emit ""
emit "- config: $CODEX_CONFIG"
emit "- model: $CODEX_MODEL"
emit "- reasoning: $CODEX_REASONING"
emit "- approval: $CODEX_APPROVAL"
emit "- sandbox: $CODEX_SANDBOX"
emit "- features: $CODEX_FEATURES"
emit "- installed skills: $CODEX_SKILL_COUNT"
emit "- custom agent files: $CODEX_AGENT_COUNT"
emit "- trusted project count: $CODEX_TRUSTED_PROJECTS"
emit ""
emit "## Claude Code"
emit ""
emit "- settings: $CLAUDE_SETTINGS"
emit "- command files: $CLAUDE_COMMAND_COUNT"
emit "- hook files: $CLAUDE_HOOK_COUNT"
emit "- enabled plugin count: $CLAUDE_PLUGIN_COUNT"
emit "- enabled plugins:"
while IFS= read -r line; do
    emit "  - $line"
done <<< "$CLAUDE_PLUGINS"
emit ""
emit "## Gemini CLI"
emit ""
emit "- settings: $GEMINI_SETTINGS"
emit "- persona file: $GEMINI_PERSONA"
emit "- auth mode: $GEMINI_AUTH_MODE"
emit "- agent files: $GEMINI_AGENT_COUNT"
emit "- hook files: $GEMINI_HOOK_COUNT"
emit "- discovered shared skill count: $GEMINI_SKILL_COUNT"
emit ""
emit "## Zed"
emit ""
emit "- settings: $ZED_SETTINGS"
emit "- extension index: $ZED_EXTENSIONS"
emit "- default agent model: $ZED_AGENT_MODEL"
emit "- trust all worktrees: $ZED_TRUST_ALL_WORKTREES"
emit "- single file review: $ZED_SINGLE_FILE_REVIEW"
emit "- active theme: $ZED_THEME"
emit "- installed extension count: $ZED_EXT_COUNT"
emit "- installed extensions:"
while IFS= read -r line; do
    emit "  - $line"
done <<< "$ZED_EXT_LIST"
emit "- external agent package count: $ZED_AGENT_COUNT"
emit "- external agents:"
while IFS= read -r line; do
    emit "  - $line"
done <<< "$ZED_AGENT_LIST"
emit ""
emit "## OpenCode"
emit ""
if [[ -d "$OPENCODE_DIR" ]]; then
    emit "- config dir: $OPENCODE_DIR"
    emit "- command files: $OPENCODE_COMMAND_COUNT"
    emit "- agent files: $OPENCODE_AGENT_COUNT"
    emit "- hook files: $OPENCODE_HOOK_COUNT"
else
    emit "- config dir: missing"
fi
emit ""
emit "## Notes"
emit ""
emit "- This report intentionally excludes auth files, runtime history, caches, and project trust details."
emit "- Use it to audit drift, not to copy live state wholesale into the repo."

if [[ -n "$OUT_FILE" ]]; then
    echo "Wrote AI tooling inventory to $OUT_FILE"
fi
