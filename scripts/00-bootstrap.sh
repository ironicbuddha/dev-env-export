#!/bin/bash
# =============================================================================
# 00-bootstrap.sh - Run the Primary Bootstrap Sequence
# =============================================================================
# Runs scripts 01 through 08 in order for the main macOS bootstrap flow.
# Stops cleanly if a manual prerequisite such as Xcode Command Line Tools is
# still pending.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANUAL_ACTION_EXIT=20
RUN_ID="$(date '+%Y%m%d-%H%M%S')"
DEFAULT_LOG_DIR="$REPO_ROOT/logs/bootstrap-$RUN_ID"
LOG_DIR="${DEV_ENV_LOG_DIR:-$DEFAULT_LOG_DIR}"
BOOTSTRAP_LOG="$LOG_DIR/bootstrap.log"
STEP_STATUS_FILE="$LOG_DIR/step-status.tsv"
ENVIRONMENT_FILE="$LOG_DIR/environment.txt"
BOOTSTRAP_OUTCOME="in_progress"
FAILED_STEP=""
LAST_STEP_STATUS=0

STEPS=(
    "01-install-brew.sh"
    "02-install-cli-tools.sh"
    "03-install-npm-globals.sh"
    "04-install-pip-packages.sh"
    "05-setup-dotfiles.sh"
    "06-setup-claude.sh"
    "07-setup-1password.sh"
    "08-setup-gemini.sh"
)

load_homebrew() {
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

write_environment_snapshot() {
    {
        echo "timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "repo_root=$REPO_ROOT"
        echo "log_dir=$LOG_DIR"
        echo "pwd=$(pwd)"
        echo "shell=${SHELL:-unknown}"
        echo "user=$(whoami 2>/dev/null || echo unknown)"
        echo "uname=$(uname -a)"
        if command -v sw_vers >/dev/null 2>&1; then
            sw_vers
        fi
        if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo "git_commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
            echo "git_branch=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
        fi
    } > "$ENVIRONMENT_FILE"
}

record_step_status() {
    local script_name="$1"
    local status="$2"
    local step_log="$3"
    printf '%s\t%s\t%s\t%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$script_name" \
        "$status" \
        "$step_log" >> "$STEP_STATUS_FILE"
}

on_exit() {
    local status="$1"

    echo ""
    echo "Bootstrap logs: $LOG_DIR"
    echo "Main log: $BOOTSTRAP_LOG"

    case "$BOOTSTRAP_OUTCOME" in
        completed)
            echo "Bootstrap outcome: completed"
            ;;
        manual_action_required)
            echo "Bootstrap outcome: manual action required"
            ;;
        failed)
            echo "Bootstrap outcome: failed"
            if [ -n "$FAILED_STEP" ]; then
                echo "Failed step: $FAILED_STEP"
            fi
            ;;
        *)
            if [ "$status" -ne 0 ]; then
                echo "Bootstrap outcome: failed"
                if [ -n "$FAILED_STEP" ]; then
                    echo "Failed step: $FAILED_STEP"
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

    if [ ! -f "$script_path" ]; then
        echo "ERROR: Missing bootstrap step: $script_path"
        exit 1
    fi

    echo ""
    echo "========================================"
    echo "Running $script_name"
    echo "========================================"
    echo ""

    {
        echo "===== $(date '+%Y-%m-%d %H:%M:%S %Z') ====="
        echo "Step: $script_name"
        echo "Script: $script_path"
        echo ""
    } >> "$step_log"

    set +e
    bash "$script_path" 2>&1 | tee -a "$step_log"
    status=${PIPESTATUS[0]}
    set -e
    LAST_STEP_STATUS="$status"

    if [ "$status" -eq 0 ]; then
        record_step_status "$script_name" "ok" "$step_log"
    elif [ "$status" -eq "$MANUAL_ACTION_EXIT" ]; then
        record_step_status "$script_name" "manual_action_required($status)" "$step_log"
    else
        record_step_status "$script_name" "failed($status)" "$step_log"
    fi

    return "$status"
}

mkdir -p "$LOG_DIR"
printf 'timestamp\tstep\tstatus\tlog_file\n' > "$STEP_STATUS_FILE"
write_environment_snapshot
exec > >(tee -a "$BOOTSTRAP_LOG") 2>&1
trap 'on_exit "$?"' EXIT

echo "========================================"
echo "Dev Environment Bootstrap"
echo "========================================"
echo ""
echo "This will run scripts 01 through 08 in order."
echo "If macOS prompts for Xcode Command Line Tools, complete that install and"
echo "then re-run this script."
echo "Logs for this run will be written to: $LOG_DIR"

if [[ "$(uname)" != "Darwin" ]]; then
    echo ""
    echo "ERROR: This bootstrap flow is intended for macOS only."
    BOOTSTRAP_OUTCOME="failed"
    exit 1
fi

for step in "${STEPS[@]}"; do
    if ! run_step "$step"; then
        if [ "$step" = "02-install-cli-tools.sh" ] && [ "$LAST_STEP_STATUS" -eq "$MANUAL_ACTION_EXIT" ]; then
            echo ""
            echo "Manual action required:"
            echo "  - Finish installing Xcode Command Line Tools."
            echo "  - Re-run ./scripts/00-bootstrap.sh after the install completes."
            BOOTSTRAP_OUTCOME="manual_action_required"
            exit 0
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

echo ""
echo "========================================"
echo "Bootstrap Complete"
echo "========================================"
echo ""
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
echo "  - ./scripts/10-check-paths.sh"
echo "  - ./scripts/12-smoke-test.sh"
