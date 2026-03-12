# Dev Environment Bootstrap

macOS bootstrap kit for Carlo's development environment.

This project is meant to bring up a fresh machine or Parallels macOS VM with
the core coding workflow already in place:

- `zsh` + Homebrew
- Warp as the primary terminal
- Zed as the primary editor
- Codex and Claude desktop/CLI tooling
- reusable shell config, dotfiles, tracked app config, and setup scripts

## Source Of Truth

For the current direction of the repo, start here:

1. `CONTEXT.md`
2. `AGENTS.md`
3. current repository contents

Older Ubuntu-era inventory and merge artifacts have been removed from the
active tree. Use [HISTORICAL.md](/Users/carlo/dev/dev-env-export/HISTORICAL.md)
for a guide to what was removed and how to recover it from Git history.
Use [SECRETS.md](/Users/carlo/dev/dev-env-export/SECRETS.md) for the current
secret-management policy.
Use [SECRETS-CHECKLIST.md](/Users/carlo/dev/dev-env-export/SECRETS-CHECKLIST.md)
for the recommended 1Password population checklist.
Use [AI-STACK.md](/Users/carlo/dev/dev-env-export/AI-STACK.md) for the current
AI-tooling inventory and tracking policy.

## Current Goal

Use this repo to provision:

- a fresh macOS laptop
- a fresh Parallels macOS VM
- a disposable development VM that should still feel like the main workstation

The target experience is a modern macOS setup centered on Zed, Warp, Codex,
Claude, and 1Password.

## What This Repo Owns

- shell defaults for macOS development
- Homebrew-driven CLI and app installation
- Git, GitHub CLI, AWS, Claude, Codex, Zed, and Warp baseline config
- documented secret-handling policy built around 1Password
- bootstrap scripts for a fresh machine or Parallels VM
- archived Ubuntu VM artifacts for reference only

## Repository Layout

| Path | Purpose |
|------|---------|
| `scripts/` | bootstrap and setup scripts |
| `shell/` | zsh configuration |
| `dotfiles/` | Git, GitHub CLI, AWS, and related user config |
| `claude/` | Claude settings, commands, and helper scripts |
| `zed/` | Zed user configuration tracked for bootstrap |
| `warp/` | Warp launch configurations and related tracked files |
| `codex/` | Codex CLI configuration tracked for bootstrap |
| `onepassword/` | 1Password CLI usage docs and secret template examples |
| `AI-STACK.md` | AI tooling inventory, drift notes, and tracking policy |

## Quick Start

### 1. Clone Or Copy The Repo

```bash
git clone <repo-url> dev-env-export
cd dev-env-export
```

If the repo is being moved manually between machines, unpack it and `cd` into
the project root before running scripts.

### 2. Run The Bootstrap Scripts

```bash
chmod +x scripts/*.sh

./scripts/00-bootstrap.sh
```

If you want to run the primary flow end-to-end, the master bootstrap script
will execute steps 1 through 7 in order and stop cleanly if macOS still needs
you to finish Xcode Command Line Tools installation.

The scripts are intended to be rerunnable. Re-running them should skip
already-installed packages and unchanged config where practical. If you want
to force a Homebrew metadata refresh before installs, run:

```bash
DEV_ENV_REFRESH_BREW=1 ./scripts/01-install-brew.sh
```

To run the steps manually instead:

```bash
./scripts/01-install-brew.sh
./scripts/02-install-cli-tools.sh
./scripts/03-install-npm-globals.sh
./scripts/04-install-pip-packages.sh
./scripts/05-setup-dotfiles.sh
./scripts/06-setup-claude.sh
./scripts/07-setup-1password.sh
```

### 3. Complete Manual Setup

```bash
exec zsh

gh auth login
aws configure
codex login
claude auth login
```

Desktop apps such as 1Password, Warp, Zed, Docker, Claude, and Codex may still
require normal first-launch/login steps.

Before those auth steps, sign in to 1Password and use it as the source of truth
for credentials, API keys, and project `.env` values.

Recommended follow-up:

- In 1Password, sign in and confirm `op account list` works
- In Zed, run `Cmd+Shift+P` and execute `cli: install`
- In Warp, open `Dev Env Bootstrap` from Launch Configurations
- In Claude, review plugins and enable only the ones you still use
- Run `./scripts/09-inventory-ai-tooling.sh` to snapshot the local AI layer

## Stack

### Core CLI

- Homebrew
- git, git-lfs, jq, curl, wget
- node, npm, nvm
- python3
- codex
- claude
- gh
- awscli
- docker-related local tooling where needed

### Primary GUI Tools

- 1Password
- Warp
- Zed
- Claude desktop
- Codex desktop

### Quality-Of-Life Apps

- Raycast
- BetterDisplay
- Hidden Bar
- Hammerspoon
- GitHub Desktop
- Obsidian

### Secondary Or Legacy GUI Tools

- GitKraken
- Sublime Text
- Chromium / Firefox

These can remain installed if useful, but they are not the primary workflow.

## History

Legacy Ubuntu VM inventories, merge reports, old prompts, and migration helper
files were removed from the active tree to keep this repo focused. Start with
`HISTORICAL.md` if you need to recover any of that material from Git history.

## Security Notes

- Keep credentials and machine-specific secrets out of versioned files.
- 1Password is the current source of truth for API keys, `.env` values, AWS,
  GitHub, and similar credentials.
- Use dedicated authentication flows for AWS, GitHub, Codex, Claude, and
  similar tools after retrieving secrets from 1Password as needed.
- Use `op run` and `op inject` where possible instead of creating ad hoc secret
  export files.
- Use `zed/`, `warp/`, and `codex/` only for portable config you intentionally
  want to recreate on new machines.
- Use `AI-STACK.md` and `scripts/09-inventory-ai-tooling.sh` to audit plugin,
  skill, extension, and agent drift before copying anything into Git.
- See `SECRETS.md` for the current secrets workflow.
- See `onepassword/README.md` for practical `op` usage in this repo.
- Review scripts before running them on a new machine, especially while the
  repo is still being modernized.
