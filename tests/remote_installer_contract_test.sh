#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-remote-installer-tests.XXXXXX")"
TEST_COUNT=0

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run_test() {
    local name="$1"

    "$name"
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "ok $TEST_COUNT - $name"
}

load_fixture() {
    local fixture_root="$1"

    mkdir -p "$fixture_root/bin" "$fixture_root/home"
cat > "$fixture_root/bin/curl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$TEST_REMOTE_LOG"
if [ -n "${TEST_REMOTE_CURL_FAILURE_OUTPUT:-}" ]; then
    printf '%s\n' "$TEST_REMOTE_CURL_FAILURE_OUTPUT" >&2
    exit "${TEST_REMOTE_CURL_STATUS:-22}"
fi
while [ "$#" -gt 0 ]; do
    if [ "$1" = "-o" ]; then
        if [ "${TEST_REMOTE_CURL_EMPTY:-0}" = 1 ]; then
            : > "$2"
            exit 0
        fi
        cp "$TEST_REMOTE_INSTALLER" "$2"
        exit 0
    fi
    shift
done
exit 1
EOF
    chmod +x "$fixture_root/bin/curl"
    export HOME="$fixture_root/home"
    export PATH="$fixture_root/bin:/usr/bin:/bin"
    export TEST_REMOTE_LOG="$fixture_root/curl.log"
    export TEST_REMOTE_INSTALLER="$fixture_root/installer.sh"
    export BOOTSTRAP_OPERATION_EVENT_FILE="$fixture_root/events.tsv"
    export DEV_ENV_OH_MY_ZSH_INSTALLER_URL="https://source.example.test/oh-my-zsh-install.sh"
    printf '%s\n' $'sequence\tevent_type\ttimestamp\tseverity\tdisposition\tfailure_class\tcode\tstep\toperation\ttarget\traw_status\trecovery\tmessage\tlog_ref' \
        > "$BOOTSTRAP_OPERATION_EVENT_FILE"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/remote-installer.sh"
}

write_installer() {
    local fixture_root="$1"

    cat > "$fixture_root/installer.sh" <<'EOF'
#!/bin/sh
mkdir -p "$HOME/.oh-my-zsh/lib" "$HOME/.oh-my-zsh/plugins" "$HOME/.oh-my-zsh/themes"
printf 'loaded\n' > "$HOME/.oh-my-zsh/oh-my-zsh.sh"
EOF
    chmod +x "$fixture_root/installer.sh"
}

test_missing_oh_my_zsh_uses_staging_and_verifies_installed_state() {
    local fixture_root="$TEST_TMP_ROOT/missing"

    load_fixture "$fixture_root"
    write_installer "$fixture_root"

    bootstrap_ensure_oh_my_zsh || fail "missing Oh My Zsh should install through the adapter"

    [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ] ||
        fail "adapter must verify the installed Oh My Zsh entrypoint"
    grep -Fq -- "$DEV_ENV_OH_MY_ZSH_INSTALLER_URL" "$TEST_REMOTE_LOG" ||
        fail "adapter must download the declared installer source"
    grep -Fq -- '--connect-timeout 15 --max-time 120 --speed-limit 1 --speed-time 120' "$TEST_REMOTE_LOG" ||
        fail "adapter must bound remote installer downloads"
    local expected_digest=""
    local expected_source_url_digest=""
    expected_digest="$(shasum -a 256 "$TEST_REMOTE_INSTALLER" | awk '{print $1}')"
    expected_source_url_digest="$(printf '%s' "$DEV_ENV_OH_MY_ZSH_INSTALLER_URL" | shasum -a 256 | awk '{print $1}')"
    grep -Fq -- $'operation_source\t' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "adapter must record remote installer source evidence"
    grep -Fq -- "oh_my_zsh_sha256_${expected_digest}" "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "source evidence must identify the exact downloaded installer"
    grep -Fq -- "oh_my_zsh_source_url_sha256_${expected_source_url_digest}" "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "source evidence must identify the declared source without recording its raw URL"
}

test_download_404_is_an_integrity_failure_without_a_retry_recommendation() {
    local fixture_root="$TEST_TMP_ROOT/download-404"

    load_fixture "$fixture_root"
    write_installer "$fixture_root"

    if TEST_REMOTE_CURL_FAILURE_OUTPUT='curl: (22) The requested URL returned error: 404' \
        bootstrap_ensure_oh_my_zsh; then
        fail "an unavailable installer source must fail"
    fi

    grep -Fq -- $'integrity_failure\toh_my_zsh_download_failed' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "a 404 installer source must be recorded as an integrity failure"
    grep -Fq -- $'\tdo_not_retry\tOh My Zsh installer download failed before target mutation.' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "a 404 installer source must not recommend a blind retry"
}

test_empty_download_is_an_integrity_failure() {
    local fixture_root="$TEST_TMP_ROOT/empty-download"

    load_fixture "$fixture_root"
    write_installer "$fixture_root"

    if TEST_REMOTE_CURL_EMPTY=1 bootstrap_ensure_oh_my_zsh; then
        fail "an empty installer download must fail"
    fi

    grep -Fq -- $'integrity_failure\toh_my_zsh_empty_installer' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "an empty installer download must be recorded as an integrity failure"
}

test_transient_download_failure_recommends_profile_retry() {
    local fixture_root="$TEST_TMP_ROOT/transient-download"

    load_fixture "$fixture_root"
    write_installer "$fixture_root"

    if TEST_REMOTE_CURL_FAILURE_OUTPUT='curl: (28) Operation timed out after 120001 milliseconds' \
        bootstrap_ensure_oh_my_zsh; then
        fail "a timed-out installer download must fail"
    fi

    grep -Fq -- $'transient_external\toh_my_zsh_download_failed' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "a timed-out installer download must be classified as transient"
    grep -Fq -- $'\tretry_profile\tOh My Zsh installer download failed before target mutation.' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "a timed-out installer download must recommend a profile retry"
}

test_failed_installer_with_partial_state_requires_manual_recovery() {
    local fixture_root="$TEST_TMP_ROOT/partial-failure"

    load_fixture "$fixture_root"
    cat > "$TEST_REMOTE_INSTALLER" <<'EOF'
#!/bin/sh
mkdir -p "$HOME/.oh-my-zsh"
printf 'partial\n' > "$HOME/.oh-my-zsh/oh-my-zsh.sh"
exit 1
EOF
    chmod +x "$TEST_REMOTE_INSTALLER"

    if bootstrap_ensure_oh_my_zsh; then
        fail "a failed installer with partial state must not be accepted"
    fi

    [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ] ||
        fail "failed installer state must be preserved for recovery"
    grep -Fq -- $'managed_state_invalid\toh_my_zsh_install_failed' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "partial installer state must be recorded for manual recovery"
}

test_failed_installer_with_verified_state_is_accepted_after_probe() {
    local fixture_root="$TEST_TMP_ROOT/verified-after-failure"

    load_fixture "$fixture_root"
    cat > "$TEST_REMOTE_INSTALLER" <<'EOF'
#!/bin/sh
mkdir -p "$HOME/.oh-my-zsh/lib" "$HOME/.oh-my-zsh/plugins" "$HOME/.oh-my-zsh/themes"
printf 'loaded\n' > "$HOME/.oh-my-zsh/oh-my-zsh.sh"
exit 1
EOF
    chmod +x "$TEST_REMOTE_INSTALLER"

    bootstrap_ensure_oh_my_zsh || fail "a verified post-failure installation should be retained"

    grep -Fq -- 'oh_my_zsh_completed_after_probe' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "verified post-failure completion must be recorded"
}

test_existing_valid_oh_my_zsh_does_not_download_again() {
    local fixture_root="$TEST_TMP_ROOT/existing"

    load_fixture "$fixture_root"
    write_installer "$fixture_root"
    mkdir -p "$HOME/.oh-my-zsh/lib" "$HOME/.oh-my-zsh/plugins" "$HOME/.oh-my-zsh/themes"
    printf 'loaded\n' > "$HOME/.oh-my-zsh/oh-my-zsh.sh"

    bootstrap_ensure_oh_my_zsh || fail "valid Oh My Zsh should be retained"

    [ ! -e "$TEST_REMOTE_LOG" ] || fail "valid Oh My Zsh must not download on rerun"
}

test_incomplete_oh_my_zsh_directory_is_preserved_as_manual_conflict() {
    local fixture_root="$TEST_TMP_ROOT/incomplete"

    load_fixture "$fixture_root"
    write_installer "$fixture_root"
    mkdir -p "$HOME/.oh-my-zsh"
    printf 'user state\n' > "$HOME/.oh-my-zsh/notes.txt"

    if bootstrap_ensure_oh_my_zsh; then
        fail "incomplete Oh My Zsh state must require manual recovery"
    fi

    [ -f "$HOME/.oh-my-zsh/notes.txt" ] ||
        fail "adapter must preserve incomplete user state"
    [ ! -e "$TEST_REMOTE_LOG" ] || fail "adapter must not download over incomplete state"
}

run_test test_missing_oh_my_zsh_uses_staging_and_verifies_installed_state
run_test test_existing_valid_oh_my_zsh_does_not_download_again
run_test test_incomplete_oh_my_zsh_directory_is_preserved_as_manual_conflict
run_test test_download_404_is_an_integrity_failure_without_a_retry_recommendation
run_test test_empty_download_is_an_integrity_failure
run_test test_transient_download_failure_recommends_profile_retry
run_test test_failed_installer_with_partial_state_requires_manual_recovery
run_test test_failed_installer_with_verified_state_is_accepted_after_probe

echo "1..$TEST_COUNT"
