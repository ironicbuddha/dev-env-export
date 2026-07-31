#!/bin/bash
# =============================================================================
# 14-install-codex-skills.sh - Apply a Skill Hub installation profile
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_HUB_REPOSITORY="https://github.com/ironicbuddha/skills-hub.git"
SKILL_HUB_DIR="${SKILL_HUB_DIR:-$HOME/dev/skills-hub}"
SKILL_HUB_OWNER_FILE="${SKILL_HUB_DIR}.bootstrap-owner"
SKILL_SELECTION="${DEV_ENV_SKILL_SELECTION:-carlo-baseline}"
REFRESH_SOURCE=0

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/operation-policy.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/skill-hub-projection.sh"

usage() {
    cat <<'EOF'
Usage: ./scripts/14-install-codex-skills.sh [options]

Acquires the public Skill Hub and applies one named installation profile.
Ordinary runs reuse a bootstrap-owned checkout without fetching. Use --refresh
to explicitly fast-forward its expected clean source before applying.

Options:
  --refresh               Refresh a bootstrap-owned Skill Hub checkout first
  --skill-selection NAME  Skill Hub profile to apply (default: carlo-baseline)
  -h, --help              Show this help

Environment:
  SKILL_HUB_DIR           Checkout path (default: ~/dev/skills-hub)
  DEV_ENV_SKILL_SELECTION Profile override
EOF
}

record_skill_hub_operation() {
    bootstrap_operation_record "$@"
}

warn_and_skip() {
    local message="$1" failure_class="${2:-optional_degraded}" code="${3:-skill_hub_unavailable}"
    local recovery="${4:-retry_skill_hub_step}"
    local retry_args="--skill-selection $SKILL_SELECTION"

    if [[ "$recovery" = retry_skill_hub_refresh ]]; then
        retry_args="--refresh $retry_args"
    fi

    echo "[WARN] $message" >&2
    echo "[WARN] Recovery: $recovery" >&2
    echo "[WARN] Skipping Skill Hub installation; resolve the warning and rerun: ./scripts/14-install-codex-skills.sh $retry_args" >&2
    record_skill_hub_operation operation_end optional_degraded "$failure_class" "$code" 0 \
        "$recovery" skill_hub "$SKILL_HUB_DIR" "$message"
    return 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --refresh)
            REFRESH_SOURCE=1
            shift
            ;;
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

hub_default_branch() {
    local hub_dir="$1" default_ref=""
    default_ref="$(git -C "$hub_dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    [[ "$default_ref" == origin/* ]] || return 1
    printf '%s\n' "${default_ref#origin/}"
}

hub_commit() { git -C "$1" rev-parse HEAD 2>/dev/null; }

valid_hub_checkout() {
    local hub_dir="$1"
    [[ ! -L "$hub_dir" ]] &&
        [[ -d "$hub_dir" ]] &&
        git -C "$hub_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
        [[ "$(git -C "$hub_dir" remote get-url origin 2>/dev/null || true)" = "$SKILL_HUB_REPOSITORY" ]] &&
        [[ -x "$hub_dir/scripts/bootstrap" ]]
}

owner_value() {
    local key="$1"
    sed -n "s/^${key}=//p" "$SKILL_HUB_OWNER_FILE" 2>/dev/null | head -n 1
}

owned_hub_checkout() {
    local hub_dir="$1" branch=""
    [[ -f "$SKILL_HUB_OWNER_FILE" && ! -L "$SKILL_HUB_OWNER_FILE" ]] || return 1
    valid_hub_checkout "$hub_dir" || return 1
    branch="$(hub_default_branch "$hub_dir")" || return 1
    [[ "$(owner_value schema_version)" = 1 ]] &&
        [[ "$(owner_value repository)" = "$SKILL_HUB_REPOSITORY" ]] &&
        [[ "$(owner_value branch)" = "$branch" ]] &&
        [[ -n "$(owner_value checkout_commit)" ]] &&
        [[ "$(git -C "$hub_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)" = "$branch" ]]
}

write_owner_marker() {
    local hub_dir="$1" branch="$2" commit="$3" marker_tmp="${SKILL_HUB_OWNER_FILE}.tmp.$$"
    umask 077
    {
        echo "schema_version=1"
        echo "repository=$SKILL_HUB_REPOSITORY"
        echo "branch=$branch"
        echo "checkout_commit=$commit"
    } > "$marker_tmp" || return 1
    mv -f "$marker_tmp" "$SKILL_HUB_OWNER_FILE"
}

acquire_new_hub() {
    local temporary_hub_dir="" branch="" commit=""
    mkdir -p "$(dirname "$SKILL_HUB_DIR")"
    temporary_hub_dir="$(mktemp -d "${SKILL_HUB_DIR}.bootstrap.XXXXXX")"
    record_skill_hub_operation operation_start changed none clone_started 0 none skill_hub_clone "$SKILL_HUB_DIR" "Skill Hub clone staging started."
    if ! git clone "$SKILL_HUB_REPOSITORY" "$temporary_hub_dir"; then
        rm -rf "$temporary_hub_dir"
        warn_and_skip "Could not clone Skill Hub from $SKILL_HUB_REPOSITORY." optional_degraded skill_hub_clone_failed retry_skill_hub_step
        return 1
    fi
    if ! valid_hub_checkout "$temporary_hub_dir" || [[ -n "$(git -C "$temporary_hub_dir" status --porcelain)" ]]; then
        rm -rf "$temporary_hub_dir"
        warn_and_skip "Cloned Skill Hub checkout is incomplete or invalid." optional_degraded skill_hub_clone_invalid retry_skill_hub_step
        return 1
    fi
    branch="$(hub_default_branch "$temporary_hub_dir")" || {
        rm -rf "$temporary_hub_dir"
        warn_and_skip "Could not determine the cloned Skill Hub branch." optional_degraded skill_hub_branch_unknown retry_skill_hub_step
        return 1
    }
    commit="$(hub_commit "$temporary_hub_dir")" || {
        rm -rf "$temporary_hub_dir"
        warn_and_skip "Could not identify the cloned Skill Hub commit." optional_degraded skill_hub_commit_unknown retry_skill_hub_step
        return 1
    }
    if [[ -e "$SKILL_HUB_DIR" || -L "$SKILL_HUB_DIR" || -e "$SKILL_HUB_OWNER_FILE" || -L "$SKILL_HUB_OWNER_FILE" ]]; then
        rm -rf "$temporary_hub_dir"
        warn_and_skip "Skill Hub destination changed during clone staging; existing state was preserved." foreign_state_conflict skill_hub_destination_changed resolve_conflict
        return 1
    fi
    mv "$temporary_hub_dir" "$SKILL_HUB_DIR"
    if ! write_owner_marker "$SKILL_HUB_DIR" "$branch" "$commit"; then
        warn_and_skip "Skill Hub was cloned but its ownership record could not be written; preserve it and resolve manually." optional_degraded skill_hub_owner_write_failed resolve_conflict
        return 1
    fi
    record_skill_hub_operation operation_end changed none clone_promoted 0 none skill_hub_clone "$SKILL_HUB_DIR" "Skill Hub clone was promoted with bootstrap ownership."
}

refresh_owned_hub() {
    local branch="$1" before_commit="" after_commit=""
    before_commit="$(hub_commit "$SKILL_HUB_DIR")" || return 1
    record_skill_hub_operation operation_start changed none refresh_started 0 none skill_hub_refresh "$SKILL_HUB_DIR@$branch" "Explicit Skill Hub refresh started at $before_commit."
    if ! git -C "$SKILL_HUB_DIR" fetch origin "$branch"; then
        warn_and_skip "Could not fetch the explicit Skill Hub refresh." optional_degraded skill_hub_fetch_failed retry_skill_hub_refresh
        return 1
    fi
    if ! git -C "$SKILL_HUB_DIR" merge-base --is-ancestor HEAD "origin/$branch"; then
        warn_and_skip "Refusing divergent Skill Hub checkout; preserve it and resolve manually." foreign_state_conflict skill_hub_divergent resolve_conflict
        return 1
    fi
    if ! git -C "$SKILL_HUB_DIR" merge --ff-only "origin/$branch"; then
        warn_and_skip "Could not fast-forward the explicit Skill Hub refresh." optional_degraded skill_hub_fast_forward_failed retry_skill_hub_refresh
        return 1
    fi
    after_commit="$(hub_commit "$SKILL_HUB_DIR")" || return 1
    if ! write_owner_marker "$SKILL_HUB_DIR" "$branch" "$after_commit"; then
        warn_and_skip "Skill Hub refreshed but its ownership record could not be updated; resolve manually before another refresh." optional_degraded skill_hub_owner_update_failed resolve_conflict
        return 1
    fi
    record_skill_hub_operation operation_end changed none refresh_fast_forwarded 0 none skill_hub_refresh "$SKILL_HUB_DIR@$branch" "Skill Hub refreshed from $before_commit to $after_commit."
}

ensure_hub() {
    local branch=""
    if [[ ! -e "$SKILL_HUB_DIR" && ! -L "$SKILL_HUB_DIR" ]]; then
        acquire_new_hub || return 1
        return 0
    fi
    if ! valid_hub_checkout "$SKILL_HUB_DIR"; then
        warn_and_skip "Refusing user-managed or invalid Skill Hub path: $SKILL_HUB_DIR" foreign_state_conflict skill_hub_invalid resolve_conflict
        return 1
    fi
    if ! owned_hub_checkout "$SKILL_HUB_DIR"; then
        warn_and_skip "Refusing unowned Skill Hub checkout: $SKILL_HUB_DIR" foreign_state_conflict skill_hub_unowned resolve_conflict
        return 1
    fi
    if [[ -n "$(git -C "$SKILL_HUB_DIR" status --porcelain)" ]]; then
        warn_and_skip "Refusing dirty Skill Hub checkout: $SKILL_HUB_DIR" foreign_state_conflict skill_hub_dirty resolve_conflict
        return 1
    fi
    if [ "$REFRESH_SOURCE" -eq 1 ]; then
        branch="$(hub_default_branch "$SKILL_HUB_DIR")" || {
            warn_and_skip "Could not determine the Skill Hub branch for refresh." foreign_state_conflict skill_hub_branch_unknown resolve_conflict
            return 1
        }
        refresh_owned_hub "$branch" || return 1
    else
        record_skill_hub_operation operation_end satisfied none checkout_reused 0 none skill_hub_checkout "$SKILL_HUB_DIR" "Reused validated bootstrap-owned Skill Hub checkout without source refresh."
    fi
}

echo "========================================"
echo "Step 14: Applying Skill Hub Profile"
echo "========================================"
echo ""
echo "Hub: $SKILL_HUB_DIR"
echo "Selection: $SKILL_SELECTION"
echo "Source refresh: $REFRESH_SOURCE"
echo ""

if ! ensure_hub; then
    exit 0
fi

if [[ ! -f "$SKILL_HUB_DIR/profiles/$SKILL_SELECTION.json" ]]; then
    warn_and_skip "Skill Hub profile not found: $SKILL_SELECTION" optional_degraded skill_hub_profile_missing retry_skill_hub_step
    exit 0
fi

record_skill_hub_operation operation_start changed none projection_apply_started 0 none skill_hub_projection "$SKILL_SELECTION" "Skill Hub profile application started."
if ! "$SKILL_HUB_DIR/scripts/bootstrap" --profile "$SKILL_SELECTION" --no-input; then
    warn_and_skip "Skill Hub profile could not be applied safely." optional_degraded skill_hub_projection_apply_failed retry_skill_hub_step
    exit 0
fi
if ! skill_hub_projection_valid "$HOME"; then
    warn_and_skip "Skill Hub profile did not produce a valid projection: $SKILL_HUB_PROJECTION_REASON" optional_degraded skill_hub_projection_invalid retry_skill_hub_step
    exit 0
fi
record_skill_hub_operation operation_end satisfied none projection_verified 0 none skill_hub_projection "$SKILL_SELECTION" "Skill Hub profile projection verified through Agents, Claude, and Codex."

echo ""
echo "Skill Hub profile applied and projection verified: $SKILL_SELECTION"
