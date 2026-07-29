#!/bin/bash

# Independently inspect, mutate, and verify nvm-owned npm global packages.

bootstrap_npm_global_package_state() {
    local package="$1" global_root="" node_path="" node_prefix=""

    node_path="$(command -v node 2>/dev/null)" || {
        printf '%s\n' unknown
        return 0
    }
    node_prefix="$(dirname "$(dirname "$node_path")")"
    global_root="$(npm root -g 2>/dev/null)" || {
        printf '%s\n' unknown
        return 0
    }
    if [ "$global_root" != "$node_prefix/lib/node_modules" ]; then
        printf '%s\n' unknown
    elif [ ! -d "$global_root/$package" ]; then
        printf '%s\n' absent
    elif npm list -g "$package" >/dev/null 2>&1; then
        printf '%s\n' present
    else
        printf '%s\n' unknown
    fi
}

bootstrap_ensure_npm_global_package() {
    local package="$1" state="" status=0

    state="$(bootstrap_npm_global_package_state "$package")"
    case "$state" in
        present)
            echo "  [SKIP] $package is already installed"
            return 0
            ;;
        unknown)
            echo "ERROR: $package has existing global-package state that npm cannot verify." >&2
            echo "       Repair it manually, then rerun this Bootstrap Profile." >&2
            return 1
            ;;
    esac

    echo "  [INSTALL] Installing $package..."
    if npm install -g "$package"; then
        :
    else
        status=$?
        state="$(bootstrap_npm_global_package_state "$package")"
        if [ "$state" = unknown ]; then
            echo "ERROR: npm install failed and left $package in an unverified state." >&2
            echo "       Repair it manually, then rerun this Bootstrap Profile." >&2
        else
            echo "ERROR: npm install failed; $package remains absent for a later profile rerun." >&2
        fi
        return "$status"
    fi

    state="$(bootstrap_npm_global_package_state "$package")"
    if [ "$state" = unknown ]; then
        echo "ERROR: npm reported success but left $package in an unverified state." >&2
        echo "       Repair it manually, then rerun this Bootstrap Profile." >&2
        return 1
    fi
    if [ "$state" != present ]; then
        echo "ERROR: npm reported success but $package is absent after installation." >&2
        return 1
    fi
}

bootstrap_corepack_command_is_usable() {
    corepack --version >/dev/null 2>&1
}

bootstrap_corepack_shims_are_present() {
    local corepack_path corepack_bin pnpm_path yarn_path

    corepack_path="$(command -v corepack 2>/dev/null)" || return 1
    corepack_bin="$(dirname "$corepack_path")"
    pnpm_path="$(command -v pnpm 2>/dev/null || true)"
    yarn_path="$(command -v yarn 2>/dev/null || true)"

    [ "$pnpm_path" = "$corepack_bin/pnpm" ] &&
        [ "$yarn_path" = "$corepack_bin/yarn" ]
}

bootstrap_ensure_corepack_enabled() {
    if bootstrap_corepack_shims_are_present; then
        if ! bootstrap_corepack_command_is_usable; then
            echo "ERROR: Corepack shims exist but the active Corepack executable is not usable." >&2
            echo "       Repair Corepack manually, then rerun this Bootstrap Profile." >&2
            return 1
        fi
        echo "  [SKIP] Corepack shims are already enabled"
        return 0
    fi

    if ! bootstrap_corepack_command_is_usable; then
        echo "ERROR: the active Corepack executable is not usable." >&2
        echo "       Repair Corepack manually, then rerun this Bootstrap Profile." >&2
        return 1
    fi

    echo "  [ENABLE] Enabling Corepack shims..."
    if ! corepack enable; then
        if bootstrap_corepack_shims_are_present && bootstrap_corepack_command_is_usable; then
            echo "  [SKIP] Corepack reported failure but its shims are usable"
            return 0
        fi
        echo "ERROR: corepack enable failed before usable shims were available." >&2
        return 1
    fi

    if ! bootstrap_corepack_shims_are_present || ! bootstrap_corepack_command_is_usable; then
        echo "ERROR: corepack enable completed without usable nvm-owned pnpm and yarn shims." >&2
        return 1
    fi
}
