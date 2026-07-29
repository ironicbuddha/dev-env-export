#!/bin/bash
# Inspect-first, ownership-aware fallback installer for Bun.

BUN_FALLBACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BUN_FALLBACK_DIR/operation-policy.sh"
# shellcheck disable=SC1091
source "$BUN_FALLBACK_DIR/artifact-integrity.sh"

bootstrap_bun_binary_usable() {
    local binary_path="$1"

    [ -f "$binary_path" ] && [ ! -L "$binary_path" ] && [ -x "$binary_path" ] &&
        "$binary_path" --version >/dev/null 2>&1
}

bootstrap_bun_fallback_marker_path() {
    printf '%s\n' "$1/.dev-env-bootstrap-bun-fallback"
}

bootstrap_bun_fallback_is_owned() {
    local marker_path
    marker_path="$(bootstrap_bun_fallback_marker_path "$1")"

    [ -f "$marker_path" ] && [ ! -L "$marker_path" ] &&
        grep -Fxq 'dev-env-bootstrap-bun-fallback-v1' "$marker_path"
}

bootstrap_bun_fallback_install_dir() {
    if [ -n "${DEV_ENV_BUN_FALLBACK_BIN_DIR:-}" ]; then
        printf '%s\n' "$DEV_ENV_BUN_FALLBACK_BIN_DIR"
    elif [ -w "$(brew --prefix)/bin" ]; then
        printf '%s\n' "$(brew --prefix)/bin"
    else
        printf '%s\n' "$HOME/.local/bin"
    fi
}

bootstrap_bun_fallback_quarantine_owned_target() {
    local install_dir="$1" final_path="$2" marker_path="$3" quarantine_suffix=""

    bootstrap_bun_fallback_is_owned "$install_dir" || return 1
    [ -f "$final_path" ] && [ ! -L "$final_path" ] || return 1

    quarantine_suffix=".quarantine-$(date -u '+%Y%m%d%H%M%S')-$$"
    mv "$marker_path" "${marker_path}${quarantine_suffix}" || return 1
    if ! mv "$final_path" "${final_path}${quarantine_suffix}"; then
        mv "${marker_path}${quarantine_suffix}" "$marker_path" || true
        return 1
    fi
}

bootstrap_bun_fallback_download_failure_class() {
    local output_file="$1"

    if grep -Eqi 'http 4[0-9][0-9]|error: 4[0-9][0-9]|certificate|ssl|malformed|unsupported protocol' "$output_file"; then
        printf '%s\n' integrity_failure
    elif grep -Eqi 'permission denied|operation not permitted|read-only file system|no space left' "$output_file"; then
        printf '%s\n' local_precondition
    elif grep -Eqi 'timed? ?out|temporary failure|could not resolve|network is unreachable|connection reset|http (408|425|429)|http 5[0-9][0-9]' "$output_file"; then
        printf '%s\n' transient_external
    else
        printf '%s\n' internal_failure
    fi
}

bootstrap_bun_fallback_download_recovery() {
    case "$1" in
        transient_external) printf '%s\n' retry_profile ;;
        *) printf '%s\n' do_not_retry ;;
    esac
}

bootstrap_ensure_bun_fallback() {
    local bun_version="" asset_arch="" asset_name="" archive_url="" release_api_url=""
    local published_digest="" install_dir="" final_path="" marker_path="" staging_dir=""
    local release_metadata_path="" archive_path="" staged_binary="" staged_marker="" status=0
    local download_log="" failure_class="" recovery=""

    if command -v bun >/dev/null 2>&1 && bun --version >/dev/null 2>&1; then
        echo "  [SKIP] bun is already available -> $(command -v bun)"
        bootstrap_operation_record operation_end satisfied none bun_present 0 none \
            bun_fallback_install bun "Usable Bun already satisfies the present declaration."
        return 0
    fi

    install_dir="$(bootstrap_bun_fallback_install_dir)" || return 1
    final_path="$install_dir/bun"
    marker_path="$(bootstrap_bun_fallback_marker_path "$install_dir")"
    if [ -e "$final_path" ] || [ -L "$final_path" ] || [ -e "$marker_path" ] || [ -L "$marker_path" ]; then
        if bootstrap_bun_binary_usable "$final_path" && bootstrap_bun_fallback_is_owned "$install_dir"; then
            echo "  [SKIP] bootstrap-owned Bun fallback is already usable -> $final_path"
            bootstrap_operation_record operation_end satisfied none bun_fallback_present 0 none \
                bun_fallback_install bun "Bootstrap-owned Bun fallback is usable."
            return 0
        fi
        if bootstrap_bun_fallback_quarantine_owned_target "$install_dir" "$final_path" "$marker_path"; then
            echo "  [REPAIR] Quarantined invalid bootstrap-owned Bun fallback."
        else
            echo "ERROR: Bun fallback target is present but is not a usable bootstrap-owned binary: $final_path" >&2
            bootstrap_operation_record operation_end required_failure foreign_state_conflict \
                bun_fallback_target_conflict 1 resolve_conflict bun_fallback_install bun \
                "Existing Bun fallback target or ownership marker is preserved for manual recovery."
            return 1
        fi
    fi

    bun_version="$(brew info --json=v2 bun 2>/dev/null | jq -r '.formulae[0].versions.stable // empty')"
    if [ -z "$bun_version" ]; then
        echo "ERROR: Could not determine the current Bun release for fallback install." >&2
        return 1
    fi
    case "$(uname -m)" in
        arm64|aarch64) asset_arch="aarch64" ;;
        x86_64) asset_arch="x64" ;;
        *)
            echo "ERROR: Unsupported architecture for Bun fallback: $(uname -m)" >&2
            return 1
            ;;
    esac
    asset_name="bun-darwin-$asset_arch.zip"
    release_api_url="https://api.github.com/repos/oven-sh/bun/releases/tags/bun-v${bun_version}"

    mkdir -p "$install_dir" || return 1
    staging_dir="$(mktemp -d "$install_dir/.dev-env-bun-fallback.XXXXXX")" || return 1
    release_metadata_path="$staging_dir/release.json"
    archive_path="$staging_dir/$asset_name"
    download_log="$staging_dir/download.log"

    bootstrap_operation_record operation_start changed none operation_started 0 none \
        bun_fallback_install bun "Bun fallback installation started."
    if curl -fsSL --connect-timeout 15 --max-time 120 --speed-limit 1 --speed-time 120 \
        -o "$release_metadata_path" "$release_api_url" 2> "$download_log"; then
        :
    else
        status=$?
        failure_class="$(bootstrap_bun_fallback_download_failure_class "$download_log")"
        recovery="$(bootstrap_bun_fallback_download_recovery "$failure_class")"
        cat "$download_log" >&2
        rm -rf "$staging_dir"
        bootstrap_operation_record operation_end required_failure "$failure_class" \
            bun_fallback_metadata_download_failed "$status" "$recovery" bun_fallback_install bun \
            "Bun release metadata download failed before target mutation."
        return "$status"
    fi
    archive_url="$(jq -r --arg name "$asset_name" \
        '.assets[]? | select(.name == $name) | .browser_download_url // empty' "$release_metadata_path" | head -n 1)"
    published_digest="$(jq -r --arg name "$asset_name" \
        '.assets[]? | select(.name == $name) | .digest // empty' "$release_metadata_path" | head -n 1)"
    published_digest="${published_digest#sha256:}"
    if [ -z "$archive_url" ] || [ -z "$published_digest" ]; then
        rm -rf "$staging_dir"
        echo "ERROR: Bun release metadata did not publish the expected asset and SHA-256 digest." >&2
        bootstrap_operation_record operation_end required_failure integrity_failure \
            bun_fallback_metadata_invalid 1 do_not_retry bun_fallback_install bun \
            "Bun release metadata omitted the expected asset or digest."
        return 1
    fi
    bootstrap_operation_record operation_source satisfied none \
        "bun_release_metadata_url_sha256_$(printf '%s' "$release_api_url" | shasum -a 256 | awk '{print $1}')" \
        0 none bun_fallback_install bun "Bun release metadata source was identified without recording its raw URL."
    bootstrap_operation_record operation_source satisfied none "bun_archive_sha256_${published_digest}" \
        0 none bun_fallback_install bun "Bun archive published SHA-256 was recorded before download."
    if curl -fsSL --connect-timeout 15 --max-time 120 --speed-limit 1 --speed-time 120 \
        -o "$archive_path" "$archive_url" 2> "$download_log"; then
        :
    else
        status=$?
        failure_class="$(bootstrap_bun_fallback_download_failure_class "$download_log")"
        recovery="$(bootstrap_bun_fallback_download_recovery "$failure_class")"
        cat "$download_log" >&2
        rm -rf "$staging_dir"
        bootstrap_operation_record operation_end required_failure "$failure_class" \
            bun_fallback_archive_download_failed "$status" "$recovery" bun_fallback_install bun \
            "Bun archive download failed before target mutation."
        return "$status"
    fi
    if ! bootstrap_verify_sha256 "$archive_path" "$published_digest" || ! unzip -tq "$archive_path" >/dev/null 2>&1; then
        rm -rf "$staging_dir"
        echo "ERROR: Bun fallback archive failed integrity verification." >&2
        bootstrap_operation_record operation_end required_failure integrity_failure \
            bun_fallback_archive_invalid 1 do_not_retry bun_fallback_install bun \
            "Bun archive digest or ZIP validation failed."
        return 1
    fi
    if ! unzip -q "$archive_path" -d "$staging_dir"; then
        rm -rf "$staging_dir"
        echo "ERROR: Bun fallback archive could not be extracted after validation." >&2
        bootstrap_operation_record operation_end required_failure integrity_failure \
            bun_fallback_extract_failed 1 do_not_retry bun_fallback_install bun \
            "Validated Bun archive could not be extracted into run-owned staging."
        return 1
    fi
    staged_binary="$staging_dir/bun-darwin-$asset_arch/bun"
    if ! bootstrap_bun_binary_usable "$staged_binary" || [ "$("$staged_binary" --version)" != "$bun_version" ]; then
        rm -rf "$staging_dir"
        echo "ERROR: Bun fallback archive did not contain the expected usable binary." >&2
        bootstrap_operation_record operation_end required_failure integrity_failure \
            bun_fallback_binary_invalid 1 do_not_retry bun_fallback_install bun \
            "Staged Bun binary failed version verification."
        return 1
    fi
    staged_marker="$staging_dir/marker"
    printf '%s\nversion=%s\ndigest=%s\n' dev-env-bootstrap-bun-fallback-v1 "$bun_version" "$published_digest" > "$staged_marker"

    if ! ln "$staged_binary" "$final_path"; then
        rm -rf "$staging_dir"
        echo "ERROR: Bun fallback target changed during atomic promotion; existing state was preserved." >&2
        bootstrap_operation_record operation_end required_failure foreign_state_conflict \
            bun_fallback_promotion_conflict 1 resolve_conflict bun_fallback_install bun \
            "Bun fallback promotion could not claim an empty final target."
        return 1
    fi
    if ! ln "$staged_marker" "$marker_path"; then
        rm -rf "$staging_dir"
        echo "ERROR: Bun fallback ownership marker changed during promotion; preserve the binary for manual recovery." >&2
        bootstrap_operation_record operation_end required_failure foreign_state_conflict \
            bun_fallback_promotion_conflict 1 resolve_conflict bun_fallback_install bun \
            "Bun fallback promotion could not claim an empty ownership marker."
        return 1
    fi
    rm -rf "$staging_dir"
    if ! bootstrap_bun_binary_usable "$final_path" || ! bootstrap_bun_fallback_is_owned "$install_dir"; then
        echo "ERROR: Bun fallback promotion did not produce a usable owned binary." >&2
        bootstrap_operation_record operation_end required_failure managed_state_invalid \
            bun_fallback_post_promotion_verify_failed 1 resolve_conflict bun_fallback_install bun \
            "Promoted Bun fallback did not verify."
        return 1
    fi
    echo "  [FALLBACK] Installed Bun $bun_version -> $final_path"
    bootstrap_operation_record operation_end changed none operation_completed 0 none \
        bun_fallback_install bun "Bun fallback was promoted atomically and reverified."
}
