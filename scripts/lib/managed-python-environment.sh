#!/bin/bash
# Convergent adapter for the bootstrap-owned Python environment.

BOOTSTRAP_MANAGED_PYTHON_SCHEMA_VERSION="1"
BOOTSTRAP_MANAGED_PYTHON_OWNER_FILE=".dev-env-bootstrap-owner"

bootstrap_managed_python_manifest_value() {
    local manifest_path="$1"
    local wanted_key="$2"
    local key=""
    local value=""

    while IFS='=' read -r key value; do
        if [ "$key" = "$wanted_key" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    done < "$manifest_path"

    return 1
}

bootstrap_managed_python_version() {
    local python_bin="$1"
    local version_output=""

    version_output="$("$python_bin" --version 2>&1)" || return 1
    case "$version_output" in
        "Python "*)
            printf '%s\n' "${version_output#Python }"
            ;;
        *)
            return 1
            ;;
    esac
}

bootstrap_managed_python_major_minor() {
    local version="$1"
    local major=""
    local remainder=""
    local minor=""

    major="${version%%.*}"
    remainder="${version#*.}"
    minor="${remainder%%.*}"
    [ -n "$major" ] && [ -n "$minor" ] || return 1
    printf '%s.%s\n' "$major" "$minor"
}

bootstrap_managed_python_write_manifest() {
    local environment_dir="$1"
    local recorded_environment_path="$2"
    local python_bin="$3"
    local python_version="$4"
    local profile="$5"
    local source_id="$6"
    local run_id="$7"
    local package_status="$8"
    local applied_packages="$9"
    local manifest_path="$environment_dir/$BOOTSTRAP_MANAGED_PYTHON_OWNER_FILE"
    local candidate_path="$manifest_path.tmp.$run_id.$$"
    local creation_python_bin="$python_bin"
    local creation_python_version="$python_version"
    local creation_profile="$profile"
    local creation_source_id="$source_id"
    local creation_run_id="$run_id"

    if [ -f "$manifest_path" ] && [ ! -L "$manifest_path" ]; then
        creation_python_bin="$(
            bootstrap_managed_python_manifest_value \
                "$manifest_path" interpreter_source || printf '%s\n' "$python_bin"
        )"
        creation_python_version="$(
            bootstrap_managed_python_manifest_value \
                "$manifest_path" interpreter_version || printf '%s\n' "$python_version"
        )"
        creation_profile="$(
            bootstrap_managed_python_manifest_value \
                "$manifest_path" bootstrap_profile || printf '%s\n' "$profile"
        )"
        creation_source_id="$(
            bootstrap_managed_python_manifest_value \
                "$manifest_path" source_id || printf '%s\n' "$source_id"
        )"
        creation_run_id="$(
            bootstrap_managed_python_manifest_value \
                "$manifest_path" created_run_id || printf '%s\n' "$run_id"
        )"
    fi

    {
        printf 'owner=dev-env-bootstrap\n'
        printf 'schema_version=%s\n' "$BOOTSTRAP_MANAGED_PYTHON_SCHEMA_VERSION"
        printf 'environment_path=%s\n' "$recorded_environment_path"
        printf 'interpreter_policy=3.14\n'
        printf 'interpreter_source=%s\n' "$creation_python_bin"
        printf 'interpreter_version=%s\n' "$creation_python_version"
        printf 'bootstrap_profile=%s\n' "$creation_profile"
        printf 'source_id=%s\n' "$creation_source_id"
        printf 'created_run_id=%s\n' "$creation_run_id"
        printf 'last_applied_profile=%s\n' "$profile"
        printf 'last_applied_source_id=%s\n' "$source_id"
        printf 'last_applied_run_id=%s\n' "$run_id"
        printf 'package_status=%s\n' "$package_status"
        printf 'last_applied_packages=%s\n' "$applied_packages"
    } > "$candidate_path" || return 1

    mv "$candidate_path" "$manifest_path"
}

bootstrap_managed_python_validate_owned_environment() {
    local environment_dir="$1"
    local recorded_environment_path="$2"
    local desired_python_bin="$3"
    local manifest_path="$environment_dir/$BOOTSTRAP_MANAGED_PYTHON_OWNER_FILE"
    local desired_version=""
    local actual_version=""
    local desired_major_minor=""
    local actual_major_minor=""
    local configured_home=""
    local configured_version=""
    local configured_major_minor=""

    bootstrap_managed_python_manifest_proves_ownership \
        "$environment_dir" "$recorded_environment_path" || return 1
    [ -f "$environment_dir/pyvenv.cfg" ] && [ ! -L "$environment_dir/pyvenv.cfg" ] || return 1
    [ -x "$environment_dir/bin/python" ] || return 1

    desired_version="$(bootstrap_managed_python_version "$desired_python_bin")" || return 1
    actual_version="$(bootstrap_managed_python_version "$environment_dir/bin/python")" || return 1
    desired_major_minor="$(bootstrap_managed_python_major_minor "$desired_version")" || return 1
    actual_major_minor="$(bootstrap_managed_python_major_minor "$actual_version")" || return 1
    configured_home="$(
        sed -n 's/^home[[:space:]]*=[[:space:]]*//p' \
            "$environment_dir/pyvenv.cfg" | head -1
    )"
    configured_version="$(
        sed -n \
            -e 's/^version[[:space:]]*=[[:space:]]*//p' \
            -e 's/^version_info[[:space:]]*=[[:space:]]*//p' \
            "$environment_dir/pyvenv.cfg" | head -1
    )"
    configured_major_minor="$(
        bootstrap_managed_python_major_minor "$configured_version"
    )" || return 1

    [ "$desired_major_minor" = "3.14" ] || return 1
    [ "$actual_major_minor" = "$desired_major_minor" ] || return 1
    [ -n "$configured_home" ] || return 1
    [ "$configured_major_minor" = "$actual_major_minor" ] || return 1
}

bootstrap_managed_python_manifest_proves_ownership() {
    local environment_dir="$1"
    local recorded_environment_path="$2"
    local manifest_path="$environment_dir/$BOOTSTRAP_MANAGED_PYTHON_OWNER_FILE"
    local owner=""
    local schema_version=""
    local manifest_environment_path=""
    local interpreter_policy=""
    local interpreter_source=""
    local interpreter_version=""
    local bootstrap_profile=""
    local source_id=""
    local created_run_id=""

    [ -f "$manifest_path" ] && [ ! -L "$manifest_path" ] || return 1
    owner="$(bootstrap_managed_python_manifest_value "$manifest_path" owner || true)"
    schema_version="$(bootstrap_managed_python_manifest_value "$manifest_path" schema_version || true)"
    manifest_environment_path="$(bootstrap_managed_python_manifest_value "$manifest_path" environment_path || true)"
    interpreter_policy="$(bootstrap_managed_python_manifest_value "$manifest_path" interpreter_policy || true)"
    interpreter_source="$(
        bootstrap_managed_python_manifest_value "$manifest_path" interpreter_source || true
    )"
    interpreter_version="$(
        bootstrap_managed_python_manifest_value "$manifest_path" interpreter_version || true
    )"
    bootstrap_profile="$(
        bootstrap_managed_python_manifest_value "$manifest_path" bootstrap_profile || true
    )"
    source_id="$(
        bootstrap_managed_python_manifest_value "$manifest_path" source_id || true
    )"
    created_run_id="$(
        bootstrap_managed_python_manifest_value "$manifest_path" created_run_id || true
    )"

    [ "$owner" = "dev-env-bootstrap" ] || return 1
    [ "$schema_version" = "$BOOTSTRAP_MANAGED_PYTHON_SCHEMA_VERSION" ] || return 1
    [ "$manifest_environment_path" = "$recorded_environment_path" ] || return 1
    [ "$interpreter_policy" = "3.14" ] || return 1
    [ -n "$interpreter_source" ] || return 1
    [ -n "$interpreter_version" ] || return 1
    [ -n "$bootstrap_profile" ] || return 1
    [ -n "$source_id" ] || return 1
    [ -n "$created_run_id" ] || return 1
}

bootstrap_managed_python_environment_state() {
    local environment_dir="$1"
    local desired_python_bin="$2"
    local manifest_path="$environment_dir/$BOOTSTRAP_MANAGED_PYTHON_OWNER_FILE"
    local recorded_python_bin=""
    local recorded_python_version=""
    local desired_python_version=""
    local desired_python_major_minor=""
    local actual_python_version=""

    recorded_python_bin="$(
        bootstrap_managed_python_manifest_value "$manifest_path" interpreter_source || true
    )"
    recorded_python_version="$(
        bootstrap_managed_python_manifest_value "$manifest_path" interpreter_version || true
    )"
    desired_python_version="$(bootstrap_managed_python_version "$desired_python_bin")" || return 1
    actual_python_version="$(
        bootstrap_managed_python_version "$environment_dir/bin/python"
    )" || return 1

    if [ "$recorded_python_bin" = "$desired_python_bin" ] &&
            [ "$recorded_python_version" = "$desired_python_version" ] &&
            [ "$actual_python_version" = "$desired_python_version" ]; then
        printf '%s\n' "valid_exact"
    else
        printf '%s\n' "valid_compatible"
    fi
}

bootstrap_managed_python_cleanup_owned_staging() {
    local environment_dir="$1"
    local staging_candidate=""
    local staging_marker=""

    for staging_candidate in "$environment_dir.staging."*; do
        if [ ! -e "$staging_candidate" ] && [ ! -L "$staging_candidate" ]; then
            continue
        fi
        case "$staging_candidate" in
            "$environment_dir.staging."*)
                ;;
            *)
                continue
                ;;
        esac
        if [ -L "$staging_candidate" ] || [ ! -d "$staging_candidate" ]; then
            continue
        fi
        if [ ! -f "$staging_candidate/.dev-env-bootstrap-staging" ] ||
                [ -L "$staging_candidate/.dev-env-bootstrap-staging" ]; then
            continue
        fi
        staging_marker="$(
            cat "$staging_candidate/.dev-env-bootstrap-staging" 2>/dev/null || true
        )"
        if [ "$staging_marker" != "$environment_dir" ]; then
            continue
        fi

        printf 'state=interrupted disposition=changed action=remove_owned_staging path=%s\n' \
            "$staging_candidate"
        if ! rm -rf "$staging_candidate"; then
            return 1
        fi
    done
}

bootstrap_managed_python_join_packages() {
    local separator=""
    local package=""

    for package in "$@"; do
        printf '%s%s' "$separator" "$package"
        separator=","
    done
    printf '\n'
}

bootstrap_managed_python_package_name() {
    local package_spec="$1"

    case "$package_spec" in
        *==*)
            printf '%s\n' "${package_spec%%==*}"
            ;;
        *)
            printf '%s\n' "$package_spec"
            ;;
    esac
}

bootstrap_managed_python_package_satisfied() {
    local environment_python="$1"
    local package_spec="$2"
    local package_name=""
    local expected_version=""
    local show_output=""
    local installed_version=""

    package_name="$(bootstrap_managed_python_package_name "$package_spec")"
    show_output="$(uv pip show --python "$environment_python" "$package_name" 2>/dev/null)" || return 1

    case "$package_spec" in
        *==*)
            expected_version="${package_spec#*==}"
            installed_version="$(printf '%s\n' "$show_output" | sed -n 's/^Version:[[:space:]]*//p' | head -1)"
            [ "$installed_version" = "$expected_version" ]
            ;;
        *)
            return 0
            ;;
    esac
}

bootstrap_managed_python_ensure() {
    local desired_python_bin="$1"
    local environment_dir="$2"
    local profile="$3"
    local source_id="$4"
    local run_id="$5"
    shift 5
    local packages=("$@")
    local manifest_path="$environment_dir/$BOOTSTRAP_MANAGED_PYTHON_OWNER_FILE"
    local desired_python_version=""
    local staging_dir=""
    local quarantine_dir=""
    local package_spec=""
    local package_name=""
    local applied_packages=""
    local created_environment=0
    local package_changed=0
    local environment_state="absent"
    local package_index=0
    local report_index=0
    local installed_packages=()
    local missing_packages=()
    local uncertain_packages=()
    local prior_applied_packages=""
    local recorded_package_status=""
    local recorded_applied_packages=""
    local manifest_changed=0

    bootstrap_managed_python_cleanup_owned_staging "$environment_dir" || {
        printf 'failure_class=local_precondition\ncode=managed_python_staging_cleanup_failed\npath=%s\nrecovery=manual_then_retry\n' \
            "$environment_dir" >&2
        return 1
    }

    if [ -L "$environment_dir" ]; then
        printf 'failure_class=foreign_state_conflict\ncode=managed_python_target_symlink\npath=%s\nrecovery=resolve_conflict\n' \
            "$environment_dir" >&2
        return 1
    fi
    if [ -e "$environment_dir" ] && [ ! -d "$environment_dir" ]; then
        printf 'failure_class=foreign_state_conflict\ncode=managed_python_target_not_directory\npath=%s\nrecovery=resolve_conflict\n' \
            "$environment_dir" >&2
        return 1
    fi

    desired_python_version="$(bootstrap_managed_python_version "$desired_python_bin")" || {
        printf 'failure_class=local_precondition\ncode=managed_python_interpreter_unusable\npath=%s\n' \
            "$desired_python_bin" >&2
        return 1
    }
    desired_python_major_minor="$(
        bootstrap_managed_python_major_minor "$desired_python_version"
    )" || {
        printf 'failure_class=local_precondition\ncode=managed_python_interpreter_version_invalid\npath=%s\n' \
            "$desired_python_bin" >&2
        return 1
    }
    if [ "$desired_python_major_minor" != "3.14" ]; then
        printf 'failure_class=local_precondition\ncode=managed_python_interpreter_out_of_policy\nexpected=3.14\nactual=%s\npath=%s\nrecovery=do_not_retry\n' \
            "$desired_python_major_minor" "$desired_python_bin" >&2
        return 1
    fi

    if [ -d "$environment_dir" ]; then
        if [ ! -e "$manifest_path" ] && [ ! -L "$manifest_path" ]; then
            printf 'failure_class=foreign_state_conflict\ncode=managed_python_environment_unmarked\npath=%s\nrecovery=resolve_conflict\n' \
                "$environment_dir" >&2
            return 1
        fi
        if ! bootstrap_managed_python_manifest_proves_ownership \
                "$environment_dir" "$environment_dir"; then
            printf 'state=unknown disposition=required_failure\nfailure_class=integrity_failure\ncode=managed_python_ownership_manifest_invalid\npath=%s\nrecovery=manual_then_retry\n' \
                "$environment_dir" >&2
            return 1
        fi
        if ! bootstrap_managed_python_validate_owned_environment \
                "$environment_dir" "$environment_dir" "$desired_python_bin"; then
            quarantine_dir="$environment_dir.quarantine.$run_id.$$"
            if [ -e "$quarantine_dir" ] || [ -L "$quarantine_dir" ]; then
                printf 'failure_class=internal_failure\ncode=managed_python_quarantine_collision\npath=%s\n' \
                    "$quarantine_dir" >&2
                return 1
            fi
            printf 'state=managed_invalid disposition=changed action=quarantine path=%s retained=%s\n' \
                "$environment_dir" "$quarantine_dir"
            if ! mv "$environment_dir" "$quarantine_dir"; then
                printf 'failure_class=local_precondition\ncode=managed_python_quarantine_failed\npath=%s\nrecovery=manual_then_retry\n' \
                    "$environment_dir" >&2
                return 1
            fi
        else
            environment_state="$(
                bootstrap_managed_python_environment_state \
                    "$environment_dir" "$desired_python_bin"
            )" || {
                printf 'failure_class=internal_failure\ncode=managed_python_state_classification_failed\npath=%s\n' \
                    "$environment_dir" >&2
                return 1
            }
        fi
    fi

    if [ ! -e "$environment_dir" ] && [ ! -L "$environment_dir" ]; then
        staging_dir="$environment_dir.staging.$run_id.$$"
        if [ -e "$staging_dir" ] || [ -L "$staging_dir" ]; then
            printf 'failure_class=internal_failure\ncode=managed_python_staging_collision\npath=%s\n' \
                "$staging_dir" >&2
            return 1
        fi

        printf 'Creating bootstrap-owned Python environment: %s\n' "$environment_dir"
        if ! uv venv --python "$desired_python_bin" "$staging_dir"; then
            printf 'failure_class=local_precondition\ncode=managed_python_create_failed\npath=%s\nrecovery=retry_profile\n' \
                "$staging_dir" >&2
            return 1
        fi
        if ! printf '%s\n' "$environment_dir" > \
                "$staging_dir/.dev-env-bootstrap-staging"; then
            printf 'failure_class=local_precondition\ncode=managed_python_staging_marker_write_failed\npath=%s\nrecovery=manual_then_retry\n' \
                "$staging_dir" >&2
            return 1
        fi
        if ! bootstrap_managed_python_write_manifest \
                "$staging_dir" \
                "$environment_dir" \
                "$desired_python_bin" \
                "$desired_python_version" \
                "$profile" \
                "$source_id" \
                "$run_id" \
                "pending" \
                ""; then
            printf 'failure_class=local_precondition\ncode=managed_python_manifest_write_failed\npath=%s\nrecovery=retry_profile\n' \
                "$staging_dir" >&2
            return 1
        fi
        if ! bootstrap_managed_python_validate_owned_environment \
                "$staging_dir" "$environment_dir" "$desired_python_bin"; then
            printf 'failure_class=managed_state_invalid\ncode=managed_python_staging_invalid\npath=%s\nrecovery=manual_then_retry\n' \
                "$staging_dir" >&2
            return 1
        fi
        if ! mv "$staging_dir" "$environment_dir"; then
            printf 'failure_class=local_precondition\ncode=managed_python_promote_failed\npath=%s\nrecovery=manual_then_retry\n' \
                "$staging_dir" >&2
            return 1
        fi
        created_environment=1
        environment_state="valid_exact"
    fi

    for ((package_index = 0; package_index < ${#packages[@]}; package_index++)); do
        package_spec="${packages[$package_index]}"
        package_name="$(bootstrap_managed_python_package_name "$package_spec")"
        if bootstrap_managed_python_package_satisfied \
                "$environment_dir/bin/python" "$package_spec"; then
            printf '  [SKIP] %s satisfies %s\n' "$package_name" "$package_spec"
            continue
        fi

        printf '  [INSTALL] Installing %s...\n' "$package_spec"
        if ! uv pip install --python "$environment_dir/bin/python" "$package_spec"; then
            installed_packages=()
            missing_packages=()
            uncertain_packages=()
            for ((report_index = 0; report_index <= package_index; report_index++)); do
                if bootstrap_managed_python_package_satisfied \
                        "$environment_dir/bin/python" "${packages[$report_index]}"; then
                    installed_packages+=("${packages[$report_index]}")
                else
                    missing_packages+=("${packages[$report_index]}")
                fi
            done
            for ((report_index = package_index + 1;
                    report_index < ${#packages[@]};
                    report_index++)); do
                uncertain_packages+=("${packages[$report_index]}")
            done
            prior_applied_packages="$(
                bootstrap_managed_python_manifest_value \
                    "$manifest_path" last_applied_packages || true
            )"
            bootstrap_managed_python_write_manifest \
                "$environment_dir" \
                "$environment_dir" \
                "$desired_python_bin" \
                "$desired_python_version" \
                "$profile" \
                "$source_id" \
                "$run_id" \
                "partial" \
                "$prior_applied_packages" || {
                    printf 'failure_class=local_precondition\ncode=managed_python_manifest_write_failed\npath=%s\nrecovery=manual_then_retry\n' \
                        "$environment_dir" >&2
                    return 1
                }
            printf 'failure_class=transient_external\ncode=managed_python_package_install_failed\npackage=%s\npath=%s\nrecovery=retry_profile\n' \
                "$package_spec" "$environment_dir" >&2
            printf 'installed=%s\nmissing=%s\nuncertain=%s\n' \
                "$(bootstrap_managed_python_join_packages "${installed_packages[@]}")" \
                "$(bootstrap_managed_python_join_packages "${missing_packages[@]}")" \
                "$(bootstrap_managed_python_join_packages "${uncertain_packages[@]}")" >&2
            return 1
        fi
        if ! bootstrap_managed_python_package_satisfied \
                "$environment_dir/bin/python" "$package_spec"; then
            printf 'failure_class=managed_state_invalid\ncode=managed_python_package_verify_failed\npackage=%s\npath=%s\nrecovery=retry_profile\n' \
                "$package_spec" "$environment_dir" >&2
            return 1
        fi
        package_changed=1
    done

    if [ "${#packages[@]}" -gt 0 ]; then
        applied_packages="$(
            bootstrap_managed_python_join_packages "${packages[@]}"
        )"
    else
        applied_packages=""
    fi
    recorded_package_status="$(
        bootstrap_managed_python_manifest_value \
            "$manifest_path" package_status || true
    )"
    recorded_applied_packages="$(
        bootstrap_managed_python_manifest_value \
            "$manifest_path" last_applied_packages || true
    )"
    if [ "$recorded_package_status" != "complete" ] ||
            [ "$recorded_applied_packages" != "$applied_packages" ]; then
        manifest_changed=1
    fi

    if [ "$created_environment" -eq 1 ] ||
            [ "$package_changed" -eq 1 ] ||
            [ "$manifest_changed" -eq 1 ]; then
        bootstrap_managed_python_write_manifest \
            "$environment_dir" \
            "$environment_dir" \
            "$desired_python_bin" \
            "$desired_python_version" \
            "$profile" \
            "$source_id" \
            "$run_id" \
            "complete" \
            "$applied_packages" || {
                printf 'failure_class=local_precondition\ncode=managed_python_manifest_write_failed\npath=%s\nrecovery=retry_profile\n' \
                    "$environment_dir" >&2
                return 1
            }
        printf 'state=%s disposition=changed path=%s\n' \
            "$environment_state" "$environment_dir"
    elif [ "$environment_state" = "valid_compatible" ]; then
        printf 'state=valid_compatible disposition=satisfied_compatible path=%s\n' \
            "$environment_dir"
    else
        printf 'state=valid_exact disposition=satisfied path=%s\n' \
            "$environment_dir"
    fi
}

bootstrap_managed_python_main() {
    local command_name="${1:-}"
    local python_bin=""
    local environment_dir=""
    local profile=""
    local source_id=""
    local run_id=""
    local packages=()

    if [ "$command_name" != "ensure" ]; then
        echo "Usage: managed-python-environment.sh ensure --python PATH --environment PATH --profile PROFILE --source-id ID --run-id ID [--package SPEC ...]" >&2
        return 2
    fi
    shift

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --python)
                python_bin="${2:-}"
                shift 2
                ;;
            --environment)
                environment_dir="${2:-}"
                shift 2
                ;;
            --profile)
                profile="${2:-}"
                shift 2
                ;;
            --source-id)
                source_id="${2:-}"
                shift 2
                ;;
            --run-id)
                run_id="${2:-}"
                shift 2
                ;;
            --package)
                packages+=("${2:-}")
                shift 2
                ;;
            *)
                echo "ERROR: Unknown managed-Python option: $1" >&2
                return 2
                ;;
        esac
    done

    if [ -z "$python_bin" ] || [ -z "$environment_dir" ] || [ -z "$profile" ] ||
            [ -z "$source_id" ] || [ -z "$run_id" ]; then
        echo "ERROR: managed-Python ensure requires python, environment, profile, source-id, and run-id." >&2
        return 2
    fi

    if [ "${#packages[@]}" -gt 0 ]; then
        bootstrap_managed_python_ensure \
            "$python_bin" \
            "$environment_dir" \
            "$profile" \
            "$source_id" \
            "$run_id" \
            "${packages[@]}"
    else
        bootstrap_managed_python_ensure \
            "$python_bin" \
            "$environment_dir" \
            "$profile" \
            "$source_id" \
            "$run_id"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -euo pipefail
    bootstrap_managed_python_main "$@"
fi
