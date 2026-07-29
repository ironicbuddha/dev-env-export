#!/bin/bash

set -euo pipefail

state_dir="${TEST_BREW_STATE_DIR:?TEST_BREW_STATE_DIR is required}"
call_log="${TEST_BREW_CALL_LOG:?TEST_BREW_CALL_LOG is required}"
command_name="${1:-}"
shift || true
printf '%s %s\n' "$command_name" "$*" >> "$call_log"
if [ -n "${TEST_BREW_CURLRC_LOG:-}" ] && [ -n "${HOMEBREW_CURLRC:-}" ]; then
    cat "$HOMEBREW_CURLRC" >> "$TEST_BREW_CURLRC_LOG"
fi

state_key() {
    printf '%s' "$1" | tr '/ ' '__'
}

case "$command_name" in
    --prefix)
        kind="formula"
        if [ "${1:-}" = "--formula" ]; then
            shift
        elif [ "${1:-}" = "--cask" ]; then
            kind="cask"
            shift
        fi
        target="${1:-}"
        prefix="$state_dir/prefix-$kind-$(state_key "$target")"
        if [ -f "$state_dir/prefix-$kind-$(state_key "$target").exists" ]; then
            mkdir -p "$prefix"
        fi
        if [ -f "$state_dir/prefix-$kind-$(state_key "$target").owned" ]; then
            mkdir -p "$prefix/.metadata"
            : > "$prefix/.metadata/INSTALL_RECEIPT.json"
        fi
        [ -d "$prefix" ] || exit 1
        printf '%s\n' "$prefix"
        ;;
    list)
        kind="formula"
        if [ "${1:-}" = "--formula" ]; then
            shift
        elif [ "${1:-}" = "--cask" ]; then
            kind="cask"
            shift
        fi
        target="${1:-}"
        [ -f "$state_dir/$kind-$(state_key "$target").present" ]
        ;;
    install|reinstall)
        cask=0
        if [ "${1:-}" = "--cask" ]; then
            cask=1
            shift
        fi
        [ "${1:-}" = "--no-binaries" ] && shift
        target="${1:-}"
        key="$command_name-$(state_key "$target")"
        calls_file="$state_dir/$key.calls"
        calls=0
        [ -f "$calls_file" ] && calls="$(cat "$calls_file")"
        calls=$((calls + 1))
        printf '%s\n' "$calls" > "$calls_file"
        mode=success
        [ -f "$state_dir/$key.mode" ] && mode="$(cat "$state_dir/$key.mode")"
        if [ -f "$state_dir/$key.stderr" ]; then cat "$state_dir/$key.stderr" >&2; fi
        if [ -f "$state_dir/$key.delay" ]; then sleep "$(cat "$state_dir/$key.delay")"; fi
        if [ "$mode" = fail_once ] && [ "$calls" -eq 1 ]; then exit 1; fi
        [ "$mode" = always_fail ] && exit 1
        if [ "$cask" -eq 1 ]; then
            : > "$state_dir/cask-$(state_key "$target").present"
        else
            : > "$state_dir/formula-$(state_key "$target").present"
        fi
        ;;
    update)
        key=update-metadata
        calls_file="$state_dir/$key.calls"
        calls=0
        [ -f "$calls_file" ] && calls="$(cat "$calls_file")"
        calls=$((calls + 1))
        printf '%s\n' "$calls" > "$calls_file"
        mode=success
        [ -f "$state_dir/$key.mode" ] && mode="$(cat "$state_dir/$key.mode")"
        if [ -f "$state_dir/$key.stderr" ]; then cat "$state_dir/$key.stderr" >&2; fi
        if [ "$mode" = fail_once ] && [ "$calls" -eq 1 ]; then exit 1; fi
        [ "$mode" = always_fail ] && exit 1
        ;;
    info|--prefix|shellenv)
        ;;
    *)
        exit 0
        ;;
esac
