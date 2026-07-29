#!/bin/bash
# Coordinates one mutating bootstrap run for one user.

BOOTSTRAP_COORDINATOR_LOG_PARENT=""
BOOTSTRAP_COORDINATOR_RUN_DIR=""
BOOTSTRAP_COORDINATOR_RUN_ID=""
BOOTSTRAP_COORDINATOR_LOCK_DIR=""
BOOTSTRAP_COORDINATOR_LOCK_HELD=0
BOOTSTRAP_COORDINATOR_STALE_LOCK_ARCHIVE=""
BOOTSTRAP_COORDINATOR_STALE_RUN_DIR=""
BOOTSTRAP_COORDINATOR_CHILD_PID=""
BOOTSTRAP_COORDINATOR_CHILD_PGID=""

bootstrap_coordinator_configure() {
    BOOTSTRAP_COORDINATOR_LOG_PARENT="$1"
    BOOTSTRAP_COORDINATOR_RUN_DIR="$2"
    BOOTSTRAP_COORDINATOR_RUN_ID="$3"
    BOOTSTRAP_COORDINATOR_LOCK_DIR="$BOOTSTRAP_COORDINATOR_LOG_PARENT/bootstrap-mutation.lock"
    BOOTSTRAP_COORDINATOR_LOCK_HELD=0
    BOOTSTRAP_COORDINATOR_STALE_LOCK_ARCHIVE=""
    BOOTSTRAP_COORDINATOR_STALE_RUN_DIR=""
    BOOTSTRAP_COORDINATOR_CHILD_PID=""
    BOOTSTRAP_COORDINATOR_CHILD_PGID=""
}

bootstrap_coordinator_write_lock_owner() {
    local owner_file="$BOOTSTRAP_COORDINATOR_LOCK_DIR/owner.txt"
    local staging_file="$BOOTSTRAP_COORDINATOR_LOCK_DIR/.owner.XXXXXX"

    staging_file="$(mktemp "$staging_file")" || return 1
    {
        echo "pid=$$"
        echo "run_id=$BOOTSTRAP_COORDINATOR_RUN_ID"
        echo "run_dir=$BOOTSTRAP_COORDINATOR_RUN_DIR"
        echo "started_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    } > "$staging_file" || {
        rm -f "$staging_file"
        return 1
    }
    chmod 0600 "$staging_file" || {
        rm -f "$staging_file"
        return 1
    }
    mv -f "$staging_file" "$owner_file"
}

bootstrap_coordinator_lock_value() {
    local key="$1"
    local owner_file="$BOOTSTRAP_COORDINATOR_LOCK_DIR/owner.txt"

    [ -f "$owner_file" ] || return 1
    sed -n "s/^${key}=//p" "$owner_file" | head -n 1
}

bootstrap_coordinator_archive_stale_lock() {
    local timestamp=""
    local archive_dir=""

    timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
    archive_dir="$BOOTSTRAP_COORDINATOR_LOG_PARENT/stale-bootstrap-lock-${timestamp}-${BOOTSTRAP_COORDINATOR_RUN_ID}"
    mv "$BOOTSTRAP_COORDINATOR_LOCK_DIR" "$archive_dir" || return 1
    BOOTSTRAP_COORDINATOR_STALE_LOCK_ARCHIVE="$archive_dir"
}

bootstrap_coordinator_acquire_lock() {
    local owner_pid=""
    local owner_run_dir=""
    local attempts=0

    mkdir -p "$BOOTSTRAP_COORDINATOR_LOG_PARENT" || return 1
    while [ "$attempts" -lt 2 ]; do
        if mkdir "$BOOTSTRAP_COORDINATOR_LOCK_DIR" 2>/dev/null; then
            bootstrap_coordinator_write_lock_owner || {
                rmdir "$BOOTSTRAP_COORDINATOR_LOCK_DIR" 2>/dev/null || true
                return 1
            }
            BOOTSTRAP_COORDINATOR_LOCK_HELD=1
            return 0
        fi

        owner_pid="$(bootstrap_coordinator_lock_value pid 2>/dev/null || true)"
        case "$owner_pid" in
            ''|*[!0-9]*)
                printf 'ERROR: Bootstrap lock has no verifiable owner pid: %s\n' \
                    "$BOOTSTRAP_COORDINATOR_LOCK_DIR" >&2
                return 76
                ;;
        esac
        if [ -n "$owner_pid" ] && kill -0 "$owner_pid" 2>/dev/null; then
            printf 'ERROR: Bootstrap run already active (pid=%s, lock=%s).\n' \
                "$owner_pid" "$BOOTSTRAP_COORDINATOR_LOCK_DIR" >&2
            return 75
        fi

        owner_run_dir="$(bootstrap_coordinator_lock_value run_dir 2>/dev/null || true)"
        bootstrap_coordinator_archive_stale_lock || return 76
        BOOTSTRAP_COORDINATOR_STALE_RUN_DIR="$owner_run_dir"
        attempts=$((attempts + 1))
    done

    return 76
}

bootstrap_coordinator_prior_run_is_incomplete() {
    [ -n "$BOOTSTRAP_COORDINATOR_STALE_RUN_DIR" ] || return 1
    [ -f "$BOOTSTRAP_COORDINATOR_STALE_RUN_DIR/current-state.txt" ] || return 1
    grep -Fqx "outcome=interrupted_incomplete" \
        "$BOOTSTRAP_COORDINATOR_STALE_RUN_DIR/current-state.txt"
}

bootstrap_coordinator_release_lock_after_finalization() {
    local state_file="$1"

    [ "$BOOTSTRAP_COORDINATOR_LOCK_HELD" -eq 1 ] || return 0
    [ -f "$state_file" ] || return 1
    grep -Eq '^outcome=(completed|completed_with_warnings|manual_action_required|required_failure|logging_failure|interrupted)$' "$state_file" ||
        return 1
    grep -Eq '^ended_at=[^n].*$' "$state_file" || return 1

    rm -f "$BOOTSTRAP_COORDINATOR_LOCK_DIR/owner.txt" || return 1
    rmdir "$BOOTSTRAP_COORDINATOR_LOCK_DIR" || return 1
    BOOTSTRAP_COORDINATOR_LOCK_HELD=0
}

bootstrap_coordinator_run_logged_child() {
    local step_log="$1"
    local status_file="$2"
    local monitor_state=""
    local child_status=0

    shift 2
    monitor_state="$(set -o | awk '$1 == "monitor" { print $2 }')"
    set -m
    (
        local pipe_status=()

        set -o pipefail
        "$@" 2>&1 | tee -a "$step_log"
        pipe_status=("${PIPESTATUS[@]}")
        printf '%s\t%s\n' "${pipe_status[0]:-1}" "${pipe_status[1]:-1}" > "$status_file"
        if [ "${pipe_status[1]:-1}" -ne 0 ]; then
            exit "${pipe_status[1]}"
        fi
        exit "${pipe_status[0]:-1}"
    ) &
    BOOTSTRAP_COORDINATOR_CHILD_PID=$!
    BOOTSTRAP_COORDINATOR_CHILD_PGID="$(ps -o pgid= -p "$BOOTSTRAP_COORDINATOR_CHILD_PID" | tr -d ' ')"
    if [ "$monitor_state" != "on" ]; then
        set +m
    fi
    if [ "$BOOTSTRAP_COORDINATOR_CHILD_PGID" != "$BOOTSTRAP_COORDINATOR_CHILD_PID" ]; then
        printf 'ERROR: Bootstrap child did not receive an isolated process group.\n' >&2
        kill -TERM "$BOOTSTRAP_COORDINATOR_CHILD_PID" 2>/dev/null || true
        wait "$BOOTSTRAP_COORDINATOR_CHILD_PID" 2>/dev/null || true
        BOOTSTRAP_COORDINATOR_CHILD_PID=""
        BOOTSTRAP_COORDINATOR_CHILD_PGID=""
        return 70
    fi

    if wait "$BOOTSTRAP_COORDINATOR_CHILD_PID"; then
        child_status=0
    else
        child_status=$?
    fi
    BOOTSTRAP_COORDINATOR_CHILD_PID=""
    BOOTSTRAP_COORDINATOR_CHILD_PGID=""
    return "$child_status"
}

bootstrap_coordinator_forward_signal() {
    local signal_name="$1"
    local child_status=0

    [ -n "$BOOTSTRAP_COORDINATOR_CHILD_PID" ] || return 0
    [ -n "$BOOTSTRAP_COORDINATOR_CHILD_PGID" ] || return 1
    kill -"$signal_name" -- "-$BOOTSTRAP_COORDINATOR_CHILD_PGID" 2>/dev/null || return 1
    if wait "$BOOTSTRAP_COORDINATOR_CHILD_PID"; then
        child_status=0
    else
        child_status=$?
    fi
    BOOTSTRAP_COORDINATOR_CHILD_PID=""
    BOOTSTRAP_COORDINATOR_CHILD_PGID=""
    return "$child_status"
}
