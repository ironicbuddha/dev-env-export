#!/bin/bash

if [ "$1" = "-n" ] && [ "$2" = "hw.optional.arm64" ]; then
    echo "${TEST_HW_OPTIONAL_ARM64:-0}"
else
    /usr/sbin/sysctl "$@"
fi
