#!/bin/bash
# Recovery-safe mutation support for bootstrap-managed and co-managed files.

BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_SEQUENCE="${BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_SEQUENCE:-0}"
BOOTSTRAP_MANAGED_ARTIFACT_BACKUP_PATH=""
BOOTSTRAP_MANAGED_ARTIFACT_EXPECTED_DIGEST=""
BOOTSTRAP_MANAGED_ARTIFACT_VALIDATOR_BIN=""
BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL=""

bootstrap_managed_artifact_refuse_symlink_path_components() {
    local path="$1"
    local parent_path=""
    local home_boundary=""

    case "$path" in
        "$HOME"|"$HOME"/*) home_boundary="$HOME" ;;
    esac
    while :; do
        if [ -L "$path" ]; then
            echo "ERROR: Refusing symlink path component for managed artifact: $path" >&2
            return 1
        fi
        [ -n "$home_boundary" ] && [ "$path" = "$home_boundary" ] && return 0
        [ -z "$home_boundary" ] && return 0
        parent_path="$(dirname "$path")"
        [ "$parent_path" != "$path" ] || return 0
        path="$parent_path"
    done
}

bootstrap_managed_artifact_refuse_unsafe_target() {
    local target_path="$1"

    bootstrap_managed_artifact_refuse_symlink_path_components "$target_path" || return 1

    if [ -L "$target_path" ]; then
        echo "ERROR: Refusing to modify symlink managed-artifact target: $target_path" >&2
        return 1
    fi

    if [ -e "$target_path" ] && [ ! -f "$target_path" ]; then
        echo "ERROR: Refusing to modify non-file managed-artifact target: $target_path" >&2
        return 1
    fi
}

bootstrap_managed_artifact_ensure_safe_directory() {
    local directory_path="$1"

    bootstrap_managed_artifact_refuse_symlink_path_components "$directory_path" || return 1
    mkdir -p "$directory_path" || return 1
    if [ ! -d "$directory_path" ] || [ -L "$directory_path" ]; then
        echo "ERROR: Refusing non-directory managed-artifact parent: $directory_path" >&2
        return 1
    fi
}

bootstrap_managed_artifact_safe_run_id() {
    local run_id="${DEV_ENV_BOOTSTRAP_RUN_ID:-}"

    if [ -z "$run_id" ]; then
        run_id="standalone-$(date '+%Y%m%d-%H%M%S')-$$"
    fi

    printf '%s' "$run_id" | LC_ALL=C tr -c '[:alnum:]._-' '_'
}

bootstrap_managed_artifact_digest() {
    local path="$1"

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$path" | awk '{print $1}'
    else
        cksum "$path" | awk '{print $1 ":" $2}'
    fi
}

bootstrap_managed_artifact_candidate_is_regular() {
    local candidate_path="$1"

    [ -f "$candidate_path" ] && [ ! -L "$candidate_path" ]
}

bootstrap_managed_artifact_matches_expected_digest() {
    local target_path="$1"
    local actual_digest=""

    actual_digest="$(bootstrap_managed_artifact_digest "$target_path")" ||
        return 1
    [ "$actual_digest" = "$BOOTSTRAP_MANAGED_ARTIFACT_EXPECTED_DIGEST" ]
}

bootstrap_managed_artifact_json_is_valid() {
    local candidate_path="$1"

    "$BOOTSTRAP_MANAGED_ARTIFACT_VALIDATOR_BIN" -m json.tool \
        "$candidate_path" >/dev/null 2>&1
}

bootstrap_managed_artifact_toml_is_valid() {
    local candidate_path="$1"

    "$BOOTSTRAP_MANAGED_ARTIFACT_VALIDATOR_BIN" - "$candidate_path" <<'PY' >/dev/null 2>&1
import sys

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

with open(sys.argv[1], "rb") as candidate:
    tomllib.load(candidate)
PY
}

bootstrap_managed_artifact_backup() {
    local target_path="$1"
    local backup_dir="$2"
    local safe_run_id=""
    local backup_path=""
    local backup_staging=""
    local mutation_label=""

    BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_SEQUENCE=$((BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_SEQUENCE + 1))
    safe_run_id="$(bootstrap_managed_artifact_safe_run_id)"
    mkdir -p "$backup_dir"
    if [ -n "$BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL" ]; then
        mutation_label=".${BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL}"
    fi
    backup_path="$backup_dir/${target_path##*/}.backup.${safe_run_id}."
    backup_path+="${BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_SEQUENCE}${mutation_label}"
    backup_staging="$(mktemp "$backup_dir/.${target_path##*/}.backup-staging.XXXXXX")" ||
        return 1

    if ! cp -p "$target_path" "$backup_staging"; then
        rm -f "$backup_staging"
        return 1
    fi
    if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
        rm -f "$backup_staging"
        echo "ERROR: Refusing to overwrite existing managed-artifact backup." >&2
        return 1
    fi
    mv "$backup_staging" "$backup_path"

    BOOTSTRAP_MANAGED_ARTIFACT_BACKUP_PATH="$backup_path"
}

bootstrap_managed_artifact_restore() {
    local target_path="$1"
    local backup_path="$2"
    local target_dir=""
    local restore_path=""

    target_dir="$(dirname "$target_path")"
    restore_path="$(mktemp "$target_dir/.${target_path##*/}.restore.XXXXXX")" ||
        return 1
    if ! cp -p "$backup_path" "$restore_path"; then
        rm -f "$restore_path"
        return 1
    fi
    mv "$restore_path" "$target_path"
}

bootstrap_managed_artifact_promote_candidate() {
    local candidate_path="$1"
    local target_path="$2"
    local backup_dir="$3"
    local validate_function="$4"
    local verify_function="$5"
    local had_original=0
    local backup_path=""

    if ! bootstrap_managed_artifact_refuse_unsafe_target "$target_path"; then
        rm -f "$candidate_path"
        return 1
    fi

    if [ -f "$target_path" ]; then
        had_original=1
        if cmp -s "$candidate_path" "$target_path"; then
            rm -f "$candidate_path"
            return 0
        fi
    fi

    if ! "$validate_function" "$candidate_path"; then
        rm -f "$candidate_path"
        return 1
    fi

    if [ "${DEV_ENV_TEST_FAIL_BEFORE_PROMOTION:-0}" = "1" ] ||
            [ "${DEV_ENV_TEST_FAIL_BEFORE_REPLACE:-0}" = "1" ]; then
        rm -f "$candidate_path"
        return 97
    fi

    if [ "$had_original" -eq 1 ]; then
        bootstrap_managed_artifact_backup "$target_path" "$backup_dir" ||
            {
                rm -f "$candidate_path"
                return 1
            }
        backup_path="$BOOTSTRAP_MANAGED_ARTIFACT_BACKUP_PATH"
    fi

    if ! mv "$candidate_path" "$target_path"; then
        rm -f "$candidate_path"
        return 1
    fi

    if [ "${DEV_ENV_TEST_FAIL_POST_VERIFICATION:-0}" = "1" ] ||
            ! "$verify_function" "$target_path"; then
        if [ "$had_original" -eq 1 ]; then
            bootstrap_managed_artifact_restore "$target_path" "$backup_path" ||
                return 1
        else
            rm -f "$target_path"
        fi
        return 98
    fi
}

bootstrap_managed_artifact_install_exact_candidate() {
    local source_path="$1"
    local target_path="$2"
    local backup_dir="$3"
    local target_dir=""
    local candidate_path=""

    if [ -L "$source_path" ] || [ ! -f "$source_path" ]; then
        echo "ERROR: Managed exact-file source is not a regular file: $source_path" >&2
        return 1
    fi
    bootstrap_managed_artifact_refuse_unsafe_target "$target_path" || return 1

    target_dir="$(dirname "$target_path")"
    mkdir -p "$target_dir"
    candidate_path="$(mktemp "$target_dir/.${target_path##*/}.candidate.XXXXXX")" ||
        return 1
    if ! cp "$source_path" "$candidate_path"; then
        rm -f "$candidate_path"
        return 1
    fi
    BOOTSTRAP_MANAGED_ARTIFACT_EXPECTED_DIGEST="$(
        bootstrap_managed_artifact_digest "$candidate_path"
    )" || {
        rm -f "$candidate_path"
        return 1
    }

    if bootstrap_managed_artifact_promote_candidate \
            "$candidate_path" \
            "$target_path" \
            "$backup_dir" \
            bootstrap_managed_artifact_candidate_is_regular \
            bootstrap_managed_artifact_matches_expected_digest; then
        :
    else
        return $?
    fi
}

bootstrap_managed_artifact_install_exact() {
    BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL=""
    bootstrap_managed_artifact_install_exact_candidate "$@"
}

bootstrap_managed_artifact_apply_versioned_migration() {
    local migration_id="$1"
    local source_path="$2"
    local target_path="$3"
    local backup_dir="$4"
    local status=0

    if [ -z "$migration_id" ]; then
        echo "ERROR: Managed-artifact migration id is required." >&2
        return 2
    fi
    BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL="$(
        printf '%s' "$migration_id" | LC_ALL=C tr -c '[:alnum:]._-' '_'
    )"
    if bootstrap_managed_artifact_install_exact_candidate \
            "$source_path" "$target_path" "$backup_dir"; then
        status=0
    else
        status=$?
    fi
    BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL=""
    return "$status"
}

bootstrap_managed_artifact_apply_versioned_transform() {
    local migration_id="$1"
    local target_path="$2"
    local backup_dir="$3"
    local transform_function="$4"
    local validate_function="${5:-bootstrap_managed_artifact_candidate_is_regular}"
    local target_dir=""
    local candidate_path=""
    local status=0

    if [ -z "$migration_id" ] || [ -z "$transform_function" ]; then
        echo "ERROR: Managed-artifact transform migration id and function are required." >&2
        return 2
    fi
    bootstrap_managed_artifact_refuse_unsafe_target "$target_path" || return 1
    [ -f "$target_path" ] || return 0

    target_dir="$(dirname "$target_path")"
    candidate_path="$(mktemp "$target_dir/.${target_path##*/}.candidate.XXXXXX")" ||
        return 1
    if ! cp "$target_path" "$candidate_path" ||
            ! "$transform_function" "$candidate_path"; then
        rm -f "$candidate_path"
        return 1
    fi

    BOOTSTRAP_MANAGED_ARTIFACT_EXPECTED_DIGEST="$(
        bootstrap_managed_artifact_digest "$candidate_path"
    )" || {
        rm -f "$candidate_path"
        return 1
    }
    BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL="$(
        printf '%s' "$migration_id" | LC_ALL=C tr -c '[:alnum:]._-' '_'
    )"
    if bootstrap_managed_artifact_promote_candidate \
            "$candidate_path" \
            "$target_path" \
            "$backup_dir" \
            "$validate_function" \
            bootstrap_managed_artifact_matches_expected_digest; then
        status=0
    else
        status=$?
    fi
    BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL=""
    rm -f "$candidate_path"
    return "$status"
}

bootstrap_managed_artifact_markers_are_valid() {
    local path="$1"
    local begin_marker="$2"
    local end_marker="$3"
    local require_block="${4:-0}"

    awk -v begin="$begin_marker" -v end="$end_marker" -v required="$require_block" '
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
            if (required == 1 && (begin_count != 1 || end_count != 1)) invalid = 1
            exit invalid
        }
    ' "$path"
}

bootstrap_managed_artifact_replace_managed_block() {
    local target_path="$1"
    local begin_marker="$2"
    local end_marker="$3"
    local backup_dir="$4"
    local target_dir=""
    local existing_path=""
    local stripped_path=""
    local block_path=""
    local candidate_path=""
    local status=0

    BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL=""
    bootstrap_managed_artifact_refuse_unsafe_target "$target_path" || return 1
    target_dir="$(dirname "$target_path")"
    mkdir -p "$target_dir"
    existing_path="$(mktemp "$target_dir/.${target_path##*/}.existing.XXXXXX")" ||
        return 1
    stripped_path="$(mktemp "$target_dir/.${target_path##*/}.stripped.XXXXXX")" ||
        {
            rm -f "$existing_path"
            return 1
        }
    block_path="$(mktemp "$target_dir/.${target_path##*/}.block.XXXXXX")" ||
        {
            rm -f "$existing_path" "$stripped_path"
            return 1
        }
    candidate_path="$(mktemp "$target_dir/.${target_path##*/}.candidate.XXXXXX")" ||
        {
            rm -f "$existing_path" "$stripped_path" "$block_path"
            return 1
        }

    if [ -f "$target_path" ]; then
        cp "$target_path" "$existing_path" || {
            rm -f "$existing_path" "$stripped_path" "$block_path" "$candidate_path"
            return 1
        }
    else
        : > "$existing_path"
    fi
    cat > "$block_path"

    if ! bootstrap_managed_artifact_markers_are_valid \
            "$existing_path" "$begin_marker" "$end_marker" 0; then
        echo "ERROR: Refusing malformed managed block in: $target_path" >&2
        rm -f "$existing_path" "$stripped_path" "$block_path" "$candidate_path"
        return 1
    fi
    if ! bootstrap_managed_artifact_markers_are_valid \
            "$block_path" "$begin_marker" "$end_marker" 1; then
        echo "ERROR: Refusing malformed replacement managed block for: $target_path" >&2
        rm -f "$existing_path" "$stripped_path" "$block_path" "$candidate_path"
        return 1
    fi

    awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { skipping = 1; next }
        $0 == end { skipping = 0; next }
        skipping != 1 { print }
    ' "$existing_path" > "$stripped_path"
    {
        if [ -s "$stripped_path" ]; then
            sed -e '${/^$/d;}' "$stripped_path"
            printf '\n'
        fi
        cat "$block_path"
    } > "$candidate_path"

    if ! command -v zsh >/dev/null 2>&1; then
        echo "ERROR: zsh is required to validate managed shell content." >&2
        rm -f "$existing_path" "$stripped_path" "$block_path" "$candidate_path"
        return 1
    fi
    if ! zsh -n "$candidate_path"; then
        echo "ERROR: Refusing invalid managed shell content for: $target_path" >&2
        rm -f "$existing_path" "$stripped_path" "$block_path" "$candidate_path"
        return 1
    fi

    BOOTSTRAP_MANAGED_ARTIFACT_EXPECTED_DIGEST="$(
        bootstrap_managed_artifact_digest "$candidate_path"
    )" || {
        rm -f "$existing_path" "$stripped_path" "$block_path" "$candidate_path"
        return 1
    }
    if bootstrap_managed_artifact_promote_candidate \
            "$candidate_path" \
            "$target_path" \
            "$backup_dir" \
            bootstrap_managed_artifact_candidate_is_regular \
            bootstrap_managed_artifact_matches_expected_digest; then
        status=0
    else
        status=$?
    fi
    rm -f "$existing_path" "$stripped_path" "$block_path" "$candidate_path"
    return "$status"
}

bootstrap_managed_artifact_merge_overlay() {
    local format="$1"
    local incoming_path="$2"
    local target_path="$3"
    local backup_dir="$4"
    local python_bin="${5:-}"
    local target_dir=""
    local existing_path=""
    local candidate_path=""
    local status=0

    BOOTSTRAP_MANAGED_ARTIFACT_MUTATION_LABEL=""
    if [ "$format" != "json" ]; then
        echo "ERROR: Unsupported managed overlay format: $format" >&2
        return 2
    fi
    if [ -L "$incoming_path" ] || [ ! -f "$incoming_path" ]; then
        echo "ERROR: Managed overlay source is not a regular file: $incoming_path" >&2
        return 1
    fi
    if [ -z "$python_bin" ] || [ ! -x "$python_bin" ]; then
        echo "ERROR: Python is required for a managed JSON overlay." >&2
        return 1
    fi
    bootstrap_managed_artifact_refuse_unsafe_target "$target_path" || return 1

    target_dir="$(dirname "$target_path")"
    mkdir -p "$target_dir"
    existing_path="$(mktemp "$target_dir/.${target_path##*/}.existing.XXXXXX")" ||
        return 1
    candidate_path="$(mktemp "$target_dir/.${target_path##*/}.candidate.XXXXXX")" ||
        {
            rm -f "$existing_path"
            return 1
        }

    if [ -f "$target_path" ]; then
        cp "$target_path" "$existing_path" || {
            rm -f "$existing_path" "$candidate_path"
            return 1
        }
    else
        printf '{}\n' > "$existing_path"
    fi

    if ! "$python_bin" - \
            "$existing_path" "$incoming_path" "$candidate_path" <<'PY'
import json
import pathlib
import sys

existing_path = pathlib.Path(sys.argv[1])
incoming_path = pathlib.Path(sys.argv[2])
candidate_path = pathlib.Path(sys.argv[3])


def merge(existing_value, incoming_value):
    if isinstance(existing_value, dict) and isinstance(incoming_value, dict):
        merged = dict(existing_value)
        for key, value in incoming_value.items():
            if key in merged:
                merged[key] = merge(merged[key], value)
            else:
                merged[key] = value
        return merged

    if isinstance(existing_value, list) and isinstance(incoming_value, list):
        merged = list(existing_value)
        for item in incoming_value:
            if item not in merged:
                merged.append(item)
        return merged

    return incoming_value


existing = json.loads(existing_path.read_text())
incoming = json.loads(incoming_path.read_text())
candidate_path.write_text(json.dumps(merge(existing, incoming), indent=2) + "\n")
PY
    then
        echo "ERROR: Refusing malformed managed JSON overlay for: $target_path" >&2
        rm -f "$existing_path" "$candidate_path"
        return 1
    fi

    BOOTSTRAP_MANAGED_ARTIFACT_EXPECTED_DIGEST="$(
        bootstrap_managed_artifact_digest "$candidate_path"
    )" || {
        rm -f "$existing_path" "$candidate_path"
        return 1
    }
    BOOTSTRAP_MANAGED_ARTIFACT_VALIDATOR_BIN="$python_bin"
    if bootstrap_managed_artifact_promote_candidate \
            "$candidate_path" \
            "$target_path" \
            "$backup_dir" \
            bootstrap_managed_artifact_json_is_valid \
            bootstrap_managed_artifact_matches_expected_digest; then
        status=0
    else
        status=$?
    fi
    rm -f "$existing_path" "$candidate_path"
    return "$status"
}
