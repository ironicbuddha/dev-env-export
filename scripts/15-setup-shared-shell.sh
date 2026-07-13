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

write_managed_block() {
    local path="$1"
    local begin_marker="$2"
    local end_marker="$3"
    local tmp_file=""
    local block_file=""

    mkdir -p "$(dirname "$path")"
    touch "$path"

    if ! awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin {
            if (inside == 1 || begin_count > 0) invalid = 1
            inside = 1
            begin_count++
        }
        $0 == end {
            if (inside != 1 || end_count > 0) invalid = 1
            inside = 0
            end_count++
        }
        END {
            if (inside == 1 || begin_count != end_count || begin_count > 1) invalid = 1
            exit invalid
        }
    ' "$path"; then
        echo "ERROR: Refusing to rewrite $path because its managed block markers are malformed." >&2
        echo "       Repair or remove the $begin_marker / $end_marker block, then rerun." >&2
        return 1
    fi

    tmp_file="$(mktemp)"
    block_file="$(mktemp)"

    cat > "$block_file"

    awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { skipping = 1; next }
        $0 == end { skipping = 0; next }
        skipping != 1 { print }
    ' "$path" > "$tmp_file"

    {
        if [ -s "$tmp_file" ]; then
            sed -e '${/^$/d;}' "$tmp_file"
            echo ""
        fi
        cat "$block_file"
    } > "$path"

    rm -f "$tmp_file" "$block_file"
}

echo "========================================"
echo "Shared Shell Setup"
echo "========================================"
echo ""

write_managed_block "$ZPROFILE" \
    "# BEGIN DEV ENV SHARED HOMEBREW" \
    "# END DEV ENV SHARED HOMEBREW" <<'EOF'
# BEGIN DEV ENV SHARED HOMEBREW
if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
# END DEV ENV SHARED HOMEBREW
EOF

write_managed_block "$ZSHRC" \
    "# BEGIN DEV ENV SHARED RUNTIME PATHS" \
    "# END DEV ENV SHARED RUNTIME PATHS" <<'EOF'
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
echo ""
