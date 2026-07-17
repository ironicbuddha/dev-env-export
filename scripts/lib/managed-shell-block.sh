#!/bin/bash
# Validate, back up, and atomically replace managed zsh startup blocks.

bootstrap_write_managed_shell_block() {
    local path="$1"
    local begin_marker="$2"
    local end_marker="$3"
    local backup_dir="$4"
    local path_dir=""
    local existing_file=""
    local stripped_file=""
    local block_file=""
    local candidate_file=""
    local backup_target=""

    path_dir="$(dirname "$path")"
    mkdir -p "$path_dir"
    existing_file="$(mktemp "$path_dir/.${path##*/}.existing.XXXXXX")"
    stripped_file="$(mktemp "$path_dir/.${path##*/}.stripped.XXXXXX")"
    block_file="$(mktemp "$path_dir/.${path##*/}.block.XXXXXX")"
    candidate_file="$(mktemp "$path_dir/.${path##*/}.candidate.XXXXXX")"

    if [ -L "$path" ]; then
        echo "ERROR: Refusing to rewrite symlink shell file: $path" >&2
        rm -f "$existing_file" "$stripped_file" "$block_file" "$candidate_file"
        return 1
    fi

    if [ -e "$path" ] && [ ! -f "$path" ]; then
        echo "ERROR: Refusing to rewrite non-file shell path: $path" >&2
        rm -f "$existing_file" "$stripped_file" "$block_file" "$candidate_file"
        return 1
    fi

    if [ -f "$path" ]; then
        cp "$path" "$existing_file"
    else
        : > "$existing_file"
    fi

    if ! awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin {
            if (inside == 1 || begin_count > 0) invalid = 1
            inside = 1
            begin_count++
        }
        $0 == end {
            if (inside != 1 || end_count > 0) invalid = 1
            inside = 0
            end_count++
        }
        END {
            if (inside == 1 || begin_count != end_count || begin_count > 1) invalid = 1
            exit invalid
        }
    ' "$existing_file"; then
        echo "ERROR: Refusing to rewrite $path because its managed block markers are malformed." >&2
        rm -f "$existing_file" "$stripped_file" "$block_file" "$candidate_file"
        return 1
    fi

    cat > "$block_file"
    awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { skipping = 1; next }
        $0 == end { skipping = 0; next }
        skipping != 1 { print }
    ' "$existing_file" > "$stripped_file"

    {
        if [ -s "$stripped_file" ]; then
            sed -e '${/^$/d;}' "$stripped_file"
            echo ""
        fi
        cat "$block_file"
    } > "$candidate_file"

    if ! command -v zsh >/dev/null 2>&1; then
        echo "ERROR: zsh is required to validate $path before replacement." >&2
        rm -f "$existing_file" "$stripped_file" "$block_file" "$candidate_file"
        return 1
    fi

    if ! zsh -n "$candidate_file"; then
        echo "ERROR: Refusing to install invalid zsh configuration for $path." >&2
        rm -f "$existing_file" "$stripped_file" "$block_file" "$candidate_file"
        return 1
    fi

    if cmp -s "$candidate_file" "$existing_file"; then
        rm -f "$existing_file" "$stripped_file" "$block_file" "$candidate_file"
        return 0
    fi

    if [ "${DEV_ENV_TEST_FAIL_BEFORE_REPLACE:-0}" = "1" ]; then
        rm -f "$existing_file" "$stripped_file" "$block_file" "$candidate_file"
        return 97
    fi

    if [ -f "$path" ]; then
        backup_target="$backup_dir/${path##*/}"
        mkdir -p "$backup_dir"
        cp -p "$path" "$backup_target"
    fi

    mv "$candidate_file" "$path"
    rm -f "$existing_file" "$stripped_file" "$block_file"
}
