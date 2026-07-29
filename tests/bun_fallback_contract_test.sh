#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-bun-fallback-tests.XXXXXX")"
TEST_COUNT=0

cleanup() { rm -rf "$TEST_TMP_ROOT"; }
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

run_test() {
    "$1"
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "ok $TEST_COUNT - $1"
}

configure_case() {
    local case_root="$1"

    mkdir -p "$case_root/bin" "$case_root/home" "$case_root/downloads"
    export HOME="$case_root/home"
    export PATH="$case_root/bin:/usr/bin:/bin"
    export DEV_ENV_BUN_FALLBACK_BIN_DIR="$case_root/home/.local/bin"
    export TEST_BUN_DOWNLOAD_DIR="$case_root/downloads"
    export TEST_BUN_CALL_LOG="$case_root/calls.log"
    export BOOTSTRAP_OPERATION_EVENT_FILE="$case_root/events.tsv"
    export BOOTSTRAP_OPERATION_STEP="02-install-cli-tools.sh"
    printf '%s\n' $'sequence\tevent_type\ttimestamp\tseverity\tdisposition\tfailure_class\tcode\tstep\toperation\ttarget\traw_status\trecovery\tmessage\tlog_ref' \
        > "$BOOTSTRAP_OPERATION_EVENT_FILE"

    cat > "$case_root/bin/brew" <<'EOF'
#!/bin/bash
printf 'brew %s\n' "$*" >> "$TEST_BUN_CALL_LOG"
case "$*" in
    'info --json=v2 bun') printf '%s\n' '{"formulae":[{"versions":{"stable":"1.2.3"}}]}' ;;
    '--prefix') printf '%s\n' "$DEV_ENV_BUN_FALLBACK_BIN_DIR/.." ;;
    *) exit 1 ;;
esac
EOF
    cat > "$case_root/bin/jq" <<'EOF'
#!/bin/bash
if [ "$1" = '-r' ]; then
    case "$*" in
        *versions.stable*) printf '%s\n' 1.2.3 ;;
        *browser_download_url*) printf '%s\n' https://downloads.example.test/bun-darwin-aarch64.zip ;;
        *'.digest'*) printf '%s\n' sha256:__DIGEST__ ;;
    esac
fi
EOF
    cat > "$case_root/bin/curl" <<'EOF'
#!/bin/bash
printf 'curl %s\n' "$*" >> "$TEST_BUN_CALL_LOG"
if [ -n "${TEST_BUN_CURL_FAILURE_OUTPUT:-}" ]; then
    printf '%s\n' "$TEST_BUN_CURL_FAILURE_OUTPUT" >&2
    exit "${TEST_BUN_CURL_STATUS:-22}"
fi
while [ "$#" -gt 0 ]; do
    if [ "$1" = '-o' ]; then
        case "$3" in
            *release.json) printf '%s\n' '{}' > "$2" ;;
            *) cp "$TEST_BUN_DOWNLOAD_DIR/bun-darwin-aarch64.zip" "$2" ;;
        esac
        exit 0
    fi
    shift
done
exit 1
EOF
    cat > "$case_root/bin/unzip" <<'EOF'
#!/bin/bash
if [ "$1" = '-tq' ]; then exit 0; fi
while [ "$#" -gt 0 ]; do
    if [ "$1" = '-d' ]; then
        mkdir -p "$2/bun-darwin-aarch64"
        cp "$TEST_BUN_DOWNLOAD_DIR/bun" "$2/bun-darwin-aarch64/bun"
        exit 0
    fi
    shift
done
exit 1
EOF
    cat > "$case_root/bin/uname" <<'EOF'
#!/bin/bash
printf '%s\n' arm64
EOF
    chmod +x "$case_root/bin/brew" "$case_root/bin/jq" "$case_root/bin/curl" \
        "$case_root/bin/unzip" "$case_root/bin/uname"
    printf 'archive\n' > "$case_root/downloads/bun-darwin-aarch64.zip"
    cat > "$case_root/downloads/bun" <<'EOF'
#!/bin/bash
printf '%s\n' 1.2.3
EOF
    chmod +x "$case_root/downloads/bun"
    local digest
    digest="$(shasum -a 256 "$case_root/downloads/bun-darwin-aarch64.zip" | awk '{print $1}')"
    sed -i '' "s/__DIGEST__/$digest/" "$case_root/bin/jq"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/lib/bun-fallback.sh"
}

test_missing_bun_is_verified_and_promoted_from_destination_staging() {
    local case_root="$TEST_TMP_ROOT/missing"

    configure_case "$case_root"
    bootstrap_ensure_bun_fallback || fail "missing Bun should install through the fallback adapter"

    [ -x "$DEV_ENV_BUN_FALLBACK_BIN_DIR/bun" ] || fail "fallback binary was not promoted"
    [ ! -L "$DEV_ENV_BUN_FALLBACK_BIN_DIR/bun" ] || fail "fallback binary must not be a symlink"
    [ -f "$DEV_ENV_BUN_FALLBACK_BIN_DIR/.dev-env-bootstrap-bun-fallback" ] ||
        fail "fallback ownership record was not promoted"
    [ "$("$DEV_ENV_BUN_FALLBACK_BIN_DIR/bun" --version)" = 1.2.3 ] ||
        fail "promoted binary was not verified"
    grep -Fq 'bun_fallback_install' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "fallback installation was not recorded"
    grep -Fq 'bun_archive_sha256_' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "published archive integrity evidence was not recorded"
    if find "$DEV_ENV_BUN_FALLBACK_BIN_DIR" -maxdepth 1 -name '.dev-env-bun-fallback.*' | grep -q .; then
        fail "run-owned destination staging was not cleaned up"
    fi
}

test_usable_foreign_bun_satisfies_present_without_download_or_overwrite() {
    local case_root="$TEST_TMP_ROOT/foreign-present"

    configure_case "$case_root"
    cat > "$case_root/bin/bun" <<'EOF'
#!/bin/bash
printf '%s\n' 9.9.9
EOF
    chmod +x "$case_root/bin/bun"

    bootstrap_ensure_bun_fallback || fail "usable foreign Bun should satisfy present policy"

    [ ! -e "$TEST_BUN_CALL_LOG" ] || fail "foreign Bun must not trigger metadata or download work"
    grep -Fq 'bun_present' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "foreign Bun satisfaction was not recorded"
}

test_unowned_or_symlinked_final_target_is_preserved_as_conflict() {
    local case_root="$TEST_TMP_ROOT/unowned-conflict"

    configure_case "$case_root"
    mkdir -p "$DEV_ENV_BUN_FALLBACK_BIN_DIR"
    ln -s "$case_root/downloads/bun" "$DEV_ENV_BUN_FALLBACK_BIN_DIR/bun"

    if bootstrap_ensure_bun_fallback; then
        fail "symlinked final target must not be overwritten"
    fi

    [ -L "$DEV_ENV_BUN_FALLBACK_BIN_DIR/bun" ] || fail "foreign symlink must be preserved"
    [ ! -e "$TEST_BUN_CALL_LOG" ] || fail "conflict must stop before metadata or downloads"
    grep -Fq 'bun_fallback_target_conflict' "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "target conflict was not recorded"
}

test_invalid_owned_target_is_quarantined_before_replacement() {
    local case_root="$TEST_TMP_ROOT/owned-repair"

    configure_case "$case_root"
    mkdir -p "$DEV_ENV_BUN_FALLBACK_BIN_DIR"
    printf 'invalid\n' > "$DEV_ENV_BUN_FALLBACK_BIN_DIR/bun"
    chmod +x "$DEV_ENV_BUN_FALLBACK_BIN_DIR/bun"
    printf '%s\n' dev-env-bootstrap-bun-fallback-v1 > \
        "$DEV_ENV_BUN_FALLBACK_BIN_DIR/.dev-env-bootstrap-bun-fallback"

    bootstrap_ensure_bun_fallback || fail "invalid owned target should be replaced"

    [ "$("$DEV_ENV_BUN_FALLBACK_BIN_DIR/bun" --version)" = 1.2.3 ] ||
        fail "owned target was not replaced with the verified binary"
    find "$DEV_ENV_BUN_FALLBACK_BIN_DIR" -maxdepth 1 -name 'bun.quarantine-*' | grep -q . ||
        fail "invalid owned target was not quarantined"
}

test_permanent_download_failure_is_not_recommended_for_blind_retry() {
    local case_root="$TEST_TMP_ROOT/download-404"

    configure_case "$case_root"
    if TEST_BUN_CURL_FAILURE_OUTPUT='curl: (22) The requested URL returned error: 404' \
        bootstrap_ensure_bun_fallback; then
        fail "missing Bun metadata must fail when the vendor reports 404"
    fi

    grep -Fq $'integrity_failure\tbun_fallback_metadata_download_failed' \
        "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "permanent metadata failure must be classified as integrity failure"
    grep -Fq $'\tdo_not_retry\tBun release metadata download failed before target mutation.' \
        "$BOOTSTRAP_OPERATION_EVENT_FILE" ||
        fail "permanent metadata failure must not recommend a blind retry"
}

run_test test_missing_bun_is_verified_and_promoted_from_destination_staging
run_test test_usable_foreign_bun_satisfies_present_without_download_or_overwrite
run_test test_unowned_or_symlinked_final_target_is_preserved_as_conflict
run_test test_invalid_owned_target_is_quarantined_before_replacement
run_test test_permanent_download_failure_is_not_recommended_for_blind_retry

echo "1..$TEST_COUNT"
