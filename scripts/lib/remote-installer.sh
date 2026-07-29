#!/bin/bash

# Source-identified adapters for required remote installers. Each adapter owns
# only its target state and never retries an installer after an ambiguous write.

REMOTE_INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$REMOTE_INSTALLER_DIR/operation-policy.sh"

bootstrap_oh_my_zsh_is_usable() {
    local target_dir="${1:-$HOME/.oh-my-zsh}"

    [ -d "$target_dir" ] && [ ! -L "$target_dir" ] &&
        [ -f "$target_dir/oh-my-zsh.sh" ] && [ ! -L "$target_dir/oh-my-zsh.sh" ] &&
        [ -d "$target_dir/lib" ] && [ ! -L "$target_dir/lib" ] &&
        [ -d "$target_dir/plugins" ] && [ ! -L "$target_dir/plugins" ] &&
        [ -d "$target_dir/themes" ] && [ ! -L "$target_dir/themes" ]
}

bootstrap_remote_installer_failure_class() {
    local output_file="$1"

    if grep -Eqi 'timed? ?out|temporary failure|could not resolve|network is unreachable|connection reset|http (408|425|429)|http 5[0-9][0-9]' "$output_file"; then
        printf '%s\n' transient_external
    elif grep -Eqi 'http 4[0-9][0-9]|error: 4[0-9][0-9]|certificate|ssl|malformed|unsupported protocol' "$output_file"; then
        printf '%s\n' integrity_failure
    elif grep -Eqi 'permission denied|operation not permitted|read-only file system|no space left' "$output_file"; then
        printf '%s\n' local_precondition
    else
        printf '%s\n' internal_failure
    fi
}

bootstrap_remote_installer_failure_recovery() {
    case "$1" in
        transient_external) printf '%s\n' retry_profile ;;
        *) printf '%s\n' do_not_retry ;;
    esac
}

bootstrap_ensure_oh_my_zsh() {
    local target_dir="$HOME/.oh-my-zsh"
    local source_url="${DEV_ENV_OH_MY_ZSH_INSTALLER_URL:-https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh}"
    local staging_dir="" installer_path="" download_log="" digest="" source_url_digest="" status=0
    local failure_class="" recovery=""

    if bootstrap_oh_my_zsh_is_usable "$target_dir"; then
        echo "  [SKIP] Oh My Zsh already installed"
        bootstrap_operation_record operation_end satisfied none remote_installer_present 0 none \
            oh_my_zsh_install oh_my_zsh "Existing Oh My Zsh installation is usable."
        return 0
    fi

    if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
        echo "ERROR: Oh My Zsh exists but is not a usable bootstrap-managed installation: $target_dir" >&2
        echo "       Preserve it and complete or repair it manually before rerunning this Bootstrap Profile." >&2
        bootstrap_operation_record operation_end manual_action foreign_state_conflict \
            oh_my_zsh_existing_state_conflict 1 resolve_conflict oh_my_zsh_install oh_my_zsh \
            "Existing Oh My Zsh state is preserved because ownership or completeness is unproven."
        return 1
    fi

    staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-oh-my-zsh.XXXXXX")" || return 1
    installer_path="$staging_dir/install.sh"
    download_log="$staging_dir/download.log"
    bootstrap_operation_record operation_start changed none operation_started 0 none \
        oh_my_zsh_install oh_my_zsh "Oh My Zsh installer download started in run-owned staging."
    bootstrap_operation_record operation_policy satisfied none remote_installer_download_bounds 0 none \
        oh_my_zsh_install oh_my_zsh "Remote installer download uses a 15-second connection timeout and 120-second transfer and low-speed limits."

    if curl --connect-timeout 15 --max-time 120 --speed-limit 1 --speed-time 120 -fsSL \
        -o "$installer_path" "$source_url" 2>"$download_log"; then
        :
    else
        status=$?
        failure_class="$(bootstrap_remote_installer_failure_class "$download_log")"
        recovery="$(bootstrap_remote_installer_failure_recovery "$failure_class")"
        cat "$download_log" >&2
        rm -rf "$staging_dir"
        echo "ERROR: Could not download the Oh My Zsh installer." >&2
        bootstrap_operation_record operation_end required_failure "$failure_class" \
            oh_my_zsh_download_failed "$status" "$recovery" oh_my_zsh_install oh_my_zsh \
            "Oh My Zsh installer download failed before target mutation."
        return "$status"
    fi
    if [ ! -s "$installer_path" ]; then
        rm -rf "$staging_dir"
        echo "ERROR: Oh My Zsh installer download was empty." >&2
        bootstrap_operation_record operation_end required_failure integrity_failure \
            oh_my_zsh_empty_installer 1 do_not_retry oh_my_zsh_install oh_my_zsh \
            "Downloaded Oh My Zsh installer was empty."
        return 1
    fi
    digest="$(shasum -a 256 "$installer_path" | awk '{print $1}')" || {
        rm -rf "$staging_dir"
        return 1
    }
    source_url_digest="$(printf '%s' "$source_url" | shasum -a 256 | awk '{print $1}')" || {
        rm -rf "$staging_dir"
        return 1
    }
    bootstrap_operation_record operation_source satisfied none "oh_my_zsh_source_url_sha256_${source_url_digest}" 0 none \
        oh_my_zsh_install oh_my_zsh "Oh My Zsh installer source URL was identified without recording its raw value."
    bootstrap_operation_record operation_source satisfied none "oh_my_zsh_sha256_${digest}" 0 none \
        oh_my_zsh_install oh_my_zsh "Oh My Zsh installer content was captured by SHA-256."

    echo "Installing Oh My Zsh..."
    if RUNZSH=no CHSH=no KEEP_ZSHRC=yes /bin/sh "$installer_path" --unattended; then
        :
    else
        status=$?
        rm -rf "$staging_dir"
        if bootstrap_oh_my_zsh_is_usable "$target_dir"; then
            bootstrap_operation_record operation_end satisfied none \
                oh_my_zsh_completed_after_probe "$status" none oh_my_zsh_install oh_my_zsh \
                "Oh My Zsh installer returned failure but post-install state is usable."
            return 0
        fi
        echo "ERROR: Oh My Zsh installer failed; inspect the preserved target state before retrying." >&2
        bootstrap_operation_record operation_end required_failure managed_state_invalid \
            oh_my_zsh_install_failed "$status" resolve_conflict oh_my_zsh_install oh_my_zsh \
            "Oh My Zsh installer failed and post-install state is not usable."
        return "$status"
    fi
    rm -rf "$staging_dir"

    if ! bootstrap_oh_my_zsh_is_usable "$target_dir"; then
        echo "ERROR: Oh My Zsh installer completed without a usable installation." >&2
        bootstrap_operation_record operation_end required_failure managed_state_invalid \
            oh_my_zsh_post_install_verify_failed 1 resolve_conflict oh_my_zsh_install oh_my_zsh \
            "Oh My Zsh installer completed without a usable post-install state."
        return 1
    fi
    bootstrap_operation_record operation_end changed none operation_completed 0 none \
        oh_my_zsh_install oh_my_zsh "Oh My Zsh installation completed and was verified."
}
