#!/bin/bash
# Recovery-safe file replacement helpers for user-owned configuration.

bootstrap_copy_file_with_backup() {
    local source_path="$1"
    local destination_path="$2"
    local backup_dir="$3"
    local backup_target="${4:-}"
    local destination_dir=""
    local temp_path=""

    destination_dir="$(dirname "$destination_path")"
    mkdir -p "$destination_dir"

    if [ -L "$destination_path" ]; then
        echo "ERROR: Refusing to replace symlink destination: $destination_path" >&2
        echo "       Replace or remove the link explicitly, then rerun." >&2
        return 1
    fi

    if [ -f "$destination_path" ] && cmp -s "$source_path" "$destination_path"; then
        return 0
    fi

    if [ -e "$destination_path" ] && [ ! -f "$destination_path" ]; then
        echo "ERROR: Refusing to replace non-file destination: $destination_path" >&2
        return 1
    fi

    if [ -f "$destination_path" ]; then
        if [ -z "$backup_target" ]; then
            backup_target="$backup_dir/${destination_path##*/}"
        fi
        mkdir -p "$(dirname "$backup_target")"
        cp -p "$destination_path" "$backup_target"
    fi

    temp_path="$(mktemp "$destination_dir/.${destination_path##*/}.tmp.XXXXXX")"
    if ! cp "$source_path" "$temp_path"; then
        rm -f "$temp_path"
        return 1
    fi
    mv "$temp_path" "$destination_path"
}
