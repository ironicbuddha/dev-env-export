#!/bin/bash
# Compatibility seam for callers that have not yet moved to managed-artifact.

BOOTSTRAP_MANAGED_SHELL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$BOOTSTRAP_MANAGED_SHELL_LIB_DIR/managed-artifact.sh"

bootstrap_write_managed_shell_block() {
    bootstrap_managed_artifact_replace_managed_block "$@"
}
