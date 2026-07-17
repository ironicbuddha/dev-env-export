#!/bin/bash

set -euo pipefail

tool_name="$(basename "$0")"
printf '%s %s\n' "$tool_name" "$*" >> "$TEST_ACTION_LOG"

case "$tool_name" in
    brew)
        if [ "${1:-}" = "shellenv" ]; then
            printf 'export PATH="%s:$PATH"\n' "$TEST_FAKE_NODE_BIN"
        elif [ "${1:-}" = "--prefix" ] && [ "${2:-}" = "nvm" ]; then
            printf '%s\n' "$TEST_NVM_PREFIX"
        else
            exit 1
        fi
        ;;
    node)
        [ "${1:-}" = "--version" ] && printf '%s\n' "v24.18.0"
        ;;
    npm)
        if [ "${1:-}" = "--version" ]; then
            printf '%s\n' "11.16.0"
        elif [ "${1:-}" = "list" ]; then
            printf '%s\n' "fixture npm globals"
        else
            exit 1
        fi
        ;;
    corepack)
        if [ "${1:-}" = "enable" ]; then
            exit 0
        elif [ "${1:-}" = "install" ] && [ "${2:-}" = "--global" ] && \
                [ "${3:-}" = "pnpm@latest" ]; then
            : > "$TEST_PNPM_MARKER"
        else
            exit 1
        fi
        ;;
    pnpm)
        if [ ! -f "$TEST_PNPM_MARKER" ]; then
            echo "corepack implicit download prompt" >> "$TEST_ACTION_LOG"
            exit 90
        fi
        [ "${1:-}" = "--version" ] && printf '%s\n' "11.13.1"
        ;;
    codex)
        printf '%s\n' "codex-cli 0.144.5"
        ;;
    vercel)
        printf '%s\n' "Vercel CLI 56.3.1"
        ;;
esac
