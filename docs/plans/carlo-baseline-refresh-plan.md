# Carlo Baseline Refresh Implementation Plan

## Purpose

Evolve this repository into a reliable, ZIP-first bootstrap for a personal-admin
Apple Silicon macOS machine. The implementation retains two explicit Bootstrap
Profiles: `carlo-baseline` for Carlo's personal workflow and `shared-baseline`
for the portable, identity-free subset.

This plan is implementation work, not a claim that the clean-machine outcome
has already been accepted. Execute it directly on `main` in the stages below;
each stage must be reviewed and verified before the next begins.

## Scope and boundaries

In scope:

- an extracted public GitHub ZIP as the zero-tool Bootstrap Entry Path for both
  profiles;
- Apple Silicon macOS only, with explicit Xcode Command Line Tools stop/retry
  behavior;
- profile-aware package, shell, app, AI-tool, Skill Hub, documentation, and
  verification updates;
- recovery-safe configuration writes, durable external run logs, and a
  documented clean-machine Carlo acceptance record.

Out of scope:

- Intel Macs, MDM-managed machines, automated sign-in or credential migration;
- restoring Ubuntu-era exports or making downloads, upstream checkouts, local
  handoffs, generated logs, or personal runtime state part of the repository;
- default MCP servers or plugins, browser automation as machine state, and
  automatic retry/checkpoint state;
- an external pull request workflow. This solo repository may ship a verified
  work branch directly to `main`.

## Delivery sequence

### 1. Establish bootstrap entry, profiles, and durable run records

Update `README.md`, `CONTEXT.md`, `scripts/00-bootstrap.sh`,
`scripts/00-check-prerequisites.sh`, `scripts/lib/bootstrap-profile.sh`,
`scripts/lib/bootstrap-prerequisites.sh`, and related tests to make the
extracted public GitHub ZIP the documented first route for both profiles.

- Explicitly reject or document unsupported Intel execution; retain only the
  Apple Silicon path.
- Preserve explicit `--profile` selection and aliases. Retain the CLT gate:
  after asking macOS to install the tools, exit with code `20` and require a
  rerun once `xcode-select`, `xcrun`, and `clang` are usable.
- Move the default Bootstrap Run Log parent to
  `~/Library/Logs/dev-env-bootstrap`, preserving `DEV_ENV_LOG_DIR` as an
  explicit parent-directory override. Keep isolated run directories, summary,
  environment snapshot, step status, and step output; redact or avoid secret
  values.
- Apply Recovery-Safe Configuration Writes consistently: back up only regular
  files, reject symlinks and non-file targets, atomically replace where
  practical, and never prune backups automatically.

### 2. Reconcile runtimes, package policy, and profile inventories

Update `manifest/homebrew-packages.sh`, `scripts/01-install-brew.sh`,
`scripts/02-install-cli-tools.sh`, `scripts/03-install-npm-globals.sh`,
`scripts/04-install-pip-packages.sh`, `scripts/lib/runtime-environment.sh`,
`scripts/lib/bootstrap-expectations.sh`, `scripts/10-check-paths.sh`,
`scripts/12-smoke-test.sh`, fixtures, and all affected documentation.

- Keep Homebrew as the machine manager and Homebrew-installed `nvm` as the
  sole Node runtime manager. Pin Node `24.18.0` LTS.
- Replace Python `3.13` assumptions with `python@3.14`; remove hard-coded
  version paths in writers, resolvers, fixtures, checks, and docs together.
- Replace user-site `pip` and `--break-system-packages` with a bootstrap-owned
  `uv` environment containing the retained document/OCR Python stack. Make the
  managed runtime/PATH block expose it; projects create their own environments.
- Enable Corepack but do not install a machine-wide `pnpm@latest`; projects pin
  their own package manager with `packageManager`.
- Keep shared document/OCR and convenience formulae (`pandoc`, `poppler`,
  `tesseract`, `imagemagick`, `mole`, `gcc`). Keep Bun and Vercel Carlo-only;
  move `taproom` to documented optional tooling.
- Remove automatic OpenSpec and GSD installation and their required-command
  verification. Preserve only relevant standalone/manual project use outside
  the baseline.

### 3. Make configuration, identity, apps, and secrets profile-safe

Update `scripts/05-setup-dotfiles.sh`, `scripts/07-setup-1password.sh`,
`scripts/08-op-inject-template.sh`, `scripts/11-create-1password-stubs.sh`,
`scripts/15-setup-shared-shell.sh`, `scripts/lib/managed-shell-block.sh`,
`scripts/lib/file-safety.sh`, tracked dotfiles, app bundles, and associated
setup documentation.

- Replace wholesale Carlo shell copies with managed Carlo blocks. Preserve
  unrelated existing shell content while installing Oh My Zsh theme/plugin and
  Zed editor behavior where the Zed CLI exists.
- Make one version-independent managed runtime/PATH block authoritative for
  Homebrew, nvm-selected Node, `~/.local/bin`, and the bootstrap-owned `uv`
  environment. Remove the automatic `venv` helper.
- Keep Shared Baseline limited to its managed runtime/PATH shell setup; deploy
  no Git, GitHub CLI, AWS, or personal-shell dotfiles there.
- Split portable Git defaults from identity-bearing values. Completion output
  must direct Carlo Baseline to the First-Run Configuration Step for Git
  identity and named cloud profiles, without copying personal email, AWS
  profiles, credentials, or a master `.env`.
- Keep 1Password desktop and CLI Carlo-only. Retain non-secret, overwrite-
  refusing stub creation as an explicitly invoked helper; remove obsolete and
  optional-service item assumptions. Shared Baseline supplies guidance only.
- Retain Warp, Zed, Raycast, Hidden Bar, Hammerspoon, and GitHub Desktop in both
  profiles. Keep Zed/Warp configuration Carlo-only and update Warp launch
  paths for current checkout locations. Treat app trust, extensions,
  permissions, accounts, and in-app state as manual first-run work.
- Remove BetterDisplay, Obsidian, and stale Sublime Text inventory. Document
  Firefox and Docker Desktop/CLI as optional manual Homebrew installs; do not
  add profile switches or prompts. Leave browsers project-owned.

### 4. Rebuild the AI and reusable-skill layer around safe shared sources

Update `codex/`, `claude/`, `gemini/`, `mcp/`, `scripts/06-setup-claude.sh`,
`scripts/08-setup-gemini.sh`, `scripts/09-inventory-ai-tooling.sh`,
`scripts/14-install-codex-skills.sh`, relevant manifests, and AI/secret docs.

- Keep Codex, Claude Code, and Gemini CLI Carlo-only; retain Buddy Mode,
  Claude commands/statusline helpers, and Codex's durable YOLO settings
  (`approval_policy = "never"`, `sandbox_mode = "danger-full-access"`).
  Do not pin model or reasoning values.
- Give Shared Baseline Codex CLI access only, without personal config,
  personas, skills, plugins, MCP defaults, Claude, Gemini, or local state.
- Narrowly merge portable AI settings with backups and leave auth, hooks,
  agents, plugins, trust state, sessions, and machine-local skills untouched.
- Create the public `https://github.com/ironicbuddha/skills-hub.git` prerequisite
  before wiring the bootstrap. It owns reviewed full skill sources under
  `skills/<skill-id>/`, provenance metadata, selection manifests, and tooling.
- Replace repo-vendored skill installation with Hub acquisition at
  `${SKILL_HUB_DIR:-~/dev/skill-hub}`. Clone if absent, fast-forward only a
  valid checkout, select `carlo-baseline` by default (with explicit
  `--skill-selection` or environment override), link selected skills into
  `~/.agents/skills`, then make `~/.codex/skills` and `~/.claude/skills`
  directory links to that projection.
- Refuse user-managed Hub/target paths with remediation. If acquisition or
  update fails, warn and skip the skill stage; do not fall back to this repo.
- Remove OpenSpec, GSD v2, OpenCode, and 21st.dev Agents from baseline scripts,
  verification, inventory, credentials guidance, and first-run docs. Replace
  default MCP configuration with a manually applied, curated catalogue, and
  retain a deliberately uninstalled Claude-plugin manifest.

### 5. Align project standards, active documentation, and repository hygiene

Update `AGENTS.md`, `CONTEXT.md`, `README.md`, `AI-STACK.md`, `DEV-STACK.md`,
`PACKAGE-MANAGERS.md`, `CODE-QUALITY.md`, `PROJECT-STANDARDS.md`,
`PERSONALITY.md`, `HISTORICAL.md`, `onepassword/`, `templates/`,
`scripts/13-apply-project-standards.sh`, `agent-direction/`, `.gitignore`, and
the relevant documentation tests/checkers.

- Keep `CONTEXT.md` as operational source of truth, repository contents next,
  and `AGENTS.md` as durable operating guidance. Use relative documentation
  links and date any intentionally retained observed inventory.
- Keep `HISTORICAL.md` as a compact Git-recovery guide only. Remove obsolete
  active Ubuntu, OpenSpec, GSD, plugin, MCP, local-inventory, and runtime claims.
- Retain profile-aware constitution, standards, quality templates, and the
  explicit non-overwriting standards applicator. Replace copied long-form
  agent-direction policy with a concise optional `AGENTS.md` starter linked to
  the constitution; provide `CLAUDE.md -> AGENTS.md` as a relative symlink with
  a documented plain-copy fallback.
- Keep specialised agent workflows in Skill Hub, selected deliberately rather
  than scaffolded into every repository.
- Ignore `.handoff/`, local scratch, temporary files, checkout-local generated
  logs, downloads, and upstream checkouts while retaining deliberate non-secret
  fixtures under `tests/fixtures/`. Do not version clean-machine acceptance or
  durable bootstrap logs.

### 6. Verify, record acceptance, and ship

Run focused contract tests after every affected stage and the full suite before
delivery:

```sh
./tests/run.sh
./scripts/run_markdownlint_repo.sh --check
git diff --check
```

Run profile-aware checks in a representative local environment, treating their
results as regression evidence rather than fresh-machine acceptance:

```sh
./scripts/10-check-paths.sh --profile shared-baseline
./scripts/10-check-paths.sh --profile carlo-baseline
./scripts/12-smoke-test.sh --profile shared-baseline
./scripts/12-smoke-test.sh --profile carlo-baseline
```

Finally, run Carlo Baseline from an extracted GitHub ZIP on a clean Apple
Silicon macOS machine. Record the command, outcome, durable external run-log
location, explicit post-bootstrap authentication/first-run work, and any
intentional optional installs in a non-secret implementation-era acceptance
record. Do not call fixtures or a provisioned local machine a substitute for
that gate.

## Dependencies and cleanup order

The public Skill Hub must exist before its bootstrap integration can land. The
runtime/PATH contract must be settled before shell writers, path checks, and
smoke tests are updated. Profile inventories must drive documentation and
verification changes; do not independently edit lists in multiple places.
Documentation and ignore cleanup follows the final inventory so it cannot
preserve obsolete claims. The clean-machine run is the final acceptance gate.

Issue [Review and simplify the project-standards package](https://github.com/ironicbuddha/dev-env-export/issues/16)
remains separate follow-up triage, not a prerequisite to this refresh plan.
