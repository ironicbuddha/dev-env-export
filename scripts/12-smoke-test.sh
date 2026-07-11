#!/bin/bash
# =============================================================================
# 12-smoke-test.sh - Verify the Post-Bootstrap Baseline
# =============================================================================
# Loads the expected Homebrew and nvm environment, then checks that the core
# CLI tools, tracked config files, and app installs expected by this repo are
# actually present.
# =============================================================================

set -euo pipefail

FAILURES=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_LIB="$SCRIPT_DIR/lib/bootstrap-profile.sh"
BOOTSTRAP_PROFILE=""

# shellcheck disable=SC1090
source "$PROFILE_LIB"

usage() {
    cat <<'EOF'
Usage: ./scripts/12-smoke-test.sh --profile PROFILE

Runs smoke checks for the selected Bootstrap Profile.

Options:
  --profile PROFILE   Required unless DEV_ENV_BOOTSTRAP_PROFILE is set
  -h, --help          Show this help

Valid profiles:
EOF
    bootstrap_print_profiles
}

PROFILE_INPUT="${DEV_ENV_BOOTSTRAP_PROFILE:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            if [ $# -lt 2 ]; then
                echo "ERROR: --profile requires a value." >&2
                usage >&2
                exit 2
            fi
            PROFILE_INPUT="${2:-}"
            shift 2
            ;;
        --profile=*)
            PROFILE_INPUT="${1#--profile=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ -z "$PROFILE_INPUT" ]; then
    echo "ERROR: Missing required Bootstrap Profile." >&2
    usage >&2
    exit 2
fi

if ! BOOTSTRAP_PROFILE="$(bootstrap_normalize_profile "$PROFILE_INPUT")"; then
    echo "ERROR: Unknown Bootstrap Profile: $PROFILE_INPUT" >&2
    usage >&2
    exit 2
fi

export DEV_ENV_BOOTSTRAP_PROFILE="$BOOTSTRAP_PROFILE"

load_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        eval "$(brew shellenv)"
        return 0
    fi

    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        return 0
    fi

    if [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
        return 0
    fi

    return 1
}

load_nvm() {
    local nvm_prefix=""

    export NVM_DIR="$HOME/.nvm"

    if command -v brew >/dev/null 2>&1; then
        nvm_prefix="$(brew --prefix nvm 2>/dev/null || true)"
        if [ -n "$nvm_prefix" ] && [ -s "$nvm_prefix/nvm.sh" ]; then
            # shellcheck disable=SC1090
            . "$nvm_prefix/nvm.sh"
            return 0
        fi
    fi

    if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "/opt/homebrew/opt/nvm/nvm.sh"
        return 0
    fi

    if [ -s "/usr/local/opt/nvm/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "/usr/local/opt/nvm/nvm.sh"
        return 0
    fi

    return 1
}

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

path_prepend_distinct() {
    local entry="$1"

    if [ -z "$entry" ]; then
        return
    fi

    PATH=":$PATH:"
    PATH="${PATH//:$entry:/:}"
    PATH="${PATH#:}"
    PATH="${PATH%:}"

    if [ -n "$PATH" ]; then
        export PATH="$entry:$PATH"
    else
        export PATH="$entry"
    fi
}

activate_nvm_node() {
    if ! nvm use 22 >/dev/null 2>&1 && ! nvm use default >/dev/null 2>&1; then
        return 1
    fi

    if [ -n "${NVM_BIN:-}" ] && [ -d "$NVM_BIN" ]; then
        path_prepend_distinct "$NVM_BIN"
        hash -r 2>/dev/null || true
    fi

    return 0
}

pass() {
    printf '[OK]   %s\n' "$1"
}

fail() {
    printf '[FAIL] %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

note() {
    printf '[INFO] %s\n' "$1"
}

check_cmd() {
    local label="$1"
    local cmd="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        pass "$label -> $(command -v "$cmd")"
    else
        fail "$label missing from PATH"
    fi
}

check_python_module() {
    local module="$1"
    local label="$2"

    if "$PYTHON_BIN" -c "import $module" >/dev/null 2>&1; then
        pass "python module present: $label"
    else
        fail "python module missing: $label"
    fi
}

check_file() {
    local path="$1"

    if [ -f "$path" ]; then
        pass "file present: $path"
    else
        fail "file missing: $path"
    fi
}

check_config_value() {
    local file="$1"
    local expected="$2"

    if [ -f "$file" ] && grep -Fqx "$expected" "$file"; then
        pass "$file contains $expected"
    else
        fail "$file is missing $expected"
    fi
}

check_app() {
    local path="$1"

    if [ -d "$path" ]; then
        pass "app present: $path"
    else
        fail "app missing: $path"
    fi
}

echo "========================================"
echo "Dev Environment Smoke Test"
echo "========================================"
echo ""
echo "Bootstrap profile: $(bootstrap_profile_label "$BOOTSTRAP_PROFILE") ($BOOTSTRAP_PROFILE)"
echo ""

if ! load_homebrew; then
    fail "Homebrew could not be loaded"
else
    pass "Homebrew shell environment loaded"
fi

if ! command -v brew >/dev/null 2>&1; then
    fail "brew missing from PATH after shellenv"
else
    pass "brew -> $(command -v brew)"
fi

if ! load_nvm; then
    fail "nvm could not be loaded"
else
    pass "nvm loaded"
    if activate_nvm_node; then
        pass "nvm activated the expected Node runtime"
    else
        fail "nvm could not activate the default or Node 22 runtime"
    fi
fi

echo ""
echo "CLI checks"
echo "----------"

check_cmd "gh" "gh"
check_cmd "git" "git"
check_cmd "jq" "jq"
check_cmd "python3" "python3"
check_cmd "codex" "codex"
check_cmd "pnpm" "pnpm"
check_cmd "vercel" "vercel"
check_cmd "node" "node"
check_cmd "npm" "npm"
check_cmd "uv" "uv"
check_cmd "bun" "bun"
check_cmd "pandoc" "pandoc"
check_cmd "pdftotext" "pdftotext"
check_cmd "pdftoppm" "pdftoppm"
check_cmd "tesseract" "tesseract"
check_cmd "magick" "magick"

if [ "$BOOTSTRAP_PROFILE" = "carlo-baseline" ]; then
    check_cmd "aws" "aws"
    check_cmd "gemini" "gemini"
    check_cmd "gws" "gws"
    check_cmd "op" "op"
    check_cmd "claude" "claude"
    check_cmd "gsd" "gsd"
    check_cmd "docker" "docker"
fi

if command -v node >/dev/null 2>&1; then
    NODE_PATH="$(command -v node)"
    if [[ "$NODE_PATH" == "$HOME/.nvm/versions/node/"* ]]; then
        pass "node is owned by nvm -> $NODE_PATH"
    else
        fail "node is not coming from nvm -> $NODE_PATH"
    fi
fi

if command -v npm >/dev/null 2>&1; then
    NPM_PATH="$(command -v npm)"
    if [[ "$NPM_PATH" == "$HOME/.nvm/versions/node/"* ]]; then
        pass "npm is owned by nvm -> $NPM_PATH"
    else
        fail "npm is not coming from nvm -> $NPM_PATH"
    fi
fi

PYTHON_BIN=""
if PYTHON_BIN="$(resolve_python_bin 2>/dev/null)"; then
    pass "baseline python resolved -> $PYTHON_BIN"
else
    fail "could not resolve the baseline Python interpreter"
fi

echo ""
echo "Python document stack"
echo "---------------------"

if [ -n "$PYTHON_BIN" ]; then
    check_python_module "docx" "python-docx"
    check_python_module "openpyxl" "openpyxl"
    check_python_module "pptx" "python-pptx"
    check_python_module "pypdf" "pypdf"
    check_python_module "pdfplumber" "pdfplumber"
    check_python_module "PIL" "Pillow"
    check_python_module "pytesseract" "pytesseract"
    check_python_module "reportlab" "reportlab"
else
    fail "baseline Python missing, cannot verify document-related Python modules"
fi

echo ""
echo "Config checks"
echo "-------------"

check_file "$HOME/.zshrc"
check_file "$HOME/.zprofile"

if [ "$BOOTSTRAP_PROFILE" = "carlo-baseline" ]; then
    check_file "$HOME/.gitconfig"
    check_file "$HOME/.gitignore_global"
    check_file "$HOME/.aws/config"
    check_file "$HOME/.config/gh/config.yml"
    check_file "$HOME/.codex/config.toml"
    check_config_value "$HOME/.codex/config.toml" 'approval_policy = "never"'
    check_config_value "$HOME/.codex/config.toml" 'sandbox_mode = "danger-full-access"'
    check_file "$HOME/.codex/skills/apply-project-standards/SKILL.md"
    check_file "$HOME/.agents/skills/apply-project-standards/SKILL.md"
    check_file "$HOME/.claude/settings.json"
    check_file "$HOME/.claude/statusline-command.sh"
    check_file "$HOME/.gemini/settings.json"
    check_file "$HOME/.gemini/GEMINI.md"
    check_file "$HOME/Library/Application Support/Zed/settings.json"
    check_file "$HOME/Library/Application Support/Zed/keymap.json"
    check_file "$HOME/.warp/launch_configurations/dev-env-bootstrap.yaml"
fi

echo ""
echo "App checks"
echo "----------"

check_app "/Applications/Warp.app"
check_app "/Applications/Zed.app"
check_app "/Applications/Raycast.app"
check_app "/Applications/Hidden Bar.app"
check_app "/Applications/Hammerspoon.app"
check_app "/Applications/GitHub Desktop.app"

if [ "$BOOTSTRAP_PROFILE" = "carlo-baseline" ]; then
    check_app "/Applications/1Password.app"
    check_app "/Applications/Docker.app"
fi

echo ""
echo "Notes"
echo "-----"
note "This smoke test checks install state and config placement, not login state."
note "Zed CLI installation is still a manual follow-up from inside Zed."
note "If auth flows are still pending, installed CLIs can exist without being signed in yet."
note "Document OCR is expected to be a fallback when native extraction or PDF text parsing yields poor results."

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "Smoke test passed."
    exit 0
fi

echo "Smoke test failed with $FAILURES issue(s)."
exit 1
