#!/bin/bash
# Named, narrowly-scoped policies for externally mutating bootstrap operations.

bootstrap_operation_timestamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

bootstrap_operation_record() {
    local event_type="$1" disposition="$2" failure_class="$3" code="$4"
    local raw_status="$5" recovery="$6" operation="$7" target="$8" message="$9"
    [ -n "${BOOTSTRAP_OPERATION_EVENT_FILE:-}" ] || return 0
    local sequence=0

    sequence="$(awk -F '\t' 'NR > 1 && $1 ~ /^[0-9]+$/ && $1 > max { max = $1 } END { print max + 1 }' \
        "$BOOTSTRAP_OPERATION_EVENT_FILE" 2>/dev/null || printf '1')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$sequence" "$event_type" "$(bootstrap_operation_timestamp)" informational "$disposition" \
        "$failure_class" "$code" "${BOOTSTRAP_OPERATION_STEP:-direct-entrypoint}" \
        "$operation" "$target" "$raw_status" "$recovery" "$message" \
        "${BOOTSTRAP_OPERATION_LOG_REF:-none}" >> "$BOOTSTRAP_OPERATION_EVENT_FILE"
}

bootstrap_operation_run_once() { local output_file="$1"; shift; "$@" > "$output_file" 2>&1; }

bootstrap_operation_homebrew_curlrc() {
    local policy="$1"
    local curlrc=""

    curlrc="$(mktemp "${TMPDIR:-/tmp}/dev-env-homebrew-curlrc.XXXXXX")" || return 1
    {
        echo "connect-timeout = 15"
        case "$policy" in
            homebrew_metadata)
                echo "max-time = 120"
                ;;
            homebrew_mutation)
                echo "speed-limit = 1"
                echo "speed-time = 120"
                ;;
            *)
                rm -f "$curlrc"
                return 2
                ;;
        esac
    } > "$curlrc" || {
        rm -f "$curlrc"
        return 1
    }
    chmod 0600 "$curlrc" || {
        rm -f "$curlrc"
        return 1
    }
    printf '%s\n' "$curlrc"
}

# Homebrew has no portable command-line switch for all of these limits.  This
# policy gives Homebrew's curl subprocesses operation-scoped limits. It still
# never kills a package-manager child whose post-termination state has not been
# proven safe. Adapters own that proof and may opt into termination later.
bootstrap_operation_run_with_observation() {
    local policy="$1" output_file="$2" operation="$3" target="$4"
    shift 4
    local pid=0 started_at=0 now=0 last_heartbeat=0 heartbeat_seconds=300 curlrc="" status=0
    local existing_curlrc="${HOMEBREW_CURLRC:-}"
    local deadline_seconds=120 deadline_recorded=0

    case "${DEV_ENV_OPERATION_HEARTBEAT_SECONDS:-}" in
        '' ) ;;
        *[!0-9]* ) ;;
        * ) heartbeat_seconds="$DEV_ENV_OPERATION_HEARTBEAT_SECONDS" ;;
    esac
    case "$policy" in
        homebrew_metadata) deadline_seconds=120 ;;
        homebrew_mutation) deadline_seconds=120 ;;
        *) return 2 ;;
    esac
    case "${DEV_ENV_OPERATION_DEADLINE_SECONDS:-}" in
        '' ) ;;
        *[!0-9]*|0 ) ;;
        * ) deadline_seconds="$DEV_ENV_OPERATION_DEADLINE_SECONDS" ;;
    esac

    if [ -n "$existing_curlrc" ]; then
        printf '%s\n' \
            "Homebrew curl configuration requires manual timeout policy: preserve $existing_curlrc and add the required timeout settings before retrying." \
            > "$output_file"
        bootstrap_operation_record operation_policy manual_action manual_action \
            "${policy}_curl_timeouts_conflict" 1 manual_then_retry "$operation" "$target" \
            "Existing Homebrew curl configuration is preserved; bootstrap cannot apply required timeout policy automatically."
        return 1
    else
        curlrc="$(bootstrap_operation_homebrew_curlrc "$policy")" || return 1
        bootstrap_operation_record operation_policy satisfied none \
            "${policy}_curl_timeouts" 0 none "$operation" "$target" \
            "Homebrew curl uses a 15-second connection timeout and policy-specific 120-second transfer limit; no package-manager hard termination is enabled."
        HOMEBREW_CURLRC="$curlrc" "$@" > "$output_file" 2>&1 &
    fi
    pid=$!
    started_at="$(date +%s)"
    last_heartbeat="$started_at"

    while kill -0 "$pid" 2>/dev/null; do
        sleep 1
        now="$(date +%s)"
        if [ "$heartbeat_seconds" -gt 0 ] && [ $((now - last_heartbeat)) -ge "$heartbeat_seconds" ]; then
            bootstrap_operation_record operation_heartbeat satisfied none "${policy}_heartbeat" 0 none \
                "$operation" "$target" "Homebrew operation is still running; raw progress remains in its step log."
            last_heartbeat="$now"
        fi
        if [ "$deadline_recorded" -eq 0 ] && [ $((now - started_at)) -ge "$deadline_seconds" ]; then
            bootstrap_operation_record operation_deadline satisfied none "${policy}_deadline_observed" 0 none \
                "$operation" "$target" "Configured deadline elapsed; preserving the child because safe termination is not proven."
            deadline_recorded=1
        fi
    done
    wait "$pid"
    status=$?
    [ -n "$curlrc" ] && rm -f "$curlrc"
    return "$status"
}

bootstrap_operation_run_homebrew_metadata() {
    local output_file="$1" operation="$2" target="$3"
    shift 3
    bootstrap_operation_run_with_observation homebrew_metadata "$output_file" "$operation" "$target" "$@"
}

bootstrap_operation_run_homebrew_mutation() {
    local output_file="$1" operation="$2" target="$3"
    shift 3
    bootstrap_operation_run_with_observation homebrew_mutation "$output_file" "$operation" "$target" "$@"
}

bootstrap_operation_retry_delay() {
    local delay="${1:-${DEV_ENV_OPERATION_RETRY_DELAY:-2}}"
    case "$delay" in ''|*[!0-9]*) delay=2;; esac
    [ "$delay" -gt 0 ] && sleep "$delay"
}
