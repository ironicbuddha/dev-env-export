#!/bin/bash
# =============================================================================
# 00-bootstrap.sh - Run a Bootstrap Profile Sequence
# =============================================================================
# Runs the selected Bootstrap Profile for the macOS bootstrap flow.
# Returns exit 20 if a manual prerequisite such as Xcode Command Line Tools is
# still pending.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PROFILE_LIB="$SCRIPT_DIR/lib/bootstrap-profile.sh"
PREREQUISITES_LIB="$SCRIPT_DIR/lib/bootstrap-prerequisites.sh"
RUN_RECORDER_LIB="$SCRIPT_DIR/lib/bootstrap-run-recorder.sh"
RUN_COORDINATOR_LIB="$SCRIPT_DIR/lib/bootstrap-run-coordinator.sh"
MANUAL_ACTION_EXIT=20
BOOTSTRAP_PROFILE=""

# shellcheck disable=SC1090
source "$PROFILE_LIB"
# shellcheck disable=SC1090
source "$PREREQUISITES_LIB"
# shellcheck disable=SC1090
source "$RUN_RECORDER_LIB"
# shellcheck disable=SC1090
source "$RUN_COORDINATOR_LIB"

usage() {
    cat <<'EOF'
Usage: /bin/bash scripts/00-bootstrap.sh --profile PROFILE
       DEV_ENV_BOOTSTRAP_PROFILE=PROFILE /bin/bash scripts/00-bootstrap.sh

Runs the selected macOS Bootstrap Profile.

Options:
  --profile PROFILE   Required unless DEV_ENV_BOOTSTRAP_PROFILE is set
  --list-profiles     Show valid profile names and aliases
  -h, --help          Show this help

Valid profiles:
EOF
    bootstrap_print_profiles
}

PROFILE_INPUT="${DEV_ENV_BOOTSTRAP_PROFILE:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            if [ $# -lt 2 ]; then
                echo "ERROR: --profile requires a value." >&2
                usage >&2
                exit 2
            fi
            PROFILE_INPUT="${2:-}"
            shift 2
            ;;
        --profile=*)
            PROFILE_INPUT="${1#--profile=}"
            shift
            ;;
        --list-profiles)
            bootstrap_print_profiles
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ -z "$PROFILE_INPUT" ]; then
    echo "ERROR: Missing required Bootstrap Profile." >&2
    usage >&2
    exit 2
fi

if ! BOOTSTRAP_PROFILE="$(bootstrap_normalize_profile "$PROFILE_INPUT")"; then
    echo "ERROR: Unknown Bootstrap Profile: $PROFILE_INPUT" >&2
    usage >&2
    exit 2
fi

export DEV_ENV_BOOTSTRAP_PROFILE="$BOOTSTRAP_PROFILE"

RUN_ID_PREFIX="$(date '+%Y%m%d-%H%M%S')"
if command -v uuidgen >/dev/null 2>&1; then
    RUN_UUID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
else
    RUN_UUID="fallback-$$-${RANDOM:-0}"
fi
LOG_PARENT="${DEV_ENV_LOG_DIR:-$HOME/Library/Logs/dev-env-bootstrap}"
mkdir -p "$LOG_PARENT"
LOG_DIR="$(mktemp -d "$LOG_PARENT/bootstrap-$RUN_ID_PREFIX-$RUN_UUID-XXXXXX")"
RUN_ID="${LOG_DIR##*/}"
export DEV_ENV_BOOTSTRAP_RUN_ID="$RUN_ID"
BOOTSTRAP_LOG="$LOG_DIR/bootstrap.log"
STEP_STATUS_FILE="$LOG_DIR/step-status.tsv"
ENVIRONMENT_FILE="$LOG_DIR/environment.txt"
SUMMARY_FILE="$LOG_DIR/summary.txt"
BOOTSTRAP_OUTCOME="in_progress"
BOOTSTRAP_START_EPOCH="$(date '+%s')"
LAST_STEP_STATUS=0
LAST_STEP_DISPOSITION=""
RUN_HAS_WARNINGS=0
TRACE_STEPS="${DEV_ENV_TRACE_STEPS:-0}"

COMMON_STEPS=(
    "00-check-prerequisites.sh"
    "01-install-brew.sh"
    "02-install-cli-tools.sh"
    "03-install-npm-globals.sh"
    "04-install-pip-packages.sh"
)

CARLO_BASELINE_STEPS=(
    "05-setup-dotfiles.sh"
    "06-setup-claude.sh"
    "07-setup-1password.sh"
    "08-setup-gemini.sh"
    "14-install-codex-skills.sh"
)

SHARED_BASELINE_STEPS=(
    "15-setup-shared-shell.sh"
)

VERIFICATION_STEPS=(
    "10-check-paths.sh"
    "12-smoke-test.sh"
)

STEPS=("${COMMON_STEPS[@]}")
case "$BOOTSTRAP_PROFILE" in
    carlo-baseline)
        STEPS+=("${CARLO_BASELINE_STEPS[@]}")
        ;;
    shared-baseline)
        STEPS+=("${SHARED_BASELINE_STEPS[@]}")
        ;;
esac
STEPS+=("${VERIFICATION_STEPS[@]}")

load_homebrew() {
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

format_duration() {
    local total_seconds="${1:-0}"
    local hours=0
    local minutes=0
    local seconds=0

    hours=$((total_seconds / 3600))
    minutes=$(((total_seconds % 3600) / 60))
    seconds=$((total_seconds % 60))

    printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds"
}

command_output_line() {
    "$@" 2>/dev/null | head -n 1 || true
}

append_environment_snapshot() {
    local phase="$1"
    local phase_title=""
    local host_name=""
    local local_host_name=""
    local translated="unknown"

    if [ "$phase" = "postflight" ] &&
            [ "${DEV_ENV_TEST_POSTFLIGHT_FAIL:-0}" = "1" ]; then
        return 79
    fi

    phase_title="$(printf '%s' "$phase" | tr '[:lower:]' '[:upper:]')"
    host_name="$(scutil --get ComputerName 2>/dev/null || hostname 2>/dev/null || echo unknown)"
    local_host_name="$(scutil --get LocalHostName 2>/dev/null || echo unknown)"

    if command -v sysctl >/dev/null 2>&1; then
        translated="$(sysctl -in sysctl.proc_translated 2>/dev/null || echo 0)"
    fi

    {
        echo "===== ${phase_title} SNAPSHOT ====="
        echo "timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "run_id=$RUN_ID"
        echo "bootstrap_profile=$BOOTSTRAP_PROFILE"
        echo "repo_root=$REPO_ROOT"
        echo "log_dir=$LOG_DIR"
        echo "pwd=$(pwd)"
        echo "home=$HOME"
        echo "shell=${SHELL:-unknown}"
        echo "user=$(whoami 2>/dev/null || echo unknown)"
        echo "uid=$(id -u 2>/dev/null || echo unknown)"
        echo "hostname=$host_name"
        echo "local_hostname=$local_host_name"
        echo "arch=$(uname -m 2>/dev/null || echo unknown)"
        echo "uname=$(uname -a)"
        echo "path=$PATH"
        echo "dev_env_log_dir_override=${DEV_ENV_LOG_DIR:-unset}"
        echo "dev_env_refresh_brew=${DEV_ENV_REFRESH_BREW:-0}"
        echo "dev_env_trace_steps=$TRACE_STEPS"
        echo "rosetta_translated=$translated"
        if command -v sw_vers >/dev/null 2>&1; then
            echo ""
            echo "[sw_vers]"
            sw_vers
        fi
        if command -v uptime >/dev/null 2>&1; then
            echo ""
            echo "uptime=$(command_output_line uptime)"
        fi
        if command -v df >/dev/null 2>&1; then
            echo ""
            echo "[disk_root]"
            df -h /
        fi
        if command -v xcode-select >/dev/null 2>&1; then
            echo ""
            echo "xcode_select_path=$(xcode-select -p 2>/dev/null || echo missing)"
        fi
        if command -v xcodebuild >/dev/null 2>&1; then
            echo "xcodebuild_version=$(command_output_line xcodebuild -version)"
        fi
        if command -v git >/dev/null 2>&1; then
            echo ""
            echo "git_version=$(command_output_line git --version)"
        fi
        if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo "git_commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
            echo "git_branch=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
            echo ""
            echo "[git_status]"
            git -C "$REPO_ROOT" status --short --branch 2>/dev/null || true
        fi
        if command -v brew >/dev/null 2>&1; then
            echo ""
            echo "brew_prefix=$(brew --prefix 2>/dev/null || echo unknown)"
            echo "brew_version=$(command_output_line brew --version)"
        fi
        if command -v node >/dev/null 2>&1; then
            echo ""
            echo "node_version=$(command_output_line node --version)"
        fi
        if command -v npm >/dev/null 2>&1; then
            echo "npm_version=$(command_output_line npm --version)"
        fi
        if command -v python3 >/dev/null 2>&1; then
            echo "python3_version=$(command_output_line python3 --version)"
        fi
        if command -v pip3 >/dev/null 2>&1; then
            echo "pip3_version=$(command_output_line pip3 --version)"
        fi
        echo ""
    } >> "$ENVIRONMENT_FILE"
}

record_step_status() {
    local script_name="$1"
    local start_ts="$2"
    local end_ts="$3"
    local duration_seconds="$4"
    local exit_code="$5"
    local status="$6"
    local step_log="$7"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$start_ts" \
        "$end_ts" \
        "$duration_seconds" \
        "$script_name" \
        "$exit_code" \
        "$status" \
        "${step_log##*/}" >> "$STEP_STATUS_FILE"
}

write_summary() {
    local end_epoch=0
    local duration_seconds=0
    local summary_staging=""

    end_epoch="$(date '+%s')"
    duration_seconds=$((end_epoch - BOOTSTRAP_START_EPOCH))
    summary_staging="$(mktemp "$LOG_DIR/.summary.XXXXXX")"

    {
        cat "$BOOTSTRAP_RECORDER_STATE_FILE"
        echo "duration_seconds=$duration_seconds"
        echo "duration_human=$(format_duration "$duration_seconds")"
        echo "trace_steps=$TRACE_STEPS"
        echo "log_dir=."
        echo "bootstrap_log=bootstrap.log"
        echo "environment_file=environment.txt"
        echo "step_status_file=step-status.tsv"
        echo "events_file=events.tsv"
        echo "current_state_file=current-state.txt"
        echo ""
        echo "[step_status]"
        cat "$STEP_STATUS_FILE"
    } > "$summary_staging"
    chmod 0600 "$summary_staging"
    mv -f "$summary_staging" "$SUMMARY_FILE"
}

on_exit() {
    local status="$1"
    local postflight_status=0

    trap - EXIT
    set +e

    if [ "$BOOTSTRAP_OUTCOME" = "in_progress" ]; then
        if [ "$status" -eq 0 ]; then
            BOOTSTRAP_OUTCOME="completed"
        else
            BOOTSTRAP_OUTCOME="required_failure"
            BOOTSTRAP_RECORDER_FAILURE_CLASS="internal_failure"
            BOOTSTRAP_RECORDER_FAILURE_CODE="bootstrap_failed_before_step"
            BOOTSTRAP_RECORDER_RAW_STATUS="$status"
            BOOTSTRAP_RECORDER_RECOVERY="retry_profile"
            BOOTSTRAP_RECORDER_RELEVANT_LOG="bootstrap.log"
        fi
    fi
    if [ "$BOOTSTRAP_OUTCOME" = "completed" ] &&
            [ "$RUN_HAS_WARNINGS" -eq 1 ]; then
        BOOTSTRAP_OUTCOME="completed_with_warnings"
    fi

    # Persist the terminal outcome before best-effort postflight probing.
    bootstrap_recorder_prepare_final_state "$BOOTSTRAP_OUTCOME" "$status"

    append_environment_snapshot "postflight" || postflight_status=$?
    if [ "$postflight_status" -ne 0 ]; then
        bootstrap_recorder_note_warning \
            postflight_probe_failed \
            "Postflight environment probing failed; durable run state was preserved." \
            environment.txt
        if [ "$BOOTSTRAP_OUTCOME" = "completed" ]; then
            BOOTSTRAP_OUTCOME="completed_with_warnings"
        fi
    fi

    bootstrap_recorder_finalize "$BOOTSTRAP_OUTCOME" "$status"
    bootstrap_coordinator_release_lock_after_finalization \
        "$BOOTSTRAP_RECORDER_STATE_FILE" || \
        echo "WARNING: Bootstrap mutation lock was retained because final state could not be confirmed."
    write_summary
    bootstrap_recorder_render_final "$LOG_DIR"
    exit "$status"
}

on_signal() {
    local signal_name="$1"
    local signal_status="$2"
    local log_ref="${CURRENT_STEP_LOG_REF:-bootstrap.log}"
    local signal_code=""

    trap - HUP INT TERM
    set +e
    signal_code="$(printf '%s' "$signal_name" | tr '[:upper:]' '[:lower:]')"
    BOOTSTRAP_OUTCOME="interrupted"
    bootstrap_coordinator_forward_signal "$signal_name" || true
    if [ -n "${CURRENT_STEP_NAME:-}" ]; then
        bootstrap_recorder_end_operation \
            interrupted \
            interrupted \
            "signal_$signal_code" \
            "$signal_status" \
            retry_profile \
            "Bootstrap interrupted by $signal_name." \
            "$log_ref"
        bootstrap_recorder_end_step \
            "$CURRENT_STEP_NAME" \
            interrupted \
            interrupted \
            "signal_$signal_code" \
            "$signal_status" \
            retry_profile \
            "Bootstrap interrupted by $signal_name." \
            "$log_ref"
    fi
    exit "$signal_status"
}

run_step() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    local step_log="$LOG_DIR/${script_name%.sh}.log"
    local status=0
    local script_status=0
    local tee_status=0
    local start_ts=""
    local end_ts=""
    local start_epoch=0
    local end_epoch=0
    local duration_seconds=0
    local status_label=""
    local disposition=""
    local failure_class="none"
    local failure_code="step_completed"
    local recovery="none"
    local recorder_message="Step completed."
    local step_log_ref="${script_name%.sh}.log"
    local step_warning_count=0
    local step_args=()
    local child_status_file=""

    if [ ! -f "$script_path" ]; then
        echo "ERROR: Missing bootstrap step: $script_path"
        exit 1
    fi

    start_ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    start_epoch="$(date '+%s')"
    bootstrap_recorder_begin_step "$script_name" "$step_log_ref"
    bootstrap_recorder_begin_operation \
        execute_step \
        "$script_name" \
        "$step_log_ref"
    CURRENT_STEP_NAME="$script_name"
    CURRENT_STEP_LOG_REF="$step_log_ref"

    echo ""
    echo "========================================"
    echo "Running $script_name"
    echo "========================================"
    echo ""
    echo "Step log: $step_log"
    if [ "$TRACE_STEPS" = "1" ]; then
        echo "WARNING: Trace mode adds local-sensitive recorder detail."
        echo "WARNING: It does not capture shell-expanded command arguments and is not automatically safe to share."
    fi

    {
        echo "===== $start_ts ====="
        echo "Step: $script_name"
        echo "Script: $script_path"
        echo "Step log: $step_log"
        echo "Trace mode: $TRACE_STEPS"
        echo "Bootstrap profile: $BOOTSTRAP_PROFILE"
        echo ""
    } >> "$step_log"

    case "$script_name" in
        "02-install-cli-tools.sh"|"03-install-npm-globals.sh"|"04-install-pip-packages.sh"|"10-check-paths.sh"|"12-smoke-test.sh")
            step_args=(--profile "$BOOTSTRAP_PROFILE")
            ;;
    esac

    set +e
    export BOOTSTRAP_OPERATION_EVENT_FILE="$BOOTSTRAP_RECORDER_EVENTS_FILE"
    export BOOTSTRAP_OPERATION_STEP="$script_name"
    export BOOTSTRAP_OPERATION_LOG_REF="$step_log_ref"
    child_status_file="$(mktemp "$LOG_DIR/.${script_name%.sh}.status.XXXXXX")"
    if [ "${#step_args[@]}" -gt 0 ]; then
        bootstrap_coordinator_run_logged_child \
            "$step_log" "$child_status_file" \
            bash "$script_path" "${step_args[@]}"
    else
        bootstrap_coordinator_run_logged_child \
            "$step_log" "$child_status_file" \
            bash "$script_path"
    fi
    status=$?
    if [ -f "$child_status_file" ]; then
        IFS=$'\t' read -r script_status tee_status < "$child_status_file"
        rm -f "$child_status_file"
    else
        script_status="$status"
        tee_status=0
    fi
    set -e
    bootstrap_recorder_sync_event_sequence

    status="$script_status"
    child_failure_adopted=0
    if [ "$status" -ne 0 ] && bootstrap_recorder_adopt_last_child_failure; then
        child_failure_adopted=1
    fi

    if [ "$tee_status" -ne 0 ]; then
        echo "ERROR: tee failed while writing $step_log (exit $tee_status)"
        status="$tee_status"
    fi

    end_ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    end_epoch="$(date '+%s')"
    duration_seconds=$((end_epoch - start_epoch))
    LAST_STEP_STATUS="$status"

    if [ "$tee_status" -ne 0 ]; then
        status_label="logging_failed(script=$script_status tee=$tee_status)"
        disposition="logging_failure"
        failure_class="internal_failure"
        failure_code="step_log_write_failed"
        recovery="retry_profile"
        recorder_message="The step log pipeline failed."
    elif [ "$status" -eq 0 ]; then
        step_warning_count="$(grep -Ec '^[[:space:]]*\[WARN\]' "$step_log" || true)"
        if [ "$step_warning_count" -gt 0 ]; then
            status_label="completed_with_warning($step_warning_count)"
            disposition="optional_degraded"
            failure_class="optional_degraded"
            failure_code="step_reported_warning"
            recovery="retry_profile"
            recorder_message="The step completed with non-gating warnings."
            RUN_HAS_WARNINGS=1
        else
            status_label="ok"
            disposition="satisfied"
        fi
    elif [ "$child_failure_adopted" -eq 1 ]; then
        disposition="$BOOTSTRAP_RECORDER_CHILD_DISPOSITION"
        if [ "$disposition" = "manual_action" ]; then
            status_label="manual_action_required($status)"
        else
            status_label="failed($status)"
        fi
        failure_class="$BOOTSTRAP_RECORDER_FAILURE_CLASS"
        failure_code="$BOOTSTRAP_RECORDER_FAILURE_CODE"
        recovery="$BOOTSTRAP_RECORDER_RECOVERY"
        recorder_message="The child operation failed: $BOOTSTRAP_RECORDER_CURRENT_OPERATION/$BOOTSTRAP_RECORDER_CURRENT_TARGET."
    elif [ "$status" -eq "$MANUAL_ACTION_EXIT" ]; then
        status_label="manual_action_required($status)"
        disposition="manual_action"
        failure_class="manual_action"
        failure_code="xcode_clt_manual_action"
        recovery="manual_then_retry"
        recorder_message="The step requires a manual prerequisite."
    else
        status_label="failed($status)"
        disposition="required_failure"
        failure_class="internal_failure"
        failure_code="step_command_failed"
        recovery="retry_profile"
        recorder_message="The required step failed."
    fi
    LAST_STEP_DISPOSITION="$disposition"

    record_step_status "$script_name" "$start_ts" "$end_ts" "$duration_seconds" "$status" "$status_label" "$step_log"
    bootstrap_recorder_end_operation \
        "$disposition" \
        "$failure_class" \
        "$failure_code" \
        "$status" \
        "$recovery" \
        "$recorder_message" \
        "$step_log_ref" \
        "$step_warning_count"
    bootstrap_recorder_end_step \
        "$script_name" \
        "$disposition" \
        "$failure_class" \
        "$failure_code" \
        "$status" \
        "$recovery" \
        "$recorder_message" \
        "$step_log_ref"

    {
        echo ""
        echo "Step outcome: $status_label"
        echo "Start: $start_ts"
        echo "End: $end_ts"
        echo "Duration: $(format_duration "$duration_seconds") ($duration_seconds seconds)"
        echo "Exit code: $status"
        if [ "$tee_status" -ne 0 ]; then
            echo "Script exit code: $script_status"
            echo "tee exit code: $tee_status"
        fi
        echo ""
    } >> "$step_log"

    echo ""
    echo "Step result: $script_name -> $status_label in $(format_duration "$duration_seconds")"
    echo "Step log: $step_log"

    CURRENT_STEP_NAME=""
    CURRENT_STEP_LOG_REF=""

    return "$status"
}

mkdir -p "$LOG_DIR"
printf 'start_time\tend_time\tduration_seconds\tstep\texit_code\tstatus\tlog_file\n' > "$STEP_STATUS_FILE"
: > "$ENVIRONMENT_FILE"
bootstrap_recorder_begin_run \
    "$LOG_DIR" \
    "$RUN_ID" \
    "$BOOTSTRAP_PROFILE" \
    "$REPO_ROOT" \
    "/bin/bash scripts/00-bootstrap.sh --profile $BOOTSTRAP_PROFILE"
bootstrap_recorder_set_step_plan "${STEPS[@]}"
append_environment_snapshot "preflight"
exec > >(tee -a "$BOOTSTRAP_LOG") 2>&1
trap 'on_exit "$?"' EXIT
trap 'on_signal HUP 129' HUP
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM
bootstrap_coordinator_configure "$LOG_PARENT" "$LOG_DIR" "$RUN_ID"
if bootstrap_coordinator_acquire_lock; then
    :
else
    lock_status=$?
    BOOTSTRAP_OUTCOME="required_failure"
    BOOTSTRAP_RECORDER_FAILURE_CLASS="concurrent_run"
    BOOTSTRAP_RECORDER_FAILURE_CODE="bootstrap_run_already_active"
    BOOTSTRAP_RECORDER_RAW_STATUS="$lock_status"
    BOOTSTRAP_RECORDER_RECOVERY="retry_profile"
    BOOTSTRAP_RECORDER_RELEVANT_LOG="bootstrap.log"
    exit "$lock_status"
fi
if [ -n "$BOOTSTRAP_COORDINATOR_STALE_LOCK_ARCHIVE" ]; then
    bootstrap_recorder_emit_event \
        stale_lock_archived \
        warning \
        changed \
        stale_lock_process_absent \
        0 \
        retry_profile \
        "Archived stale bootstrap lock with its prior-run link." \
        "${BOOTSTRAP_COORDINATOR_STALE_LOCK_ARCHIVE##*/}"
    bootstrap_recorder_write_current_state
fi
if bootstrap_coordinator_prior_run_is_incomplete; then
    bootstrap_recorder_emit_event \
        incomplete_prior_run_detected \
        warning \
        changed \
        prior_run_interrupted_incomplete \
        0 \
        retry_profile \
        "Recognized the incomplete prior run before starting a new mutation sequence." \
        "${BOOTSTRAP_COORDINATOR_STALE_LOCK_ARCHIVE##*/}"
    bootstrap_recorder_write_current_state
fi

echo "========================================"
echo "Dev Environment Bootstrap"
echo "========================================"
echo ""
echo "Bootstrap profile: $(bootstrap_profile_label "$BOOTSTRAP_PROFILE") ($BOOTSTRAP_PROFILE)"
echo "This will run the selected profile steps in order."
echo "If macOS prompts for Xcode Command Line Tools, complete that install and"
echo "then re-run this script with the same --profile value."
echo "Logs for this run will be written to: $LOG_DIR"
echo "Local diagnostic bundle privacy: local-sensitive"
echo "Artifacts: bootstrap.log, environment.txt, events.tsv, current-state.txt,"
echo "step-status.tsv, summary.txt, and per-step logs."
if [ "$TRACE_STEPS" = "1" ]; then
    echo "WARNING: DEV_ENV_TRACE_STEPS=1 is enabled."
    echo "WARNING: Trace metadata is local-sensitive. Sanitize before sharing."
    bootstrap_recorder_emit_event \
        trace_enabled \
        warning \
        satisfied \
        trace_is_local_sensitive \
        0 \
        none \
        "Trace metadata is local-sensitive." \
        bootstrap.log
    bootstrap_recorder_write_current_state
else
    echo "Set DEV_ENV_TRACE_STEPS=1 for additional orchestration trace metadata."
fi

if [[ "$(uname)" != "Darwin" ]]; then
    echo ""
    echo "ERROR: This bootstrap flow is intended for macOS only."
    BOOTSTRAP_OUTCOME="required_failure"
    exit 1
fi

if ! bootstrap_ensure_apple_silicon; then
    BOOTSTRAP_OUTCOME="required_failure"
    exit 1
fi

for step in "${STEPS[@]}"; do
    if ! run_step "$step"; then
        if [ "$LAST_STEP_STATUS" -eq "$MANUAL_ACTION_EXIT" ]; then
            BOOTSTRAP_OUTCOME="manual_action_required"
            exit "$MANUAL_ACTION_EXIT"
        fi

        if [ "$LAST_STEP_DISPOSITION" = "logging_failure" ]; then
            BOOTSTRAP_OUTCOME="logging_failure"
        else
            BOOTSTRAP_OUTCOME="required_failure"
        fi
        exit 1
    fi

    case "$step" in
        "01-install-brew.sh"|"02-install-cli-tools.sh")
            load_homebrew
            ;;
    esac
done

BOOTSTRAP_OUTCOME="completed"

echo ""
echo "========================================"
echo "Bootstrap Complete"
echo "========================================"
