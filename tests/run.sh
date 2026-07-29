#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_suite() {
    local evidence_class="$1"
    local suite_name="$2"
    local suite_path="$3"

    echo ""
    echo "[evidence=$evidence_class] Running $suite_name..."
    /bin/bash "$suite_path"
}

echo "Checking shell syntax..."
find "$REPO_ROOT/scripts" "$REPO_ROOT/manifest" "$REPO_ROOT/tests" \
    -type f -name '*.sh' -print0 |
    while IFS= read -r -d '' shell_file; do
        /bin/bash -n "$shell_file"
    done

run_suite \
    "helper" \
    "bootstrap contract vocabulary tests" \
    "$REPO_ROOT/tests/bootstrap_contract_vocabulary_test.sh"

run_suite \
    "helper" \
    "fresh-process harness tests" \
    "$REPO_ROOT/tests/fresh_process_harness_test.sh"

run_suite \
    "helper" \
    "run-recorder contract tests" \
    "$REPO_ROOT/tests/run_recorder_contract_test.sh"

run_suite \
    "orchestrator" \
    "run-coordinator contract tests" \
    "$REPO_ROOT/tests/run_coordinator_contract_test.sh"

run_suite \
    "step" \
    "Homebrew operation contract tests" \
    "$REPO_ROOT/tests/homebrew_operations_contract_test.sh"

run_suite \
    "helper" \
    "managed-artifact contract tests" \
    "$REPO_ROOT/tests/managed_artifact_contract_test.sh"

run_suite \
    "step" \
    "npm configuration contract tests" \
    "$REPO_ROOT/tests/npm_configuration_contract_test.sh"

run_suite \
    "orchestrator" \
    "bootstrap contract tests" \
    "$REPO_ROOT/tests/bootstrap_contract_test.sh"

run_suite \
    "classified-per-test" \
    "resilience contract tests" \
    "$REPO_ROOT/tests/resilience_contract_test.sh"

run_suite \
    "step" \
    "npm globals contract tests" \
    "$REPO_ROOT/tests/npm_globals_contract_test.sh"

run_suite \
    "step" \
    "nvm runtime contract tests" \
    "$REPO_ROOT/tests/nvm_runtime_contract_test.sh"

run_suite \
    "step" \
    "Bun fallback contract tests" \
    "$REPO_ROOT/tests/bun_fallback_contract_test.sh"

run_suite \
    "step" \
    "remote installer contract tests" \
    "$REPO_ROOT/tests/remote_installer_contract_test.sh"

run_suite \
    "step" \
    "uv environment contract tests" \
    "$REPO_ROOT/tests/uv_environment_contract_test.sh"

run_suite \
    "step-real-adapter" \
    "real uv environment regression" \
    "$REPO_ROOT/tests/uv_environment_real_regression_test.sh"

run_suite \
    "classified-per-test" \
    "Skill Hub contract tests" \
    "$REPO_ROOT/tests/skill_hub_contract_test.sh"

run_suite \
    "step" \
    "project standards contract tests" \
    "$REPO_ROOT/tests/project_standards_contract_test.sh"

echo ""
echo "[evidence=machine-acceptance] Not run by the hermetic suite; use the clean-machine release gate."
