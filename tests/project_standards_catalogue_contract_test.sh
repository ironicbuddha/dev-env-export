#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_ROOT="$REPO_ROOT/project-standards"

corepack pnpm --dir "$PACKAGE_ROOT" typecheck
corepack pnpm --dir "$PACKAGE_ROOT" test
