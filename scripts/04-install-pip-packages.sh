#!/bin/bash
# =============================================================================
# 04-install-pip-packages.sh - Install Python pip Packages
# =============================================================================
# Bootstrap script for current macOS workflow
# Target: macOS with Homebrew
#
# This script installs a small set of convenience Python libraries at the user
# level. On Homebrew Python this may require --break-system-packages because the
# interpreter is externally managed.
# =============================================================================

set -euo pipefail

echo "========================================"
echo "Step 4: Installing Python pip Packages"
echo "========================================"
echo ""

resolve_python_bin() {
    local brew_prefix=""

    if command -v brew >/dev/null 2>&1; then
        brew_prefix="$(brew --prefix python@3.13 2>/dev/null || true)"
        if [ -n "$brew_prefix" ] && [ -x "$brew_prefix/bin/python3.13" ]; then
            printf '%s\n' "$brew_prefix/bin/python3.13"
            return
        fi
        if [ -n "$brew_prefix" ] && [ -x "$brew_prefix/libexec/bin/python3" ]; then
            printf '%s\n' "$brew_prefix/libexec/bin/python3"
            return
        fi
    fi

    if command -v python3.13 >/dev/null 2>&1; then
        command -v python3.13
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        command -v python3
        return
    fi

    return 1
}

if ! PYTHON_BIN="$(resolve_python_bin)"; then
    echo "ERROR: Python not found. Run 02-install-cli-tools.sh first."
    exit 1
fi

if ! "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
    echo "ERROR: Selected Python does not have pip available: $PYTHON_BIN"
    exit 1
fi

echo "Using Python: $("$PYTHON_BIN" --version) [$PYTHON_BIN]"
echo "Using pip: $("$PYTHON_BIN" -m pip --version)"
echo ""

# -----------------------------------------------------------------------------
# Detect pip install flags that work with Homebrew Python
# -----------------------------------------------------------------------------
PIP_INSTALL_ARGS=(--user)

if "$PYTHON_BIN" -m pip install --dry-run --user pip >/dev/null 2>&1; then
    echo "Using standard user-site pip installs."
elif "$PYTHON_BIN" -m pip install --dry-run --user --break-system-packages pip >/dev/null 2>&1; then
    PIP_INSTALL_ARGS+=(--break-system-packages)
    echo "Using user-site pip installs with --break-system-packages."
else
    echo "ERROR: Unable to determine a safe pip install mode for this Python."
    echo "       Consider using project virtual environments instead."
    exit 1
fi

# -----------------------------------------------------------------------------
# Install pip packages (user-level to avoid permission issues)
# -----------------------------------------------------------------------------
echo ""
echo "Installing pip packages..."
echo ""

PIP_PACKAGES=(
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

for package in "${PIP_PACKAGES[@]}"; do
    if "$PYTHON_BIN" -m pip show "$package" &> /dev/null; then
        echo "  [SKIP] $package is already installed"
    else
        echo "  [INSTALL] Installing $package..."
        "$PYTHON_BIN" -m pip install "${PIP_INSTALL_ARGS[@]}" "$package"
    fi
done

echo ""
echo "========================================"
echo "Step 4 Complete: pip packages installed"
echo "========================================"
echo ""
echo "Installed packages:"
"$PYTHON_BIN" -m pip list --user 2>/dev/null | head -20 || true
echo ""
echo "Note: Packages are installed at the user level for convenience only."
echo "      Project-specific dependencies should still live in project virtualenvs."
echo "      User site-packages: $("$PYTHON_BIN" -m site --user-site)"
echo ""
echo "Next: Run 05-setup-dotfiles.sh"
