# CONTEXT.md

<!-- BEGIN HANDOFF DISCOVERY -->
## Handoff Discovery

Before starting work in this repository, check `/Users/carlo/dev/handoff-docs` for handoff documents whose metadata `source_repo` matches this repository path. Load the most recently modified matching handoff document into context before making changes.

Most recent handoff: `/Users/carlo/dev/handoff-docs/dev-env-export-handoff-2026-07-09-204557.md`
Last updated: 2026-07-09 20:45
<!-- END HANDOFF DISCOVERY -->

## Project Snapshot

This repository captures the baseline configuration for Carlo's development
environment so a new machine or dev VM can be brought online quickly.

The project started as an export/merge of Ubuntu VM environments, but the live
workflow has changed. The current target is a macOS development environment,
typically running inside Parallels, with modern coding tools configured from the
start.

## Language

**Carlo Baseline**:
The full personal workstation setup for Carlo's own macOS laptop, Parallels VM,
or disposable dev VM.
_Avoid_: default setup, full setup

**Shared Baseline**:
The portable subset of the Carlo Baseline that can be applied to someone else's
macOS development environment without assuming Carlo-specific identity,
secrets, preferences, or private workflow state.
_Avoid_: someone else's setup, external setup, public setup

**Bootstrap Profile**:
A named bootstrap scope that selects which baseline should be applied to a
machine. The canonical profiles are `carlo-baseline` and `shared-baseline`,
with `carlo` and `shared` accepted as aliases for ergonomics.
_Avoid_: mode, variant, script fork

**Bootstrap Entry Path**:
The expected starting route before this repo's scripts run. For the Shared
Baseline, the zero-tool entry path is a GitHub ZIP archive extracted on macOS,
with Terminal opened in the extracted folder. No Git CLI, Xcode Command Line
Tools, Homebrew, editor, or executable file modes are assumed. GitHub Desktop
and a normal Git clone remain supported acquisition paths.
_Avoid_: clone method, install prerequisite

**Shared AI Layer**:
The AI-tooling slice of the Shared Baseline. It is centered on Codex CLI access
for collaboration from the shell. It does not assume Codex Desktop is installed
as part of the reusable baseline, and does not install Carlo-specific Codex
personas, skills, MCP defaults, private plugin manifests, Claude CLI, Gemini
CLI, or other personal AI workflow state.
_Avoid_: minimal AI layer, shared Carlo AI setup

**Shared Shell Setup**:
The shell slice of the Shared Baseline. It makes the installed tools usable from
`zsh`, including required path and runtime-manager wiring, without installing
Carlo-specific prompts, themes, aliases, functions, history preferences, or
other personal shell behavior.
_Avoid_: shared dotfiles, clean shell setup

**Shared Secret Handling**:
The secret-management guidance for the Shared Baseline. It may document
1Password as the preferred place for credentials and post-bootstrap sign-ins,
but does not install 1Password, configure accounts, create vaults, copy items,
enable SSH agents, or assume Carlo's secret model.
_Avoid_: shared 1Password setup, secret bootstrap

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
  - OpenSpec CLI
  - GSD v2 CLI (`gsd` via `gsd-pi`)
- Shell baseline: `zsh`
- Package management baseline: Homebrew
- Node runtime baseline: `nvm` installed by Homebrew, with Node 26.5 as the default runtime
- Google Workspace baseline CLI: `googleworkspace-cli` (`gws`) when Workspace
  automation is part of the machine workflow
- JavaScript package-manager stance: keep `npm`, prefer `pnpm` for new
  TypeScript-first repos
- Primary dev language: TypeScript for most application and service work
- Python stance: mainly for scripting, automation, document workflows, and
  library-driven cases where it is the pragmatic fit
- Primary frontend stack: Next.js 16.2.10, Vite, Tailwind CSS, shadcn/ui
- Primary backend stack: Node.js 26.5 and TypeScript for APIs, services, Lambdas,
  and microservice-style workloads
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
- GSD v2 CLI installation and first-run guidance
- AI tooling inventory and drift control for plugins, skills, agents, and MCP
  adjacent tooling
- editor and terminal setup for Zed and Warp
- documented 1Password-backed secret handling and post-install auth steps
- new-project starter standards covering testing, deployment, security, and
  operational expectations

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
- New repos should also start with an explicit standards document covering
  testing, deployment, security, secrets, and operational expectations.
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
- Codex, Claude, Gemini, and OpenSpec are primary tools, not optional extras
- GSD v2 is the current standalone orchestration layer when GSD workflows are needed
- older Ubuntu merge docs are reference material only
- the target dev stack is TypeScript-first with Next.js, Vite, Tailwind,
  shadcn/ui, Node.js on AWS, and Vercel, with Python kept available for
  scripting and library-driven work
- Homebrew remains the primary machine package manager even if project-level
  package managers vary

## Success Condition

This repo is successful when Carlo can use it to provision a new macOS machine
or VM and quickly end up with a familiar, AI-assisted coding environment without
having to rediscover setup decisions by hand.
