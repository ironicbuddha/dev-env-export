#!/bin/bash
# =============================================================================
# 04-install-pip-packages.sh - Install Bootstrap Python Packages
# =============================================================================
# Bootstrap script for current macOS workflow
# Target: macOS with Homebrew
#
# This script creates a bootstrap-owned uv environment for the retained
# document/OCR Python stack. Project dependencies stay in project environments.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_LIB="$SCRIPT_DIR/lib/bootstrap-profile.sh"
RUNTIME_LIB="$SCRIPT_DIR/lib/runtime-environment.sh"
BOOTSTRAP_PROFILE=""

# shellcheck disable=SC1090
source "$PROFILE_LIB"
# shellcheck disable=SC1090
source "$RUNTIME_LIB"

usage() {
    cat <<'EOF'
Usage: ./scripts/04-install-pip-packages.sh --profile PROFILE

Installs user-level Python packages for the selected Bootstrap Profile.

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
echo "Step 4: Installing Bootstrap Python Packages"
echo "========================================"
echo ""
echo "Bootstrap profile: $(bootstrap_profile_label "$BOOTSTRAP_PROFILE") ($BOOTSTRAP_PROFILE)"
echo ""

if ! PYTHON_BIN="$(bootstrap_resolve_homebrew_python_bin)"; then
    echo "ERROR: Homebrew Python 3.14 not found. Run 02-install-cli-tools.sh first."
    exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
    echo "ERROR: uv not found. Run 02-install-cli-tools.sh first."
    exit 1
fi

UV_ENV_DIR="$(bootstrap_uv_environment_dir)"

echo "Using Homebrew Python: $("$PYTHON_BIN" --version) [$PYTHON_BIN]"
echo "Creating or updating bootstrap uv environment: $UV_ENV_DIR"
if ! uv venv --python "$PYTHON_BIN" "$UV_ENV_DIR"; then
    echo "ERROR: uv could not create the bootstrap Python environment."
    exit 1
fi

UV_PYTHON_BIN="$UV_ENV_DIR/bin/python"
if [ ! -x "$UV_PYTHON_BIN" ]; then
    echo "ERROR: bootstrap uv environment does not contain Python: $UV_PYTHON_BIN"
    exit 1
fi

echo "Using bootstrap Python: $UV_PYTHON_BIN"
echo ""

# -----------------------------------------------------------------------------
# Install Python packages into the bootstrap-owned uv environment.
# -----------------------------------------------------------------------------
echo ""
echo "Installing pip packages..."
echo ""

COMMON_PIP_PACKAGES=(
    # Document, PDF, and image handling for AI workflows
    python-docx         # Read and write .docx files
    openpyxl            # Read and write .xlsx files
    python-pptx         # Read and write .pptx files
    pypdf               # Read and assemble PDFs
    pdfplumber          # Extract structured text from PDFs
    pillow              # Image loading and preprocessing
    pytesseract         # OCR wrapper for tesseract
    reportlab           # Generate PDFs
)

SHARED_BASELINE_PIP_PACKAGES=(
)

CARLO_BASELINE_PIP_PACKAGES=(
    # Data validation and typing
    pydantic            # Data validation using Python type annotations
    annotated-types     # Type annotations support
    typing-inspection   # Type inspection utilities

    # Database
    psycopg2-binary     # PostgreSQL adapter
    sqlalchemy          # SQL toolkit and ORM

    # CLI development
    typer               # CLI framework (based on Click)
    shellingham         # Shell detection

    # Concurrency
    greenlet            # Lightweight in-process concurrent programming
)

PIP_PACKAGES=("${COMMON_PIP_PACKAGES[@]}")
case "$BOOTSTRAP_PROFILE" in
    carlo-baseline)
        PIP_PACKAGES+=("${CARLO_BASELINE_PIP_PACKAGES[@]}")
        ;;
    shared-baseline)
        if [ "${#SHARED_BASELINE_PIP_PACKAGES[@]}" -gt 0 ]; then
            PIP_PACKAGES+=("${SHARED_BASELINE_PIP_PACKAGES[@]}")
        fi
        ;;
esac

for package in "${PIP_PACKAGES[@]}"; do
    if uv pip show --python "$UV_PYTHON_BIN" "$package" &> /dev/null; then
        echo "  [SKIP] $package is already installed"
    else
        echo "  [INSTALL] Installing $package..."
        uv pip install --python "$UV_PYTHON_BIN" "$package"
    fi
done

echo ""
echo "========================================"
echo "Step 4 Complete: bootstrap Python packages installed"
echo "========================================"
echo ""
echo "Installed packages:"
uv pip list --python "$UV_PYTHON_BIN" 2>/dev/null | head -20 || true
echo ""
echo "Note: Packages live in the bootstrap-owned uv environment."
echo "      Project-specific dependencies should still live in project environments."
echo ""
echo "Next: Run 05-setup-dotfiles.sh"
