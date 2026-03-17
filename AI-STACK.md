# AI Stack

This document captures the current AI-tooling layer for this repo and the
policy for what should be tracked here versus what should stay out of Git.

## Why This Exists

The machine bootstrap is no longer just shell, Git, and apps. The real daily
workflow also depends on:

- Codex CLI and desktop app
- Claude Code CLI and desktop app
- Gemini CLI
- Zed agent settings and external agents
- optional GSD runtimes such as `opencode`
- plugins, skills, hooks, commands, and MCP-aware integrations

That layer drifts faster than dotfiles do. This file is meant to stop the repo
from lying about what is actually in use.

## Document And OCR Baseline

The local AI workflow should not assume plain text inputs only. The intended
baseline now includes support for:

- modern Microsoft Office files: `.docx`, `.xlsx`, `.pptx`
- PDFs
- common image formats used for screenshots, scans, or exported pages

Preferred extraction order:

1. native parser for the file type
2. structural PDF extraction
3. OCR only when the first two paths fail or produce clearly degraded output

Local baseline tools for this path:

- Homebrew CLIs:
  - `pandoc`
  - `poppler` for `pdftotext` and `pdftoppm`
  - `tesseract`
  - `imagemagick`
- Python packages:
  - `python-docx`
  - `openpyxl`
  - `python-pptx`
  - `pypdf`
  - `pdfplumber`
  - `pillow`
  - `pytesseract`
  - `reportlab`

Practical policy:

- do not OCR every PDF by default when text extraction already works
- treat OCR as a recovery path for scans, image-only pages, or mangled output
- keep the workflow capable of both reading and writing supported formats

## Google Workspace CLI

For Google Workspace automation on this machine, prefer `googleworkspace-cli`
with the `gws` command rather than ad hoc scripts or stale one-off admin tools.

Baseline usage:

- install via Homebrew as `googleworkspace-cli`
- run `gws auth setup` during machine follow-up if Workspace automation matters
- keep local auth state out of Git like every other runtime credential cache

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
  - 54 installed skills under `~/.codex/skills`
  - 2 additional agent skill packages under `~/.agents/skills`
  - 24 custom agent definition files
  - 14 trusted project entries
- Repo-owned inventory and vendoring/install policy now lives in
  `codex/SKILLS.md`

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

### Gemini CLI

- CLI version: `gemini 0.33.2`
- Live config paths:
  - `~/.gemini/settings.json`
  - `~/.gemini/GEMINI.md`
  - `~/.agents/skills/`
- Current tracked repo targets:
  - `gemini/README.md`
  - `gemini/GEMINI.md`
  - `gemini/settings.json`
  - `scripts/08-setup-gemini.sh`
- Current local footprint:
  - 12 local Gemini agent files
  - 3 Gemini hook files
  - shared discovery of the `~/.agents/skills` skill root
- Current live config shape:
  - `experimental.enableAgents = true`
  - witty loading phrases enabled
  - auth mode `oauth-personal`
  - statusline and hooks already present in the live local setup
- Repo policy:
  - track only portable Gemini persona and settings defaults
  - preserve local hook, auth, and project state instead of mirroring it into
    Git
  - use `scripts/08-setup-gemini.sh` to merge repo defaults and maintain shared
    skill discovery

### Zed

- App version: `Zed 0.227.1`
- Live config paths:
  - `~/Library/Application Support/Zed/settings.json`
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
- `21st.dev Agents` should be treated similarly: an optional app-level agent
  infrastructure tool in the broader AI chain, not a required machine bootstrap
  dependency.
- If it remains in active use, track the 1Password item name and env var
  convention here, but do not try to mirror runtime credentials or dashboard
  state into Git.

### GSD Workflow Position

- `get-shit-done` is compatible with multiple runtimes, including Claude,
  Codex, and OpenCode.
- For this repo, Claude and Codex remain the primary AI runtimes.
- OpenCode should be treated as optional experimentation or future GSD support,
  not as a required baseline dependency.

## AI Provider Credentials In Scope

These provider credentials are currently expected to live in 1Password and be
represented in the repo's secret scaffolding and checklist:

- `openai - api credential`
- `anthropic - api credential`
- `firecrawl - api credential`
- `21st - agents api credential`
- `google - gemini api key`
- `google stitch - api credential`

Track the item names and guidance in Git. Keep the actual values out of Git.

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

Use `./scripts/10-check-paths.sh` after bootstrap to verify whether these tools
are actually visible in the intended shell environment.

## What To Track In Git

Track only portable, intentionally recreated defaults:

- sanitized Codex defaults in `codex/`
- curated Claude settings, commands, and helper scripts in `claude/`
- curated Gemini persona, settings defaults, and setup docs in `gemini/`
- curated Zed settings and keymaps in `zed/`
- Warp launch configurations in `warp/`
- curated default MCP server manifest and policy in `mcp/`
- 1Password-backed secret patterns and templates
- docs that explain the intended AI workflow and how to rebuild it

## What To Document But Not Sync Blindly

Document these so they are visible, but do not mirror the entire live tree into
the repo:

- Claude plugin inventory
- Codex skill inventory
- Gemini hook and agent inventory
- Zed extension inventory
- external agent package names and versions
- optional `opencode` and GSD runtime usage
- live MCP inventories beyond the curated defaults tracked in `mcp/`

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
- `~/.gemini/google_accounts.json`
- `~/.gemini/oauth_creds.json`
- `~/.gemini/state.json`
- `~/.gemini/projects.json`
- `~/.gemini/trustedFolders.json`
- `~/.gemini/installation_id`
- plugin caches and marketplace cache data
- Zed databases, crash dumps, and thread state

If a file contains auth, local paths, runtime state, or a machine trust
decision, it probably does not belong in this repo.

## MCP Status

This machine is clearly using MCP-aware tooling, and the repo now carries a
curated default MCP manifest in `mcp/servers.yaml`.

Current signals:

- Claude has `context7` and other plugin integrations enabled
- Zed has external agent packages installed for Codex and Claude
- `opencode` includes Context7-oriented guidance in its GSD workflows
- Docker Desktop is part of the machine baseline and is now the default source
  and management path for MCP servers
- the default server list now explicitly includes Sequential Thinking as part of
  the baseline reasoning/tooling layer

The right split now is:

1. inventory the live setup
2. keep the always-install baseline in `mcp/servers.yaml`
3. document live extras only when they prove they belong in the curated set

## Recommended Next Additions

- recover the source for `load-manifest` and `stage-commit-push` if those two
  should be vendored into this repo
- review whether Docker, Figma, or Firecrawl belong in the default MCP set or
  should stay optional
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
