#!/bin/bash
# Shared prerequisite checks for bootstrap entry paths that can reach Homebrew.

bootstrap_apple_silicon_usable() {
    [ "$(uname -m)" = "arm64" ]
}

bootstrap_ensure_apple_silicon() {
    if bootstrap_apple_silicon_usable; then
        return 0
    fi

    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = "1" ]; then
        echo "ERROR: This Apple Silicon Mac is running this bootstrap under Rosetta." >&2
        echo "       Open a native arm64 Terminal session, then rerun this command." >&2
        return 1
    fi

    echo "ERROR: This bootstrap supports Apple Silicon Macs only (detected: $(uname -m))." >&2
    return 1
}

bootstrap_xcode_clt_usable() {
    local clang_path=""

    command -v xcode-select >/dev/null 2>&1 || return 1
    xcode-select -p >/dev/null 2>&1 || return 1
    command -v xcrun >/dev/null 2>&1 || return 1

    clang_path="$(xcrun --find clang 2>/dev/null)" || return 1
    [ -n "$clang_path" ] || return 1
    [ -x "$clang_path" ] || return 1
    "$clang_path" --version >/dev/null 2>&1 || return 1
}

bootstrap_ensure_xcode_clt() {
    echo "Checking Xcode Command Line Tools usability..."

    if bootstrap_xcode_clt_usable; then
        echo "  [OK] Xcode Command Line Tools are installed and usable"
        return 0
    fi

    echo "  [ACTION] Xcode Command Line Tools are missing or unusable"
    if command -v xcode-select >/dev/null 2>&1; then
        xcode-select --install >/dev/null 2>&1 || true
    fi
    echo "Manual action required: complete or repair the Xcode Command Line Tools installation, then re-run this command."
    return 20
}
