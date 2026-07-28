#!/bin/bash
# Create a deterministic, whitelist-based diagnostic bundle safe for sharing.

set -euo pipefail

usage() {
    printf '%s\n' \
        "Usage: /bin/bash scripts/create-shareable-bootstrap-bundle.sh \\" \
        "  --run-dir RUN_DIRECTORY --output-dir NEW_DIRECTORY" \
        "" \
        "Creates a sanitized directory without raw transcripts or environment snapshots."
}

RUN_DIR=""
OUTPUT_DIR=""
BUNDLE_DIR=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --run-dir)
            [ "$#" -ge 2 ] || {
                usage >&2
                exit 2
            }
            RUN_DIR="$2"
            shift 2
            ;;
        --output-dir)
            [ "$#" -ge 2 ] || {
                usage >&2
                exit 2
            }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'ERROR: Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[ -n "$RUN_DIR" ] && [ -n "$OUTPUT_DIR" ] || {
    usage >&2
    exit 2
}
[ -d "$RUN_DIR" ] && [ ! -L "$RUN_DIR" ] || {
    printf 'ERROR: Run directory must be a real directory: %s\n' "$RUN_DIR" >&2
    exit 1
}
[ -f "$RUN_DIR/current-state.txt" ] && [ ! -L "$RUN_DIR/current-state.txt" ] || {
    printf 'ERROR: Missing regular current-state.txt in %s\n' "$RUN_DIR" >&2
    exit 1
}
[ -f "$RUN_DIR/events.tsv" ] && [ ! -L "$RUN_DIR/events.tsv" ] || {
    printf 'ERROR: Missing regular events.tsv in %s\n' "$RUN_DIR" >&2
    exit 1
}
[ ! -e "$OUTPUT_DIR" ] && [ ! -L "$OUTPUT_DIR" ] || {
    printf 'ERROR: Output path already exists: %s\n' "$OUTPUT_DIR" >&2
    exit 1
}

OUTPUT_PARENT="$(dirname "$OUTPUT_DIR")"
OUTPUT_NAME="$(basename "$OUTPUT_DIR")"
[ -d "$OUTPUT_PARENT" ] && [ ! -L "$OUTPUT_PARENT" ] || {
    printf 'ERROR: Output parent must be a real directory: %s\n' "$OUTPUT_PARENT" >&2
    exit 1
}
BUNDLE_DIR="$(mktemp -d "$OUTPUT_PARENT/.${OUTPUT_NAME}.staging.XXXXXX")"
chmod 0700 "$BUNDLE_DIR"

cleanup() {
    if [ -n "$BUNDLE_DIR" ] && [ -d "$BUNDLE_DIR" ]; then
        rm -rf "$BUNDLE_DIR"
    fi
}

trap cleanup EXIT

awk -F= '
    BEGIN {
        print "privacy=shareable-sanitized"
    }
    $1 == "schema_version" ||
    $1 == "bootstrap_profile" ||
    $1 == "source_kind" ||
    $1 == "source_identity" ||
    $1 == "outcome" ||
    $1 == "exit_status" ||
    $1 == "failed_step" ||
    $1 == "failed_operation" ||
    $1 == "failure_class" ||
    $1 == "failure_code" ||
    $1 == "raw_status" ||
    $1 == "completed_steps" ||
    $1 == "remaining_steps" ||
    $1 == "uncertain_work" ||
    $1 == "warning_count" ||
    $1 == "warning_logs" ||
    $1 == "recovery" ||
    $1 == "safe_action" {
        print
    }
' "$RUN_DIR/current-state.txt" > "$BUNDLE_DIR/summary.txt"

profile="$(sed -n 's/^bootstrap_profile=//p' "$RUN_DIR/current-state.txt" | head -n 1)"
relevant_log="$(sed -n 's/^relevant_log=//p' "$RUN_DIR/current-state.txt" | head -n 1)"
relevant_log="${relevant_log##*/}"
{
    printf 'rerun_command=/bin/bash scripts/00-bootstrap.sh --profile %s\n' \
        "${profile:-unknown}"
    printf 'relevant_log=%s\n' "${relevant_log:-none}"
} >> "$BUNDLE_DIR/summary.txt"

awk -F '\t' 'BEGIN { OFS="\t" }
    NR == 1 {
        print "sequence", "event_type", "timestamp", "severity", \
            "disposition", "failure_class", "code", "step", "operation", \
            "raw_status", "recovery", "log_ref"
        next
    }
    {
        sub(/^.*\//, "", $8)
        sub(/^.*\//, "", $14)
        print $1, $2, $3, $4, $5, $6, $7, $8, $9, $11, $12, $14
    }
' "$RUN_DIR/events.tsv" > "$BUNDLE_DIR/events.tsv"

printf '%s\n' \
    "Sanitized bootstrap diagnostic bundle" \
    "Privacy class: shareable-sanitized" \
    "This bundle is generated explicitly and is never uploaded automatically." \
    > "$BUNDLE_DIR/README.txt"

printf '%s\n' \
    "Raw transcripts and environment snapshots are excluded." \
    "Per-step raw logs are excluded." \
    "Event messages and targets are excluded." \
    "User, host, home, repository, and log-directory paths are excluded." \
    "Git status filenames and other nonessential identifiers are excluded." \
    "Credentials, auth tokens, cloud profiles, 1Password output, master environment files, and secret-bearing arguments are excluded." \
    > "$BUNDLE_DIR/redactions.txt"

chmod 0600 \
    "$BUNDLE_DIR/README.txt" \
    "$BUNDLE_DIR/events.tsv" \
    "$BUNDLE_DIR/redactions.txt" \
    "$BUNDLE_DIR/summary.txt"

mv "$BUNDLE_DIR" "$OUTPUT_DIR"
BUNDLE_DIR=""
trap - EXIT
printf 'Shareable bundle created: %s\n' "$OUTPUT_DIR"
