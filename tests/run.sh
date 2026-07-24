#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Checking shell syntax..."
find "$REPO_ROOT/scripts" "$REPO_ROOT/manifest" "$REPO_ROOT/tests" \
    -type f -name '*.sh' -print0 |
    while IFS= read -r -d '' shell_file; do
        /bin/bash -n "$shell_file"
    done

echo "Running bootstrap contract tests..."
/bin/bash "$REPO_ROOT/tests/bootstrap_contract_test.sh"

echo "Running resilience contract tests..."
/bin/bash "$REPO_ROOT/tests/resilience_contract_test.sh"

echo "Running npm globals contract tests..."
/bin/bash "$REPO_ROOT/tests/npm_globals_contract_test.sh"

echo "Running uv environment contract tests..."
/bin/bash "$REPO_ROOT/tests/uv_environment_contract_test.sh"

echo "Running Skill Hub contract tests..."
/bin/bash "$REPO_ROOT/tests/skill_hub_contract_test.sh"

echo "Running project standards contract tests..."
/bin/bash "$REPO_ROOT/tests/project_standards_contract_test.sh"
