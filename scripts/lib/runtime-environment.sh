#!/bin/bash
# Shared Homebrew, nvm, Node, PATH, and Python runtime discovery.

RUNTIME_ENVIRONMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$RUNTIME_ENVIRONMENT_DIR/operation-policy.sh"

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
    local actual_version="" node_path="" npm_path=""

    nvm use "$expected_version" >/dev/null 2>&1 || return 1

    if [ -n "${NVM_BIN:-}" ] && [ -d "$NVM_BIN" ]; then
        bootstrap_path_prepend_distinct "$NVM_BIN"
        hash -r 2>/dev/null || true
    fi

    node_path="$(command -v node 2>/dev/null)" || return 1
    npm_path="$(command -v npm 2>/dev/null)" || return 1
    [ -n "${NVM_BIN:-}" ] || return 1
    [ "$node_path" = "$NVM_BIN/node" ] || return 1
    [ "$npm_path" = "$NVM_BIN/npm" ] || return 1
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
    local expected_version="$1" status=0

    if ! bootstrap_nvm_exact_runtime_is_installed "$expected_version"; then
        echo "Installing Node.js v${expected_version} via nvm..."
        bootstrap_operation_record operation_start changed none operation_started 0 none \
            nvm_runtime_ensure "$expected_version" "nvm runtime installation started."
        if nvm install "$expected_version"; then
            :
        else
            status=$?
            bootstrap_operation_record operation_end required_failure transient_external \
                nvm_runtime_install_failed "$status" retry_profile nvm_runtime_ensure "$expected_version" \
                "nvm runtime installation failed; retry the Bootstrap Profile after inspecting its log."
            return "$status"
        fi
        bootstrap_operation_record operation_end changed none operation_completed 0 none \
            nvm_runtime_ensure "$expected_version" "nvm runtime installation completed."
    else
        echo "  [SKIP] Node.js v${expected_version} already installed via nvm"
        bootstrap_operation_record operation_end satisfied none nvm_runtime_present 0 none \
            nvm_runtime_ensure "$expected_version" "Exact nvm runtime is already installed."
    fi

    if ! bootstrap_nvm_exact_runtime_is_installed "$expected_version"; then
        bootstrap_operation_record operation_end required_failure managed_state_invalid \
            nvm_runtime_post_install_verify_failed 1 resolve_conflict nvm_runtime_ensure "$expected_version" \
            "nvm runtime is not available after installation."
        return 1
    fi

    if ! bootstrap_nvm_default_is_exact "$expected_version"; then
        bootstrap_operation_record operation_start changed none operation_started 0 none \
            nvm_default_alias_ensure default "nvm default alias update started."
        if nvm alias default "$expected_version" >/dev/null 2>&1; then
            bootstrap_operation_record operation_end changed none operation_completed 0 none \
                nvm_default_alias_ensure default "nvm default alias now targets the exact runtime."
        else
            status=$?
            bootstrap_operation_record operation_end required_failure managed_state_invalid \
                nvm_default_alias_update_failed "$status" retry_profile nvm_default_alias_ensure default \
                "nvm default alias could not be updated."
            return "$status"
        fi
    else
        bootstrap_operation_record operation_end satisfied none nvm_default_alias_present 0 none \
            nvm_default_alias_ensure default "nvm default alias already targets the exact runtime."
    fi

    if ! bootstrap_nvm_default_is_exact "$expected_version"; then
        bootstrap_operation_record operation_end required_failure managed_state_invalid \
            nvm_default_alias_post_update_verify_failed 1 resolve_conflict nvm_default_alias_ensure default \
            "nvm default alias does not target the exact runtime after update."
        return 1
    fi
    bootstrap_operation_record operation_start changed none operation_started 0 none \
        nvm_activation_ensure "$expected_version" "nvm runtime activation started."
    if bootstrap_activate_nvm_node "$expected_version"; then
        bootstrap_operation_record operation_end changed none operation_completed 0 none \
            nvm_activation_ensure "$expected_version" "Exact nvm runtime and npm are active."
        return 0
    else
        status=$?
    fi
    bootstrap_operation_record operation_end required_failure managed_state_invalid \
        nvm_activation_verify_failed "$status" resolve_conflict nvm_activation_ensure "$expected_version" \
        "Exact nvm runtime activation did not yield matching node and npm binaries."
    return "$status"
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
