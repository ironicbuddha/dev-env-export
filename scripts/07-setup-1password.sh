#!/bin/bash
# =============================================================================
# 07-setup-1password.sh - Verify 1Password App + CLI Setup
# =============================================================================
# Bootstrap helper for the current 1Password-backed secrets workflow.
# =============================================================================

set -euo pipefail

echo "========================================"
echo "Step 8: Setting Up 1Password"
echo "========================================"
echo ""

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
echo "4. If no account is available yet, run: op signin"
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
echo "  - op signin"
echo "  - op item list --categories 'API Credential'"
echo ""
echo "See SECRETS.md and onepassword/README.md for repo usage patterns."
