#!/bin/bash
# =============================================================================
# 14-install-codex-skills.sh - Link Repo-Vendored Codex Skills Into Home
# =============================================================================
# Links skills tracked in codex/skills/ into ~/.codex/skills and optionally
# mirrors them into ~/.agents/skills for shared discovery.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_SKILLS_DIR="$REPO_ROOT/codex/skills"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CODEX_SKILLS_HOME="$CODEX_HOME/skills"
SHARED_SKILLS_HOME="$HOME/.agents/skills"
SKILL_NAME=""
LINK_SHARED=1
BACKUP_DIR="$HOME/.codex-skill-backup-$(date '+%Y%m%d-%H%M%S')"
USED_BACKUP_DIR=0

declare -a INSTALLED_ITEMS=()
declare -a SKIPPED_ITEMS=()
declare -a WARNING_ITEMS=()

usage() {
    cat <<'EOF'
Usage: ./scripts/14-install-codex-skills.sh [options]

Options:
  --skill NAME        Install only one repo-vendored skill
  --no-shared-link    Do not link skills into ~/.agents/skills
  -h, --help          Show this help

Examples:
  ./scripts/14-install-codex-skills.sh
  ./scripts/14-install-codex-skills.sh --skill apply-project-standards
  ./scripts/14-install-codex-skills.sh --skill apply-project-standards --no-shared-link
EOF
}

record_installed() {
    INSTALLED_ITEMS+=("$1")
}

record_skipped() {
    SKIPPED_ITEMS+=("$1")
}

record_warning() {
    WARNING_ITEMS+=("$1")
    echo "[WARN] $1" >&2
}

ensure_backup_dir() {
    if [[ "$USED_BACKUP_DIR" -eq 0 ]]; then
        mkdir -p "$BACKUP_DIR"
        USED_BACKUP_DIR=1
    fi
}

backup_existing_path() {
    local dest="$1"
    local relative_path="${dest#"$HOME"/}"
    local backup_target=""

    ensure_backup_dir

    if [[ "$relative_path" == "$dest" ]]; then
        relative_path="$(basename "$dest")"
    fi

    backup_target="$BACKUP_DIR/$relative_path"
    mkdir -p "$(dirname "$backup_target")"
    mv "$dest" "$backup_target"
    record_installed "Backed up $dest to $backup_target"
}

link_skill() {
    local src="$1"
    local dest="$2"
    local label="$3"

    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        record_skipped "$label already pointed at $src"
        return
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        backup_existing_path "$dest"
    fi

    ln -s "$src" "$dest"
    record_installed "Linked $label to $src"
}

collect_skill_dirs() {
    if [[ ! -d "$SOURCE_SKILLS_DIR" ]]; then
        echo "ERROR: Repo skill directory not found: $SOURCE_SKILLS_DIR" >&2
        exit 1
    fi

    if [[ -n "$SKILL_NAME" ]]; then
        if [[ ! -f "$SOURCE_SKILLS_DIR/$SKILL_NAME/SKILL.md" ]]; then
            echo "ERROR: Repo skill not found: $SKILL_NAME" >&2
            exit 1
        fi
        printf '%s\n' "$SOURCE_SKILLS_DIR/$SKILL_NAME"
        return
    fi

    find "$SOURCE_SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d | while IFS= read -r skill_dir; do
        if [[ -f "$skill_dir/SKILL.md" ]]; then
            printf '%s\n' "$skill_dir"
        fi
    done | sort
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skill)
            SKILL_NAME="${2:-}"
            shift 2
            ;;
        --no-shared-link)
            LINK_SHARED=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

echo "========================================"
echo "Installing Repo-Vendored Codex Skills"
echo "========================================"
echo ""
echo "Source: $SOURCE_SKILLS_DIR"
echo "Codex target: $CODEX_SKILLS_HOME"
if [[ "$LINK_SHARED" -eq 1 ]]; then
    echo "Shared target: $SHARED_SKILLS_HOME"
fi
echo ""

mkdir -p "$CODEX_SKILLS_HOME"
if [[ "$LINK_SHARED" -eq 1 ]]; then
    mkdir -p "$SHARED_SKILLS_HOME"
fi

installed_any=0
while IFS= read -r skill_dir; do
    skill_name="$(basename "$skill_dir")"
    codex_target="$CODEX_SKILLS_HOME/$skill_name"

    link_skill "$skill_dir" "$codex_target" "~/.codex/skills/$skill_name"
    installed_any=1

    if [[ "$LINK_SHARED" -eq 1 ]]; then
        shared_target="$SHARED_SKILLS_HOME/$skill_name"
        if [[ -e "$shared_target" && ! -L "$shared_target" ]]; then
            record_warning "Skipping shared skill link for $skill_name because $shared_target already exists and is not a symlink"
        else
            link_skill "$codex_target" "$shared_target" "~/.agents/skills/$skill_name"
        fi
    fi
done < <(collect_skill_dirs)

if [[ "$installed_any" -eq 0 ]]; then
    record_warning "No repo-vendored skills were found under $SOURCE_SKILLS_DIR"
fi

echo ""
echo "Installed:"
if [[ "${#INSTALLED_ITEMS[@]}" -gt 0 ]]; then
    printf '  - %s\n' "${INSTALLED_ITEMS[@]}"
else
    echo "  (none)"
fi

echo ""
echo "Skipped:"
if [[ "${#SKIPPED_ITEMS[@]}" -gt 0 ]]; then
    printf '  - %s\n' "${SKIPPED_ITEMS[@]}"
else
    echo "  (none)"
fi

if [[ "${#WARNING_ITEMS[@]}" -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    printf '  - %s\n' "${WARNING_ITEMS[@]}"
fi

if [[ "$USED_BACKUP_DIR" -eq 1 ]]; then
    echo ""
    echo "Backups: $BACKUP_DIR"
fi
