#!/bin/bash
# =============================================================================
# 05-setup-dotfiles.sh - Install Carlo Baseline portable configuration
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANAGED_ARTIFACT_LIB="$SCRIPT_DIR/lib/managed-artifact.sh"
PROFILE_LIB="$SCRIPT_DIR/lib/bootstrap-profile.sh"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# shellcheck disable=SC1090
source "$MANAGED_ARTIFACT_LIB"
# shellcheck disable=SC1090
source "$PROFILE_LIB"

PROFILE_INPUT="${DEV_ENV_BOOTSTRAP_PROFILE:-carlo-baseline}"
if ! BOOTSTRAP_PROFILE="$(bootstrap_normalize_profile "$PROFILE_INPUT")"; then
    echo "ERROR: Unknown Bootstrap Profile: $PROFILE_INPUT" >&2
    exit 2
fi

if [ "$BOOTSTRAP_PROFILE" != "carlo-baseline" ]; then
    echo "ERROR: Shared Baseline uses 15-setup-shared-shell.sh; it does not deploy Carlo configuration." >&2
    exit 2
fi

copy_with_backup() {
    local source_path="$1"
    local destination_path="$2"

    if [ -f "$destination_path" ] && cmp -s "$source_path" "$destination_path"; then
        echo "  [SKIP] $(basename "$destination_path") is unchanged"
        return 0
    fi

    bootstrap_managed_artifact_install_exact "$source_path" "$destination_path" "$BACKUP_DIR"
    echo "  [COPY] $source_path -> $destination_path"
}

install_portable_git_config() {
    local destination_path="$HOME/.gitconfig"

    if [ -L "$destination_path" ]; then
        echo "ERROR: Refusing to modify symlink Git configuration: $destination_path" >&2
        return 1
    fi

    if [ -e "$destination_path" ] && [ ! -f "$destination_path" ]; then
        echo "ERROR: Refusing to modify non-file Git configuration: $destination_path" >&2
        return 1
    fi

    if [ -f "$destination_path" ]; then
        echo "  [PRESERVE] Existing Git configuration, including identity"
        return 0
    fi

    copy_with_backup "$REPO_ROOT/dotfiles/gitconfig" "$destination_path"
}

echo "========================================"
echo "Step 5: Setting Up Carlo Configuration"
echo "========================================"
echo ""

echo "Installing managed shell blocks..."
bootstrap_managed_artifact_replace_managed_block "$HOME/.zprofile" \
    "# BEGIN DEV ENV CARLO HOMEBREW" \
    "# END DEV ENV CARLO HOMEBREW" \
    "$BACKUP_DIR" <<'EOF'
# BEGIN DEV ENV CARLO HOMEBREW
if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
# END DEV ENV CARLO HOMEBREW
EOF

bootstrap_managed_artifact_replace_managed_block "$HOME/.zshrc" \
    "# BEGIN DEV ENV CARLO RUNTIME PATHS" \
    "# END DEV ENV CARLO RUNTIME PATHS" \
    "$BACKUP_DIR" <<'EOF'
# BEGIN DEV ENV CARLO RUNTIME PATHS
path_prepend_distinct() {
    local entry="$1"
    [ -n "$entry" ] || return 0
    case ":$PATH:" in
        *":$entry:"*) ;;
        *) export PATH="$entry:$PATH" ;;
    esac
}

if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export NVM_DIR="$HOME/.nvm"
if command -v brew >/dev/null 2>&1; then
    NVM_BREW_PREFIX="$(brew --prefix nvm 2>/dev/null || true)"
    if [ -n "$NVM_BREW_PREFIX" ] && [ -s "$NVM_BREW_PREFIX/nvm.sh" ]; then
        . "$NVM_BREW_PREFIX/nvm.sh"
        nvm use --silent default >/dev/null 2>&1 || nvm use --silent 24.18.0 >/dev/null 2>&1 || true
    fi
    unset NVM_BREW_PREFIX
fi

path_prepend_distinct "$HOME/.local/bin"
DEV_ENV_UV_ENV_DIR="${DEV_ENV_UV_ENV_DIR:-$HOME/.local/share/dev-env-bootstrap/python}"
if [ -d "$DEV_ENV_UV_ENV_DIR/bin" ]; then
    path_prepend_distinct "$DEV_ENV_UV_ENV_DIR/bin"
fi
unset DEV_ENV_UV_ENV_DIR
# END DEV ENV CARLO RUNTIME PATHS
EOF

bootstrap_managed_artifact_replace_managed_block "$HOME/.zshrc" \
    "# BEGIN DEV ENV CARLO SHELL" \
    "# END DEV ENV CARLO SHELL" \
    "$BACKUP_DIR" <<'EOF'
# BEGIN DEV ENV CARLO SHELL
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
if [ -s "$ZSH/oh-my-zsh.sh" ]; then
    source "$ZSH/oh-my-zsh.sh"
fi

if command -v zed >/dev/null 2>&1; then
    export EDITOR="zed --wait"
    export VISUAL="$EDITOR"
fi
# END DEV ENV CARLO SHELL
EOF

echo ""
echo "Installing portable Git and GitHub CLI defaults..."
install_portable_git_config
copy_with_backup "$REPO_ROOT/dotfiles/gitignore_global" "$HOME/.gitignore_global"
copy_with_backup "$REPO_ROOT/dotfiles/gh-config.yml" "$HOME/.config/gh/config.yml"

echo ""
echo "Installing Carlo-managed app configuration..."
copy_with_backup "$REPO_ROOT/zed/settings.json" "$HOME/Library/Application Support/Zed/settings.json"
copy_with_backup "$REPO_ROOT/zed/keymap.json" "$HOME/Library/Application Support/Zed/keymap.json"

for launch_config in "$REPO_ROOT"/warp/launch_configurations/*.yaml "$REPO_ROOT"/warp/launch_configurations/*.yml; do
    [ -f "$launch_config" ] || continue
    copy_with_backup "$launch_config" "$HOME/.warp/launch_configurations/$(basename "$launch_config")"
done

bootstrap_managed_artifact_ensure_safe_directory "$HOME/.local/bin"
bootstrap_managed_artifact_ensure_safe_directory "$HOME/.tmp"
bootstrap_managed_artifact_ensure_safe_directory "$HOME/bin"

echo ""
echo "========================================"
echo "Step 5 Complete: Carlo configuration installed"
echo "========================================"
echo ""
echo "First-Run Configuration Step (required):"
echo "  - Set your Git identity: git config --global user.name 'Your Name'"
echo "  - Set your Git email: git config --global user.email 'you@example.com'"
echo "  - Add named cloud profiles and authenticate with 1Password-backed credentials."
echo "  - Sign in to GitHub CLI with: gh auth login --web --git-protocol https"
echo ""
echo "No personal email, cloud profiles, credentials, or master .env were copied."
