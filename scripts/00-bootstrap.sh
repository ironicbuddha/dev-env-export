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
MANUAL_ACTION_EXIT=20
BOOTSTRAP_PROFILE=""

# shellcheck disable=SC1090
source "$PROFILE_LIB"

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

RUN_ID="$(date '+%Y%m%d-%H%M%S')"
LOG_PARENT="${DEV_ENV_LOG_DIR:-$REPO_ROOT/logs}"
mkdir -p "$LOG_PARENT"
LOG_DIR="$(mktemp -d "$LOG_PARENT/bootstrap-$RUN_ID-XXXXXX")"
BOOTSTRAP_LOG="$LOG_DIR/bootstrap.log"
STEP_STATUS_FILE="$LOG_DIR/step-status.tsv"
ENVIRONMENT_FILE="$LOG_DIR/environment.txt"
SUMMARY_FILE="$LOG_DIR/summary.txt"
BOOTSTRAP_OUTCOME="in_progress"
FAILED_STEP=""
CURRENT_STEP=""
BOOTSTRAP_START_TS="$(date '+%Y-%m-%d %H:%M:%S %Z')"
BOOTSTRAP_START_EPOCH="$(date '+%s')"
LAST_STEP_STATUS=0
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
            echo ""
            echo "[brew_config]"
            brew config 2>/dev/null || true
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
        "$step_log" >> "$STEP_STATUS_FILE"
}

write_summary() {
    local exit_status="$1"
    local end_ts=""
    local end_epoch=0
    local duration_seconds=0
    local relevant_step=""

    end_ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    end_epoch="$(date '+%s')"
    duration_seconds=$((end_epoch - BOOTSTRAP_START_EPOCH))
    relevant_step="${FAILED_STEP:-$CURRENT_STEP}"

    {
        echo "run_id=$RUN_ID"
        echo "started_at=$BOOTSTRAP_START_TS"
        echo "ended_at=$end_ts"
        echo "duration_seconds=$duration_seconds"
        echo "duration_human=$(format_duration "$duration_seconds")"
        echo "outcome=$BOOTSTRAP_OUTCOME"
        echo "bootstrap_profile=$BOOTSTRAP_PROFILE"
        echo "exit_status=$exit_status"
        echo "failed_step=${FAILED_STEP:-none}"
        echo "relevant_step=${relevant_step:-none}"
        echo "trace_steps=$TRACE_STEPS"
        echo "log_dir=$LOG_DIR"
        echo "bootstrap_log=$BOOTSTRAP_LOG"
        echo "environment_file=$ENVIRONMENT_FILE"
        echo "step_status_file=$STEP_STATUS_FILE"
        echo ""
        echo "[step_status]"
        cat "$STEP_STATUS_FILE"
    } > "$SUMMARY_FILE"
}

on_exit() {
    local status="$1"
    local relevant_step=""

    append_environment_snapshot "postflight"
    write_summary "$status"

    relevant_step="${FAILED_STEP:-$CURRENT_STEP}"

    echo ""
    echo "Bootstrap logs: $LOG_DIR"
    echo "Main log: $BOOTSTRAP_LOG"
    echo "Environment snapshot: $ENVIRONMENT_FILE"
    echo "Step status: $STEP_STATUS_FILE"
    echo "Summary: $SUMMARY_FILE"

    case "$BOOTSTRAP_OUTCOME" in
        completed)
            echo "Bootstrap outcome: completed"
            ;;
        manual_action_required)
            echo "Bootstrap outcome: manual action required"
            ;;
        failed)
            echo "Bootstrap outcome: failed"
            if [ -n "$relevant_step" ]; then
                echo "Failed step: $relevant_step"
            fi
            ;;
        *)
            if [ "$status" -ne 0 ]; then
                echo "Bootstrap outcome: failed"
                if [ -n "$relevant_step" ]; then
                    echo "Failed step: $relevant_step"
                fi
            fi
            ;;
    esac
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
    local pipe_status=()
    local step_args=()

    if [ ! -f "$script_path" ]; then
        echo "ERROR: Missing bootstrap step: $script_path"
        exit 1
    fi

    CURRENT_STEP="$script_name"
    start_ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    start_epoch="$(date '+%s')"

    echo ""
    echo "========================================"
    echo "Running $script_name"
    echo "========================================"
    echo ""
    echo "Step log: $step_log"
    if [ "$TRACE_STEPS" = "1" ]; then
        echo "Trace mode: enabled (DEV_ENV_TRACE_STEPS=1)"
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
    if [ "$TRACE_STEPS" = "1" ]; then
        if [ "${#step_args[@]}" -gt 0 ]; then
            bash -x "$script_path" "${step_args[@]}" 2>&1 | tee -a "$step_log"
        else
            bash -x "$script_path" 2>&1 | tee -a "$step_log"
        fi
    else
        if [ "${#step_args[@]}" -gt 0 ]; then
            bash "$script_path" "${step_args[@]}" 2>&1 | tee -a "$step_log"
        else
            bash "$script_path" 2>&1 | tee -a "$step_log"
        fi
    fi
    pipe_status=("${PIPESTATUS[@]}")
    set -e

    script_status="${pipe_status[0]:-1}"
    tee_status="${pipe_status[1]:-0}"
    status="$script_status"

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
    elif [ "$status" -eq 0 ]; then
        status_label="ok"
    elif [ "$status" -eq "$MANUAL_ACTION_EXIT" ]; then
        status_label="manual_action_required($status)"
    else
        status_label="failed($status)"
    fi

    record_step_status "$script_name" "$start_ts" "$end_ts" "$duration_seconds" "$status" "$status_label" "$step_log"

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

    return "$status"
}

mkdir -p "$LOG_DIR"
printf 'start_time\tend_time\tduration_seconds\tstep\texit_code\tstatus\tlog_file\n' > "$STEP_STATUS_FILE"
: > "$ENVIRONMENT_FILE"
append_environment_snapshot "preflight"
exec > >(tee -a "$BOOTSTRAP_LOG") 2>&1
trap 'on_exit "$?"' EXIT

echo "========================================"
echo "Dev Environment Bootstrap"
echo "========================================"
echo ""
echo "Bootstrap profile: $(bootstrap_profile_label "$BOOTSTRAP_PROFILE") ($BOOTSTRAP_PROFILE)"
echo "This will run the selected profile steps in order."
echo "If macOS prompts for Xcode Command Line Tools, complete that install and"
echo "then re-run this script with the same --profile value."
echo "Logs for this run will be written to: $LOG_DIR"
echo "Artifacts: bootstrap.log, environment.txt, step-status.tsv, summary.txt, and per-step logs."
if [ "$TRACE_STEPS" = "1" ]; then
    echo "Step trace logging is enabled."
else
    echo "Set DEV_ENV_TRACE_STEPS=1 for command-by-command step tracing."
fi

if [[ "$(uname)" != "Darwin" ]]; then
    echo ""
    echo "ERROR: This bootstrap flow is intended for macOS only."
    BOOTSTRAP_OUTCOME="failed"
    exit 1
fi

for step in "${STEPS[@]}"; do
    if ! run_step "$step"; then
        if [ "$LAST_STEP_STATUS" -eq "$MANUAL_ACTION_EXIT" ]; then
            echo ""
            echo "Manual action required:"
            echo "  - Finish installing Xcode Command Line Tools."
            echo "  - Re-run /bin/bash scripts/00-bootstrap.sh --profile $BOOTSTRAP_PROFILE after the install completes."
            BOOTSTRAP_OUTCOME="manual_action_required"
            exit "$MANUAL_ACTION_EXIT"
        fi

        BOOTSTRAP_OUTCOME="failed"
        FAILED_STEP="$step"
        exit 1
    fi

    case "$step" in
        "01-install-brew.sh"|"02-install-cli-tools.sh")
            load_homebrew
            ;;
    esac
done

BOOTSTRAP_OUTCOME="completed"
CURRENT_STEP=""

echo ""
echo "========================================"
echo "Bootstrap Complete"
echo "========================================"
echo ""
case "$BOOTSTRAP_PROFILE" in
    carlo-baseline)
        echo "Recommended manual follow-up:"
        echo "  - exec zsh"
        echo "  - gh auth login --web --git-protocol https"
        echo "  - gh auth setup-git"
        echo "  - aws configure"
        echo "  - launch gemini and complete OAuth if prompted"
        echo "  - gws auth setup"
        echo "  - codex login"
        echo "  - claude auth login"
        echo "  - open 1Password and confirm op account list works"
        echo ""
        echo "Zed trust follow-up:"
        echo "  - Open /Users/carlo/dev in Zed"
        echo "  - Use the Restricted Mode prompt or workspace::ToggleWorktreeSecurity"
        echo "  - Trust all projects in the /Users/carlo/dev folder"
        echo ""
        echo "Optional next steps:"
        echo "  - gemini skills list"
        echo "  - ./scripts/08-op-inject-template.sh --help"
        echo "  - ./scripts/09-inventory-ai-tooling.sh"
        ;;
    shared-baseline)
        echo "Recommended manual follow-up:"
        echo "  - exec zsh"
        echo "  - git config --global user.name \"Your Name\""
        echo "  - git config --global user.email \"you@example.com\""
        echo "  - gh auth login --web --git-protocol https"
        echo "  - gh auth setup-git"
        echo "  - vercel login"
        echo "  - codex login"
        echo "  - complete any Zed, Warp, Raycast, Hidden Bar, Hammerspoon, or GitHub Desktop first-launch prompts"
        echo "  - store credentials in 1Password or the user's preferred secret manager"
        ;;
esac
