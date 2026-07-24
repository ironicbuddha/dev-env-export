#!/bin/bash
# =============================================================================
# 14-install-codex-skills.sh - Apply a Skill Hub installation profile
# =============================================================================

set -euo pipefail

SKILL_HUB_REPOSITORY="https://github.com/ironicbuddha/skill-hub.git"
SKILL_HUB_DIR="${SKILL_HUB_DIR:-$HOME/dev/skills-hub}"
SKILL_SELECTION="${DEV_ENV_SKILL_SELECTION:-carlo-baseline}"

usage() {
    cat <<'EOF'
Usage: ./scripts/14-install-codex-skills.sh [options]

Acquires the public Skill Hub and applies one named installation profile.
This script never replaces a user-managed checkout or skill target. Acquisition
or update failures are reported and skipped so the broader bootstrap can finish.

Options:
  --skill-selection NAME  Skill Hub profile to apply (default: carlo-baseline)
  -h, --help              Show this help

Environment:
  SKILL_HUB_DIR           Checkout path (default: ~/dev/skills-hub)
  DEV_ENV_SKILL_SELECTION Profile override
EOF
}

warn_and_skip() {
    echo "[WARN] $1" >&2
    echo "[WARN] Skipping Skill Hub installation; resolve the path manually and rerun this step." >&2
    return 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skill-selection)
            SKILL_SELECTION="${2:-}"
            if [[ -z "$SKILL_SELECTION" ]]; then
                echo "ERROR: --skill-selection requires a value." >&2
                exit 2
            fi
            shift 2
            ;;
        --skill-selection=*)
            SKILL_SELECTION="${1#--skill-selection=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! "$SKILL_SELECTION" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "ERROR: Skill selection must use lowercase letters, numbers, and hyphens." >&2
    exit 2
fi

valid_hub_checkout() {
    [[ ! -L "$SKILL_HUB_DIR" ]] &&
        [[ -d "$SKILL_HUB_DIR" ]] &&
        git -C "$SKILL_HUB_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
        [[ "$(git -C "$SKILL_HUB_DIR" remote get-url origin 2>/dev/null || true)" = "$SKILL_HUB_REPOSITORY" ]] &&
        [[ -x "$SKILL_HUB_DIR/scripts/bootstrap" ]]
}

acquire_hub() {
    if [[ ! -e "$SKILL_HUB_DIR" ]]; then
        mkdir -p "$(dirname "$SKILL_HUB_DIR")"
        if ! git clone "$SKILL_HUB_REPOSITORY" "$SKILL_HUB_DIR"; then
            warn_and_skip "Could not clone Skill Hub from $SKILL_HUB_REPOSITORY."
            return 1
        fi
    elif ! valid_hub_checkout; then
        warn_and_skip "Refusing user-managed or invalid Skill Hub path: $SKILL_HUB_DIR"
        return 1
    fi

    if [[ -n "$(git -C "$SKILL_HUB_DIR" status --porcelain)" ]]; then
        warn_and_skip "Refusing to update dirty Skill Hub checkout: $SKILL_HUB_DIR"
        return 1
    fi

    local default_ref=""
    local default_branch=""
    default_ref="$(git -C "$SKILL_HUB_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    if [[ "$default_ref" != origin/* ]]; then
        warn_and_skip "Could not determine the Skill Hub default branch."
        return 1
    fi
    default_branch="${default_ref#origin/}"

    if [[ "$(git -C "$SKILL_HUB_DIR" rev-parse --abbrev-ref HEAD)" != "$default_branch" ]]; then
        warn_and_skip "Refusing to update Skill Hub checkout not on $default_branch."
        return 1
    fi

    if ! git -C "$SKILL_HUB_DIR" fetch origin "$default_branch" ||
        ! git -C "$SKILL_HUB_DIR" merge --ff-only "origin/$default_branch"; then
        warn_and_skip "Could not fast-forward Skill Hub checkout: $SKILL_HUB_DIR"
        return 1
    fi
}

echo "========================================"
echo "Step 14: Applying Skill Hub Profile"
echo "========================================"
echo ""
echo "Hub: $SKILL_HUB_DIR"
echo "Selection: $SKILL_SELECTION"
echo ""

if ! acquire_hub; then
    exit 0
fi

if [[ ! -f "$SKILL_HUB_DIR/profiles/$SKILL_SELECTION.json" ]]; then
    warn_and_skip "Skill Hub profile not found: $SKILL_SELECTION"
    exit 0
fi

if ! "$SKILL_HUB_DIR/scripts/bootstrap" --profile "$SKILL_SELECTION" --no-input; then
    warn_and_skip "Skill Hub profile could not be applied safely."
    exit 0
fi

echo ""
echo "Skill Hub profile applied: $SKILL_SELECTION"
