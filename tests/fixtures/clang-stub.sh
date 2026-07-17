#!/bin/bash

echo "clang $*" >> "$TEST_ACTION_LOG"

if [ "${TEST_CLT_STATE:-usable}" = "usable" ] && [ "${1:-}" = "--version" ]; then
    echo "Apple clang fixture"
    exit 0
fi

exit 1
