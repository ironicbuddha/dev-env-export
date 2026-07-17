#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Darwin"
else
    /usr/bin/uname "$@"
fi
