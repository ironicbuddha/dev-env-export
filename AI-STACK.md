# AI Stack

This document captures the current AI-tooling layer for this repo and the
policy for what should be tracked here versus what should stay out of Git.

## Why This Exists

The machine bootstrap is no longer just shell, Git, and apps. The real daily
workflow also depends on:

- Codex CLI and desktop app
- Claude Code CLI and desktop app
- Zed agent settings and external agents
- optional GSD runtimes such as `opencode`
- plugins, skills, hooks, commands, and MCP-aware integrations

That layer drifts faster than dotfiles do. This file is meant to stop the repo
from lying about what is actually in use.

## Current Local Inventory

Observed on this machine on March 12, 2026.

### Codex

- CLI version: `codex-cli 0.114.0`
- Live config path: `~/.codex/config.toml`
- Current tracked repo target: `codex/config.toml`
- Live config shape:
  - model `gpt-5.4`
  - reasoning `high`
  - approval `never`
  - sandbox `danger-full-access`
  - `multi_agent = true`
  - `default_mode_request_user_input = true`
- Current local footprint:
  - 49 installed skills
  - 24 custom agent definition files
  - 14 trusted project entries

### Claude Code

- CLI version: `claude 2.1.73`
- Live config path: `~/.claude/settings.json`
- Current tracked repo targets:
  - `claude/settings/settings.json`
  - `claude/settings/settings.local.json`
  - `claude/statusline-command.sh`
  - `claude/commands/`
  - `claude/PLUGIN-MANIFEST.md`
- Current local footprint:
  - 76 command files
  - 3 hook files
  - 15 enabled plugins
- Enabled plugins currently in use:
  - `code-review@claude-plugins-official`
  - `code-simplifier@claude-plugins-official`
  - `context7@claude-plugins-official`
  - `document-skills@anthropic-agent-skills`
  - `feature-dev@claude-plugins-official`
  - `frontend-design@claude-plugins-official`
  - `github@claude-plugins-official`
  - `playwright@claude-plugins-official`
  - `pyright-lsp@claude-plugins-official`
  - `ralph-loop@claude-plugins-official`
  - `security-guidance@claude-plugins-official`
  - `superpowers@claude-plugins-official`
  - `taches-cc-resources@taches-cc-resources`
  - `typescript-lsp@claude-plugins-official`
  - `vercel@claude-plugins-official`
- Curated repo policy:
  - tracked settings still enable no plugins by default
  - plugin choices should follow `claude/PLUGIN-MANIFEST.md`

### Zed

- App version: `Zed 0.227.1`
- Live config paths:
  - `~/.config/zed/settings.json`
  - `~/Library/Application Support/Zed/extensions/index.json`
  - `~/Library/Application Support/Zed/external_agents/`
- Current tracked repo targets:
  - `zed/settings.json`
  - `zed/keymap.json`
- Current local footprint:
  - 4 installed extensions
  - 3 installed external agent packages
- Local extensions:
  - `git-firefly`
  - `html`
  - `lua`
  - `macos-classic`
- Local external agents:
  - `claude-agent-acp/0.18.0`
  - `claude-code-acp/0.13.1`
  - `codex/v0.9.5`
- Notable live settings that are not yet fully mirrored in the repo:
  - Codex agent server default mode set to `full-access`
  - default Zed agent model set to OpenAI `gpt-5.2-codex`
  - agent edit, save, and move tools auto-allowed
  - `single_file_review = false`
  - `session.trust_all_worktrees = true`
  - macOS Classic theme in active use

### AI-Adjacent Tooling

- `opencode` is present at `~/.config/opencode`
- The current `opencode` footprint includes:
  - GSD command set
  - GSD agent definitions
  - hooks and statusline helpers
  - permission config allowing access to its own GSD bundle
- Treat `opencode` as an optional runtime for
  `gsd-build/get-shit-done`, not as a required base-machine tool.
- This repo does not currently track `opencode`, but it is a legitimate
  candidate for optional GSD workflow support.

### GSD Workflow Position

- `get-shit-done` is compatible with multiple runtimes, including Claude,
  Codex, and OpenCode.
- For this repo, Claude and Codex remain the primary AI runtimes.
- OpenCode should be treated as optional experimentation or future GSD support,
  not as a required baseline dependency.

### Gaps On This Machine

The inventory found some tools missing in `PATH` on this machine. Those gaps
should be interpreted deliberately:

- `op`
- `warp`
- `uv`
- `bun`
- `playwright`
- `vercel`
- `docker`

Repo stance:

- `op`, `warp`, and `docker` are already first-class bootstrap targets
- `uv` and `bun` should be first-class bootstrap targets because the dev stack
  is TypeScript and Python heavy
- `vercel` should be first-class bootstrap support because Vercel is part of
  the current hosting workflow
- `playwright` should be treated as a project-local tool by default, typically
  invoked with `npx playwright`, not as a mandatory global install

So the right interpretation is not "these gaps are fine." It is "the bootstrap
and docs need to account for each one on purpose."

## What To Track In Git

Track only portable, intentionally recreated defaults:

- sanitized Codex defaults in `codex/`
- curated Claude settings, commands, and helper scripts in `claude/`
- curated Zed settings and keymaps in `zed/`
- Warp launch configurations in `warp/`
- 1Password-backed secret patterns and templates
- docs that explain the intended AI workflow and how to rebuild it

## What To Document But Not Sync Blindly

Document these so they are visible, but do not mirror the entire live tree into
the repo:

- Claude plugin inventory
- Codex skill inventory
- Zed extension inventory
- external agent package names and versions
- optional `opencode` and GSD runtime usage
- MCP servers, once there is a deliberate list worth keeping

These are good candidates for inventory scripts and Markdown docs. They are bad
candidates for naive directory copies.

## What Must Stay Out Of Git

Do not track runtime state, auth, or machine trust:

- `~/.codex/auth.json`
- `~/.codex/history*`
- `~/.codex/sessions/`
- `~/.codex/log/`
- `~/.codex/tmp/`
- `~/.codex/*.db`
- trusted project path lists copied verbatim from live config
- `~/.claude/history.jsonl`
- `~/.claude/projects/`
- `~/.claude/file-history/`
- `~/.claude/debug/`
- `~/.claude/backups/`
- plugin caches and marketplace cache data
- Zed databases, crash dumps, and thread state

If a file contains auth, local paths, runtime state, or a machine trust
decision, it probably does not belong in this repo.

## MCP Status

This machine is clearly using MCP-aware tooling, but the configuration is not
yet represented in one clean tracked place.

Current signals:

- Claude has `context7` and other plugin integrations enabled
- Zed has external agent packages installed for Codex and Claude
- `opencode` includes Context7-oriented guidance in its GSD workflows

What is missing is a deliberate, versioned MCP manifest for this repo.

Until that exists, the right move is:

1. inventory the live setup
2. decide which servers are actually worth carrying to every new machine
3. add a curated `mcp/` or `ai/` area only after that list is intentional

## Recommended Next Additions

- decide whether any Codex skills should be vendored here or only documented
- add a small `mcp/README.md` once the always-install server list is clear
- decide whether GSD support should stay Claude/Codex-only or also document an
  optional OpenCode path
- run the inventory script after each major toolchain change to catch drift

## Inventory Script

Use the repo helper to snapshot the current AI-tooling layer:

```bash
./scripts/09-inventory-ai-tooling.sh
./scripts/09-inventory-ai-tooling.sh --out-file AI-INVENTORY.local.md
```

The script reports versions, counts, and non-secret inventories for Codex,
Claude, Zed, and adjacent tools. It is meant for audits, not for syncing
runtime state into Git.
