#!/bin/bash
# =============================================================================
# 15-setup-shared-shell.sh - Install Minimal Shared Shell Wiring
# =============================================================================
# Adds only the shell wiring needed for Homebrew, nvm, and user-level binaries.
# It deliberately avoids prompts, themes, aliases, functions, and personal
# preferences.
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
    fi
elif [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    . "/opt/homebrew/opt/nvm/nvm.sh"
elif [ -s "/usr/local/opt/nvm/nvm.sh" ]; then
    . "/usr/local/opt/nvm/nvm.sh"
fi

if [ -d "$HOME/.local/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
fi
# END DEV ENV SHARED RUNTIME PATHS
EOF

echo "Installed minimal shared shell wiring:"
echo "  - $ZPROFILE"
echo "  - $ZSHRC"
echo "Backups (when files changed): $BACKUP_DIR"
echo ""
