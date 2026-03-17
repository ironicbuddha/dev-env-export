# CONTEXT.md

## Project Snapshot

This repository captures the baseline configuration for Carlo's development
environment so a new machine or dev VM can be brought online quickly.

The project started as an export/merge of Ubuntu VM environments, but the live
workflow has changed. The current target is a macOS development environment,
typically running inside Parallels, with modern coding tools configured from the
start.

## Current Reality

- Primary virtualization path: Parallels
- Primary guest OS for this repo: macOS
- Preferred terminal: Warp
- Preferred editor: Zed
- Preferred secret store: 1Password
- Preferred default interaction style: jocular, profane, nerdy buddy mode
- AI coding tools in active use:
  - Codex desktop app / CLI
  - Claude desktop app / CLI
  - Gemini CLI
- Shell baseline: `zsh`
- Package management baseline: Homebrew
- Node runtime baseline: `nvm` installed by Homebrew
- Google Workspace baseline CLI: `googleworkspace-cli` (`gws`) when Workspace
  automation is part of the machine workflow
- JavaScript package-manager stance: keep `npm`, prefer `pnpm` for new
  TypeScript-heavy repos
- Primary dev languages: TypeScript and Python
- Primary frontend stack: Next.js, Vite, Tailwind CSS, shadcn/ui
- Primary backend stack: Django and Flask
- Primary cloud and hosting targets: AWS and Vercel
- Supporting package tools expected to matter: `uv`, `bun`, and `vercel`
- Supporting document/media tools expected to matter: `pandoc`, `poppler`,
  `tesseract`, and `imagemagick`

## Repository Goal

Turn this repo into a reliable bootstrap package for:

- a fresh macOS laptop
- a fresh Parallels macOS VM
- a disposable dev VM that should still feel like Carlo's real workstation

That means the repo should eventually cover:

- core CLI installation
- shell and dotfile setup
- Codex and Claude configuration
- Gemini CLI configuration
- AI tooling inventory and drift control for plugins, skills, agents, and MCP
  adjacent tooling
- editor and terminal setup for Zed and Warp
- documented 1Password-backed secret handling and post-install auth steps

## Transition State

The repo has already been pulled away from the old Ubuntu export model. Some
historical context remains in Git history, but the active tree is now aimed at
a clean macOS/Parallels bootstrap workflow.

## What Needs To Be True Going Forward

- The repo should describe the machine Carlo uses now, not the machine Carlo
  used several months ago.
- Setup instructions should match files that actually exist in the repo.
- Scripts should be safe to rerun and explicit about destructive behavior.
- Machine-specific secrets should stay outside versioned config.
- Document workflows should prefer native parsing first and use OCR only as a
  targeted fallback for bad or missing extraction.
- New repos should start with a small, explicit lint and format baseline for
  Markdown, CSS, TSX, and Python.
- 1Password should be treated as the canonical home for `.env` values, API
  keys, AWS credentials, GitHub credentials, and similar secrets.
- The default interaction style should feel lively and informal unless the user
  explicitly switches to serious mode with `Heaven's No`.
- Legacy tooling should be clearly marked as legacy.

## Current Priority Areas

1. Establish top-level project guidance and current context.
2. Modernize bootstrap scripts for current macOS usage.
3. Add first-class support for Warp and Zed.
4. Keep Codex and Claude setup central to the environment.
5. Keep the repo clean, current, and easy to apply on a fresh machine.

## Near-Term Interpretation For Agents

If an agent is deciding how to frame a change, assume:

- macOS is the target unless explicitly stated otherwise
- Parallels VMs matter as much as physical machines
- Zed/Warp are the preferred local editor and terminal defaults
- Codex, Claude, and Gemini are primary tools, not optional extras
- older Ubuntu merge docs are reference material only
- the target dev stack is TypeScript and Python with Next.js, Vite, Tailwind,
  shadcn/ui, Django, Flask, AWS, and Vercel
- Homebrew remains the primary machine package manager even if project-level
  package managers vary

## Success Condition

This repo is successful when Carlo can use it to provision a new macOS machine
or VM and quickly end up with a familiar, AI-assisted coding environment without
having to rediscover setup decisions by hand.
