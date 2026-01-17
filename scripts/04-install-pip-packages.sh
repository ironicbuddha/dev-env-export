#!/bin/bash
# =============================================================================
# 04-install-pip-packages.sh - Install Python pip Packages
# =============================================================================
# Exported from Ubuntu VM on 2026-01-17
# Target: macOS with Apple Silicon (arm64)
#
# This script installs Python packages that were installed on the Linux system.
# Safe to run multiple times (idempotent).
# =============================================================================

set -e  # Exit on any error

echo "========================================"
echo "Step 4: Installing Python pip Packages"
echo "========================================"
echo ""

# Ensure Python is available
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python not found. Run 02-install-cli-tools.sh first."
    exit 1
fi

echo "Using Python: $(python3 --version)"
echo "Using pip: $(pip3 --version)"
echo ""

# -----------------------------------------------------------------------------
# Upgrade pip first
# -----------------------------------------------------------------------------
echo "Upgrading pip..."
python3 -m pip install --upgrade pip

# -----------------------------------------------------------------------------
# Install pip packages (user-level to avoid permission issues)
# -----------------------------------------------------------------------------
echo ""
echo "Installing pip packages..."
echo ""

PIP_PACKAGES=(
    # Data validation & typing (VM1 only)
    pydantic            # Data validation using Python type annotations
    annotated-types     # Type annotations support
    typing-inspection   # Type inspection utilities

    # Database (VM1 only)
    psycopg2-binary     # PostgreSQL adapter
    sqlalchemy          # SQL toolkit and ORM

    # CLI development (VM1 only)
    typer               # CLI framework (based on Click)
    shellingham         # Shell detection

    # Concurrency (VM1 only)
    greenlet            # Lightweight in-process concurrent programming
)

for package in "${PIP_PACKAGES[@]}"; do
    if pip3 show "$package" &> /dev/null; then
        echo "  [SKIP] $package is already installed"
    else
        echo "  [INSTALL] Installing $package..."
        pip3 install --user "$package"
    fi
done

echo ""
echo "========================================"
echo "Step 4 Complete: pip packages installed"
echo "========================================"
echo ""
echo "Installed packages:"
pip3 list --user 2>/dev/null | head -20 || true
echo ""
echo "Note: Packages installed with --user flag to avoid permission issues."
echo "      They are located in: $(python3 -m site --user-site)"
echo ""
echo "Next: Run 05-setup-dotfiles.sh"
