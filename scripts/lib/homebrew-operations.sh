#!/bin/bash
# Inspect-first Homebrew formula and cask adapters.

HOME_BREW_OPERATIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HOME_BREW_OPERATIONS_DIR/operation-policy.sh"

bootstrap_homebrew_formula_present() { brew list --formula "$1" >/dev/null 2>&1; }

bootstrap_homebrew_prefix_exists() {
    local kind="$1" target="$2" prefix=""
    prefix="$(brew --prefix "--$kind" "$target" 2>/dev/null)" || return 1
    [ -n "$prefix" ] && { [ -e "$prefix" ] || [ -L "$prefix" ]; }
}

bootstrap_homebrew_classify_failure() {
    local output_file="$1"
    if grep -Eqi 'Homebrew curl configuration requires manual timeout policy' "$output_file"; then
        printf '%s\n' manual_action
    elif grep -Eqi 'connection reset|timed? ?out|temporary failure|could not resolve|network is unreachable|http (408|425|429)|http 5[0-9][0-9]' "$output_file"; then
        printf '%s\n' transient_external
    elif grep -Eqi 'checksum|sha-?256|signature|digest|integrity' "$output_file"; then
        printf '%s\n' integrity_failure
    elif grep -Eqi 'partial|incomplete|corrupt' "$output_file"; then
        printf '%s\n' managed_state_invalid
    elif grep -Eqi 'permission denied|operation not permitted|read-only file system|no space left' "$output_file"; then
        printf '%s\n' local_precondition
    elif grep -Eqi 'http 4[0-9][0-9]|forbidden|not found|unauthorized' "$output_file"; then
        printf '%s\n' internal_failure
    elif grep -Eqi 'password|interactive|press return|sudo' "$output_file"; then
        printf '%s\n' manual_action
    else
        printf '%s\n' internal_failure
    fi
}

bootstrap_homebrew_failure_recovery() {
    case "$1" in
        transient_external) printf '%s\n' retry_operation;;
        manual_action) printf '%s\n' manual_then_retry;;
        *) printf '%s\n' do_not_retry;;
    esac
}

bootstrap_homebrew_failure_code() {
    local output_file="$1"
    if grep -Eqi 'Homebrew curl configuration requires manual timeout policy' "$output_file"; then
        printf '%s\n' homebrew_curl_policy_conflict
    elif grep -Eqi 'retry-after' "$output_file"; then
        printf '%s\n' http_retry_after
    elif grep -Eqi 'http (408|425|429)|http 5[0-9][0-9]' "$output_file"; then
        printf '%s\n' eligible_http_transient
    elif grep -Eqi 'http 4[0-9][0-9]|forbidden|not found|unauthorized' "$output_file"; then
        printf '%s\n' permanent_http_failure
    elif grep -Eqi 'connection reset' "$output_file"; then
        printf '%s\n' connection_reset
    elif grep -Eqi 'timed? ?out|temporary failure|could not resolve|network is unreachable|http 408|http 429|http 5[0-9][0-9]' "$output_file"; then
        printf '%s\n' transient_network_failure
    elif grep -Eqi 'checksum|sha-?256|signature|digest|integrity' "$output_file"; then
        printf '%s\n' integrity_failure
    elif grep -Eqi 'permission denied|operation not permitted|read-only file system|no space left' "$output_file"; then
        printf '%s\n' permission_denied
    elif grep -Eqi 'password|interactive|press return|sudo' "$output_file"; then
        printf '%s\n' interactive_vendor_action
    elif grep -Eqi 'partial|incomplete|corrupt' "$output_file"; then
        printf '%s\n' partial_vendor_state
    else
        printf '%s\n' ambiguous_vendor_state
    fi
}

bootstrap_homebrew_mutate() {
    local operation="$1" target="$2" inspection_function="$3" retry_safety_function="$4"
    shift 4
    local output_file status failure_class failure_code recovery
    output_file="$(mktemp "${TMPDIR:-/tmp}/dev-env-homebrew-operation.XXXXXX")" || return 1
    bootstrap_operation_record operation_start changed none operation_started 0 none "$operation" "$target" "Homebrew operation started."
    if bootstrap_operation_run_homebrew_mutation "$output_file" "$operation" "$target" "$@"; then
        cat "$output_file"; rm -f "$output_file"
        if ! "$inspection_function" "$target"; then
            bootstrap_operation_record operation_end required_failure managed_state_invalid post_operation_verify_failed 1 resolve_conflict "$operation" "$target" "Homebrew command succeeded but the required target is not usable."
            return 1
        fi
        bootstrap_operation_record operation_end changed none operation_completed 0 none "$operation" "$target" "Homebrew operation completed and verified."
        return 0
    else
        status=$?
    fi
    cat "$output_file" >&2
    if "$inspection_function" "$target"; then
        rm -f "$output_file"
        bootstrap_operation_record operation_end satisfied none operation_completed_after_probe "$status" none "$operation" "$target" "Homebrew reported failure but post-operation inspection is satisfied."
        return 0
    fi
    failure_class="$(bootstrap_homebrew_classify_failure "$output_file")"
    failure_code="$(bootstrap_homebrew_failure_code "$output_file")"
    recovery="$(bootstrap_homebrew_failure_recovery "$failure_class")"
    if [ "$failure_class" = transient_external ] && "$retry_safety_function" "$target"; then
        bootstrap_operation_record operation_retry changed "$failure_class" transient_retry_safe "$status" retry_operation "$operation" "$target" "Post-failure inspection proved the target absent; retrying once."
        bootstrap_operation_retry_delay
        : > "$output_file"
        if bootstrap_operation_run_homebrew_mutation "$output_file" "$operation" "$target" "$@"; then
            cat "$output_file"; rm -f "$output_file"
            if ! "$inspection_function" "$target"; then
                bootstrap_operation_record operation_end required_failure managed_state_invalid post_retry_verify_failed 1 resolve_conflict "$operation" "$target" "Retried Homebrew command succeeded but the required target is not usable."
                return 1
            fi
            bootstrap_operation_record operation_end changed none operation_completed_after_retry 0 none "$operation" "$target" "One safe retry completed and verified."
            return 0
        else
            status=$?
        fi
        cat "$output_file" >&2
        failure_class="$(bootstrap_homebrew_classify_failure "$output_file")"
        failure_code="$(bootstrap_homebrew_failure_code "$output_file")"
        recovery="$(bootstrap_homebrew_failure_recovery "$failure_class")"
    elif [ "$failure_class" = transient_external ]; then
        failure_class=managed_state_invalid
        failure_code=ambiguous_post_failure_state
        recovery=resolve_conflict
    fi
    rm -f "$output_file"
    if [ "$failure_class" = manual_action ]; then
        bootstrap_operation_record operation_end manual_action "$failure_class" "$failure_code" "$status" "$recovery" "$operation" "$target" "Homebrew operation requires manual action before retrying."
    else
        bootstrap_operation_record operation_end required_failure "$failure_class" "$failure_code" "$status" "$recovery" "$operation" "$target" "Homebrew operation failed; no further automatic retry is safe."
    fi
    return "$status"
}

bootstrap_homebrew_ensure_formula() {
    local formula="$1"
    if bootstrap_homebrew_formula_present "$formula"; then
        echo "  [SKIP] $formula is already installed"
        bootstrap_operation_record operation_end satisfied none formula_present 0 none formula_ensure "$formula" "Installed formula is usable."
        return 0
    fi
    echo "  [INSTALL] Installing $formula..."
    bootstrap_homebrew_mutate formula_install "$formula" bootstrap_homebrew_formula_present \
        bootstrap_homebrew_formula_retry_safe brew install "$formula"
}

bootstrap_homebrew_formula_retry_safe() {
    ! brew list --formula "$1" >/dev/null 2>&1 &&
        ! bootstrap_homebrew_prefix_exists formula "$1"
}

bootstrap_homebrew_refresh_metadata() {
    local output_file status=0 attempt=1 failure_class="" failure_code=""

    if [ "${DEV_ENV_REFRESH_BREW:-0}" != 1 ]; then
        echo "  [SKIP] brew update (set DEV_ENV_REFRESH_BREW=1 to refresh formulas)"
        return 0
    fi
    echo "Refreshing Homebrew metadata because DEV_ENV_REFRESH_BREW=1..."
    output_file="$(mktemp "${TMPDIR:-/tmp}/dev-env-homebrew-metadata.XXXXXX")" || return 1
    bootstrap_operation_record operation_start changed none operation_started 0 none brew_metadata_refresh metadata "Homebrew metadata refresh started."
    while [ "$attempt" -le 3 ]; do
        if bootstrap_operation_run_homebrew_metadata "$output_file" brew_metadata_refresh metadata brew update; then
            cat "$output_file"; rm -f "$output_file"
            bootstrap_operation_record operation_end changed none metadata_refreshed 0 none brew_metadata_refresh metadata "Requested Homebrew metadata refresh completed."
            return 0
        else
            status=$?
        fi
        cat "$output_file" >&2
        failure_class="$(bootstrap_homebrew_classify_failure "$output_file")"
        failure_code="$(bootstrap_homebrew_failure_code "$output_file")"
        [ "$failure_class" = transient_external ] || break
        [ "$attempt" -lt 3 ] || break
        bootstrap_operation_record operation_retry changed "$failure_class" metadata_retry "$status" retry_operation brew_metadata_refresh metadata "Retrying read-only metadata refresh."
        if [ "$attempt" -eq 1 ]; then
            bootstrap_operation_retry_delay 2
        else
            bootstrap_operation_retry_delay 8
        fi
        attempt=$((attempt + 1))
        : > "$output_file"
    done
    rm -f "$output_file"
    if [ "$failure_class" = manual_action ]; then
        bootstrap_operation_record operation_end manual_action "$failure_class" "$failure_code" "$status" "$(bootstrap_homebrew_failure_recovery "$failure_class")" brew_metadata_refresh metadata "Homebrew metadata refresh requires manual action before retrying."
    else
        bootstrap_operation_record operation_end required_failure "$failure_class" "$failure_code" "$status" "$(bootstrap_homebrew_failure_recovery "$failure_class")" brew_metadata_refresh metadata "Homebrew metadata refresh failed."
    fi
    return "$status"
}

bootstrap_homebrew_ensure_cask() {
    local app="$1" cask_action=install
    if bootstrap_cask_install_satisfied "$app"; then
        echo "  [SKIP] $app is installed and usable"
        bootstrap_operation_record operation_end satisfied none cask_present 0 none cask_ensure "$app" "Installed cask app is usable."
        return 0
    fi
    if brew list --cask "$app" >/dev/null 2>&1; then
        if ! bootstrap_homebrew_cask_repair_owned "$app"; then
            bootstrap_operation_record operation_end required_failure foreign_state_conflict \
                cask_repair_ownership_unproven 1 resolve_conflict cask_repair "$app" \
                "Registered cask has an unusable app bundle, but Homebrew ownership evidence is insufficient for repair."
            return 1
        fi
        cask_action=reinstall
        echo "  [REPAIR] $app is registered but its app bundle is unusable"
    fi
    if [ "$app" = docker ]; then
        bootstrap_homebrew_mutate cask_repair "$app" bootstrap_cask_install_satisfied \
            bootstrap_homebrew_cask_retry_safe brew "$cask_action" --cask --no-binaries "$app"
    else
        bootstrap_homebrew_mutate cask_install "$app" bootstrap_cask_install_satisfied \
            bootstrap_homebrew_cask_retry_safe brew "$cask_action" --cask "$app"
    fi
}

bootstrap_homebrew_cask_retry_safe() {
    ! brew list --cask "$1" >/dev/null 2>&1 &&
        ! bootstrap_homebrew_prefix_exists cask "$1" &&
        ! bootstrap_cask_any_app_bundle_present "$1"
}

bootstrap_homebrew_cask_repair_owned() {
    local app="$1" prefix=""
    prefix="$(brew --prefix --cask "$app" 2>/dev/null)" || return 1
    [ -d "$prefix" ] && [ ! -L "$prefix" ] &&
        find "$prefix" -maxdepth 3 -type f -name INSTALL_RECEIPT.json -print -quit 2>/dev/null | grep -q .
}
