#!/bin/bash

nvm() {
    local command="${1:-}"
    local argument="${2:-}"
    local state_dir="${TEST_NVM_STATE:?}"
    local runtime=""
    local default=""

    mkdir -p "$state_dir"
    printf '%s\n' "$*" >> "${TEST_NVM_LOG:?}"
    runtime="$(cat "$state_dir/runtime" 2>/dev/null || true)"
    default="$(cat "$state_dir/default" 2>/dev/null || true)"

    case "$command" in
        version)
            if [ "$argument" = "default" ]; then
                [ -n "$default" ] && printf 'v%s\n' "$default" || printf 'N/A\n'
            elif [ "$argument" = "$runtime" ]; then
                printf 'v%s\n' "$runtime"
            else
                printf 'N/A\n'
            fi
            ;;
        install)
            printf '%s\n' "$argument" > "$state_dir/runtime"
            ;;
        alias)
            [ "$argument" = "default" ] || return 1
            printf '%s\n' "${3:-}" > "$state_dir/default"
            ;;
        use)
            [ "$argument" = "$runtime" ] || return 1
            NVM_BIN="$NVM_DIR/versions/node/v${argument}/bin"
            export NVM_BIN
            ;;
        *)
            return 1
            ;;
    esac
}
