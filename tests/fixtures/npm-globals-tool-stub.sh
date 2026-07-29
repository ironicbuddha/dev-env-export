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
        elif [ "${1:-}" = "root" ] && [ "${2:-}" = "-g" ]; then
            printf '%s\n' "$TEST_NPM_GLOBAL_ROOT"
        elif [ "${1:-}" = "list" ] && [ "${2:-}" = "-g" ]; then
            if [ "${3:-}" = "${TEST_NPM_LIST_FAIL_PACKAGE:-}" ]; then
                exit 1
            fi
            if [ -d "$TEST_NPM_GLOBAL_ROOT/${3:-}" ]; then
                exit 0
            fi
            exit 1
        elif [ "${1:-}" = "install" ] && [ "${2:-}" = "-g" ]; then
            if [ "${3:-}" = "${TEST_NPM_INSTALL_FAIL_PACKAGE:-}" ]; then
                [ "${TEST_NPM_INSTALL_LEAVES_RESIDUE:-0}" != 1 ] ||
                    mkdir -p "$TEST_NPM_GLOBAL_ROOT/${3:-}"
                exit 1
            fi
            mkdir -p "$TEST_NPM_GLOBAL_ROOT/${3:-}"
            exit 0
        else
            exit 1
        fi
        ;;
    corepack)
        if [ "${1:-}" = "--version" ]; then
            [ "${TEST_COREPACK_VERSION_FAIL:-0}" != 1 ] || exit 1
            printf '%s\n' "0.34.0"
        elif [ "${1:-}" = "enable" ]; then
            corepack_bin_dir="$(dirname "$0")"
            printf '#!/bin/bash\nexit 0\n' > "$corepack_bin_dir/pnpm"
            printf '#!/bin/bash\nexit 0\n' > "$corepack_bin_dir/yarn"
            chmod +x "$corepack_bin_dir/pnpm" "$corepack_bin_dir/yarn"
            exit 0
        else
            exit 1
        fi
        ;;
    codex)
        printf '%s\n' "codex-cli 0.144.5"
        ;;
    vercel)
        printf '%s\n' "Vercel CLI 56.3.1"
        ;;
    gemini)
        printf '%s\n' "Gemini CLI 0.52.0"
        ;;
esac
