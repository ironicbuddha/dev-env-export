#!/bin/bash
# =============================================================================
# 07-import-secrets.sh - Import Secrets from secrets-export.txt
# =============================================================================
# Safely imports selected secrets into the current user account:
# - ~/.aws/credentials
# - ~/.ssh/id_ed25519 (+ derived public key)
# - Optional: OPENAI_API_KEY into ~/.zshrc
#
# Usage:
#   ./scripts/07-import-secrets.sh [--source FILE] [--dry-run] [--write-openai]
# =============================================================================

set -euo pipefail

SOURCE_FILE="secrets-export.txt"
DRY_RUN=0
WRITE_OPENAI=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            SOURCE_FILE="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --write-openai)
            WRITE_OPENAI=1
            shift
            ;;
        -h|--help)
            cat <<'EOF'
Usage: ./scripts/07-import-secrets.sh [options]

Options:
  --source FILE      Path to secrets export file (default: secrets-export.txt)
  --dry-run          Print actions without writing files
  --write-openai     Write OPENAI_API_KEY export line into ~/.zshrc
  -h, --help         Show this help
EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "ERROR: Source file not found: $SOURCE_FILE"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ "$SOURCE_FILE" != /* ]]; then
    SOURCE_FILE="$PROJECT_ROOT/$SOURCE_FILE"
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="$HOME/.secrets-import-backup-$timestamp"

log() {
    echo "$1"
}

run_or_print() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[DRY-RUN] $*"
    else
        eval "$@"
    fi
}

extract_section() {
    local section_title="$1"
    awk -v title="$section_title" '
        $0 == title {
            in_section = 1
            next
        }
        in_section && /^={10,}$/ {
            if (started) {
                exit
            }
            started = 1
            next
        }
        in_section && started {
            print
        }
    ' "$SOURCE_FILE"
}

extract_aws_credentials() {
    extract_section "AWS CREDENTIALS (~/.aws/credentials)" \
        | awk '
            /^\[.*\]$/ {keep=1}
            keep==1 {print}
        ' \
        | sed '/^[[:space:]]*$/d'
}

extract_ssh_private_key() {
    awk '
        /-----BEGIN OPENSSH PRIVATE KEY-----/ {in_key=1}
        in_key {print}
        /-----END OPENSSH PRIVATE KEY-----/ {exit}
    ' "$SOURCE_FILE"
}

extract_openai_key_line() {
    grep -m1 '^OPENAI_API_KEY=' "$SOURCE_FILE" || true
}

log "========================================"
log "Step 7: Importing Secrets"
log "========================================"
log "Source file: $SOURCE_FILE"
log ""

aws_tmp="$(mktemp)"
ssh_tmp="$(mktemp)"
trap 'rm -f "$aws_tmp" "$ssh_tmp"' EXIT

extract_aws_credentials > "$aws_tmp"
extract_ssh_private_key > "$ssh_tmp"
openai_line="$(extract_openai_key_line)"

if ! grep -q '^aws_access_key_id[[:space:]]*=' "$aws_tmp"; then
    echo "ERROR: AWS credentials block not found or invalid in $SOURCE_FILE"
    exit 1
fi

if ! grep -q '^-----BEGIN OPENSSH PRIVATE KEY-----$' "$ssh_tmp"; then
    echo "ERROR: SSH private key block not found in $SOURCE_FILE"
    exit 1
fi

log "Validated secret blocks:"
log "  [OK] AWS credentials section"
log "  [OK] SSH private key section"
if [[ -n "$openai_line" ]]; then
    log "  [OK] OPENAI_API_KEY line found"
else
    log "  [SKIP] OPENAI_API_KEY line not found"
fi
log ""

run_or_print "mkdir -p \"$HOME/.aws\" \"$HOME/.ssh\""
run_or_print "chmod 700 \"$HOME/.ssh\""

if [[ -f "$HOME/.aws/credentials" ]]; then
    run_or_print "mkdir -p \"$backup_dir\""
    run_or_print "cp \"$HOME/.aws/credentials\" \"$backup_dir/aws-credentials\""
    log "  [BACKUP] Existing ~/.aws/credentials backed up"
fi

if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    run_or_print "mkdir -p \"$backup_dir\""
    run_or_print "cp \"$HOME/.ssh/id_ed25519\" \"$backup_dir/id_ed25519\""
    log "  [BACKUP] Existing ~/.ssh/id_ed25519 backed up"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] Install ~/.aws/credentials from extracted block"
else
    cp "$aws_tmp" "$HOME/.aws/credentials"
fi
run_or_print "chmod 600 \"$HOME/.aws/credentials\""
log "  [WRITE] ~/.aws/credentials"

if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] Install ~/.ssh/id_ed25519 from extracted block"
else
    cp "$ssh_tmp" "$HOME/.ssh/id_ed25519"
fi
run_or_print "chmod 600 \"$HOME/.ssh/id_ed25519\""
log "  [WRITE] ~/.ssh/id_ed25519"

if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] Generate ~/.ssh/id_ed25519.pub from private key"
else
    ssh-keygen -y -f "$HOME/.ssh/id_ed25519" > "$HOME/.ssh/id_ed25519.pub"
fi
run_or_print "chmod 644 \"$HOME/.ssh/id_ed25519.pub\""
log "  [WRITE] ~/.ssh/id_ed25519.pub"

if [[ "$WRITE_OPENAI" -eq 1 ]]; then
    if [[ -z "$openai_line" ]]; then
        log "  [SKIP] --write-openai requested, but OPENAI_API_KEY line not found"
    else
        run_or_print "touch \"$HOME/.zshrc\""
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "[DRY-RUN] Update OPENAI_API_KEY line in ~/.zshrc"
        else
            if grep -q '^export OPENAI_API_KEY=' "$HOME/.zshrc"; then
                sed -i.bak 's|^export OPENAI_API_KEY=.*$|export '"$openai_line"'|' "$HOME/.zshrc"
                rm -f "$HOME/.zshrc.bak"
            else
                printf '\nexport %s\n' "$openai_line" >> "$HOME/.zshrc"
            fi
        fi
        log "  [WRITE] ~/.zshrc (OPENAI_API_KEY)"
    fi
else
    log "  [INFO] OPENAI_API_KEY not written (use --write-openai to enable)"
fi

log ""
log "========================================"
log "Step 7 Complete: Secrets imported"
log "========================================"
if [[ -d "$backup_dir" ]]; then
    log "Backups: $backup_dir"
fi
log ""
log "Next suggested checks:"
log "  - aws sts get-caller-identity"
log "  - ssh-keygen -lf ~/.ssh/id_ed25519.pub"
log "  - claude auth login"

