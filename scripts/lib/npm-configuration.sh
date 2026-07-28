#!/bin/bash
# Keep co-managed user npm configuration compatible with nvm.

BOOTSTRAP_NPM_CONFIGURATION_LIB_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
)"

# shellcheck disable=SC1091
source "$BOOTSTRAP_NPM_CONFIGURATION_LIB_DIR/managed-artifact.sh"

bootstrap_ensure_nvm_compatible_npm_configuration() {
    local npmrc_path="${1:-$HOME/.npmrc}"
    local backup_dir="${2:-$HOME/.dev-env-npmrc-backups}"
    local npmrc_dir=""
    local candidate_path=""

    bootstrap_managed_artifact_refuse_unsafe_target "$npmrc_path" || return 1

    if [ ! -f "$npmrc_path" ]; then
        return 0
    fi

    if ! bootstrap_npm_configuration_has_owned_assignments "$npmrc_path"; then
        return 0
    fi

    npmrc_dir="$(dirname "$npmrc_path")"
    candidate_path="$(mktemp "$npmrc_dir/.${npmrc_path##*/}.candidate.XXXXXX")" ||
        return 1
    if ! LC_ALL=C sed -E \
            '/^[[:space:]]*(prefix|globalconfig)[[:space:]]*=/d' \
            "$npmrc_path" > "$candidate_path"; then
        rm -f "$candidate_path"
        return 1
    fi

    BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL=""
    if bootstrap_managed_artifact_promote_candidate \
            "$candidate_path" \
            "$npmrc_path" \
            "$backup_dir" \
            bootstrap_npm_configuration_candidate_valid \
            bootstrap_npm_configuration_is_compatible; then
        :
    else
        return $?
    fi

    echo "  [UPDATE] Removed nvm-incompatible npm configuration assignments"
}

bootstrap_npm_configuration_has_owned_assignments() {
    local npmrc_path="$1"

    LC_ALL=C grep -Eq \
        '^[[:space:]]*(prefix|globalconfig)[[:space:]]*=' \
        "$npmrc_path"
}

bootstrap_npm_configuration_candidate_valid() {
    local candidate_path="$1"

    if ! LC_ALL=C tr -d '\000' < "$candidate_path" | cmp -s - "$candidate_path"; then
        echo "ERROR: Refusing malformed npm configuration: $candidate_path" >&2
        return 1
    fi

    if command -v npm >/dev/null 2>&1 &&
            ! npm config list --userconfig "$candidate_path" --json \
                >/dev/null 2>&1; then
        echo "ERROR: Refusing npm configuration that npm cannot parse." >&2
        return 1
    fi
}

bootstrap_npm_configuration_is_compatible() {
    local npmrc_path="$1"

    ! bootstrap_npm_configuration_has_owned_assignments "$npmrc_path"
}
