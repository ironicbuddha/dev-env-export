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
- Codex and Claude desktop apps plus Gemini CLI, OpenSpec CLI, and GSD v2 workflows
- reusable dotfiles, tracked app config, and bootstrap scripts

## Source Of Truth

When the repo and older documentation disagree, use this priority order:

1. `CONTEXT.md`
2. current repository contents
3. `AGENTS.md`
4. `PERSONALITY.md`
5. historical inventory and merge documents

The inventory and merge docs explain how the repo got here. They do not define
the target state anymore.

## Agent skills

### Issue tracker

GitHub Issues is the planning tracker; external PRs are not a request surface.
Implementation may use a work branch merged directly into `main` without a PR.
See `docs/agents/issue-tracker.md`.

### Triage labels

Use the standard `needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, and `wontfix` labels. See
`docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository using root `CONTEXT.md` and `docs/adr/`.
See `docs/agents/domain.md`.

## What Agents Should Optimize For

- fast setup of a fresh macOS dev machine or VM
- minimal manual steps after clone/unpack
- idempotent, safe reruns where practical
- clear separation between portable config and machine-specific secrets
- current-tool relevance over preserving legacy Ubuntu assumptions

## Current Tooling Priorities

- Shell: `zsh`
- Package manager: Homebrew
- Node runtime manager: `nvm` via Homebrew
- JS package-manager stance: keep `npm`, prefer `pnpm` for new TypeScript-first
  repos
- Terminal: Warp
- Editor: Zed
- Secrets: 1Password
- AI tools: Codex CLI/app, Claude CLI/app, Gemini CLI, OpenSpec CLI, GSD v2 CLI
- Supporting CLIs: GitHub CLI, AWS CLI, Google Workspace CLI, Node/npm,
  Python, Docker, and GSD v2 as needed
- Supporting document/media CLIs: Pandoc, Poppler, Tesseract, and ImageMagick
  for Office, PDF, image, and OCR-heavy workflows
- Primary dev stack: TypeScript-first across frontend and backend with
  Next.js, Vite, Tailwind CSS, shadcn/ui, Node.js on AWS, and Vercel, with
  Python retained for scripting and library-heavy cases
- Default interaction mode: buddy mode

Legacy Ubuntu-specific material belongs in history, not in the active setup.

## Repo Areas

- `scripts/`: machine bootstrap and setup scripts
- `shell/`: zsh config and login-shell setup
- `dotfiles/`: git, GitHub CLI, AWS, and related user config
- `claude/`: Claude settings, commands, and helper scripts
- `gemini/`: tracked Gemini persona, settings defaults, and setup docs
- `zed/`: tracked Zed user settings and keybindings
- `warp/`: tracked Warp launch configurations
- `codex/`: tracked Codex CLI defaults
- `mcp/`: curated default MCP server manifest and policy
- `onepassword/`: 1Password CLI usage docs and secret template examples
- `templates/`: starter config bundles and reusable repo scaffolds
- `DEV-STACK.md`: current language, framework, and hosting targets
- `PACKAGE-MANAGERS.md`: machine and project package-manager policy
- `CODE-QUALITY.md`: default linting and formatting baseline for new repos
- `PROJECT-STANDARDS.md`: default testing, deployment, security, and delivery
  baseline for new repos
- `AI-STACK.md`: current AI-tooling inventory and Git-tracking policy
- `PERSONALITY.md`: default interaction style and mode switch rules
- `HISTORICAL.md`: guide to removed legacy material recoverable from Git history

## Working Rules

- Prefer editing scripts and docs so they reflect the current macOS workflow.
- Avoid adding Linux-only assumptions unless they are explicitly documented as
  legacy reference.
- Keep secrets out of the repo. Use 1Password as the source of truth and
  document secret flows separately.
- Default to the repo's buddy-mode interaction style unless the user says
  `Heaven's No`, which switches to serious mode.
- If a tool has drifted out of active use, mark it as legacy instead of quietly
  treating it as current.
- Prefer repo-local lint and format defaults in new repos, especially for
  Markdown, CSS, TSX, and Python.
- Prefer new repos to start from the project standards and constitution
  template, not ad hoc conventions.
- If you introduce a new primary tool, update both `AGENTS.md` and
  `CONTEXT.md`.

## Expected Maintenance Tasks

Agents working here should typically do one or more of the following:

- modernize install scripts for current macOS behavior
- add setup support for Zed and Warp
- keep 1Password integration practical and explicit
- keep Codex and Claude setup current
- keep the AI tooling layer honest about current plugins, skills, agents, and
  extensions
- keep new-project starter standards aligned with the real stack and workflow
- remove or downgrade stale references to Ubuntu where appropriate
- improve bootstrap safety, backups, and rerun behavior
- keep README-level setup instructions aligned with the actual repo contents

## Definition Of A Good Change

A good change makes a fresh-machine setup more accurate, more repeatable, or
more aligned with Carlo's real workflow today.
