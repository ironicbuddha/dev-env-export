#!/bin/bash
# =============================================================================
# 07-setup-1password.sh - Verify 1Password App + CLI Setup
# =============================================================================
# Bootstrap helper for the current 1Password-backed secrets workflow.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_LIB="$SCRIPT_DIR/lib/bootstrap-profile.sh"
PROFILE_INPUT="${DEV_ENV_BOOTSTRAP_PROFILE:-carlo-baseline}"

# shellcheck disable=SC1090
source "$PROFILE_LIB"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) PROFILE_INPUT="${2:-}"; shift 2 ;;
        --profile=*) PROFILE_INPUT="${1#--profile=}"; shift ;;
        -h|--help)
            echo "Usage: ./scripts/07-setup-1password.sh [--profile PROFILE]"
            bootstrap_print_profiles
            exit 0
            ;;
        *) echo "ERROR: Unknown option: $1" >&2; exit 2 ;;
    esac
done

if ! BOOTSTRAP_PROFILE="$(bootstrap_normalize_profile "$PROFILE_INPUT")"; then
    echo "ERROR: Unknown Bootstrap Profile: $PROFILE_INPUT" >&2
    exit 2
fi

echo "========================================"
echo "Step 7: Setting Up 1Password"
echo "========================================"
echo ""

if [ "$BOOTSTRAP_PROFILE" = "shared-baseline" ]; then
    echo "Shared Baseline does not install or configure 1Password."
    echo "Use your preferred secret manager; 1Password guidance is in SECRETS.md."
    exit 0
fi

APP_PATH="/Applications/1Password.app"

if [ -d "$APP_PATH" ]; then
    echo "  [OK] 1Password app detected at $APP_PATH"
else
    echo "  [WARN] 1Password app not found in /Applications"
    echo "         Install it with scripts/02-install-cli-tools.sh first."
fi

if command -v op >/dev/null 2>&1; then
    echo "  [OK] 1Password CLI detected: $(op --version)"
else
    echo "  [ERROR] 1Password CLI (op) is not installed."
    echo "          Install it with scripts/02-install-cli-tools.sh first."
    exit 1
fi

echo ""
echo "Recommended setup flow:"
echo "1. Open the 1Password desktop app and sign in."
echo "2. If needed, enable 1Password CLI integration in the app."
echo "3. Run: op account list"
echo "4. If no account is available yet, try: eval \"\$(op signin)\""
echo "   Or use app integration instead of terminal-only sign-in."
echo ""

if op account list >/dev/null 2>&1; then
    echo "  [OK] 1Password CLI can access at least one signed-in account"
else
    echo "  [INFO] 1Password CLI is installed but not signed in yet"
fi

echo ""
echo "Useful next commands:"
echo "  - op account list"
echo "  - op vault list"
echo "  - eval \"\$(op signin)\""
echo "  - op signin -f"
echo "  - op item list --categories 'API Credential'"
echo ""
echo "See SECRETS.md and onepassword/README.md for repo usage patterns."
