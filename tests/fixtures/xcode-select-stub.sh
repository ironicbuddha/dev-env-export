#!/bin/bash

echo "xcode-select $*" >> "$TEST_ACTION_LOG"

case "${1:-}" in
    -p)
        if [ "${TEST_CLT_STATE:-usable}" = "usable" ] || [ "${TEST_CLT_STATE:-usable}" = "broken" ]; then
            echo "/Library/Developer/CommandLineTools"
            exit 0
        fi
        exit 1
        ;;
    --install)
        exit 0
        ;;
esac

exit 2
