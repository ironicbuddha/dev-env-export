#!/bin/bash
# Single source of required command, cask, and app-bundle expectations.

BOOTSTRAP_EXPECTATIONS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_EXPECTATIONS_REPO_ROOT="$(dirname "$(dirname "$BOOTSTRAP_EXPECTATIONS_LIB_DIR")")"
BOOTSTRAP_EXPECTATIONS_MANIFEST="$BOOTSTRAP_EXPECTATIONS_REPO_ROOT/manifest/homebrew-packages.sh"

bootstrap_cask_bundle_name() {
    case "$1" in
        warp) printf '%s\n' "Warp.app" ;;
        zed) printf '%s\n' "Zed.app" ;;
        raycast) printf '%s\n' "Raycast.app" ;;
        hiddenbar) printf '%s\n' "Hidden Bar.app" ;;
        hammerspoon) printf '%s\n' "Hammerspoon.app" ;;
        github) printf '%s\n' "GitHub Desktop.app" ;;
        1password) printf '%s\n' "1Password.app" ;;
        audio-hijack) printf '%s\n' "Audio Hijack.app" ;;
        chatgpt) printf '%s\n' "ChatGPT.app" ;;
        claude) printf '%s\n' "Claude.app" ;;
        command-x) printf '%s\n' "Command X.app" ;;
        google-chrome) printf '%s\n' "Google Chrome.app" ;;
        google-drive) printf '%s\n' "Google Drive.app" ;;
        libreoffice) printf '%s\n' "LibreOffice.app" ;;
        loopback) printf '%s\n' "Loopback.app" ;;
        macdown) printf '%s\n' "MacDown.app" ;;
        macwhisper) printf '%s\n' "MacWhisper.app" ;;
        microsoft-teams) printf '%s\n' "Microsoft Teams.app" ;;
        miro) printf '%s\n' "Miro.app" ;;
        nordvpn) printf '%s\n' "NordVPN.app" ;;
        obsidian) printf '%s\n' "Obsidian.app" ;;
        slack) printf '%s\n' "Slack.app" ;;
        utm) printf '%s\n' "UTM.app" ;;
        vlc) printf '%s\n' "VLC.app" ;;
        whatsapp) printf '%s\n' "WhatsApp.app" ;;
        zoom) printf '%s\n' "zoom.us.app" ;;
        *) return 1 ;;
    esac
}

bootstrap_load_expectations() {
    local profile="$1"
    local cask=""
    local bundle=""

    # shellcheck disable=SC1090
    source "$BOOTSTRAP_EXPECTATIONS_MANIFEST"

    BOOTSTRAP_REQUIRED_COMMANDS=(
        brew git gh jq make mole python3 uv pandoc pdftotext pdftoppm
        tesseract magick codex node npm corepack
    )
    BOOTSTRAP_REQUIRED_CASKS=("${COMMON_CASK_APPS[@]}")

    case "$profile" in
        carlo-baseline)
            BOOTSTRAP_REQUIRED_COMMANDS+=(
                aws gemini gws op claude bun vercel
            )
            BOOTSTRAP_REQUIRED_CASKS+=("${CARLO_BASELINE_CASK_APPS[@]}")
            ;;
        shared-baseline)
            if [ "${#SHARED_BASELINE_CASK_APPS[@]}" -gt 0 ]; then
                BOOTSTRAP_REQUIRED_CASKS+=("${SHARED_BASELINE_CASK_APPS[@]}")
            fi
            ;;
        *)
            echo "ERROR: Unknown Bootstrap Profile for expectations: $profile" >&2
            return 2
            ;;
    esac

    BOOTSTRAP_REQUIRED_APP_BUNDLES=()
    for cask in "${BOOTSTRAP_REQUIRED_CASKS[@]}"; do
        if bundle="$(bootstrap_cask_bundle_name "$cask" 2>/dev/null)"; then
            BOOTSTRAP_REQUIRED_APP_BUNDLES+=("$bundle")
        fi
    done
}
