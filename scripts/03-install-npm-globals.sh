#!/bin/bash
# =============================================================================
# 03-install-npm-globals.sh - Install Global npm Packages
# =============================================================================
# Bootstrap script for current macOS workflow
# Target: macOS with Homebrew
#
# This script installs global npm packages for the current AI CLI workflow.
# Safe to run multiple times (idempotent).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_LIB="$SCRIPT_DIR/lib/bootstrap-profile.sh"
BOOTSTRAP_PROFILE=""

# shellcheck disable=SC1090
source "$PROFILE_LIB"

usage() {
    cat <<'EOF'
Usage: ./scripts/03-install-npm-globals.sh --profile PROFILE

Installs global npm packages for the selected Bootstrap Profile.

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

echo "========================================"
echo "Step 3: Installing Global npm Packages"
echo "========================================"
echo ""
echo "Bootstrap profile: $(bootstrap_profile_label "$BOOTSTRAP_PROFILE") ($BOOTSTRAP_PROFILE)"
echo ""

strip_npmrc_conflicts() {
    local npmrc_path="$HOME/.npmrc"
    local tmp_path=""

    if [ ! -f "$npmrc_path" ]; then
        return
    fi

    tmp_path="$(mktemp)"
    awk '
        /^[[:space:]]*prefix[[:space:]]*=/ { next }
        /^[[:space:]]*globalconfig[[:space:]]*=/ { next }
        { print }
    ' "$npmrc_path" > "$tmp_path"

    if ! cmp -s "$tmp_path" "$npmrc_path"; then
        mv "$tmp_path" "$npmrc_path"
        echo "  [UPDATE] Removed nvm-incompatible prefix/globalconfig from ~/.npmrc"
    else
        rm -f "$tmp_path"
    fi

    if [ -f "$npmrc_path" ] && [ ! -s "$npmrc_path" ]; then
        rm -f "$npmrc_path"
        echo "  [CLEANUP] Removed empty ~/.npmrc"
    fi
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

strip_npmrc_conflicts

if ! load_nvm; then
    echo "ERROR: nvm is required for this step and could not be loaded."
    echo "       Run 02-install-cli-tools.sh first and make sure nvm installed cleanly."
    exit 1
fi

if ! activate_nvm_node; then
    echo "ERROR: Node.js could not be activated under nvm."
    echo "       Run 02-install-cli-tools.sh first."
    exit 1
fi

# Ensure Node.js is available from nvm after loading it.
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js not found under nvm. Run 02-install-cli-tools.sh first."
    exit 1
fi

NODE_PATH="$(command -v node)"
if [[ "$NODE_PATH" != "$NVM_DIR"/versions/node/* ]]; then
    echo "ERROR: Active Node is not coming from nvm: $NODE_PATH"
    echo "       This step intentionally refuses to install globals into a non-nvm Node."
    exit 1
fi

echo "Using Node.js: $(node --version)"
echo "Using npm: $(npm --version)"
echo "Using Node binary: $NODE_PATH"
echo ""

# -----------------------------------------------------------------------------
# Install global npm packages
# -----------------------------------------------------------------------------
echo ""
echo "Installing global npm packages..."
echo ""

COMMON_NPM_PACKAGES=(
    corepack                    # Package manager manager
    @openai/codex              # Codex CLI
    pnpm                       # Preferred package manager for TS-first repos
    vercel                     # Vercel CLI
)

SHARED_BASELINE_NPM_PACKAGES=(
)

CARLO_BASELINE_NPM_PACKAGES=(
    @anthropic-ai/claude-code   # Claude Code CLI
    @fission-ai/openspec       # OpenSpec agentic framework CLI
    gsd-pi                     # GSD v2 standalone CLI
)

NPM_PACKAGES=("${COMMON_NPM_PACKAGES[@]}")
case "$BOOTSTRAP_PROFILE" in
    carlo-baseline)
        NPM_PACKAGES+=("${CARLO_BASELINE_NPM_PACKAGES[@]}")
        ;;
    shared-baseline)
        NPM_PACKAGES+=("${SHARED_BASELINE_NPM_PACKAGES[@]}")
        ;;
esac

for package in "${NPM_PACKAGES[@]}"; do
    if npm list -g "$package" &> /dev/null; then
        echo "  [SKIP] $package is already installed"
    else
        echo "  [INSTALL] Installing $package..."
        npm install -g "$package"
    fi
done

# Enable corepack for pnpm/yarn support
echo ""
echo "Enabling corepack..."
corepack enable || echo "  [WARN] corepack enable failed (may need sudo)"

echo ""
echo "========================================"
echo "Step 3 Complete: npm packages installed"
echo "========================================"
echo ""
echo "Installed packages:"
npm list -g --depth=0 2>/dev/null || true
echo ""
echo "Codex version: $(codex --version 2>/dev/null || echo 'not in PATH yet')"
echo "pnpm version: $(pnpm --version 2>/dev/null || echo 'not in PATH yet')"
echo "Vercel version: $(vercel --version 2>/dev/null | head -1 || echo 'not in PATH yet')"
if [ "$BOOTSTRAP_PROFILE" = "carlo-baseline" ]; then
    echo "Claude Code version: $(claude --version 2>/dev/null || echo 'not in PATH yet')"
    echo "OpenSpec version: $(openspec --version 2>/dev/null || echo 'not in PATH yet')"
    echo "GSD version: $(gsd --version 2>/dev/null || echo 'not in PATH yet')"
fi
echo ""
echo "Note: These CLIs are installed under the active nvm-managed Node version."
echo "      If they are not found in a new shell, make sure nvm loads correctly."
echo ""
echo "Next: Run 04-install-pip-packages.sh"
