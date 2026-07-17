#!/bin/bash

echo "xcrun $*" >> "$TEST_ACTION_LOG"

if [ "${1:-}" = "--find" ] && [ "${2:-}" = "clang" ] && [ "${TEST_CLT_STATE:-usable}" = "usable" ]; then
    echo "$TEST_FAKE_CLANG"
    exit 0
fi

exit 1
