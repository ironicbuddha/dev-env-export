#!/bin/bash
# =============================================================================
# 00-bootstrap.sh - Run the Primary Bootstrap Sequence
# =============================================================================
# Runs scripts 01 through 07 in order for the main macOS bootstrap flow.
# Stops cleanly if a manual prerequisite such as Xcode Command Line Tools is
# still pending.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STEPS=(
    "01-install-brew.sh"
    "02-install-cli-tools.sh"
    "03-install-npm-globals.sh"
    "04-install-pip-packages.sh"
    "05-setup-dotfiles.sh"
    "06-setup-claude.sh"
    "07-setup-1password.sh"
)

load_homebrew() {
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

run_step() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"

    if [ ! -f "$script_path" ]; then
        echo "ERROR: Missing bootstrap step: $script_path"
        exit 1
    fi

    echo ""
    echo "========================================"
    echo "Running $script_name"
    echo "========================================"
    echo ""

    bash "$script_path"
}

echo "========================================"
echo "Dev Environment Bootstrap"
echo "========================================"
echo ""
echo "This will run scripts 01 through 07 in order."
echo "If macOS prompts for Xcode Command Line Tools, complete that install and"
echo "then re-run this script."

if [[ "$(uname)" != "Darwin" ]]; then
    echo ""
    echo "ERROR: This bootstrap flow is intended for macOS only."
    exit 1
fi

for step in "${STEPS[@]}"; do
    run_step "$step"

    case "$step" in
        "01-install-brew.sh"|"02-install-cli-tools.sh")
            load_homebrew
            ;;
    esac

    case "$step" in
        "02-install-cli-tools.sh")
            if ! xcode-select -p >/dev/null 2>&1; then
                echo ""
                echo "Manual action required:"
                echo "  - Finish installing Xcode Command Line Tools."
                echo "  - Re-run ./scripts/00-bootstrap.sh after the install completes."
                exit 0
            fi
            ;;
    esac
done

echo ""
echo "========================================"
echo "Bootstrap Complete"
echo "========================================"
echo ""
echo "Recommended manual follow-up:"
echo "  - exec zsh"
echo "  - gh auth login"
echo "  - aws configure"
echo "  - codex login"
echo "  - claude auth login"
echo "  - open 1Password and confirm op account list works"
echo ""
echo "Optional next steps:"
echo "  - ./scripts/08-op-inject-template.sh --help"
echo "  - ./scripts/09-inventory-ai-tooling.sh"
