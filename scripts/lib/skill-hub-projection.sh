#!/bin/bash
# Shared validation for the Skill Hub harness projection.

SKILL_HUB_PROJECTION_REASON=""

skill_hub_projection_valid() {
    local home_dir="${1:-$HOME}"
    local agents_root="$home_dir/.agents/skills"
    local claude_root="$home_dir/.claude/skills"
    local codex_root="$home_dir/.codex/skills"
    local agents_resolved=""
    local claude_resolved=""
    local codex_resolved=""
    local selected_skill=""
    local selected_relative_path=""

    SKILL_HUB_PROJECTION_REASON=""

    if [[ ! -d "$agents_root" || -L "$agents_root" ]]; then
        SKILL_HUB_PROJECTION_REASON="Agents skill directory is missing or is not a real directory: $agents_root"
        return 1
    fi

    if [[ ! -L "$claude_root" || ! -d "$claude_root" ]]; then
        SKILL_HUB_PROJECTION_REASON="Claude skill projection is missing or broken: $claude_root"
        return 1
    fi

    if [[ ! -L "$codex_root" || ! -d "$codex_root" ]]; then
        SKILL_HUB_PROJECTION_REASON="Codex skill projection is missing or broken: $codex_root"
        return 1
    fi

    agents_resolved="$(cd -P "$agents_root" && pwd)"
    claude_resolved="$(cd -P "$claude_root" && pwd)"
    codex_resolved="$(cd -P "$codex_root" && pwd)"
    if [[ "$claude_resolved" != "$agents_resolved" || "$codex_resolved" != "$agents_resolved" ]]; then
        SKILL_HUB_PROJECTION_REASON="Claude and Codex skill projections must resolve to $agents_root"
        return 1
    fi

    selected_skill="$(find -L "$agents_root" -type f -name SKILL.md -print -quit 2>/dev/null)"
    if [[ -z "$selected_skill" || ! -r "$selected_skill" ]]; then
        SKILL_HUB_PROJECTION_REASON="No readable selected SKILL.md exists under $agents_root"
        return 1
    fi

    selected_relative_path="${selected_skill#"$agents_root"/}"
    if [[ ! -r "$claude_root/$selected_relative_path" || ! -r "$codex_root/$selected_relative_path" ]]; then
        SKILL_HUB_PROJECTION_REASON="Selected skill is not readable through every harness root: $selected_relative_path"
        return 1
    fi
}
