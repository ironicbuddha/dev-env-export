# Dev Environment Bootstrap

macOS bootstrap kit for Carlo's development environment.

This project is meant to bring up a fresh machine or Parallels macOS VM with
the core coding workflow already in place:

- `zsh` + Homebrew
- Warp as the primary terminal
- Zed as the primary editor
- Codex, Claude, Gemini, OpenSpec, and GSD v2 CLI tooling
- reusable shell config, dotfiles, tracked app config, and setup scripts

## Source Of Truth

For the current direction of the repo, start here:

1. `CONTEXT.md`
2. current repository contents
3. `AGENTS.md`

Older Ubuntu-era inventory and merge artifacts have been removed from the
active tree. Use [HISTORICAL.md](/Users/carlo/dev/dev-env-export/HISTORICAL.md)
for a guide to what was removed and how to recover it from Git history.
Use [SECRETS.md](/Users/carlo/dev/dev-env-export/SECRETS.md) for the current
secret-management policy.
Use [SECRETS-CHECKLIST.md](/Users/carlo/dev/dev-env-export/SECRETS-CHECKLIST.md)
for the recommended 1Password population checklist.
Use [DEV-STACK.md](/Users/carlo/dev/dev-env-export/DEV-STACK.md) for the
current language, framework, and hosting stack this machine should support.
Use [PACKAGE-MANAGERS.md](/Users/carlo/dev/dev-env-export/PACKAGE-MANAGERS.md)
for the package-manager policy across Homebrew, npm, pnpm, and uv.
Use [CODE-QUALITY.md](/Users/carlo/dev/dev-env-export/CODE-QUALITY.md) for the
default linting and formatting baseline new repos should start with.
Use [PROJECT-STANDARDS.md](/Users/carlo/dev/dev-env-export/PROJECT-STANDARDS.md)
for the default testing, deployment, security, and delivery baseline new repos
should start with.
Use [AI-STACK.md](/Users/carlo/dev/dev-env-export/AI-STACK.md) for the current
AI-tooling inventory and tracking policy.

## Current Goal

Use this repo to provision:

- a fresh macOS laptop
- a fresh Parallels macOS VM
- a disposable development VM that should still feel like the main workstation

The target experience is a modern macOS setup centered on Zed, Warp, Codex,
Claude, Gemini, OpenSpec, GSD v2, and 1Password.

## What This Repo Owns

- shell defaults for macOS development
- Homebrew-driven CLI and app installation
- Git, GitHub CLI, AWS, Claude, Codex, Gemini, OpenSpec, GSD v2, Zed, and Warp baseline config
- GSD v2 install, shell-path, and migration guidance
- curated MCP server defaults and policy
- document, PDF, and image tooling for AI-assisted read/write workflows
- documented secret-handling policy built around 1Password
- new-project standards and constitution templates for TypeScript-first repos,
  with Python support where it is justified
- bootstrap scripts for a fresh machine or Parallels VM
- archived Ubuntu VM artifacts for reference only

## Repository Layout

| Path | Purpose |
| ---- | ------- |
| `scripts/` | bootstrap and setup scripts |
| `shell/` | zsh configuration |
| `dotfiles/` | Git, GitHub CLI, AWS, and related user config |
| `claude/` | Claude settings, commands, helper scripts, and plugin manifest |
| `gemini/` | Gemini CLI persona, settings defaults, and setup docs |
| `zed/` | Zed user configuration tracked for bootstrap |
| `warp/` | Warp launch configurations and related tracked files |
| `codex/` | Codex CLI configuration tracked for bootstrap |
| `mcp/` | curated default MCP server manifest and policy |
| `onepassword/` | 1Password CLI usage docs and secret template examples |
| `templates/` | starter config bundles and reusable repo scaffolds |
| `manifest/` | install manifests and review buckets for bootstrap tooling |
| `DEV-STACK.md` | current languages, frameworks, and hosting targets |
| `PACKAGE-MANAGERS.md` | package-manager policy for machine and project layers |
| `CODE-QUALITY.md` | default linting and formatting baseline for new repos |
| `PROJECT-STANDARDS.md` | default engineering baseline for new repos beyond lint and format |
| `AI-STACK.md` | AI tooling inventory, drift notes, and tracking policy |

## Quick Start

### 1. Clone Or Copy The Repo

For the Carlo Baseline, clone or copy the repo however you normally do:

```bash
git clone <repo-url> dev-env-export
cd dev-env-export
```

If the repo is being moved manually between machines, unpack it and `cd` into
the project root before running scripts.

For the Shared Baseline, the expected entry path is GitHub Desktop on macOS:
sign in, fetch this repo, and open the local checkout. Do not assume Homebrew,
Git CLI, `gh`, Node, Python tooling, or AI CLIs already exist before the
bootstrap runs.

### 2. Choose A Bootstrap Profile

The master bootstrap requires an explicit profile every time. Canonical profile
names are `carlo-baseline` and `shared-baseline`; aliases `carlo` and `shared`
also work.

```bash
chmod +x scripts/*.sh scripts/lib/*.sh

./scripts/00-bootstrap.sh --profile carlo-baseline
./scripts/00-bootstrap.sh --profile shared-baseline
```

You can also use the environment variable form:

```bash
DEV_ENV_BOOTSTRAP_PROFILE=shared-baseline ./scripts/00-bootstrap.sh
```

Use `./scripts/00-bootstrap.sh --list-profiles` if you need to check the valid
names. The script validates the profile before doing install work and stops
cleanly if macOS still needs you to finish Xcode Command Line Tools
installation.

Each bootstrap run writes timestamped logs under `logs/bootstrap-*` by default.
If a step blows up on a fresh VM, keep that log directory around so the failure
can be diagnosed without guessing.
Each run now leaves behind `bootstrap.log`, `environment.txt`,
`step-status.tsv`, `summary.txt`, and one log per step so you can see both the
machine context and the exact step outcome/duration.
If you want the logs somewhere else, set `DEV_ENV_LOG_DIR=/path/to/logs`
before running `./scripts/00-bootstrap.sh`.
If you want command-by-command tracing inside each step, run
`DEV_ENV_TRACE_STEPS=1 ./scripts/00-bootstrap.sh --profile carlo-baseline`.

The scripts are intended to be rerunnable. Re-running them should skip
already-installed packages and unchanged config where practical. If you want
to force a Homebrew metadata refresh before installs, run:

```bash
DEV_ENV_REFRESH_BREW=1 ./scripts/01-install-brew.sh
```

The npm steps are designed for `nvm`. If you have old `prefix` or
`globalconfig` settings in `~/.npmrc`, the bootstrap scripts will remove those
so Node 22 globals install under the active nvm-managed runtime.

Docker is Carlo Baseline tooling. In that profile it is installed in two pieces
on purpose: the `docker` formula provides the CLI, and the Docker Desktop cask
provides the app bundle. That avoids the privileged cask symlink step that can
otherwise derail unattended bootstrap runs. Docker Desktop is also the default
source and management path for MCP servers in this repo.

If Homebrew refuses to install `bun` because the local Xcode Command Line Tools
are too old, the bootstrap falls back to the official Bun release binary so the
machine still lands in a usable state. After a CLT update or reinstall, you can
switch Bun back to Homebrew ownership if you care about that detail.

This repo keeps Homebrew as the primary machine-level package manager. For
project-level JavaScript workflows, keep `npm` available but prefer `pnpm` for
new TypeScript-first repos. See `PACKAGE-MANAGERS.md`.

The active Homebrew install set lives in
`manifest/homebrew-packages.sh`. Use that file to cull stale apps from the
default bootstrap and keep a visible review bucket for stuff you no longer use.

The Carlo Baseline also installs repo-vendored Codex skills during
`./scripts/05-setup-dotfiles.sh`, so Carlo machines pick up tracked local skills
without a separate follow-up command. The Shared Baseline installs Codex CLI
only and does not install Carlo-specific Codex config, skills, personas, MCP
defaults, or plugin manifests.

To run the steps manually instead:

```bash
./scripts/01-install-brew.sh
./scripts/02-install-cli-tools.sh --profile shared-baseline
./scripts/03-install-npm-globals.sh --profile shared-baseline
./scripts/04-install-pip-packages.sh --profile shared-baseline
./scripts/15-setup-shared-shell.sh
./scripts/10-check-paths.sh --profile shared-baseline
./scripts/12-smoke-test.sh --profile shared-baseline
```

For the Carlo Baseline manual path, run the same first four steps with
`--profile carlo-baseline`, then run:

```bash
./scripts/05-setup-dotfiles.sh
./scripts/06-setup-claude.sh
./scripts/07-setup-1password.sh
./scripts/08-setup-gemini.sh
./scripts/10-check-paths.sh --profile carlo-baseline
./scripts/12-smoke-test.sh --profile carlo-baseline
```

If `./scripts/02-install-cli-tools.sh` prompts for Xcode Command Line Tools,
stop there, finish that install, and then re-run step 2 before continuing.

### 3. Complete Manual Setup

For the Shared Baseline:

```bash
exec zsh

git config --global user.name "Your Name"
git config --global user.email "you@example.com"
gh auth login --web --git-protocol https
gh auth setup-git
vercel login
codex login
```

Codex Desktop may already be installed on the target machine, but it is not a
Shared Baseline prerequisite and is not installed by the bootstrap. Store
credentials in 1Password or the user's preferred secret manager; the Shared
Baseline documents 1Password but does not install or configure it.

For the Carlo Baseline:

```bash
exec zsh

gh auth login --web --git-protocol https
gh auth setup-git
aws configure
gemini
gws auth setup
codex login
claude auth login
gsd config
```

Desktop apps such as 1Password, Warp, Zed, Docker, Claude, and Codex may still
require normal first-launch/login steps.

`openspec` is installed as an npm global under the active `nvm` Node runtime
during `./scripts/03-install-npm-globals.sh`.

`gemini` is CLI-only here. Launch it once and complete the OAuth flow if it
prompts for authentication.

`gsd` is now the standalone GSD v2 CLI installed from the `gsd-pi` npm
package. On first launch it runs a setup wizard and stores global preferences
under `~/.gsd/preferences.md`. The tracked shell config also removes the
oh-my-zsh git-plugin `gsd` alias so the CLI command resolves cleanly.

**Warp Agent Mode (Autonomous Operation):**

To allow agents to run commands without constant confirmation:

1. Open Warp Settings (`Cmd + ,`).
2. Navigate to **AI > Agents > Profiles** and select your active profile.
3. Set **Executing commands** to **Always allow**.
4. Review the **Command denylist** and remove essential developer tools like `rsync`, `curl`, `npm`, `vercel`, `docker`, and `rm` to enable full autonomy.
5. Use `Cmd + Shift + I` in a session to toggle "Run until completion" for a specific task.

Before those auth steps, sign in to 1Password and use it as the source of truth
for credentials, API keys, and project `.env` values.

For normal GitHub CLI and agent usage on this machine, prefer browser-based
`gh auth login` over PAT-based auth. That is enough for basic repo and gist
operations over HTTPS, and does not require a GitHub App or SSH key.

Recommended follow-up:

- In 1Password, sign in and confirm `op account list` works
- In GitHub CLI, authenticate with `gh auth login --web --git-protocol https`
  and then run `gh auth setup-git`
- In Google Workspace CLI, run `gws auth setup` if Workspace automation is part
  of the current machine workflow
- In Gemini CLI, launch `gemini` once and complete OAuth if prompted
- In GSD, run `gsd config` once to initialize provider and tool settings
- In projects that still use legacy `.planning/` state, launch `gsd` there and run `/gsd migrate`
- In Zed, run `Cmd+Shift+P` and execute `cli: install`
- In Zed, open `/Users/carlo/dev`, then use the `Restricted Mode` prompt or
  `workspace::ToggleWorktreeSecurity` to trust all projects in that folder
- In Warp, open `Dev Env Bootstrap` from Launch Configurations
- In Claude, use `claude/PLUGIN-MANIFEST.md` to install only the plugins you still use
- Run `./scripts/11-create-1password-stubs.sh --vault Private` to scaffold secret items in 1Password
- Run `./scripts/09-inventory-ai-tooling.sh` to snapshot the local AI layer
- Run `./scripts/10-check-paths.sh --profile carlo-baseline` to verify the
  expected CLIs are actually visible
- Run `./scripts/12-smoke-test.sh --profile carlo-baseline` to verify the
  post-bootstrap baseline end to end

## Known Niggles

These are known non-blocking rough edges, not current show-stoppers:

- `scripts/10-check-paths.sh` is still a lighter check than
  `scripts/12-smoke-test.sh`; use the smoke test when you want Python-module
  coverage and app/config verification too
- `scripts/09-inventory-ai-tooling.sh` still treats Warp as a version-style
  CLI check even though Warp is mainly an app-first tool in this repo
- `AI-STACK.md` is still partly a dated snapshot of one machine's observed tool
  state and should be refreshed after the fresh-VM validation pass if the
  current baseline changes

## Stack

The framework and hosting stack is documented in
`DEV-STACK.md`. At a glance, this repo is being shaped around:

- TypeScript as the default for application code
- Next.js and Vite
- Tailwind CSS and shadcn/ui
- Node.js and TypeScript for backend services, Lambdas, and microservices
- Python for scripting, automation, document tooling, and library-driven edge
  cases
- AWS and Vercel

## Starting New Repos

When you spin up a new repo from this environment, do not start from scratch.

- Use [PROJECT-STANDARDS.md](/Users/carlo/dev/dev-env-export/PROJECT-STANDARDS.md)
  as the default standard for testing, deployment, security, and operations.
- Carlo Baseline bootstrap runs already install repo-vendored Codex skills for
  you.
- Install or refresh the Codex skill manually with
  [scripts/14-install-codex-skills.sh](/Users/carlo/dev/dev-env-export/scripts/14-install-codex-skills.sh)
  if you want to update an existing machine without rerunning the broader
  bootstrap.
- Run
  [scripts/13-apply-project-standards.sh](/Users/carlo/dev/dev-env-export/scripts/13-apply-project-standards.sh)
  to copy the starter into a target repo with a profile-aware baseline.
- That script also deploys the standard agent direction files from
  `agent-direction/` as root `AGENTS.md` and `CLAUDE.md` unless you use
  `--constitution-only`.
- Copy
  [templates/project-standards/constitution.md](/Users/carlo/dev/dev-env-export/templates/project-standards/constitution.md)
  into the new repo as `constitution.md`.
- Merge the right files from
  [templates/code-quality/](/Users/carlo/dev/dev-env-export/templates/code-quality/)
  for the repo's lint and format baseline.

Example:

```bash
./scripts/14-install-codex-skills.sh --skill apply-project-standards

./scripts/13-apply-project-standards.sh \
  --repo ~/dev/my-api \
  --profile ts-service
```

### Shared Baseline CLI

- Homebrew
- git, gh, jq
- nvm-managed node, npm, corepack, pnpm, bun
- python3, uv
- pandoc, poppler, tesseract, imagemagick
- codex
- vercel
- make, gcc

### Carlo Baseline Additional CLI

- gemini-cli (`gemini`)
- gsd-pi (`gsd`, `gsd-cli`)
- googleworkspace-cli (`gws`)
- claude
- OpenSpec (`openspec`)
- awscli
- docker-related local tooling where needed
- taproom

### Shared Baseline GUI Tools

- Warp
- Zed
- Raycast
- Hidden Bar
- Hammerspoon
- GitHub Desktop

### Carlo Baseline Additional GUI Tools

- 1Password
- 1Password CLI
- BetterDisplay
- Obsidian
- Docker Desktop
- Firefox
- Claude desktop
- Codex desktop

### Review Bucket

- Sublime Text

### Optional Infra Tooling

- Terraform

The review and optional buckets stay visible in the manifest but are not
installed by default.

## Document Workflow Baseline

This machine baseline now assumes local tooling for common AI-driven document
work:

- modern Office files: `.docx`, `.xlsx`, `.pptx`
- PDFs with native text extraction first
- images with OCR fallback when text extraction fails or is clearly degraded

Default policy:

- prefer native parsers and structural extraction first
- use PDF text extraction before page-image OCR
- use OCR only when extraction is empty, badly garbled, or obviously incomplete

The bootstrap installs the local CLI pieces for that path, and the Python
bootstrap adds the common document libraries used to read and write those file
types.

## Package Manager Policy

- Homebrew stays the primary machine-level package manager.
- Homebrew installs `nvm`, and `nvm` owns the active Node runtime.
- `npm` stays installed for compatibility and global CLIs.
- `pnpm` is the preferred project package manager for new TS-heavy repos.
- `uv` is the preferred fast Python package tool where Python is the right
  tool.

See `PACKAGE-MANAGERS.md` for the detailed policy.

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
