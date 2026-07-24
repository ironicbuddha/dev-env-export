#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Darwin"
elif [ "$1" = "-m" ] && [ -n "${TEST_UNAME_MACHINE:-}" ]; then
    echo "$TEST_UNAME_MACHINE"
else
    /usr/bin/uname "$@"
fi
