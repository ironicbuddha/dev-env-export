#!/bin/bash
# Stable bootstrap state and outcome vocabularies.

BOOTSTRAP_CONTRACT_SCHEMA_VERSION="${BOOTSTRAP_CONTRACT_SCHEMA_VERSION:-1}"

bootstrap_contract_values() {
    local dimension="${1:-}"

    case "$dimension" in
        state)
            printf '%s\n' \
                absent \
                valid_exact \
                valid_compatible \
                managed_version_drift \
                managed_invalid \
                foreign_conflict \
                unknown \
                interrupted
            ;;
        disposition)
            printf '%s\n' \
                changed \
                satisfied \
                satisfied_compatible \
                optional_skipped \
                optional_degraded \
                manual_action \
                required_failure \
                interrupted \
                logging_failure
            ;;
        failure_class)
            printf '%s\n' \
                transient_external \
                manual_action \
                local_precondition \
                managed_state_invalid \
                foreign_state_conflict \
                integrity_failure \
                interrupted \
                concurrent_run \
                internal_failure \
                optional_degraded
            ;;
        package_requirement)
            printf '%s\n' present range exact
            ;;
        gating)
            printf '%s\n' required optional
            ;;
        recovery)
            printf '%s\n' \
                retry_operation \
                retry_profile \
                manual_then_retry \
                resolve_conflict \
                do_not_retry \
                none
            ;;
        *)
            return 1
            ;;
    esac
}

bootstrap_contract_validate() {
    local dimension="${1:-}"
    local value="${2:-}"
    local known_values=""
    local known_value=""

    if ! known_values="$(bootstrap_contract_values "$dimension")"; then
        printf '%s\n' \
            "failure_class=internal_failure" \
            "code=contract_dimension_unknown" \
            "dimension=$dimension" >&2
        return 1
    fi

    for known_value in $known_values; do
        if [ "$known_value" = "$value" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    done

    printf '%s\n' \
        "failure_class=internal_failure" \
        "code=contract_value_unknown" \
        "dimension=$dimension" >&2
    return 1
}
