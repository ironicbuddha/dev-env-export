#!/bin/bash
# Integrity checks for downloaded bootstrap artifacts.

bootstrap_verify_sha256() {
    local artifact_path="$1"
    local expected_digest="$2"
    local actual_digest=""

    case "$expected_digest" in
        [0-9a-fA-F][0-9a-fA-F]*) ;;
        *) return 1 ;;
    esac

    [ "${#expected_digest}" -eq 64 ] || return 1
    actual_digest="$(shasum -a 256 "$artifact_path" | awk '{print $1}')" || return 1
    [ "$(printf '%s' "$actual_digest" | tr '[:upper:]' '[:lower:]')" = \
        "$(printf '%s' "$expected_digest" | tr '[:upper:]' '[:lower:]')" ]
}
