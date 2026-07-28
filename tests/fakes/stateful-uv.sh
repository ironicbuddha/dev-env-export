#!/bin/bash

set -euo pipefail

state_dir="${BOOTSTRAP_TEST_STATE_DIR:?BOOTSTRAP_TEST_STATE_DIR is required}"
call_log="${BOOTSTRAP_TEST_CALL_LOG:?BOOTSTRAP_TEST_CALL_LOG is required}"

printf 'uv\t%s\n' "$*" >> "$call_log"

environment_from_python() {
    local environment_python="$1"

    (cd "$(dirname "$environment_python")/.." && pwd)
}

package_name_from_spec() {
    local package_spec="$1"

    printf '%s\n' "${package_spec%%==*}"
}

package_version_from_spec() {
    local package_spec="$1"

    case "$package_spec" in
        *==*)
            printf '%s\n' "${package_spec#*==}"
            ;;
        *)
            printf '%s\n' "1.0.0"
            ;;
    esac
}

package_record() {
    local environment_dir="$1"
    local package_name="$2"
    local package_version="$3"

    printf '%s\t%s\n' "$package_name" "$package_version" >> \
        "$environment_dir/.fake-uv-packages.tsv"
}

package_version() {
    local environment_dir="$1"
    local package_name="$2"

    awk -F '\t' -v package_name="$package_name" \
        '$1 == package_name { version = $2 } END { if (version != "") print version }' \
        "$environment_dir/.fake-uv-packages.tsv" 2>/dev/null
}

case "${1:-}" in
    --version)
        printf 'uv 0.8.0\n'
        ;;
    venv)
        python_bin="${3:-}"
        environment_dir="${4:-}"
        failure_status=1

        if [ -f "$state_dir/uv.venv-failure-status" ]; then
            failure_status="$(cat "$state_dir/uv.venv-failure-status")"
            exit "$failure_status"
        fi
        if [ -e "$environment_dir" ] || [ -L "$environment_dir" ]; then
            echo "A virtual environment already exists at: $environment_dir" >&2
            exit 2
        fi

        python_version="$("$python_bin" --version 2>&1)"
        python_version="${python_version#Python }"
        if [ -f "$state_dir/uv.created-python-version" ]; then
            python_version="$(cat "$state_dir/uv.created-python-version")"
        fi

        mkdir -p "$environment_dir/bin"
        printf 'home = %s\nversion = %s\n' \
            "$(dirname "$(dirname "$python_bin")")" \
            "$python_version" > "$environment_dir/pyvenv.cfg"
        {
            printf '#!/bin/bash\n'
            printf 'printf "Python %s\\\\n"\n' "$python_version"
        } > "$environment_dir/bin/python"
        chmod +x "$environment_dir/bin/python"
        ;;
    pip)
        operation="${2:-}"
        environment_python="${4:-}"
        environment_dir="$(environment_from_python "$environment_python")"

        case "$operation" in
            show)
                package_name="$(package_name_from_spec "${5:-}")"
                installed_version="$(package_version "$environment_dir" "$package_name")"
                [ -n "$installed_version" ] || exit 1
                printf 'Name: %s\nVersion: %s\n' "$package_name" "$installed_version"
                ;;
            install)
                package_spec="${5:-}"
                package_name="$(package_name_from_spec "$package_spec")"
                package_version="$(package_version_from_spec "$package_spec")"
                if [ -f "$state_dir/uv.install-failure-package" ] &&
                        [ "$(cat "$state_dir/uv.install-failure-package")" = "$package_name" ]; then
                    if [ -f "$state_dir/uv.install-failure-after-write" ]; then
                        package_record "$environment_dir" "$package_name" "$package_version"
                    fi
                    exit "$(cat "$state_dir/uv.install-failure-status" 2>/dev/null || printf '1')"
                fi
                package_record "$environment_dir" "$package_name" "$package_version"
                ;;
            list)
                cat "$environment_dir/.fake-uv-packages.tsv" 2>/dev/null || true
                ;;
            *)
                echo "Unsupported fake uv pip operation: $operation" >&2
                exit 64
                ;;
        esac
        ;;
    *)
        echo "Unsupported fake uv command: ${1:-}" >&2
        exit 64
        ;;
esac
