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
RUNTIME_LIB="$SCRIPT_DIR/lib/runtime-environment.sh"
EXPECTATIONS_LIB="$SCRIPT_DIR/lib/bootstrap-expectations.sh"
APP_BUNDLE_LIB="$SCRIPT_DIR/lib/app-bundle.sh"
BOOTSTRAP_PROFILE=""

# shellcheck disable=SC1090
source "$PROFILE_LIB"
# shellcheck disable=SC1090
source "$RUNTIME_LIB"
# shellcheck disable=SC1090
source "$EXPECTATIONS_LIB"
# shellcheck disable=SC1090
source "$APP_BUNDLE_LIB"

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

bootstrap_load_expectations "$BOOTSTRAP_PROFILE"

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

    if bootstrap_app_bundle_usable "$path"; then
        pass "app present and usable: $path"
    else
        fail "app missing or unusable: $path"
    fi
}

echo "========================================"
echo "Dev Environment Smoke Test"
echo "========================================"
echo ""
echo "Bootstrap profile: $(bootstrap_profile_label "$BOOTSTRAP_PROFILE") ($BOOTSTRAP_PROFILE)"
echo ""

if ! bootstrap_load_homebrew; then
    fail "Homebrew could not be loaded"
else
    pass "Homebrew shell environment loaded"
fi

if ! command -v brew >/dev/null 2>&1; then
    fail "brew missing from PATH after shellenv"
else
    pass "brew -> $(command -v brew)"
fi

if ! bootstrap_load_nvm; then
    fail "nvm could not be loaded"
else
    pass "nvm loaded"
    if bootstrap_activate_nvm_node "$BOOTSTRAP_NODE_VERSION"; then
        pass "nvm activated exact Node $BOOTSTRAP_NODE_VERSION"
    else
        fail "nvm could not activate exact Node $BOOTSTRAP_NODE_VERSION"
    fi
fi

echo ""
echo "CLI checks"
echo "----------"

for required_command in "${BOOTSTRAP_REQUIRED_COMMANDS[@]}"; do
    check_cmd "$required_command" "$required_command"
done

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
if PYTHON_BIN="$(bootstrap_resolve_python_bin 2>/dev/null)"; then
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

if command -v zsh >/dev/null 2>&1; then
    ZSH_SYNTAX_OK=1
    for zsh_startup_file in "$HOME/.zprofile" "$HOME/.zshrc"; do
        if ! zsh -n "$zsh_startup_file"; then
            ZSH_SYNTAX_OK=0
        fi
    done
    if [ "$ZSH_SYNTAX_OK" -eq 1 ]; then
        pass "zsh startup files pass syntax validation"
    else
        fail "zsh startup files contain syntax errors"
    fi

    ZSH_PROBE='command -v brew >/dev/null 2>&1 && command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 && command -v codex >/dev/null 2>&1 && actual_node="$(node --version)" && [ "${actual_node#v}" = "$BOOTSTRAP_NODE_VERSION" ]'
    if [ "$BOOTSTRAP_PROFILE" = "carlo-baseline" ]; then
        ZSH_PROBE="$ZSH_PROBE && command -v openspec >/dev/null 2>&1"
    fi

    if ZDOTDIR="$HOME" BOOTSTRAP_NODE_VERSION="$BOOTSTRAP_NODE_VERSION" \
            zsh -dilc "$ZSH_PROBE" >/dev/null 2>&1; then
        pass "clean login-interactive zsh loads the required runtime"
    else
        fail "clean login-interactive zsh cannot load the required runtime"
    fi
else
    fail "zsh missing; cannot verify the installed startup files"
fi

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

for required_bundle in "${BOOTSTRAP_REQUIRED_APP_BUNDLES[@]}"; do
    check_app "/Applications/$required_bundle"
done

echo ""
echo "Notes"
echo "-----"
note "This smoke test checks install state and shell loading, not application authentication state."
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
