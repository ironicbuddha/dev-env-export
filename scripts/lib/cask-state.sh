#!/bin/bash
# Required Homebrew cask state and repair contract.

bootstrap_cask_app_bundles() {
    local app="$1"
    local known_bundle=""

    if command -v bootstrap_cask_bundle_name >/dev/null 2>&1 && \
            known_bundle="$(bootstrap_cask_bundle_name "$app" 2>/dev/null)"; then
        printf '%s\n' "$known_bundle"
        return 0
    fi

    brew info --cask --json=v2 "$app" 2>/dev/null |
        jq -r '.casks[0].artifacts[]? | select(type == "object" and has("app")) | .app[0]'
}

bootstrap_cask_app_present() {
    local app="$1"
    local app_bundle=""
    local applications_dir="${BOOTSTRAP_APPLICATIONS_DIR:-/Applications}"
    local bundle_count=0

    while IFS= read -r app_bundle; do
        [ -n "$app_bundle" ] || continue
        bundle_count=$((bundle_count + 1))
        bootstrap_app_bundle_usable "$applications_dir/$app_bundle" || return 1
    done < <(bootstrap_cask_app_bundles "$app")

    [ "$bundle_count" -gt 0 ]
}

bootstrap_cask_any_app_bundle_present() {
    local app="$1"
    local app_bundle=""
    local applications_dir="${BOOTSTRAP_APPLICATIONS_DIR:-/Applications}"

    while IFS= read -r app_bundle; do
        [ -n "$app_bundle" ] || continue
        [ -e "$applications_dir/$app_bundle" ] || [ -L "$applications_dir/$app_bundle" ] && return 0
    done < <(bootstrap_cask_app_bundles "$app")
    return 1
}

bootstrap_cask_has_app_bundle() {
    local app="$1"
    local app_bundle=""

    app_bundle="$(bootstrap_cask_app_bundles "$app" | head -n 1)"
    [ -n "$app_bundle" ]
}

bootstrap_cask_install_satisfied() {
    local app="$1"

    if bootstrap_cask_has_app_bundle "$app"; then
        bootstrap_cask_app_present "$app"
    else
        brew list --cask "$app" >/dev/null 2>&1
    fi
}

bootstrap_cask_status() {
    if bootstrap_cask_install_satisfied "$1"; then
        printf '%s\n' "installed"
    else
        printf '%s\n' "missing"
    fi
}

bootstrap_install_required_cask() {
    local app="$1"
    local cask_action="install"

    if bootstrap_cask_install_satisfied "$app"; then
        echo "  [SKIP] $app is installed and usable"
        return 0
    fi

    if brew list --cask "$app" >/dev/null 2>&1; then
        cask_action="reinstall"
        echo "  [REPAIR] $app is registered but its app bundle is unusable"
    fi

    if [ "$app" = "docker" ]; then
        echo "  [INSTALL] Installing $app app bundle without cask-managed binaries..."
        echo "            Docker CLI is provided by the docker formula to avoid sudo-only cask symlink steps."
        if ! brew "$cask_action" --cask --no-binaries "$app"; then
            echo "ERROR: Required cask failed to install: $app"
            return 1
        fi
    else
        echo "  [INSTALL] Installing $app..."
        if ! brew "$cask_action" --cask "$app"; then
            echo "ERROR: Required cask failed to install: $app"
            return 1
        fi
    fi

    if ! bootstrap_cask_install_satisfied "$app"; then
        echo "ERROR: Required cask is still missing or unusable after installation: $app"
        return 1
    fi
}
