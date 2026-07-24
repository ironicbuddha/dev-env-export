#!/bin/bash
# =============================================================================
# 15-setup-shared-shell.sh - Install Minimal Shared Shell Wiring
# =============================================================================
# Adds only the shell wiring needed for Homebrew, nvm, bootstrap tools, and
# user-level binaries.
# It deliberately avoids prompts, themes, aliases, and personal preferences.
# =============================================================================

set -euo pipefail

ZPROFILE="$HOME/.zprofile"
ZSHRC="$HOME/.zshrc"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGED_SHELL_LIB="$SCRIPT_DIR/lib/managed-shell-block.sh"
BACKUP_DIR="$(mktemp -d "$HOME/.shared-shell-backup-$(date +%Y%m%d-%H%M%S)-XXXXXX")"

# shellcheck disable=SC1090
source "$MANAGED_SHELL_LIB"

echo "========================================"
echo "Shared Shell Setup"
echo "========================================"
echo ""

bootstrap_write_managed_shell_block "$ZPROFILE" \
    "# BEGIN DEV ENV SHARED HOMEBREW" \
    "# END DEV ENV SHARED HOMEBREW" \
    "$BACKUP_DIR" <<'EOF'
# BEGIN DEV ENV SHARED HOMEBREW
if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
# END DEV ENV SHARED HOMEBREW
EOF

bootstrap_write_managed_shell_block "$ZSHRC" \
    "# BEGIN DEV ENV SHARED RUNTIME PATHS" \
    "# END DEV ENV SHARED RUNTIME PATHS" \
    "$BACKUP_DIR" <<'EOF'
# BEGIN DEV ENV SHARED RUNTIME PATHS
export NVM_DIR="$HOME/.nvm"
if command -v brew >/dev/null 2>&1; then
    NVM_BREW_PREFIX="$(brew --prefix nvm 2>/dev/null || true)"
    if [ -n "$NVM_BREW_PREFIX" ] && [ -s "$NVM_BREW_PREFIX/nvm.sh" ]; then
        . "$NVM_BREW_PREFIX/nvm.sh"
        nvm use --silent default >/dev/null 2>&1 || nvm use --silent 24.18.0 >/dev/null 2>&1 || true
    fi
elif [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    . "/opt/homebrew/opt/nvm/nvm.sh"
elif [ -s "/usr/local/opt/nvm/nvm.sh" ]; then
    . "/usr/local/opt/nvm/nvm.sh"
fi

path_prepend_distinct() {
    local entry="$1"
    [ -n "$entry" ] || return 0
    case ":$PATH:" in
        *":$entry:"*) ;;
        *) export PATH="$entry:$PATH" ;;
    esac
}

path_prepend_distinct "$HOME/.local/bin"
DEV_ENV_UV_ENV_DIR="${DEV_ENV_UV_ENV_DIR:-$HOME/.local/share/dev-env-bootstrap/python}"
if [ -d "$DEV_ENV_UV_ENV_DIR/bin" ]; then
    path_prepend_distinct "$DEV_ENV_UV_ENV_DIR/bin"
fi
unset DEV_ENV_UV_ENV_DIR
# END DEV ENV SHARED RUNTIME PATHS
EOF

echo "Installed minimal shared shell wiring:"
echo "  - $ZPROFILE"
echo "  - $ZSHRC"
echo "Backups (when files changed): $BACKUP_DIR"
echo ""
