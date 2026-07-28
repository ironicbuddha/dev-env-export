#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-uv-environment-tests.XXXXXX")"

# shellcheck disable=SC1091
source "$REPO_ROOT/tests/lib/fresh-process-harness.sh"

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    return 1
}

setup_case() {
    local case_name="$1"
    local case_root="$TEST_TMP_ROOT/$case_name"
    local python_prefix="$case_root/python-3.14"

    bootstrap_test_case_init "$case_root"
    bootstrap_test_install_stateful_uv "$case_root"
    mkdir -p "$python_prefix/bin"

    cat > "$case_root/fake-bin/brew" <<EOF
#!/bin/bash
[ "\${1:-}" = "--prefix" ] &&
    [ "\${2:-}" = "python@3.14" ] &&
    printf '%s\\n' "$python_prefix"
EOF
    cat > "$python_prefix/bin/python3.14" <<'EOF'
#!/bin/bash
printf '%s\n' "Python 3.14.0"
EOF
    chmod +x "$case_root/fake-bin/brew" "$python_prefix/bin/python3.14"

    printf '%s\n' "$case_root"
}

run_step() {
    local case_root="$1"
    local output_file="$2"
    local profile="${3:-shared-baseline}"

    bootstrap_test_run_with_env \
        "$case_root" \
        "$output_file" \
        DEV_ENV_UV_ENV_DIR="$case_root/bootstrap-python" \
        DEV_ENV_BOOTSTRAP_RUN_ID="test-run" \
        -- \
        /bin/bash "$REPO_ROOT/scripts/04-install-pip-packages.sh" \
        --profile "$profile"
}

run_adapter() {
    local case_root="$1"
    local output_file="$2"
    shift 2

    bootstrap_test_run_with_env \
        "$case_root" \
        "$output_file" \
        -- \
        /bin/bash "$REPO_ROOT/scripts/lib/managed-python-environment.sh" \
        ensure \
        --python "$case_root/python-3.14/bin/python3.14" \
        --environment "$case_root/bootstrap-python" \
        --profile shared-baseline \
        --source-id contract-test \
        --run-id test-run \
        "$@"
}

test_document_stack_uses_convergent_bootstrap_owned_uv_environment() {
    local case_root=""
    local output_file=""
    local environment_dir=""
    local manifest_digest_before=""

    case_root="$(setup_case convergent)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"

    run_step "$case_root" "$output_file" ||
        fail "first step-04 invocation should create the managed environment"
    [ -f "$environment_dir/.dev-env-bootstrap-owner" ] ||
        fail "the managed environment should contain an ownership manifest"
    grep -Fq $'uv\tvenv ' "$case_root/calls.log" ||
        fail "absence should create the managed environment"
    grep -Fq $'uv\tpip install --python '"$environment_dir/bin/python python-docx" \
        "$case_root/calls.log" ||
        fail "step 4 should install the document stack into the managed environment"
    manifest_digest_before="$(shasum -a 256 \
        "$environment_dir/.dev-env-bootstrap-owner" | awk '{print $1}')"
    : > "$case_root/calls.log"

    run_step "$case_root" "$output_file" ||
        fail "an immediate second run should reuse the valid environment"

    if grep -Fq $'uv\tvenv ' "$case_root/calls.log"; then
        fail "an immediate second run should not invoke uv venv"
    fi
    if grep -Fq $'uv\tpip install ' "$case_root/calls.log"; then
        fail "an immediate second run should not mutate packages"
    fi
    [ "$manifest_digest_before" = "$(shasum -a 256 \
        "$environment_dir/.dev-env-bootstrap-owner" | awk '{print $1}')" ] ||
        fail "an immediate second run should not rewrite the ownership manifest"
    if find "$case_root" -maxdepth 1 \
            \( -name 'bootstrap-python.staging.*' -o \
                -name 'bootstrap-python.quarantine.*' \) \
            -print -quit | grep -q .; then
        fail "an immediate second run should create no staging or quarantine"
    fi
    if grep -Fq -- '--clear' "$case_root/calls.log"; then
        fail "managed Python convergence must never use uv venv --clear"
    fi
}

test_wrong_interpreter_owned_environment_is_quarantined_and_rebuilt() {
    local case_root=""
    local output_file=""
    local environment_dir=""
    local quarantine_dir=""

    case_root="$(setup_case wrong-interpreter)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"

    run_step "$case_root" "$output_file" ||
        fail "fixture setup should create the managed environment"
    cat > "$environment_dir/bin/python" <<'EOF'
#!/bin/bash
printf '%s\n' "Python 3.13.9"
EOF
    chmod +x "$environment_dir/bin/python"
    : > "$case_root/calls.log"

    run_step "$case_root" "$output_file" ||
        fail "a wrong-interpreter owned environment should be rebuilt"

    quarantine_dir="$(find "$case_root" -maxdepth 1 -type d \
        -name 'bootstrap-python.quarantine.*' -print -quit)"
    [ -n "$quarantine_dir" ] ||
        fail "the invalid owned environment should be retained in quarantine"
    grep -Fq "Python 3.13.9" "$quarantine_dir/bin/python" ||
        fail "quarantine should preserve the invalid environment as evidence"
    [ "$("$environment_dir/bin/python" --version)" = "Python 3.14.0" ] ||
        fail "the replacement should use the declared Python line"
    [ "$(grep -Fc $'uv\tvenv ' "$case_root/calls.log")" -eq 1 ] ||
        fail "rebuild should make one uv venv call"
}

test_compatible_python_patch_is_reused_without_recreation() {
    local case_root=""
    local output_file=""
    local environment_dir=""
    local python_bin=""

    case_root="$(setup_case compatible-patch)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"
    python_bin="$case_root/python-3.14/bin/python3.14"

    run_step "$case_root" "$output_file" ||
        fail "fixture setup should create the managed environment"
    cat > "$python_bin" <<'EOF'
#!/bin/bash
printf '%s\n' "Python 3.14.1"
EOF
    chmod +x "$python_bin"
    : > "$case_root/calls.log"

    run_step "$case_root" "$output_file" ||
        fail "a compatible Python patch change should preserve the environment"

    grep -Fq "state=valid_compatible disposition=satisfied_compatible" "$output_file" ||
        fail "the adapter should report compatible reuse explicitly"
    if grep -Fq $'uv\tvenv ' "$case_root/calls.log"; then
        fail "compatible Python patch drift should not invoke uv venv"
    fi
    [ "$("$environment_dir/bin/python" --version)" = "Python 3.14.0" ] ||
        fail "compatible reuse should preserve the existing environment"
}

test_package_failure_retains_owned_environment_and_reports_forward_recovery() {
    local case_root=""
    local output_file=""
    local environment_dir=""

    case_root="$(setup_case package-failure)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"
    printf '%s\n' "pypdf" > "$case_root/state/uv.install-failure-package"
    printf '%s\n' "75" > "$case_root/state/uv.install-failure-status"

    if run_step "$case_root" "$output_file"; then
        fail "a package-manager failure should fail required step 04"
    fi

    [ -d "$environment_dir" ] ||
        fail "package failure should retain the owned environment"
    grep -Fq "package_status=partial" \
        "$environment_dir/.dev-env-bootstrap-owner" ||
        fail "the ownership manifest should record partial package work"
    grep -Fq "installed=python-docx,openpyxl,python-pptx" "$output_file" ||
        fail "failure output should report verified installed work"
    grep -Fq "missing=pypdf" "$output_file" ||
        fail "failure output should report verified missing work"
    grep -Fq "uncertain=pdfplumber,pillow,pytesseract,reportlab" "$output_file" ||
        fail "failure output should report work not yet inspected"

    rm "$case_root/state/uv.install-failure-package"
    : > "$case_root/calls.log"
    run_step "$case_root" "$output_file" ||
        fail "the next run should resume package work forward"

    if grep -Fq $'uv\tvenv ' "$case_root/calls.log"; then
        fail "package recovery should not recreate the valid environment"
    fi
    if grep -Fq $'uv\tpip install --python '"$environment_dir/bin/python python-docx" \
            "$case_root/calls.log"; then
        fail "package recovery should not reinstall verified package work"
    fi
    grep -Fq "package_status=complete" \
        "$environment_dir/.dev-env-bootstrap-owner" ||
        fail "successful forward recovery should mark package work complete"
}

test_interrupted_owned_staging_is_removed_before_reinspection() {
    local case_root=""
    local output_file=""
    local environment_dir=""
    local interrupted_staging=""

    case_root="$(setup_case interrupted-staging)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"
    interrupted_staging="$environment_dir.staging.interrupted-run"
    mkdir -p "$interrupted_staging/bin"
    printf '%s\n' "$environment_dir" > \
        "$interrupted_staging/.dev-env-bootstrap-staging"
    printf '%s\n' "partial evidence" > "$interrupted_staging/bin/partial"

    run_step "$case_root" "$output_file" ||
        fail "owned interrupted staging should be recoverable"

    [ ! -e "$interrupted_staging" ] ||
        fail "proven owned staging should be removed before a fresh attempt"
    [ -d "$environment_dir" ] ||
        fail "the final target should be created after staging recovery"
    grep -Fq "state=interrupted disposition=changed action=remove_owned_staging" \
        "$output_file" ||
        fail "staging recovery should be observable"
}

test_corrupt_owned_environment_is_quarantined_and_rebuilt() {
    local case_root=""
    local output_file=""
    local environment_dir=""
    local quarantine_dir=""

    case_root="$(setup_case corrupt-owned)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"

    run_step "$case_root" "$output_file" ||
        fail "fixture setup should create the managed environment"
    printf '%s\n' "not a pyvenv configuration" > "$environment_dir/pyvenv.cfg"
    : > "$case_root/calls.log"

    run_step "$case_root" "$output_file" ||
        fail "a corrupt owned environment should be rebuilt"

    quarantine_dir="$(find "$case_root" -maxdepth 1 -type d \
        -name 'bootstrap-python.quarantine.*' -print -quit)"
    [ -n "$quarantine_dir" ] ||
        fail "the corrupt owned environment should be retained in quarantine"
    grep -Fq "not a pyvenv configuration" "$quarantine_dir/pyvenv.cfg" ||
        fail "quarantine should retain the corrupt environment evidence"
    grep -Eq '^(version|version_info)[[:space:]]*=' \
        "$environment_dir/pyvenv.cfg" ||
        fail "the replacement should contain a valid pyvenv configuration"
}

test_missing_package_is_the_only_package_mutation() {
    local case_root=""
    local output_file=""
    local environment_dir=""
    local package_state=""
    local candidate_state=""

    case_root="$(setup_case missing-package)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"
    package_state="$environment_dir/.fake-uv-packages.tsv"
    candidate_state="$environment_dir/.fake-uv-packages.candidate"

    run_step "$case_root" "$output_file" ||
        fail "fixture setup should create the managed package set"
    awk -F '\t' '$1 != "pypdf"' "$package_state" > "$candidate_state"
    mv "$candidate_state" "$package_state"
    : > "$case_root/calls.log"

    run_step "$case_root" "$output_file" ||
        fail "a missing package should be installed forward"

    [ "$(grep -Fc $'uv\tpip install ' "$case_root/calls.log")" -eq 1 ] ||
        fail "only one package mutation should occur"
    grep -Fq $'uv\tpip install --python '"$environment_dir/bin/python pypdf" \
        "$case_root/calls.log" ||
        fail "the missing package should be the only install"
    if grep -Fq $'uv\tvenv ' "$case_root/calls.log"; then
        fail "package convergence should preserve the valid environment"
    fi
}

test_exact_package_version_drift_is_converged_without_recreation() {
    local case_root=""
    local output_file=""
    local environment_dir=""

    case_root="$(setup_case exact-package)"
    output_file="$case_root/output/adapter.txt"
    environment_dir="$case_root/bootstrap-python"

    run_adapter "$case_root" "$output_file" --package 'demo-package==2.0.0' ||
        fail "fixture setup should install the exact package declaration"
    printf 'demo-package\t1.0.0\n' >> \
        "$environment_dir/.fake-uv-packages.tsv"
    : > "$case_root/calls.log"

    run_adapter "$case_root" "$output_file" --package 'demo-package==2.0.0' ||
        fail "out-of-policy package drift should converge"

    grep -Fq $'uv\tpip install --python '"$environment_dir/bin/python demo-package==2.0.0" \
        "$case_root/calls.log" ||
        fail "the adapter should reinstall the declared exact version"
    if grep -Fq $'uv\tvenv ' "$case_root/calls.log"; then
        fail "package version drift should not recreate a valid environment"
    fi
}

test_foreign_target_types_are_preserved_as_conflicts() {
    local directory_case=""
    local symlink_case=""
    local file_case=""
    local output_file=""

    directory_case="$(setup_case foreign-directory)"
    mkdir -p "$directory_case/bootstrap-python"
    printf '%s\n' "keep directory" > "$directory_case/bootstrap-python/sentinel"
    output_file="$directory_case/output/step-04.txt"
    if run_step "$directory_case" "$output_file"; then
        fail "an unmarked directory should be a conflict"
    fi
    grep -Fq "code=managed_python_environment_unmarked" "$output_file" ||
        fail "an unmarked directory should have a precise conflict code"
    grep -Fq "keep directory" "$directory_case/bootstrap-python/sentinel" ||
        fail "an unmarked directory should remain unchanged"

    symlink_case="$(setup_case foreign-symlink)"
    mkdir -p "$symlink_case/foreign-environment"
    printf '%s\n' "keep symlink target" > \
        "$symlink_case/foreign-environment/sentinel"
    ln -s "$symlink_case/foreign-environment" \
        "$symlink_case/bootstrap-python"
    output_file="$symlink_case/output/step-04.txt"
    if run_step "$symlink_case" "$output_file"; then
        fail "a symlink target should be a conflict"
    fi
    [ -L "$symlink_case/bootstrap-python" ] ||
        fail "the environment symlink should be preserved"
    grep -Fq "keep symlink target" \
        "$symlink_case/foreign-environment/sentinel" ||
        fail "the symlink destination should remain unchanged"

    file_case="$(setup_case foreign-file)"
    printf '%s\n' "keep file" > "$file_case/bootstrap-python"
    output_file="$file_case/output/step-04.txt"
    if run_step "$file_case" "$output_file"; then
        fail "a non-directory target should be a conflict"
    fi
    grep -Fq "keep file" "$file_case/bootstrap-python" ||
        fail "a non-directory target should remain unchanged"
}

test_creation_permission_failure_preserves_final_target() {
    local case_root=""
    local output_file=""

    case_root="$(setup_case permission-failure)"
    output_file="$case_root/output/step-04.txt"
    printf '%s\n' "73" > "$case_root/state/uv.venv-failure-status"

    if run_step "$case_root" "$output_file"; then
        fail "an environment creation failure should fail required step 04"
    fi

    [ ! -e "$case_root/bootstrap-python" ] ||
        fail "a failed staged creation should not promote a final target"
    grep -Fq "code=managed_python_create_failed" "$output_file" ||
        fail "creation failure should provide a precise recovery code"
}

test_partial_owned_environment_is_quarantined_and_rebuilt() {
    local case_root=""
    local output_file=""
    local environment_dir=""
    local quarantine_dir=""

    case_root="$(setup_case partial-owned)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"

    run_step "$case_root" "$output_file" ||
        fail "fixture setup should create the managed environment"
    mv "$environment_dir/bin/python" "$environment_dir/bin/python.partial"
    : > "$case_root/calls.log"

    run_step "$case_root" "$output_file" ||
        fail "a partial owned environment should be rebuilt"

    quarantine_dir="$(find "$case_root" -maxdepth 1 -type d \
        -name 'bootstrap-python.quarantine.*' -print -quit)"
    [ -f "$quarantine_dir/bin/python.partial" ] ||
        fail "quarantine should retain partial owned state as evidence"
    [ -x "$environment_dir/bin/python" ] ||
        fail "the replacement environment should be usable"
}

test_carlo_profile_routes_through_the_same_convergent_adapter() {
    local case_root=""
    local output_file=""
    local environment_dir=""

    case_root="$(setup_case carlo-profile)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"

    run_step "$case_root" "$output_file" carlo-baseline ||
        fail "Carlo Baseline should create the shared managed environment"
    grep -Fq $'uv\tpip install --python '"$environment_dir/bin/python pydantic" \
        "$case_root/calls.log" ||
        fail "Carlo Baseline should add its declared package set"
    : > "$case_root/calls.log"

    run_step "$case_root" "$output_file" carlo-baseline ||
        fail "Carlo Baseline should converge on immediate rerun"
    if grep -Eq $'uv\t(venv|pip install) ' "$case_root/calls.log"; then
        fail "Carlo Baseline immediate rerun should make no environment or package mutation"
    fi
}

test_unknown_ownership_manifest_is_preserved_without_repair() {
    local case_root=""
    local output_file=""
    local environment_dir=""

    case_root="$(setup_case unknown-ownership)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"
    mkdir -p "$environment_dir"
    {
        printf 'owner=dev-env-bootstrap\n'
        printf 'schema_version=1\n'
        printf 'environment_path=%s\n' "$environment_dir"
        printf 'interpreter_policy=3.14\n'
    } > "$environment_dir/.dev-env-bootstrap-owner"
    printf '%s\n' "preserve unknown state" > "$environment_dir/sentinel"

    if run_step "$case_root" "$output_file"; then
        fail "an incomplete ownership manifest should stop required work"
    fi

    grep -Fq "state=unknown" "$output_file" ||
        fail "an incomplete manifest should classify the target as unknown"
    grep -Fq "code=managed_python_ownership_manifest_invalid" "$output_file" ||
        fail "unknown ownership should provide a precise manual recovery code"
    grep -Fq "preserve unknown state" "$environment_dir/sentinel" ||
        fail "unknown state should remain unchanged"
    if find "$case_root" -maxdepth 1 \
            -name 'bootstrap-python.quarantine.*' -print -quit | grep -q .; then
        fail "unknown state should never inherit managed repair authority"
    fi
}

test_verified_recovery_closes_partial_manifest_without_package_mutation() {
    local case_root=""
    local output_file=""
    local environment_dir=""

    case_root="$(setup_case verified-partial-recovery)"
    output_file="$case_root/output/step-04.txt"
    environment_dir="$case_root/bootstrap-python"
    printf '%s\n' "reportlab" > "$case_root/state/uv.install-failure-package"
    : > "$case_root/state/uv.install-failure-after-write"

    if run_step "$case_root" "$output_file"; then
        fail "the simulated vendor failure should fail required step 04"
    fi
    grep -Fq "package_status=partial" \
        "$environment_dir/.dev-env-bootstrap-owner" ||
        fail "the vendor failure should leave a partial package cursor"

    rm "$case_root/state/uv.install-failure-package"
    : > "$case_root/calls.log"
    run_step "$case_root" "$output_file" ||
        fail "a fully verified package set should close partial recovery"

    if grep -Fq $'uv\tpip install ' "$case_root/calls.log"; then
        fail "verified recovery should not reinstall already present packages"
    fi
    grep -Fq "package_status=complete" \
        "$environment_dir/.dev-env-bootstrap-owner" ||
        fail "verified recovery should close the partial package cursor"
}

test_out_of_policy_requested_interpreter_fails_before_mutation() {
    local case_root=""
    local output_file=""
    local python_bin=""

    case_root="$(setup_case out-of-policy-interpreter)"
    output_file="$case_root/output/adapter.txt"
    python_bin="$case_root/python-3.13/bin/python3.13"
    mkdir -p "$(dirname "$python_bin")"
    cat > "$python_bin" <<'EOF'
#!/bin/bash
printf '%s\n' "Python 3.13.9"
EOF
    chmod +x "$python_bin"

    if bootstrap_test_run_with_env \
            "$case_root" \
            "$output_file" \
            -- \
            /bin/bash "$REPO_ROOT/scripts/lib/managed-python-environment.sh" \
            ensure \
            --python "$python_bin" \
            --environment "$case_root/bootstrap-python" \
            --profile shared-baseline \
            --source-id contract-test \
            --run-id test-run; then
        fail "an out-of-policy requested interpreter should fail"
    fi

    grep -Fq "code=managed_python_interpreter_out_of_policy" "$output_file" ||
        fail "the interpreter policy failure should be precise"
    [ ! -e "$case_root/bootstrap-python" ] ||
        fail "an out-of-policy interpreter should not create a final target"
    if grep -Fq $'uv\tvenv ' "$case_root/calls.log"; then
        fail "interpreter policy validation should happen before uv mutation"
    fi
}

test_document_stack_uses_convergent_bootstrap_owned_uv_environment
echo "ok 1 - document_stack_uses_convergent_bootstrap_owned_uv_environment"
test_wrong_interpreter_owned_environment_is_quarantined_and_rebuilt
echo "ok 2 - wrong_interpreter_owned_environment_is_quarantined_and_rebuilt"
test_compatible_python_patch_is_reused_without_recreation
echo "ok 3 - compatible_python_patch_is_reused_without_recreation"
test_package_failure_retains_owned_environment_and_reports_forward_recovery
echo "ok 4 - package_failure_retains_owned_environment_and_reports_forward_recovery"
test_interrupted_owned_staging_is_removed_before_reinspection
echo "ok 5 - interrupted_owned_staging_is_removed_before_reinspection"
test_corrupt_owned_environment_is_quarantined_and_rebuilt
echo "ok 6 - corrupt_owned_environment_is_quarantined_and_rebuilt"
test_missing_package_is_the_only_package_mutation
echo "ok 7 - missing_package_is_the_only_package_mutation"
test_exact_package_version_drift_is_converged_without_recreation
echo "ok 8 - exact_package_version_drift_is_converged_without_recreation"
test_foreign_target_types_are_preserved_as_conflicts
echo "ok 9 - foreign_target_types_are_preserved_as_conflicts"
test_creation_permission_failure_preserves_final_target
echo "ok 10 - creation_permission_failure_preserves_final_target"
test_partial_owned_environment_is_quarantined_and_rebuilt
echo "ok 11 - partial_owned_environment_is_quarantined_and_rebuilt"
test_carlo_profile_routes_through_the_same_convergent_adapter
echo "ok 12 - carlo_profile_routes_through_the_same_convergent_adapter"
test_unknown_ownership_manifest_is_preserved_without_repair
echo "ok 13 - unknown_ownership_manifest_is_preserved_without_repair"
test_verified_recovery_closes_partial_manifest_without_package_mutation
echo "ok 14 - verified_recovery_closes_partial_manifest_without_package_mutation"
test_out_of_policy_requested_interpreter_fails_before_mutation
echo "ok 15 - out_of_policy_requested_interpreter_fails_before_mutation"
echo "1..15"
