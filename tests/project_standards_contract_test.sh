#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLIER="$REPO_ROOT/scripts/13-apply-project-standards.sh"
TEST_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file_contains() {
    local file="$1"
    local expected="$2"
    grep -Fq "$expected" "$file" || fail "Expected $file to contain: $expected"
}

target="$TEST_ROOT/target"
mkdir -p "$target"

/bin/bash "$APPLIER" --repo "$target" --profile markdown >/dev/null

[[ -f "$target/AGENTS.md" ]] || fail "Expected AGENTS.md starter"
[[ -L "$target/CLAUDE.md" ]] || fail "Expected CLAUDE.md to be a relative symlink"
[[ "$(readlink "$target/CLAUDE.md")" == "AGENTS.md" ]] || fail "Expected CLAUDE.md to link to AGENTS.md"
assert_file_contains "$target/AGENTS.md" '[constitution.md](constitution.md)'

/bin/bash "$APPLIER" --repo "$target" --profile markdown >/dev/null

[[ -L "$target/CLAUDE.md" ]] || fail "Expected repeated application to preserve the symlink"
[[ "$(readlink "$target/CLAUDE.md")" == "AGENTS.md" ]] || fail "Expected repeated application to preserve the symlink target"

existing_target="$TEST_ROOT/existing-target"
mkdir -p "$existing_target"
printf '%s\n' 'keep this Claude guidance' > "$existing_target/CLAUDE.md"

/bin/bash "$APPLIER" --repo "$existing_target" --profile markdown >/dev/null

[[ ! -L "$existing_target/CLAUDE.md" ]] || fail "Expected existing CLAUDE.md to remain a file"
assert_file_contains "$existing_target/CLAUDE.md" 'keep this Claude guidance'

echo "Project standards contract tests passed."
