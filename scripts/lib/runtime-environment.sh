#!/bin/bash
# Shared Homebrew, nvm, Node, PATH, and Python runtime discovery.

bootstrap_load_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        eval "$(brew shellenv)"
        return 0
    fi

    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        return 0
    fi

    if [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
        return 0
    fi

    return 1
}

bootstrap_load_nvm() {
    local nvm_prefix=""

    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    mkdir -p "$NVM_DIR"

    if command -v brew >/dev/null 2>&1; then
        nvm_prefix="$(brew --prefix nvm 2>/dev/null || true)"
        if [ -n "$nvm_prefix" ] && [ -s "$nvm_prefix/nvm.sh" ]; then
            # shellcheck disable=SC1090
            . "$nvm_prefix/nvm.sh"
            return 0
        fi
    fi

    if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "/opt/homebrew/opt/nvm/nvm.sh"
        return 0
    fi

    if [ -s "/usr/local/opt/nvm/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "/usr/local/opt/nvm/nvm.sh"
        return 0
    fi

    return 1
}

bootstrap_path_prepend_distinct() {
    local entry="$1"

    [ -n "$entry" ] || return 0

    PATH=":$PATH:"
    PATH="${PATH//:$entry:/:}"
    PATH="${PATH#:}"
    PATH="${PATH%:}"

    if [ -n "$PATH" ]; then
        export PATH="$entry:$PATH"
    else
        export PATH="$entry"
    fi
}

bootstrap_activate_nvm_node() {
    local expected_version="$1"
    local actual_version=""

    nvm use "$expected_version" >/dev/null 2>&1 || return 1

    if [ -n "${NVM_BIN:-}" ] && [ -d "$NVM_BIN" ]; then
        bootstrap_path_prepend_distinct "$NVM_BIN"
        hash -r 2>/dev/null || true
    fi

    command -v node >/dev/null 2>&1 || return 1
    actual_version="$(node --version 2>/dev/null)" || return 1
    [ "${actual_version#v}" = "$expected_version" ]
}

bootstrap_nvm_version_matches() {
    local actual_version="$1"
    local expected_version="$2"

    case "$actual_version" in
        "$expected_version"|"v$expected_version")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

bootstrap_nvm_exact_runtime_is_installed() {
    local expected_version="$1"
    local installed_version=""

    installed_version="$(nvm version "$expected_version" 2>/dev/null || true)"
    bootstrap_nvm_version_matches "$installed_version" "$expected_version"
}

bootstrap_nvm_default_is_exact() {
    local expected_version="$1"
    local default_version=""

    default_version="$(nvm version default 2>/dev/null || true)"
    bootstrap_nvm_version_matches "$default_version" "$expected_version"
}

bootstrap_ensure_nvm_node_runtime() {
    local expected_version="$1"

    if ! bootstrap_nvm_exact_runtime_is_installed "$expected_version"; then
        echo "Installing Node.js v${expected_version} via nvm..."
        nvm install "$expected_version" || return 1
    else
        echo "  [SKIP] Node.js v${expected_version} already installed via nvm"
    fi

    bootstrap_nvm_exact_runtime_is_installed "$expected_version" || return 1

    if ! bootstrap_nvm_default_is_exact "$expected_version"; then
        nvm alias default "$expected_version" >/dev/null 2>&1 || return 1
    fi

    bootstrap_nvm_default_is_exact "$expected_version" || return 1
    bootstrap_activate_nvm_node "$expected_version"
}

bootstrap_uv_environment_dir() {
    printf '%s\n' "${DEV_ENV_UV_ENV_DIR:-$HOME/.local/share/dev-env-bootstrap/python}"
}

bootstrap_resolve_homebrew_python_bin() {
    local brew_prefix=""

    if command -v brew >/dev/null 2>&1; then
        brew_prefix="$(brew --prefix python@3.14 2>/dev/null || true)"
        if [ -n "$brew_prefix" ] && [ -x "$brew_prefix/bin/python3.14" ]; then
            printf '%s\n' "$brew_prefix/bin/python3.14"
            return 0
        fi
        if [ -n "$brew_prefix" ] && [ -x "$brew_prefix/libexec/bin/python3" ]; then
            printf '%s\n' "$brew_prefix/libexec/bin/python3"
            return 0
        fi
    fi

    if command -v python3.14 >/dev/null 2>&1; then
        command -v python3.14
        return 0
    fi

    return 1
}

bootstrap_resolve_python_bin() {
    local uv_environment_dir=""

    uv_environment_dir="$(bootstrap_uv_environment_dir)"
    if [ -x "$uv_environment_dir/bin/python" ]; then
        printf '%s\n' "$uv_environment_dir/bin/python"
        return 0
    fi

    bootstrap_resolve_homebrew_python_bin
}
