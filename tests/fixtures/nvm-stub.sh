#!/bin/bash

nvm() {
    case "${1:-}" in
        version)
            case "${2:-}" in
                24.18.0|default)
                    printf '%s\n' 'v24.18.0'
                    return 0
                    ;;
            esac
            ;;
        alias)
            if [ "${2:-}" = "default" ] && [ "${3:-}" = "24.18.0" ]; then
                return 0
            fi
            ;;
        install)
            if [ "${2:-}" = "24.18.0" ]; then
                return 0
            fi
            ;;
        use)
            if [ "${2:-}" = "24.18.0" ]; then
                NVM_BIN="$TEST_FAKE_NODE_BIN"
                export NVM_BIN
                return 0
            fi
            ;;
    esac

    return 1
}
