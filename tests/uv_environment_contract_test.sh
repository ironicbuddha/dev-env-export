#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-uv-environment-tests.XXXXXX")"
FIXTURE_ROOT="$TEST_TMP_ROOT/fixture"
FAKE_BIN="$FIXTURE_ROOT/bin"
PYTHON_PREFIX="$FIXTURE_ROOT/python-3.14"
UV_ENV_DIR="$FIXTURE_ROOT/bootstrap-python"
OUTPUT_FILE="$FIXTURE_ROOT/output.txt"
ACTION_LOG="$FIXTURE_ROOT/actions.log"

cleanup() {
    rm -rf "$TEST_TMP_ROOT"
}

trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$FIXTURE_ROOT/scripts/lib" "$FAKE_BIN" "$PYTHON_PREFIX/bin"
cp "$REPO_ROOT/scripts/04-install-pip-packages.sh" "$FIXTURE_ROOT/scripts/04-install-pip-packages.sh"
cp "$REPO_ROOT/scripts/lib/bootstrap-profile.sh" "$FIXTURE_ROOT/scripts/lib/bootstrap-profile.sh"
cp "$REPO_ROOT/scripts/lib/runtime-environment.sh" "$FIXTURE_ROOT/scripts/lib/runtime-environment.sh"

cat > "$FAKE_BIN/brew" <<EOF
#!/bin/bash
[ "\${1:-}" = "--prefix" ] && [ "\${2:-}" = "python@3.14" ] && printf '%s\\n' "$PYTHON_PREFIX"
EOF

cat > "$PYTHON_PREFIX/bin/python3.14" <<'EOF'
#!/bin/bash
[ "${1:-}" = "--version" ] && printf '%s\n' "Python 3.14.0"
EOF

cat > "$FAKE_BIN/uv" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >> "$TEST_ACTION_LOG"

case "${1:-}" in
    venv)
        mkdir -p "${4:-}/bin"
        printf '#!/bin/bash\n' > "${4:-}/bin/python"
        chmod +x "${4:-}/bin/python"
        ;;
    pip)
        case "${2:-}" in
            show) exit 1 ;;
            install|list) exit 0 ;;
        esac
        ;;
esac
EOF

chmod +x "$FAKE_BIN/brew" "$FAKE_BIN/uv" "$PYTHON_PREFIX/bin/python3.14"

if PATH="$FAKE_BIN:/usr/bin:/bin" \
        TEST_ACTION_LOG="$ACTION_LOG" \
        DEV_ENV_UV_ENV_DIR="$UV_ENV_DIR" \
        /bin/bash "$FIXTURE_ROOT/scripts/04-install-pip-packages.sh" \
        --profile shared-baseline > "$OUTPUT_FILE" 2>&1; then
    :
else
    sed 's/^/  | /' "$OUTPUT_FILE" >&2
    fail "uv environment installer should complete"
fi

grep -Fq "uv venv --python $PYTHON_PREFIX/bin/python3.14 $UV_ENV_DIR" "$ACTION_LOG" || \
    fail "step 4 did not create the bootstrap-owned uv environment with Python 3.14"
grep -Fq "uv pip install --python $UV_ENV_DIR/bin/python python-docx" "$ACTION_LOG" || \
    fail "step 4 did not install the document stack into the uv environment"
if grep -Fq -- '--user' "$ACTION_LOG" || grep -Fq 'break-system-packages' "$ACTION_LOG"; then
    fail "step 4 fell back to user-site pip installation"
fi

echo "ok 1 - document_stack_uses_bootstrap_owned_uv_environment"
echo "1..1"
