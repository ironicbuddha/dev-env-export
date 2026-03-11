# AGENTS.md

## Purpose

This repository is a machine-bootstrap project for Carlo's coding environment.
Its job is to help spin up a new macOS machine or Parallels macOS VM with the
same core development workflow, tools, and preferences already in place.

This repo is no longer Ubuntu-first. Older Ubuntu VM exports and merge docs are
historical reference material only. The current direction is:

- macOS guests in Parallels
- Apple Silicon / Homebrew-first setup
- Zed and Warp as primary editor + terminal
- Codex and Claude desktop apps plus CLI workflows
- reusable dotfiles, shell config, editor settings, and install scripts

## Source Of Truth

When the repo and older documentation disagree, use this priority order:

1. `CONTEXT.md`
2. current repository contents
3. `AGENTS.md`
4. historical inventory and merge documents

The inventory and merge docs explain how the repo got here. They do not define
the target state anymore.

## What Agents Should Optimize For

- fast setup of a fresh macOS dev machine or VM
- minimal manual steps after clone/unpack
- idempotent, safe reruns where practical
- clear separation between portable config and machine-specific secrets
- current-tool relevance over preserving legacy Ubuntu assumptions

## Current Tooling Priorities

- Shell: `zsh`
- Package manager: Homebrew
- Terminal: Warp
- Editor: Zed
- Secrets: 1Password
- AI tools: Codex CLI/app, Claude CLI/app
- Supporting CLIs: GitHub CLI, AWS CLI, Node/npm, Python, Docker as needed

Legacy Ubuntu-specific material can remain temporarily as archive reference, but
new work should move the repo toward the current stack instead of deepening the
old one.

## Repo Areas

- `scripts/`: machine bootstrap and setup scripts
- `shell/`: zsh config and login-shell setup
- `dotfiles/`: git, GitHub CLI, AWS, and related user config
- `claude/`: Claude settings, commands, and helper scripts
- `zed/`: tracked Zed user settings and keybindings
- `warp/`: tracked Warp launch configurations
- `codex/`: tracked Codex CLI defaults
- `onepassword/`: 1Password CLI usage docs and secret template examples
- `HISTORICAL.md`: guide to removed legacy material recoverable from Git history

## Working Rules

- Prefer editing scripts and docs so they reflect the current macOS workflow.
- Avoid adding Linux-only assumptions unless they are explicitly documented as
  legacy reference.
- Keep secrets out of the repo. Use 1Password as the source of truth and
  document secret flows separately.
- If a tool has drifted out of active use, mark it as legacy instead of quietly
  treating it as current.
- If you introduce a new primary tool, update both `AGENTS.md` and
  `CONTEXT.md`.

## Expected Maintenance Tasks

Agents working here should typically do one or more of the following:

- modernize install scripts for current macOS behavior
- add setup support for Zed and Warp
- keep Codex and Claude setup current
- remove or downgrade stale references to Ubuntu where appropriate
- improve bootstrap safety, backups, and rerun behavior
- keep README-level setup instructions aligned with the actual repo contents

## Definition Of A Good Change

A good change makes a fresh-machine setup more accurate, more repeatable, or
more aligned with Carlo's real workflow today.
