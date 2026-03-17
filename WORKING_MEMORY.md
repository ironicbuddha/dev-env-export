# Working Memory

Last updated: 2026-03-17

## Current State

- The repo is aligned around a macOS bootstrap flow with Homebrew, `nvm`,
  Warp, Zed, Codex, Claude, Docker Desktop, and 1Password.
- The machine-level bootstrap logic was already hardened earlier in this work:
  nvm-first Node handling, Docker split install, Bun fallback, and better rerun
  behavior.
- The machine has been brought up to the repo baseline closely enough that the
  verification scripts passed earlier in this session history:
  - `./scripts/10-check-paths.sh`
  - `./scripts/12-smoke-test.sh`
- Docker Desktop is installed at `/Applications/Docker.app`.
- The Docker CLI is installed via the `docker` Homebrew formula.

## Last Pushed Baseline

- Commit `b27938e`
- Message: `Harden bootstrap and clean Markdown lint`

That commit already contains the earlier bootstrap/script hardening work. The
changes below are newer local work and are not committed yet.

## Repo Changes In Flight

Current tracked modifications:

- `AGENTS.md`
- `AI-STACK.md`
- `CONTEXT.md`
- `DEV-STACK.md`
- `PACKAGE-MANAGERS.md`
- `README.md`
- `SECRETS-CHECKLIST.md`
- `SECRETS.md`
- `claude/PLUGIN-MANIFEST.md`
- `dotfiles/gh-config.yml`
- `dotfiles/gitconfig`
- `onepassword/README.md`
- `onepassword/stubs/core.tsv`
- `scripts/00-bootstrap.sh`

Current untracked additions:

- `CODE-QUALITY.md`
- `mcp/README.md`
- `mcp/servers.yaml`
- `templates/code-quality/`

Note:

- `onepassword/examples/project.env.tpl` was updated locally to match the new
  hyphen-based 1Password item names and added `FIRECRAWL_API_KEY`, but that file
  is ignored by Git because of the repo's `*.env.*` ignore rule.

## What Changed This Session

### GitHub Auth Policy

- The repo docs were updated to prefer:
  - `gh auth login --web --git-protocol https`
  - `gh auth setup-git`
- Repo stance now says normal `gh` repo/gist work does not need a PAT, SSH key,
  or GitHub App.

Affected files include:

- `README.md`
- `SECRETS.md`
- `SECRETS-CHECKLIST.md`
- `onepassword/README.md`
- `dotfiles/gh-config.yml`
- `dotfiles/gitconfig`
- `scripts/00-bootstrap.sh`

### 1Password Naming Cleanup

- The repo switched from slash-separated item titles like
  `openai / api credential` to hyphenated titles like
  `openai - api credential`.
- Reason: 1Password secret references parse `/` as a path separator and the old
  naming caused parsing issues.

The tracked default 1Password item names now include:

- `github - personal access token`
- `aws - main account`
- `openai - api credential`
- `anthropic - api credential`
- `firecrawl - api credential`
- `21st - agents api credential`
- `google - gemini api key`
- `google stitch - api credential`
- `vercel - personal token`
- `figma - personal access token`
- `ssh - primary developer key`
- `recovery - github`
- `recovery - aws`
- `recovery - openai`
- `recovery - anthropic`

### AI / Provider Additions

- Added `21st - agents api credential` to the tracked provider list and
  1Password scaffolding.
- Added `firecrawl - api credential` to the tracked provider list and
  1Password scaffolding.

### MCP Policy

- Added a real MCP policy area under `mcp/`.
- `mcp/servers.yaml` is now the editable source of truth for:
  - MCP source
  - default servers
  - optional servers
- Current MCP source:
  - `docker-library`
- Current default MCP servers:
  - `context7`
  - `github`
  - `playwright`
  - `Sequential Thinking`
- Current optional MCP servers:
  - `figma`
  - `firecrawl`
  - `docker`
- Repo policy now says Docker Desktop / Docker library is the default source
  and management path for MCP servers.

### Claude Plugin Policy

- Added `ccstatusline` to the Claude plugin manifest as an optional plugin.
- Promoted `code-simplifier@claude-plugins-official` from "hold or drop" into
  the optional plugin set.
- `ccstatusline` was deliberately kept optional because the repo already tracks
  `claude/statusline-command.sh` as a custom statusline path.

### Code Quality Baseline

- Added `CODE-QUALITY.md` as the repo-level lint/format baseline for new repos.
- Added a starter bundle under `templates/code-quality/` with:
  - `.prettierrc.json`
  - `.prettierignore`
  - `.markdownlint.json`
  - `eslint.config.mjs`
  - `stylelint.config.mjs`
  - `package.quality.json`
  - `pyproject.toml`
  - `Makefile.python`
- Repo stance is explicit that these are repo-local defaults, not new global
  machine bootstrap installs.

## Verification Snapshot

Verification done during this session's doc/template work:

- `markdownlint` passed on touched tracked Markdown files
- JSON starter files parse cleanly
- `templates/code-quality/pyproject.toml` parses cleanly
- `node --check` passed for:
  - `templates/code-quality/eslint.config.mjs`
  - `templates/code-quality/stylelint.config.mjs`
- `mcp/servers.yaml` parses cleanly

Earlier machine/bootstrap verification still worth remembering:

- `./scripts/10-check-paths.sh` passed
- `./scripts/12-smoke-test.sh` passed

## Machine-Specific Caveat

- Bun currently exists at `/opt/homebrew/bin/bun`, but it is not Homebrew-owned
  on this machine.
- Reason: `brew install oven-sh/bun/bun` failed because local Command Line
  Tools were too old.
- The repo now handles this automatically with a fallback binary install, so
  fresh bootstrap still lands in a usable state.

## Useful Next Steps

- Commit the current repo changes once reviewed.
- Decide whether the MCP optional/default split still feels right now that
  Docker is the default source for MCP servers.
- If desired, add actual MCP bootstrap/setup instructions beyond the manifest so
  a fresh machine can recreate the curated MCP set automatically.
- If desired, add copy instructions or a helper script for the
  `templates/code-quality/` starter bundle so new repos can adopt it faster.
