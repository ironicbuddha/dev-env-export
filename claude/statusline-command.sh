#!/bin/bash
# Claude Code Custom Statusline Script
# Exported from Ubuntu VM on 2026-01-17
# Dependencies: jq (install via: brew install jq)

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON
model=$(echo "$input" | jq -r '.model.display_name' | sed -E 's/.*(Opus|Sonnet|Haiku) ([0-9.]+).*/\1 \2/')
used=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
proj=$(echo "$input" | jq -r '.workspace.project_dir')

# Calculate totals
total_tok=$((total_in + total_out))
tok_used="$((total_tok / 1000))k"
tok_total="$((ctx_size / 1000))k"

# Create progress bar
used_int=$(printf "%.0f" "$used")
filled=$((used_int * 10 / 100))
[ $filled -gt 10 ] && filled=10
progress=$(printf "%-10s" "$(printf "%${filled}s" | tr " " "=")" )

# Get git info
branch=$(cd "$proj" 2>/dev/null && git symbolic-ref --short HEAD 2>/dev/null || echo "no-git")
repo=$(basename "$proj" 2>/dev/null || echo "no-repo")

# Output
printf "%s [%s] %d%% | %s/%s | %s | %s" "$model" "$progress" "$used_int" "$tok_used" "$tok_total" "$branch" "$repo"
