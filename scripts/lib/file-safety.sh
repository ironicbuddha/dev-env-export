#!/bin/bash
# Compatibility seam for callers that have not yet moved to managed-artifact.

BOOTSTRAP_FILE_SAFETY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$BOOTSTRAP_FILE_SAFETY_LIB_DIR/managed-artifact.sh"

bootstrap_copy_file_with_backup() {
    local source_path="$1"
    local destination_path="$2"
    local backup_dir="$3"
    local requested_backup_target="${4:-}"

    if [ -n "$requested_backup_target" ]; then
        backup_dir="$(dirname "$requested_backup_target")"
    fi

    bootstrap_managed_artifact_install_exact \
        "$source_path" "$destination_path" "$backup_dir"
}
