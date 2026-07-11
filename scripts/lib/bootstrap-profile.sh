#!/bin/bash
# Shared Bootstrap Profile helpers.

bootstrap_print_profiles() {
    cat <<'EOF'
Canonical profiles:
  carlo-baseline   Carlo's full personal workstation baseline
  shared-baseline  Portable shared development baseline

Aliases:
  carlo   -> carlo-baseline
  shared  -> shared-baseline
EOF
}

bootstrap_normalize_profile() {
    local profile="${1:-}"

    case "$profile" in
        carlo|carlo-baseline)
            printf '%s\n' "carlo-baseline"
            ;;
        shared|shared-baseline)
            printf '%s\n' "shared-baseline"
            ;;
        *)
            return 1
            ;;
    esac
}

bootstrap_profile_label() {
    case "$1" in
        carlo-baseline)
            printf '%s\n' "Carlo Baseline"
            ;;
        shared-baseline)
            printf '%s\n' "Shared Baseline"
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}
