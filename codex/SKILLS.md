# Codex Skills

This document records the Codex-accessible skill inventory observed on this
machine and the repo policy for what should live in Git versus what should be
installed during machine bootstrap.

Observed on 2026-03-17.

## Skill Roots

- `~/.codex/skills`: 54 installed skills
- `~/.agents/skills`: 2 installed skills
- Total skills currently available to Codex in this environment: 56

## Repo Policy

- Candidate repo-vendored skills:
  - `load-manifest`
  - `stage-commit-push`
- Current state of those two skills:
  - Carlo identified them as custom skills worth considering for vendoring.
  - Their source directories were not present under `~/.codex/skills` or
    `~/.agents/skills` during this inventory pass.
  - Do not fabricate placeholder skill bodies in Git. Copy the real source
    into the repo once those skill directories are located.
- Install-on-build skills:
  - everything else in the inventory below can stay external and be installed
    when rebuilding the machine
- Bundled/system skills:
  - keep the `.system/*` skills external; they are platform-managed helpers,
    not repo-owned local customizations

## Planned Repo Layout

If `load-manifest` and `stage-commit-push` are recovered and promoted into the
repo, store them under `codex/skills/` and treat them as portable Codex
customizations that should be copied into `~/.codex/skills/` during bootstrap.

## Inventory

### Bundled System Skills

- `openai-docs` (`codex:.system/openai-docs`): Official OpenAI docs workflow
  for current API and product guidance.
- `skill-creator` (`codex:.system/skill-creator`): Guide for creating or
  updating Codex skills.
- `skill-installer` (`codex:.system/skill-installer`): Installs Codex skills
  from curated sources or GitHub repos.

### Repo, Platform, And Helper Skills

- `gh-actions` (`codex:gh-actions`): GitHub Actions workflow creation, repair,
  and operations.
- `load-context` (`codex:load-context`): Loads core repo docs before answering
  or editing.
- `markdown-lint-fix-commit-push` (`codex:markdown-lint-fix-commit-push`):
  End-to-end markdown lint, stage, commit, and push workflow.
- `openai-docs` (`codex:openai-docs`): User-facing OpenAI docs skill for
  current official references and citations.
- `find-skills` (`agents:find-skills`): Helps discover installable skills when
  a user asks whether a capability already exists.

### Document, Media, And Data Skills

- `doc` (`codex:doc`): Read, create, and edit `.docx` files with layout-aware
  checks.
- `docx` (`codex:docx`): Convert Markdown into `.docx` via Pandoc.
- `macwhisper-webhook` (`codex:macwhisper-webhook`): Receive MacWhisper Pro
  webhooks and save transcript artifacts locally.
- `pdf` (`codex:pdf`): Read, create, and review PDFs with rendering-aware
  extraction and generation tools.
- `repo-audio-review` (`codex:repo-audio-review`): Process repo audio-note
  workflows from transcription through review output.
- `screenshot` (`codex:screenshot`): Capture desktop or window screenshots when
  tool-local capture is insufficient.
- `spreadsheet` (`codex:spreadsheet`): Create, edit, analyze, and format
  spreadsheets such as `.xlsx`, `.csv`, and `.tsv`.

### App, Frontend, Browser, And Deploy Skills

- `chatgpt-apps` (`codex:chatgpt-apps`): Build and troubleshoot ChatGPT Apps
  SDK projects with MCP server and widget UI pieces.
- `figma` (`codex:figma`): Use the Figma MCP server for design context,
  screenshots, variables, and assets.
- `figma-implement-design` (`codex:figma-implement-design`): Translate Figma
  nodes into production-ready code with high visual fidelity.
- `playwright` (`codex:playwright`): Automate a real browser from the terminal
  for UI flows and extraction.
- `vercel-deploy` (`codex:vercel-deploy`): Deploy sites and apps to Vercel.
- `shadcn` (`agents:shadcn`): Manage shadcn/ui components, registries, presets,
  and project composition.

### Security Skills

- `security-best-practices` (`codex:security-best-practices`): Security
  best-practice review for supported language stacks.
- `security-ownership-map` (`codex:security-ownership-map`): Security-oriented
  ownership and bus-factor analysis from git history.
- `security-threat-model` (`codex:security-threat-model`): Repository-grounded
  threat modeling and abuse-path documentation.

### GSD Workflow Skills

- `gsd-add-phase` (`codex:gsd-add-phase`): Add a phase to the end of the
  current milestone.
- `gsd-add-tests` (`codex:gsd-add-tests`): Generate tests for a completed phase
  from UAT criteria and implementation.
- `gsd-add-todo` (`codex:gsd-add-todo`): Capture a todo from current
  conversation context.
- `gsd-audit-milestone` (`codex:gsd-audit-milestone`): Audit milestone
  completion against original intent.
- `gsd-check-todos` (`codex:gsd-check-todos`): List pending todos and select
  one to work on.
- `gsd-cleanup` (`codex:gsd-cleanup`): Archive accumulated phase directories
  from completed milestones.
- `gsd-complete-milestone` (`codex:gsd-complete-milestone`): Archive a
  completed milestone and prep the next version.
- `gsd-debug` (`codex:gsd-debug`): Systematic debugging with persistent state.
- `gsd-discuss-phase` (`codex:gsd-discuss-phase`): Gather phase context before
  planning.
- `gsd-execute-phase` (`codex:gsd-execute-phase`): Execute all plans in a phase
  with wave-based parallelization.
- `gsd-health` (`codex:gsd-health`): Diagnose planning directory health and
  optionally repair it.
- `gsd-help` (`codex:gsd-help`): Show available GSD commands and usage.
- `gsd-insert-phase` (`codex:gsd-insert-phase`): Insert urgent work as a
  decimal phase between existing phases.
- `gsd-join-discord` (`codex:gsd-join-discord`): Join the GSD Discord
  community.
- `gsd-list-phase-assumptions` (`codex:gsd-list-phase-assumptions`): Surface
  Claude's assumptions before planning.
- `gsd-map-codebase` (`codex:gsd-map-codebase`): Analyze codebase structure and
  produce `.planning/codebase/` docs.
- `gsd-new-milestone` (`codex:gsd-new-milestone`): Start a new milestone cycle.
- `gsd-new-project` (`codex:gsd-new-project`): Initialize a new project with
  deep context gathering.
- `gsd-pause-work` (`codex:gsd-pause-work`): Create a context handoff when
  pausing work.
- `gsd-plan-milestone-gaps` (`codex:gsd-plan-milestone-gaps`): Create phases to
  close milestone audit gaps.
- `gsd-plan-phase` (`codex:gsd-plan-phase`): Create detailed `PLAN.md` files
  with verification loops.
- `gsd-progress` (`codex:gsd-progress`): Show project progress and route to the
  next action.
- `gsd-quick` (`codex:gsd-quick`): Execute a quick task with GSD guarantees.
- `gsd-reapply-patches` (`codex:gsd-reapply-patches`): Reapply local
  modifications after a GSD update.
- `gsd-remove-phase` (`codex:gsd-remove-phase`): Remove a future phase and
  renumber following phases.
- `gsd-research-phase` (`codex:gsd-research-phase`): Research phase
  implementation outside the normal planner flow.
- `gsd-resume-work` (`codex:gsd-resume-work`): Resume work from previous
  session context.
- `gsd-set-profile` (`codex:gsd-set-profile`): Switch GSD model profiles.
- `gsd-settings` (`codex:gsd-settings`): Configure GSD workflow toggles and
  model profile.
- `gsd-update` (`codex:gsd-update`): Update GSD and show the changelog.
- `gsd-validate-phase` (`codex:gsd-validate-phase`): Audit and fill Nyquist
  validation gaps for a completed phase.
- `gsd-verify-work` (`codex:gsd-verify-work`): Validate built features through
  conversational UAT.
