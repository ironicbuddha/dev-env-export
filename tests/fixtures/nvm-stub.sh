#!/bin/bash

nvm() {
    if [ "${1:-}" = "use" ] && [ "${2:-}" = "24.18.0" ]; then
        NVM_BIN="$TEST_FAKE_NODE_BIN"
        export NVM_BIN
        return 0
    fi

    return 1
}
