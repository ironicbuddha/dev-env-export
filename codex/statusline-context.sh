#!/bin/bash
# Codex status/context helper
#
# Prints a compact summary that can be used in a shell prompt, terminal
# statusline, tmux segment, Warp status command, or future Codex integration
# hook.
#
# Usage:
#   ./codex/statusline-context.sh
#   ./codex/statusline-context.sh --format compact
#   ./codex/statusline-context.sh --no-color
#
# Optional environment variables:
# - CODEX_STATUS_ROOT: directory to inspect instead of the current working dir
# - CODEX_STATUS_TASK: short current task label
# - CODEX_STATUS_LAST_CHECK: last verification summary (for example: "tests:12/12")
# - CODEX_STATUS_LAST_CMD: short last command result (for example: "lint:ok")

set -euo pipefail

ROOT_DIR="${CODEX_STATUS_ROOT:-$PWD}"
CONFIG_PATH="${HOME}/.codex/config.toml"
FORMAT="pretty"
FORCE_NO_COLOR=0

usage() {
    cat <<'EOF'
Usage: statusline-context.sh [--format pretty|compact] [--no-color]

Formats:
  pretty   Bracketed terminal-friendly segments with color when supported
  compact  Tighter plain-text output for tmux, Warp, or narrow status bars
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --format)
            shift
            if [ $# -eq 0 ]; then
                echo "Missing value for --format" >&2
                exit 2
            fi
            FORMAT="$1"
            ;;
        --pretty)
            FORMAT="pretty"
            ;;
        --compact|--tmux|--warp)
            FORMAT="compact"
            ;;
        --no-color)
            FORCE_NO_COLOR=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [ "$FORMAT" != "pretty" ] && [ "$FORMAT" != "compact" ]; then
    echo "Invalid format: $FORMAT" >&2
    exit 2
fi

if [ -t 1 ] && [ "$FORCE_NO_COLOR" -ne 1 ] && [ "${NO_COLOR:-}" != "1" ] && [ "$FORMAT" = "pretty" ]; then
    C_RESET=$'\033[0m'
    C_DIM=$'\033[2m'
    C_CYAN=$'\033[36m'
    C_BLUE=$'\033[34m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
    C_MAGENTA=$'\033[35m'
else
    C_RESET=""
    C_DIM=""
    C_CYAN=""
    C_BLUE=""
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
    C_MAGENTA=""
fi

read_toml_value() {
    local key="$1"

    if [ ! -f "$CONFIG_PATH" ]; then
        return 1
    fi

    python3 - "$CONFIG_PATH" "$key" <<'PY'
import sys
import tomllib

config_path, dotted_key = sys.argv[1], sys.argv[2]

with open(config_path, "rb") as fh:
    data = tomllib.load(fh)

current = data
for part in dotted_key.split("."):
    if not isinstance(current, dict) or part not in current:
        sys.exit(1)
    current = current[part]

if isinstance(current, bool):
    print(str(current).lower())
else:
    print(current)
PY
}

git_branch() {
    git -C "$ROOT_DIR" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null \
        || printf '%s\n' "no-git"
}

git_dirty_count() {
    git -C "$ROOT_DIR" status --short 2>/dev/null | wc -l | tr -d ' '
}

git_staged_count() {
    git -C "$ROOT_DIR" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' '
}

repo_name() {
    git -C "$ROOT_DIR" rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null \
        || basename "$ROOT_DIR"
}

repo_state() {
    if [ -d "$ROOT_DIR/.git/rebase-merge" ] || [ -d "$ROOT_DIR/.git/rebase-apply" ]; then
        printf '%s\n' "rebase"
        return
    fi

    if [ -f "$ROOT_DIR/.git/MERGE_HEAD" ]; then
        printf '%s\n' "merge"
        return
    fi

    printf '%s\n' "normal"
}

mcp_count() {
    codex mcp list 2>/dev/null | awk '
        /^No MCP servers configured/ { print 0; found = 1; next }
        NF > 0 { count += 1 }
        END {
            if (found == 1) exit
            if (count == 0) print 0
            else print count
        }
    '
}

paint() {
    local color="$1"
    local text="$2"
    printf '%s%s%s' "$color" "$text" "$C_RESET"
}

trim_value() {
    local value="$1"
    local max_len="$2"

    if [ "${#value}" -le "$max_len" ]; then
        printf '%s' "$value"
        return
    fi

    printf '%s...' "${value:0:max_len-3}"
}

format_sandbox() {
    case "$1" in
        danger-full-access) printf '%s\n' "danger" ;;
        workspace-write) printf '%s\n' "write" ;;
        read-only) printf '%s\n' "read" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

format_multi() {
    case "$1" in
        true) printf '%s\n' "on" ;;
        false) printf '%s\n' "off" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

segment() {
    local label="$1"
    local value="$2"
    local color="$3"

    printf '[%s%s%s %s] ' "$C_DIM" "$label" "$C_RESET" "$(paint "$color" "$value")"
}

model="$(read_toml_value model || printf '%s\n' "unknown-model")"
reasoning="$(read_toml_value model_reasoning_effort || printf '%s\n' "unknown")"
approval="$(read_toml_value approval_policy || printf '%s\n' "unknown")"
sandbox="$(read_toml_value sandbox_mode || printf '%s\n' "unknown")"
multi_agent="$(read_toml_value features.multi_agent || printf '%s\n' "unknown")"
branch="$(git_branch)"
dirty="$(git_dirty_count)"
staged="$(git_staged_count)"
repo="$(repo_name)"
state="$(repo_state)"
mcp="$(mcp_count)"
task="${CODEX_STATUS_TASK:-}"
last_check="${CODEX_STATUS_LAST_CHECK:-}"
last_cmd="${CODEX_STATUS_LAST_CMD:-}"

git_color="$C_GREEN"
if [ "$dirty" -gt 0 ]; then
    git_color="$C_YELLOW"
fi
if [ "$state" != "normal" ]; then
    git_color="$C_RED"
fi

sandbox_short="$(format_sandbox "$sandbox")"
sandbox_color="$C_GREEN"
if [ "$sandbox_short" = "write" ]; then
    sandbox_color="$C_YELLOW"
fi
if [ "$sandbox_short" = "danger" ]; then
    sandbox_color="$C_RED"
fi

approval_color="$C_GREEN"
if [ "$approval" = "on-request" ] || [ "$approval" = "untrusted" ]; then
    approval_color="$C_YELLOW"
fi
if [ "$approval" = "never" ]; then
    approval_color="$C_MAGENTA"
fi

check_color="$C_GREEN"
case "$last_check" in
    "" ) ;;
    *fail*|*FAIL*|*error*|*ERROR*) check_color="$C_RED" ;;
    *warn*|*WARN*) check_color="$C_YELLOW" ;;
esac

cmd_color="$C_CYAN"
case "$last_cmd" in
    "" ) ;;
    *fail*|*FAIL*|*error*|*ERROR*) cmd_color="$C_RED" ;;
    *warn*|*WARN*) cmd_color="$C_YELLOW" ;;
esac

if [ "$FORMAT" = "compact" ]; then
    output=""
    output+="$(trim_value "${repo}:${branch}" 28)"
    output+=" d${dirty}/s${staged}/${state}"
    output+=" $(trim_value "${model}/${reasoning}" 24)"
    output+=" sbx:${sandbox_short}"
    output+=" ask:${approval}"
    output+=" mcp:${mcp}"
    output+=" ma:$(format_multi "$multi_agent")"

    if [ -n "$task" ]; then
        output+=" task:$(trim_value "$task" 24)"
    fi

    if [ -n "$last_check" ]; then
        output+=" check:$(trim_value "$last_check" 24)"
    fi

    if [ -n "$last_cmd" ]; then
        output+=" cmd:$(trim_value "$last_cmd" 24)"
    fi

    printf '%s\n' "$output"
    exit 0
fi

output=""
output+="$(segment "mdl" "$(trim_value "${model}/${reasoning}" 28)" "$C_CYAN")"
output+="$(segment "git" "$(trim_value "${repo}:${branch}" 32)" "$C_BLUE")"
output+="$(segment "ws" "d${dirty}/s${staged}/${state}" "$git_color")"
output+="$(segment "sbx" "$sandbox_short" "$sandbox_color")"
output+="$(segment "ask" "$approval" "$approval_color")"
output+="$(segment "mcp" "$mcp" "$C_GREEN")"
output+="$(segment "ma" "$(format_multi "$multi_agent")" "$C_CYAN")"

if [ -n "$task" ]; then
    output+="$(segment "task" "$(trim_value "$task" 28)" "$C_BLUE")"
fi

if [ -n "$last_check" ]; then
    output+="$(segment "check" "$(trim_value "$last_check" 28)" "$check_color")"
fi

if [ -n "$last_cmd" ]; then
    output+="$(segment "cmd" "$(trim_value "$last_cmd" 28)" "$cmd_color")"
fi

printf '%s\n' "${output% }"
