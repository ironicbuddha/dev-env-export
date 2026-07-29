#!/bin/bash
# Durable stock-Bash recorder for one bootstrap invocation.

BOOTSTRAP_RECORDER_SCHEMA_VERSION="${BOOTSTRAP_RECORDER_SCHEMA_VERSION:-1}"
BOOTSTRAP_RECORDER_RUN_DIR=""
BOOTSTRAP_RECORDER_RUN_ID=""
BOOTSTRAP_RECORDER_PROFILE=""
BOOTSTRAP_RECORDER_SOURCE_ROOT=""
BOOTSTRAP_RECORDER_RERUN_COMMAND=""
BOOTSTRAP_RECORDER_EVENTS_FILE=""
BOOTSTRAP_RECORDER_STATE_FILE=""
BOOTSTRAP_RECORDER_EVENT_SEQUENCE=0
BOOTSTRAP_RECORDER_OUTCOME="interrupted_incomplete"
BOOTSTRAP_RECORDER_CURRENT_STEP=""
BOOTSTRAP_RECORDER_CURRENT_OPERATION=""
BOOTSTRAP_RECORDER_CURRENT_TARGET=""
BOOTSTRAP_RECORDER_WARNING_COUNT=0
BOOTSTRAP_RECORDER_SOURCE_KIND="unknown"
BOOTSTRAP_RECORDER_SOURCE_IDENTITY="unknown"
BOOTSTRAP_RECORDER_FAILED_STEP=""
BOOTSTRAP_RECORDER_FAILED_OPERATION=""
BOOTSTRAP_RECORDER_FAILURE_CLASS="none"
BOOTSTRAP_RECORDER_FAILURE_CODE="none"
BOOTSTRAP_RECORDER_RAW_STATUS=0
BOOTSTRAP_RECORDER_RECOVERY="none"
BOOTSTRAP_RECORDER_SAFE_ACTION="none"
BOOTSTRAP_RECORDER_RELEVANT_LOG="none"
BOOTSTRAP_RECORDER_CHILD_DISPOSITION=""
BOOTSTRAP_RECORDER_EXIT_STATUS=0
BOOTSTRAP_RECORDER_STARTED_AT=""
BOOTSTRAP_RECORDER_ENDED_AT="none"
BOOTSTRAP_RECORDER_STEP_PLAN=()
BOOTSTRAP_RECORDER_COMPLETED_STEPS=()
BOOTSTRAP_RECORDER_WARNING_LOGS=()

bootstrap_recorder_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

bootstrap_recorder_clean_field() {
    printf '%s' "${1:-}" | tr '\t\r\n' '   '
}

bootstrap_recorder_join_csv() {
    local joined=""
    local value=""

    for value in "$@"; do
        if [ -n "$joined" ]; then
            joined="$joined,$value"
        else
            joined="$value"
        fi
    done
    printf '%s\n' "${joined:-none}"
}

bootstrap_recorder_array_contains() {
    local wanted="$1"
    shift
    local value=""

    for value in "$@"; do
        [ "$value" = "$wanted" ] && return 0
    done
    return 1
}

bootstrap_recorder_source_tree_digest() (
    local source_root="$1"
    local log_parent="$2"
    local excluded_log_parent=""

    [ -d "$source_root" ] || return 1
    command -v shasum >/dev/null 2>&1 || return 1
    case "$log_parent" in
        "$source_root"/*)
            excluded_log_parent="./${log_parent#"$source_root"/}"
            ;;
    esac
    cd "$source_root" || return 1

    find . \
        \( \
            -path './.git' -o -path './.git/*' -o \
            -path './.handoff' -o -path './.handoff/*' -o \
            -path './.scratch' -o -path './.scratch/*' -o \
            -path './tmp' -o -path './tmp/*' -o \
            -path "$excluded_log_parent" -o \
            -path "$excluded_log_parent/*" \
        \) -prune -o \
        -type f -print0 |
        xargs -0 shasum -a 256 |
        LC_ALL=C sort |
        shasum -a 256 |
        awk '{print $1}'
)

bootstrap_recorder_detect_source() {
    local tree_digest=""
    local git_commit=""
    local git_state="clean"

    tree_digest="$(bootstrap_recorder_source_tree_digest \
        "$BOOTSTRAP_RECORDER_SOURCE_ROOT" \
        "$(dirname "$BOOTSTRAP_RECORDER_RUN_DIR")" \
        2>/dev/null || true)"
    [ -n "$tree_digest" ] || tree_digest="unavailable"

    if command -v git >/dev/null 2>&1 &&
            git -C "$BOOTSTRAP_RECORDER_SOURCE_ROOT" \
                rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git_commit="$(git -C "$BOOTSTRAP_RECORDER_SOURCE_ROOT" \
            rev-parse HEAD 2>/dev/null || true)"
        if ! git -C "$BOOTSTRAP_RECORDER_SOURCE_ROOT" \
                diff --quiet --ignore-submodules -- 2>/dev/null ||
                ! git -C "$BOOTSTRAP_RECORDER_SOURCE_ROOT" \
                    diff --cached --quiet --ignore-submodules -- 2>/dev/null ||
                [ -n "$(git -C "$BOOTSTRAP_RECORDER_SOURCE_ROOT" \
                    ls-files --others --exclude-standard 2>/dev/null)" ]; then
            git_state="modified"
        fi
        BOOTSTRAP_RECORDER_SOURCE_KIND="git"
        BOOTSTRAP_RECORDER_SOURCE_IDENTITY="git:${git_commit:-unknown}:$git_state:tree-sha256:$tree_digest"
    else
        BOOTSTRAP_RECORDER_SOURCE_KIND="zip"
        BOOTSTRAP_RECORDER_SOURCE_IDENTITY="zip-tree-sha256:$tree_digest"
    fi
}

bootstrap_recorder_write_latest_pointer() {
    local log_parent=""
    local latest_file=""
    local latest_staging=""

    log_parent="$(dirname "$BOOTSTRAP_RECORDER_RUN_DIR")"
    latest_file="$log_parent/latest-run.txt"
    latest_staging="$(mktemp "$log_parent/.latest-run.XXXXXX")" || return 1
    printf '%s\n' "$(basename "$BOOTSTRAP_RECORDER_RUN_DIR")" > "$latest_staging" || {
        rm -f "$latest_staging"
        return 1
    }
    chmod 0600 "$latest_staging" || {
        rm -f "$latest_staging"
        return 1
    }
    mv -f "$latest_staging" "$latest_file"
}

bootstrap_recorder_emit_event() {
    local event_type="${1:-event}"
    local severity="${2:-informational}"
    local disposition="${3:-satisfied}"
    local code="${4:-none}"
    local status="${5:-0}"
    local recovery="${6:-none}"
    local message="${7:-}"
    local log_ref="${8:-none}"
    local failure_class="${9:-none}"

    BOOTSTRAP_RECORDER_EVENT_SEQUENCE=$((BOOTSTRAP_RECORDER_EVENT_SEQUENCE + 1))
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$BOOTSTRAP_RECORDER_EVENT_SEQUENCE" \
        "$(bootstrap_recorder_clean_field "$event_type")" \
        "$(bootstrap_recorder_timestamp)" \
        "$(bootstrap_recorder_clean_field "$severity")" \
        "$(bootstrap_recorder_clean_field "$disposition")" \
        "$(bootstrap_recorder_clean_field "$failure_class")" \
        "$(bootstrap_recorder_clean_field "$code")" \
        "$(bootstrap_recorder_clean_field "$BOOTSTRAP_RECORDER_CURRENT_STEP")" \
        "$(bootstrap_recorder_clean_field "$BOOTSTRAP_RECORDER_CURRENT_OPERATION")" \
        "$(bootstrap_recorder_clean_field "$BOOTSTRAP_RECORDER_CURRENT_TARGET")" \
        "$(bootstrap_recorder_clean_field "$status")" \
        "$(bootstrap_recorder_clean_field "$recovery")" \
        "$(bootstrap_recorder_clean_field "$message")" \
        "$(bootstrap_recorder_clean_field "$log_ref")" >> "$BOOTSTRAP_RECORDER_EVENTS_FILE"
}

bootstrap_recorder_sync_event_sequence() {
    local last_sequence=0

    [ -f "$BOOTSTRAP_RECORDER_EVENTS_FILE" ] || return 0
    last_sequence="$(awk -F '\t' 'NR > 1 && $1 ~ /^[0-9]+$/ && $1 > max { max = $1 } END { print max + 0 }' \
        "$BOOTSTRAP_RECORDER_EVENTS_FILE")"
    BOOTSTRAP_RECORDER_EVENT_SEQUENCE="$last_sequence"
}

bootstrap_recorder_adopt_last_child_failure() {
    local child_failure=""
    local disposition="" operation="" target="" failure_class="" failure_code=""
    local raw_status="" recovery="" log_ref=""

    [ -f "$BOOTSTRAP_RECORDER_EVENTS_FILE" ] || return 1
    child_failure="$(awk -F '\t' -v step="$BOOTSTRAP_RECORDER_CURRENT_STEP" '
        $2 == "operation_end" && $8 == step &&
            ($5 == "manual_action" || $5 == "required_failure" ||
             $5 == "logging_failure" || $5 == "interrupted") {
                result = $5 FS $9 FS $10 FS $6 FS $7 FS $11 FS $12 FS $14
            }
        END { if (result != "") print result; else exit 1 }
    ' "$BOOTSTRAP_RECORDER_EVENTS_FILE")" || return 1
    IFS=$'\t' read -r disposition operation target failure_class failure_code raw_status recovery log_ref \
        <<< "$child_failure"
    [ -n "$disposition" ] && [ -n "$operation" ] && [ -n "$failure_class" ] && [ -n "$failure_code" ] || return 1

    BOOTSTRAP_RECORDER_CHILD_DISPOSITION="$disposition"
    BOOTSTRAP_RECORDER_CURRENT_OPERATION="$operation"
    BOOTSTRAP_RECORDER_CURRENT_TARGET="$target"
    BOOTSTRAP_RECORDER_FAILED_STEP="$BOOTSTRAP_RECORDER_CURRENT_STEP"
    BOOTSTRAP_RECORDER_FAILED_OPERATION="$operation"
    BOOTSTRAP_RECORDER_FAILURE_CLASS="$failure_class"
    BOOTSTRAP_RECORDER_FAILURE_CODE="$failure_code"
    BOOTSTRAP_RECORDER_RAW_STATUS="$raw_status"
    BOOTSTRAP_RECORDER_RECOVERY="$recovery"
    BOOTSTRAP_RECORDER_RELEVANT_LOG="$log_ref"
}

bootstrap_recorder_write_current_state() {
    local state_staging=""
    local remaining_steps=()
    local planned_step=""
    local uncertain_work="none"

    for planned_step in \
        ${BOOTSTRAP_RECORDER_STEP_PLAN[@]+"${BOOTSTRAP_RECORDER_STEP_PLAN[@]}"}; do
        if ! bootstrap_recorder_array_contains \
                "$planned_step" \
                ${BOOTSTRAP_RECORDER_COMPLETED_STEPS[@]+"${BOOTSTRAP_RECORDER_COMPLETED_STEPS[@]}"}; then
            remaining_steps+=("$planned_step")
        fi
    done
    if [ "$BOOTSTRAP_RECORDER_OUTCOME" = "interrupted_incomplete" ] &&
            [ -n "$BOOTSTRAP_RECORDER_CURRENT_STEP" ]; then
        uncertain_work="$BOOTSTRAP_RECORDER_CURRENT_STEP"
        if [ -n "$BOOTSTRAP_RECORDER_CURRENT_OPERATION" ]; then
            uncertain_work="$uncertain_work/$BOOTSTRAP_RECORDER_CURRENT_OPERATION"
        fi
    fi

    state_staging="$(mktemp "$BOOTSTRAP_RECORDER_RUN_DIR/.current-state.XXXXXX")" ||
        return 1
    {
        echo "schema_version=$BOOTSTRAP_RECORDER_SCHEMA_VERSION"
        echo "run_id=$BOOTSTRAP_RECORDER_RUN_ID"
        echo "bootstrap_profile=$BOOTSTRAP_RECORDER_PROFILE"
        echo "source_kind=$BOOTSTRAP_RECORDER_SOURCE_KIND"
        echo "source_identity=$BOOTSTRAP_RECORDER_SOURCE_IDENTITY"
        echo "privacy=local-sensitive"
        echo "outcome=$BOOTSTRAP_RECORDER_OUTCOME"
        echo "exit_status=$BOOTSTRAP_RECORDER_EXIT_STATUS"
        echo "started_at=$BOOTSTRAP_RECORDER_STARTED_AT"
        echo "ended_at=$BOOTSTRAP_RECORDER_ENDED_AT"
        echo "current_step=${BOOTSTRAP_RECORDER_CURRENT_STEP:-none}"
        echo "current_operation=${BOOTSTRAP_RECORDER_CURRENT_OPERATION:-none}"
        echo "current_target=${BOOTSTRAP_RECORDER_CURRENT_TARGET:-none}"
        echo "failed_step=${BOOTSTRAP_RECORDER_FAILED_STEP:-none}"
        echo "failed_operation=${BOOTSTRAP_RECORDER_FAILED_OPERATION:-none}"
        echo "failure_class=$BOOTSTRAP_RECORDER_FAILURE_CLASS"
        echo "failure_code=$BOOTSTRAP_RECORDER_FAILURE_CODE"
        echo "raw_status=$BOOTSTRAP_RECORDER_RAW_STATUS"
        echo "completed_steps=$(bootstrap_recorder_join_csv \
            ${BOOTSTRAP_RECORDER_COMPLETED_STEPS[@]+"${BOOTSTRAP_RECORDER_COMPLETED_STEPS[@]}"})"
        echo "remaining_steps=$(bootstrap_recorder_join_csv \
            ${remaining_steps[@]+"${remaining_steps[@]}"})"
        echo "uncertain_work=$uncertain_work"
        echo "warning_count=$BOOTSTRAP_RECORDER_WARNING_COUNT"
        echo "warning_logs=$(bootstrap_recorder_join_csv \
            ${BOOTSTRAP_RECORDER_WARNING_LOGS[@]+"${BOOTSTRAP_RECORDER_WARNING_LOGS[@]}"})"
        echo "recovery=$BOOTSTRAP_RECORDER_RECOVERY"
        echo "safe_action=$BOOTSTRAP_RECORDER_SAFE_ACTION"
        echo "rerun_command=$BOOTSTRAP_RECORDER_RERUN_COMMAND"
        echo "relevant_log=$BOOTSTRAP_RECORDER_RELEVANT_LOG"
        echo "events_file=events.tsv"
        echo "state_file=current-state.txt"
        echo "updated_at=$(bootstrap_recorder_timestamp)"
    } > "$state_staging" || {
        rm -f "$state_staging"
        return 1
    }
    chmod 0600 "$state_staging" || {
        rm -f "$state_staging"
        return 1
    }
    mv -f "$state_staging" "$BOOTSTRAP_RECORDER_STATE_FILE"
}

bootstrap_recorder_begin_run() {
    BOOTSTRAP_RECORDER_RUN_DIR="$1"
    BOOTSTRAP_RECORDER_RUN_ID="$2"
    BOOTSTRAP_RECORDER_PROFILE="$3"
    BOOTSTRAP_RECORDER_SOURCE_ROOT="$4"
    BOOTSTRAP_RECORDER_RERUN_COMMAND="$5"
    BOOTSTRAP_RECORDER_EVENTS_FILE="$BOOTSTRAP_RECORDER_RUN_DIR/events.tsv"
    BOOTSTRAP_RECORDER_STATE_FILE="$BOOTSTRAP_RECORDER_RUN_DIR/current-state.txt"
    BOOTSTRAP_RECORDER_EVENT_SEQUENCE=0
    BOOTSTRAP_RECORDER_OUTCOME="interrupted_incomplete"
    BOOTSTRAP_RECORDER_CURRENT_STEP=""
    BOOTSTRAP_RECORDER_CURRENT_OPERATION=""
    BOOTSTRAP_RECORDER_CURRENT_TARGET=""
    BOOTSTRAP_RECORDER_WARNING_COUNT=0
    BOOTSTRAP_RECORDER_FAILED_STEP=""
    BOOTSTRAP_RECORDER_FAILED_OPERATION=""
    BOOTSTRAP_RECORDER_FAILURE_CLASS="none"
    BOOTSTRAP_RECORDER_FAILURE_CODE="none"
    BOOTSTRAP_RECORDER_RAW_STATUS=0
    BOOTSTRAP_RECORDER_RECOVERY="retry_profile"
    BOOTSTRAP_RECORDER_SAFE_ACTION="inspect_incomplete_then_rerun_same_profile"
    BOOTSTRAP_RECORDER_RELEVANT_LOG="none"
    BOOTSTRAP_RECORDER_CHILD_DISPOSITION=""
    BOOTSTRAP_RECORDER_EXIT_STATUS=0
    BOOTSTRAP_RECORDER_STARTED_AT="$(bootstrap_recorder_timestamp)"
    BOOTSTRAP_RECORDER_ENDED_AT="none"
    BOOTSTRAP_RECORDER_STEP_PLAN=()
    BOOTSTRAP_RECORDER_COMPLETED_STEPS=()
    BOOTSTRAP_RECORDER_WARNING_LOGS=()

    mkdir -p "$BOOTSTRAP_RECORDER_RUN_DIR"
    chmod 0700 "$BOOTSTRAP_RECORDER_RUN_DIR"
    bootstrap_recorder_detect_source
    printf '%s\n' \
        $'sequence\tevent_type\ttimestamp\tseverity\tdisposition\tfailure_class\tcode\tstep\toperation\ttarget\traw_status\trecovery\tmessage\tlog_ref' \
        > "$BOOTSTRAP_RECORDER_EVENTS_FILE"
    chmod 0600 "$BOOTSTRAP_RECORDER_EVENTS_FILE"

    bootstrap_recorder_emit_event \
        run_start \
        informational \
        changed \
        run_started \
        0 \
        none \
        "Bootstrap run started." \
        bootstrap.log
    bootstrap_recorder_write_current_state
    bootstrap_recorder_write_latest_pointer
}

bootstrap_recorder_set_step_plan() {
    BOOTSTRAP_RECORDER_STEP_PLAN=("$@")
    bootstrap_recorder_write_current_state
}

bootstrap_recorder_begin_step() {
    local step_name="$1"
    local log_ref="${2:-none}"

    BOOTSTRAP_RECORDER_CURRENT_STEP="$step_name"
    BOOTSTRAP_RECORDER_CURRENT_OPERATION=""
    BOOTSTRAP_RECORDER_CURRENT_TARGET=""
    BOOTSTRAP_RECORDER_RELEVANT_LOG="$log_ref"
    BOOTSTRAP_RECORDER_OUTCOME="interrupted_incomplete"
    bootstrap_recorder_emit_event \
        step_start informational changed step_started 0 none \
        "Bootstrap step started." "$log_ref"
    bootstrap_recorder_write_current_state
}

bootstrap_recorder_begin_operation() {
    local operation="$1"
    local target="${2:-none}"
    local log_ref="${3:-none}"

    BOOTSTRAP_RECORDER_CURRENT_OPERATION="$operation"
    BOOTSTRAP_RECORDER_CURRENT_TARGET="$target"
    BOOTSTRAP_RECORDER_OUTCOME="interrupted_incomplete"
    bootstrap_recorder_emit_event \
        operation_start informational changed operation_started 0 none \
        "Operation started for $target." "$log_ref"
    bootstrap_recorder_write_current_state
}

bootstrap_recorder_end_operation() {
    local disposition="$1"
    local failure_class="$2"
    local code="$3"
    local raw_status="$4"
    local recovery="$5"
    local message="$6"
    local log_ref="${7:-none}"
    local warning_count="${8:-1}"
    local severity="informational"

    case "$disposition" in
        optional_degraded)
            severity="warning"
            BOOTSTRAP_RECORDER_WARNING_COUNT=$((BOOTSTRAP_RECORDER_WARNING_COUNT + warning_count))
            if ! bootstrap_recorder_array_contains \
                    "$log_ref" \
                    ${BOOTSTRAP_RECORDER_WARNING_LOGS[@]+"${BOOTSTRAP_RECORDER_WARNING_LOGS[@]}"}; then
                BOOTSTRAP_RECORDER_WARNING_LOGS+=("$log_ref")
            fi
            ;;
        manual_action|required_failure|logging_failure|interrupted)
            severity="error"
            BOOTSTRAP_RECORDER_FAILED_STEP="$BOOTSTRAP_RECORDER_CURRENT_STEP"
            BOOTSTRAP_RECORDER_FAILED_OPERATION="$BOOTSTRAP_RECORDER_CURRENT_OPERATION"
            BOOTSTRAP_RECORDER_FAILURE_CLASS="$failure_class"
            BOOTSTRAP_RECORDER_FAILURE_CODE="$code"
            BOOTSTRAP_RECORDER_RAW_STATUS="$raw_status"
            BOOTSTRAP_RECORDER_RECOVERY="$recovery"
            BOOTSTRAP_RECORDER_RELEVANT_LOG="$log_ref"
            ;;
    esac

    bootstrap_recorder_emit_event \
        operation_end "$severity" "$disposition" "$code" "$raw_status" \
        "$recovery" "$message" "$log_ref" "$failure_class"
    BOOTSTRAP_RECORDER_CURRENT_OPERATION=""
    BOOTSTRAP_RECORDER_CURRENT_TARGET=""
    bootstrap_recorder_write_current_state
}

bootstrap_recorder_end_step() {
    local step_name="$1"
    local disposition="$2"
    local failure_class="$3"
    local code="$4"
    local raw_status="$5"
    local recovery="$6"
    local message="$7"
    local log_ref="${8:-none}"
    local severity="informational"

    BOOTSTRAP_RECORDER_CURRENT_STEP="$step_name"
    case "$disposition" in
        changed|satisfied|satisfied_compatible|optional_skipped|optional_degraded)
            if ! bootstrap_recorder_array_contains \
                    "$step_name" \
                    ${BOOTSTRAP_RECORDER_COMPLETED_STEPS[@]+"${BOOTSTRAP_RECORDER_COMPLETED_STEPS[@]}"}; then
                BOOTSTRAP_RECORDER_COMPLETED_STEPS+=("$step_name")
            fi
            ;;
        manual_action|required_failure|logging_failure|interrupted)
            severity="error"
            BOOTSTRAP_RECORDER_FAILED_STEP="$step_name"
            BOOTSTRAP_RECORDER_FAILURE_CLASS="$failure_class"
            BOOTSTRAP_RECORDER_FAILURE_CODE="$code"
            BOOTSTRAP_RECORDER_RAW_STATUS="$raw_status"
            BOOTSTRAP_RECORDER_RECOVERY="$recovery"
            BOOTSTRAP_RECORDER_RELEVANT_LOG="$log_ref"
            ;;
    esac
    [ "$disposition" = "optional_degraded" ] && severity="warning"

    bootstrap_recorder_emit_event \
        step_end "$severity" "$disposition" "$code" "$raw_status" \
        "$recovery" "$message" "$log_ref" "$failure_class"
    BOOTSTRAP_RECORDER_CURRENT_STEP=""
    bootstrap_recorder_write_current_state
}

bootstrap_recorder_note_warning() {
    local code="$1"
    local message="$2"
    local log_ref="${3:-none}"

    BOOTSTRAP_RECORDER_WARNING_COUNT=$((BOOTSTRAP_RECORDER_WARNING_COUNT + 1))
    if ! bootstrap_recorder_array_contains \
            "$log_ref" \
            ${BOOTSTRAP_RECORDER_WARNING_LOGS[@]+"${BOOTSTRAP_RECORDER_WARNING_LOGS[@]}"}; then
        BOOTSTRAP_RECORDER_WARNING_LOGS+=("$log_ref")
    fi
    bootstrap_recorder_emit_event \
        warning warning optional_degraded "$code" 0 retry_profile \
        "$message" "$log_ref" optional_degraded
    bootstrap_recorder_write_current_state
}

bootstrap_recorder_prepare_final_state() {
    local outcome="$1"
    local exit_status="$2"

    BOOTSTRAP_RECORDER_OUTCOME="$outcome"
    BOOTSTRAP_RECORDER_EXIT_STATUS="$exit_status"
    if [ "$outcome" = "completed" ] ||
            [ "$outcome" = "completed_with_warnings" ] ||
            [ "$outcome" = "manual_action_required" ] ||
            [ "$outcome" = "required_failure" ] ||
            [ "$outcome" = "logging_failure" ] ||
            [ "$outcome" = "interrupted" ]; then
        BOOTSTRAP_RECORDER_ENDED_AT="$(bootstrap_recorder_timestamp)"
    fi
    case "$outcome" in
        completed)
            BOOTSTRAP_RECORDER_RECOVERY="none"
            BOOTSTRAP_RECORDER_SAFE_ACTION="complete_profile_follow_up"
            BOOTSTRAP_RECORDER_RELEVANT_LOG="summary.txt"
            ;;
        completed_with_warnings)
            BOOTSTRAP_RECORDER_RECOVERY="retry_profile"
            BOOTSTRAP_RECORDER_SAFE_ACTION="review_warnings_then_complete_profile_follow_up"
            BOOTSTRAP_RECORDER_RELEVANT_LOG="$(
                bootstrap_recorder_join_csv \
                    ${BOOTSTRAP_RECORDER_WARNING_LOGS[@]+"${BOOTSTRAP_RECORDER_WARNING_LOGS[@]}"}
            )"
            ;;
        manual_action_required)
            BOOTSTRAP_RECORDER_SAFE_ACTION="complete_manual_action_then_rerun_same_profile"
            ;;
        required_failure|logging_failure|interrupted|interrupted_incomplete)
            BOOTSTRAP_RECORDER_SAFE_ACTION="review_relevant_log_then_rerun_same_profile"
            ;;
    esac
    bootstrap_recorder_write_current_state
}

bootstrap_recorder_finalize() {
    local outcome="$1"
    local exit_status="$2"
    local disposition="satisfied"
    local severity="informational"
    local code="run_completed"

    bootstrap_recorder_prepare_final_state "$outcome" "$exit_status"
    case "$outcome" in
        completed_with_warnings)
            disposition="optional_degraded"
            severity="warning"
            code="run_completed_with_warnings"
            ;;
        manual_action_required)
            disposition="manual_action"
            severity="error"
            code="run_manual_action_required"
            ;;
        required_failure)
            disposition="required_failure"
            severity="error"
            code="run_required_failure"
            ;;
        logging_failure)
            disposition="logging_failure"
            severity="error"
            code="run_logging_failure"
            ;;
        interrupted)
            disposition="interrupted"
            severity="error"
            code="run_interrupted"
            ;;
        interrupted_incomplete)
            disposition="interrupted"
            severity="error"
            code="run_interrupted_incomplete"
            ;;
    esac
    bootstrap_recorder_emit_event \
        run_end "$severity" "$disposition" "$code" "$exit_status" \
        "$BOOTSTRAP_RECORDER_RECOVERY" "Bootstrap run finalized." \
        "$BOOTSTRAP_RECORDER_RELEVANT_LOG" \
        "$BOOTSTRAP_RECORDER_FAILURE_CLASS"
    BOOTSTRAP_RECORDER_CURRENT_STEP=""
    BOOTSTRAP_RECORDER_CURRENT_OPERATION=""
    BOOTSTRAP_RECORDER_CURRENT_TARGET=""
    bootstrap_recorder_write_current_state
}

bootstrap_recorder_render_profile_guidance() {
    local profile="$1"
    local outcome="$2"

    case "$outcome" in
        manual_action_required)
            printf '%s\n' \
                "Manual action required:" \
                "  - Finish installing Xcode Command Line Tools." \
                "  - Re-run /bin/bash scripts/00-bootstrap.sh --profile $profile after the install completes."
            return
            ;;
        required_failure|logging_failure|interrupted|interrupted_incomplete)
            printf '%s\n' \
                "Recovery:" \
                "  - Review the relevant relative log named above." \
                "  - Preserve existing machine state; do not follow destructive vendor cleanup hints." \
                "  - Re-run /bin/bash scripts/00-bootstrap.sh --profile $profile after resolving the reported condition."
            return
            ;;
    esac

    case "$profile" in
        carlo-baseline)
            printf '%s\n' \
                "Recommended manual follow-up:" \
                "  - exec zsh" \
                "  - gh auth login --web --git-protocol https" \
                "  - gh auth setup-git" \
                "  - aws configure" \
                "  - launch gemini and complete OAuth if prompted" \
                "  - gws auth setup" \
                "  - codex login" \
                "  - claude auth login" \
                "  - open 1Password and confirm op account list works" \
                "" \
                "Zed trust follow-up:" \
                "  - Open /Users/carlo/dev in Zed" \
                "  - Use the Restricted Mode prompt or workspace::ToggleWorktreeSecurity" \
                "  - Trust all projects in the /Users/carlo/dev folder" \
                "" \
                "Optional next steps:" \
                "  - gemini skills list" \
                "  - ./scripts/08-op-inject-template.sh --help" \
                "  - ./scripts/09-inventory-ai-tooling.sh"
            ;;
        shared-baseline)
            printf '%s\n' \
                "Recommended manual follow-up:" \
                "  - exec zsh" \
                "  - gh auth login --web --git-protocol https" \
                "  - gh auth setup-git" \
                "  - codex login"
            ;;
    esac
}

bootstrap_recorder_render_final() {
    local log_dir="$1"
    local state_file="$BOOTSTRAP_RECORDER_STATE_FILE"
    local value=""
    local key=""

    printf '%s\n' \
        "" \
        "Bootstrap outcome: $BOOTSTRAP_RECORDER_OUTCOME" \
        "Source: $BOOTSTRAP_RECORDER_SOURCE_IDENTITY"

    for key in \
        failed_step \
        failed_operation \
        failure_class \
        failure_code \
        raw_status \
        completed_steps \
        remaining_steps \
        uncertain_work \
        warning_count \
        warning_logs \
        safe_action \
        rerun_command \
        relevant_log
    do
        value="$(sed -n "s/^${key}=//p" "$state_file" | head -n 1)"
        printf '%s: %s\n' "$key" "${value:-none}"
    done

    printf '%s\n' \
        "Bootstrap logs: $log_dir" \
        "Current state: current-state.txt" \
        "Structured events: events.tsv" \
        "Summary: summary.txt" \
        "Create a shareable bundle:" \
        "  /bin/bash scripts/create-shareable-bootstrap-bundle.sh --run-dir \"$log_dir\" --output-dir <new-directory>" \
        ""
    bootstrap_recorder_render_profile_guidance \
        "$BOOTSTRAP_RECORDER_PROFILE" \
        "$BOOTSTRAP_RECORDER_OUTCOME"
}
