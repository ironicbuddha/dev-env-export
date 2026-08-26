#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_ROOT="$REPO_ROOT/project-standards"

(
    cd "$PACKAGE_ROOT"
    corepack pnpm typecheck
    corepack pnpm test
)
