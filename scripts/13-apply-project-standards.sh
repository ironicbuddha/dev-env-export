#!/bin/bash
# =============================================================================
# 13-apply-project-standards.sh - Apply Project Standards Starter To a Repo
# =============================================================================
# Copies the repo's project-standards starter into a target repository and
# applies the matching code-quality baseline for a chosen profile.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
QUALITY_DIR="$REPO_ROOT/templates/code-quality"
STANDARDS_DIR="$REPO_ROOT/templates/project-standards"
AGENT_DIRECTION_DIR="$REPO_ROOT/templates/agent-direction"

TARGET_REPO=""
PROFILE=""
FORCE=0
DRY_RUN=0
CONSTITUTION_ONLY=0

declare -a APPLIED_ITEMS=()
declare -a SKIPPED_ITEMS=()
declare -a WARNING_ITEMS=()

usage() {
    cat <<'EOF'
Usage: ./scripts/13-apply-project-standards.sh --repo PATH --profile PROFILE [options]

Profiles:
  next         Next.js app
  vite         Vite frontend app
  ts-service   TypeScript API, Lambda, or service repo
  python       Python script or library-driven worker
  mixed        Frontend + backend split repo

Options:
  --repo PATH             Target repository path
  --profile PROFILE       Starter profile to apply
  --force                 Overwrite conflicting files after backing them up
  --dry-run               Print planned actions without changing files
  --constitution-only     Only write constitution.md
  -h, --help              Show this help

Examples:
  ./scripts/13-apply-project-standards.sh \
    --repo ~/dev/my-next-app \
    --profile next

  ./scripts/13-apply-project-standards.sh \
    --repo ~/dev/my-api \
    --profile ts-service \
    --force

  ./scripts/13-apply-project-standards.sh \
    --repo ~/dev/my-script \
    --profile python \
    --dry-run
EOF
}

record_applied() {
    APPLIED_ITEMS+=("$1")
}

record_skipped() {
    SKIPPED_ITEMS+=("$1")
}

record_warning() {
    WARNING_ITEMS+=("$1")
    echo "[WARN] $1" >&2
}

info() {
    echo "[INFO] $1"
}

resolve_target_repo() {
    local target_input="$1"

    if [[ ! -d "$target_input" ]]; then
        echo "ERROR: Target path is not a directory: $target_input" >&2
        exit 1
    fi

    target_input="$(cd "$target_input" && pwd)"

    if git -C "$target_input" rev-parse --show-toplevel >/dev/null 2>&1; then
        git -C "$target_input" rev-parse --show-toplevel
    else
        printf '%s\n' "$target_input"
    fi
}

backup_path_for() {
    local dest="$1"
    printf '%s.bak.%s\n' "$dest" "$(date '+%Y%m%d-%H%M%S')"
}

write_file_safe() {
    local src="$1"
    local dest="$2"
    local label="$3"
    local backup=""

    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
        record_skipped "$label already matched existing file"
        return
    fi

    if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
        record_skipped "$label skipped because $dest already exists"
        record_warning "Use --force to overwrite $dest"
        return
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        record_applied "Would write $label to $dest"
        return
    fi

    mkdir -p "$(dirname "$dest")"

    if [[ -e "$dest" ]]; then
        backup="$(backup_path_for "$dest")"
        mv "$dest" "$backup"
        record_applied "Backed up $dest to $backup"
    fi

    cp "$src" "$dest"
    record_applied "Wrote $label to $dest"
}

render_constitution() {
    local profile="$1"
    local project_name="$2"
    local today="$3"
    local output_file="$4"
    local project_type=""
    local primary_language=""
    local frontend_stack=""
    local backend_shape=""
    local package_manager=""
    local deployment_target=""
    local data_sensitivity="moderate"
    local runtime_versions=""

    case "$profile" in
        next)
            project_type="web-app"
            primary_language="TypeScript"
            frontend_stack="Next.js"
            backend_shape="none"
            package_manager="pnpm"
            deployment_target="Vercel"
            runtime_versions="Node 22.x"
            ;;
        vite)
            project_type="web-app"
            primary_language="TypeScript"
            frontend_stack="Vite"
            backend_shape="none"
            package_manager="pnpm"
            deployment_target="other"
            runtime_versions="Node 22.x"
            ;;
        ts-service)
            project_type="api"
            primary_language="TypeScript"
            frontend_stack="none"
            backend_shape="node-service"
            package_manager="pnpm"
            deployment_target="AWS"
            runtime_versions="Node 22.x"
            ;;
        python)
            project_type="worker"
            primary_language="Python"
            frontend_stack="none"
            backend_shape="python-script"
            package_manager="uv"
            deployment_target="AWS"
            runtime_versions="Python 3.x"
            ;;
        mixed)
            project_type="mixed"
            primary_language="mixed"
            frontend_stack="Next.js"
            backend_shape="node-service"
            package_manager="pnpm"
            deployment_target="Vercel + AWS"
            runtime_versions="Node 22.x and Python 3.x"
            ;;
        *)
            echo "ERROR: Unsupported profile: $profile" >&2
            exit 1
            ;;
    esac

    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: python3 is required to render the constitution template" >&2
        exit 1
    fi

    python3 - \
        "$STANDARDS_DIR/constitution.md" \
        "$output_file" \
        "$project_name" \
        "$project_type" \
        "$primary_language" \
        "$frontend_stack" \
        "$backend_shape" \
        "$package_manager" \
        "$deployment_target" \
        "$data_sensitivity" \
        "$runtime_versions" \
        "$today" <<'PY'
from pathlib import Path
import sys

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

(
    project_name,
    project_type,
    primary_language,
    frontend_stack,
    backend_shape,
    package_manager,
    deployment_target,
    data_sensitivity,
    runtime_versions,
    today,
) = sys.argv[3:]

content = template_path.read_text()

replacements = {
    "{{PROJECT_NAME}}": project_name,
    "{{web-app | api | lambda | worker | library | mixed}}": project_type,
    "{{TypeScript | Python | mixed}}": primary_language,
    "{{Next.js | Vite | none}}": frontend_stack,
    "{{node-service | lambda | worker | python-script | none}}": backend_shape,
    "{{pnpm | npm | uv}}": package_manager,
    "{{Vercel | AWS | Vercel + AWS | other}}": deployment_target,
    "{{low | moderate | high}}": data_sensitivity,
    "{{fill in}}": runtime_versions,
    "{{0.1.0}}": "0.1.0",
    "{{YYYY-MM-DD}}": today,
}

for needle, replacement in replacements.items():
    content = content.replace(needle, replacement)

output_path.write_text(content)
PY
}

write_rendered_file_safe() {
    local render_file="$1"
    local dest="$2"
    local label="$3"
    local backup=""

    if [[ -f "$dest" ]] && cmp -s "$render_file" "$dest"; then
        record_skipped "$label already matched existing file"
        return
    fi

    if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
        record_skipped "$label skipped because $dest already exists"
        record_warning "Use --force to overwrite $dest"
        return
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        record_applied "Would write $label to $dest"
        return
    fi

    mkdir -p "$(dirname "$dest")"

    if [[ -e "$dest" ]]; then
        backup="$(backup_path_for "$dest")"
        mv "$dest" "$backup"
        record_applied "Backed up $dest to $backup"
    fi

    cp "$render_file" "$dest"
    record_applied "Wrote $label to $dest"
}

merge_package_json_quality() {
    local target_repo_root="$1"
    local package_json="$target_repo_root/package.json"
    local quality_json="$QUALITY_DIR/package.quality.json"
    local temp_file=""

    if [[ ! -f "$package_json" ]]; then
        record_skipped "package.json merge skipped because $package_json was not found"
        record_warning "Create package.json first if you want the quality scripts and devDependencies merged automatically"
        return
    fi

    if ! command -v jq >/dev/null 2>&1; then
        record_skipped "package.json merge skipped because jq is not installed"
        record_warning "Install jq to enable automatic package.json merging"
        return
    fi

    temp_file="$(mktemp)"

    jq \
        -s \
        --arg force "$FORCE" \
        '
        def merge_missing(base; extra):
          reduce (extra | keys_unsorted[]) as $k (
            base;
            if .[$k] == null then
              . + {($k): extra[$k]}
            else
              .
            end
          );

        .[0] as $target
        | .[1] as $quality
        | $target
        | .scripts =
            if $force == "1" then
              (($target.scripts // {}) + ($quality.scripts // {}))
            else
              merge_missing(($target.scripts // {}); ($quality.scripts // {}))
            end
        | .devDependencies =
            if $force == "1" then
              (($target.devDependencies // {}) + ($quality.devDependencies // {}))
            else
              merge_missing(($target.devDependencies // {}); ($quality.devDependencies // {}))
            end
        ' \
        "$package_json" \
        "$quality_json" > "$temp_file"

    if cmp -s "$package_json" "$temp_file"; then
        record_skipped "package.json already contained the quality merge result"
        rm -f "$temp_file"
        return
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        record_applied "Would merge quality scripts and devDependencies into $package_json"
        rm -f "$temp_file"
        return
    fi

    cp "$temp_file" "$package_json"
    rm -f "$temp_file"
    record_applied "Merged quality scripts and devDependencies into $package_json"
}

append_ruff_if_needed() {
    local pyproject_file="$1"
    local ruff_marker='^\[tool\.ruff\]'
    local ruff_content=""

    if grep -Eq "$ruff_marker" "$pyproject_file"; then
        record_skipped "Ruff config already exists in $pyproject_file"
        return
    fi

    ruff_content="$(awk 'BEGIN { printing = 0 } /^\[tool\.ruff\]/ { printing = 1 } printing { print }' "$QUALITY_DIR/pyproject.toml")"

    if [[ -z "$ruff_content" ]]; then
        record_warning "Could not extract Ruff config from template"
        return
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        record_applied "Would append Ruff config to $pyproject_file"
        return
    fi

    {
        printf '\n# Dev Env Export quality baseline\n\n'
        printf '%s\n' "$ruff_content"
    } >> "$pyproject_file"

    record_applied "Appended Ruff config to $pyproject_file"

    if ! grep -Eq '^\[dependency-groups\]' "$pyproject_file"; then
        record_warning "pyproject.toml still needs a dev dependency entry for Ruff if this repo does not already manage it"
    fi
}

apply_python_baseline() {
    local target_repo_root="$1"
    local pyproject_file="$target_repo_root/pyproject.toml"
    local makefile_path="$target_repo_root/Makefile"
    local python_makefile_template="$QUALITY_DIR/Makefile.python"
    local fallback_makefile_path="$target_repo_root/Makefile.python"

    write_file_safe "$QUALITY_DIR/.markdownlint.json" "$target_repo_root/.markdownlint.json" ".markdownlint.json"

    if [[ ! -f "$pyproject_file" ]]; then
        write_file_safe "$QUALITY_DIR/pyproject.toml" "$pyproject_file" "pyproject.toml"
    else
        append_ruff_if_needed "$pyproject_file"
    fi

    if [[ ! -f "$makefile_path" ]]; then
        write_file_safe "$python_makefile_template" "$makefile_path" "Makefile"
    elif grep -Eq 'ruff' "$makefile_path"; then
        record_skipped "Makefile already appears to include Ruff commands"
    else
        write_file_safe "$python_makefile_template" "$fallback_makefile_path" "Makefile.python"
        record_warning "A Makefile already exists, so the Python starter was written to $fallback_makefile_path instead"
    fi
}

apply_ts_baseline() {
    local target_repo_root="$1"

    write_file_safe "$QUALITY_DIR/.prettierrc.json" "$target_repo_root/.prettierrc.json" ".prettierrc.json"
    write_file_safe "$QUALITY_DIR/.prettierignore" "$target_repo_root/.prettierignore" ".prettierignore"
    write_file_safe "$QUALITY_DIR/.markdownlint.json" "$target_repo_root/.markdownlint.json" ".markdownlint.json"
    write_file_safe "$QUALITY_DIR/eslint.config.mjs" "$target_repo_root/eslint.config.mjs" "eslint.config.mjs"
    write_file_safe "$QUALITY_DIR/stylelint.config.mjs" "$target_repo_root/stylelint.config.mjs" "stylelint.config.mjs"
    merge_package_json_quality "$target_repo_root"
}

apply_agent_direction() {
    local target_repo_root="$1"

    if [[ ! -d "$AGENT_DIRECTION_DIR" ]]; then
        record_warning "Agent direction templates not found at $AGENT_DIRECTION_DIR"
        return
    fi

    if [[ ! -f "$AGENT_DIRECTION_DIR/AGENTS.md" || ! -f "$AGENT_DIRECTION_DIR/CLAUDE.md" ]]; then
        record_warning "Agent direction templates must include AGENTS.md and CLAUDE.md"
        return
    fi

    write_file_safe "$AGENT_DIRECTION_DIR/AGENTS.md" "$target_repo_root/AGENTS.md" "AGENTS.md"
    write_file_safe "$AGENT_DIRECTION_DIR/CLAUDE.md" "$target_repo_root/CLAUDE.md" "CLAUDE.md"
}

print_summary() {
    local target_repo_root="$1"

    echo ""
    echo "========================================"
    echo "Project Standards Apply Summary"
    echo "========================================"
    echo ""
    echo "Repo: $target_repo_root"
    echo "Profile: $PROFILE"
    echo "Dry run: $DRY_RUN"
    echo "Constitution only: $CONSTITUTION_ONLY"
    echo ""

    if [[ "${#APPLIED_ITEMS[@]}" -gt 0 ]]; then
        echo "Applied:"
        printf '  - %s\n' "${APPLIED_ITEMS[@]}"
        echo ""
    fi

    if [[ "${#SKIPPED_ITEMS[@]}" -gt 0 ]]; then
        echo "Skipped:"
        printf '  - %s\n' "${SKIPPED_ITEMS[@]}"
        echo ""
    fi

    if [[ "${#WARNING_ITEMS[@]}" -gt 0 ]]; then
        echo "Warnings:"
        printf '  - %s\n' "${WARNING_ITEMS[@]}"
        echo ""
    fi

    echo "Next:"
    echo "  - Review $target_repo_root/constitution.md and trim any profile sections that do not apply"
    if [[ "$PROFILE" == "next" || "$PROFILE" == "vite" || "$PROFILE" == "ts-service" || "$PROFILE" == "mixed" ]]; then
        echo "  - Install the repo-local JS tooling with the repo's package manager"
        echo "  - Run lint, format:check, test, and build once the repo scripts are in place"
    fi
    if [[ "$PROFILE" == "python" || "$PROFILE" == "mixed" ]]; then
        echo "  - Review pyproject.toml and ensure Ruff is wired into the repo's real dev dependency flow"
        echo "  - Adjust the Python Makefile target names if the repo already has command conventions"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            TARGET_REPO="${2:-}"
            shift 2
            ;;
        --profile)
            PROFILE="${2:-}"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --constitution-only)
            CONSTITUTION_ONLY=1
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

if [[ -z "$TARGET_REPO" || -z "$PROFILE" ]]; then
    usage >&2
    exit 1
fi

case "$PROFILE" in
    next|vite|ts-service|python|mixed)
        ;;
    *)
        echo "ERROR: Unsupported profile: $PROFILE" >&2
        usage >&2
        exit 1
        ;;
esac

TARGET_REPO="$(resolve_target_repo "$TARGET_REPO")"
PROJECT_NAME="$(basename "$TARGET_REPO")"
TODAY="$(date '+%Y-%m-%d')"
CONSTITUTION_TMP="$(mktemp)"

trap 'rm -f "$CONSTITUTION_TMP"' EXIT

info "Applying project standards starter"
info "Repo: $TARGET_REPO"
info "Profile: $PROFILE"

render_constitution "$PROFILE" "$PROJECT_NAME" "$TODAY" "$CONSTITUTION_TMP"
write_rendered_file_safe "$CONSTITUTION_TMP" "$TARGET_REPO/constitution.md" "constitution.md"

if [[ "$CONSTITUTION_ONLY" -ne 1 ]]; then
    apply_agent_direction "$TARGET_REPO"

    case "$PROFILE" in
        next|vite|ts-service)
            apply_ts_baseline "$TARGET_REPO"
            ;;
        python)
            apply_python_baseline "$TARGET_REPO"
            ;;
        mixed)
            apply_ts_baseline "$TARGET_REPO"
            apply_python_baseline "$TARGET_REPO"
            ;;
    esac
fi

print_summary "$TARGET_REPO"
