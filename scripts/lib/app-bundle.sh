#!/bin/bash
# Validate that a macOS .app directory contains launchable bundle structure.

bootstrap_app_bundle_usable() {
    local app_path="$1"
    local executable=""

    [ -d "$app_path" ] || return 1
    [ -f "$app_path/Contents/Info.plist" ] || return 1
    [ -d "$app_path/Contents/MacOS" ] || return 1

    for executable in "$app_path/Contents/MacOS/"*; do
        if [ -f "$executable" ] && [ -x "$executable" ]; then
            return 0
        fi
    done

    return 1
}
