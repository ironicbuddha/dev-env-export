# Claude Plugin Manifest

This file is the curated plugin policy for Claude Code in this repo.

The live machine currently has more plugins enabled than the repo should track
by default. The goal here is not to mirror everything in `~/.claude`; it is to
define the plugin set that is actually worth reinstalling on a fresh machine.

Tracked settings in this repo still enable no plugins by default. Use this file
to decide what to install and enable after bootstrap.

## Core Plugins

These are the plugins most worth carrying forward as part of the normal
workflow.

- `context7@claude-plugins-official`
  Current docs and API reference lookups. High value, low drama.
- `github@claude-plugins-official`
  Useful whenever the workflow touches GitHub repos, issues, or PRs.
- `code-review@claude-plugins-official`
  Fits the repo's review-heavy workflow and is directly aligned with how work
  gets done here.
- `document-skills@anthropic-agent-skills`
  Worth keeping because this machine already leans hard on local skills and
  structured prompting.
- `playwright@claude-plugins-official`
  Strong fit for browser automation, UI checks, and real workflow validation.
- `vercel@claude-plugins-official`
  Keep if Vercel remains part of the normal shipping path.
- `frontend-design@claude-plugins-official`
  Keep because design-to-implementation work is part of the active tool stack.

## Optional Plugins

Useful, but not universal enough to treat as part of the default plugin loadout
for every machine.

- `pyright-lsp@claude-plugins-official`
  Good when doing real Python-heavy work.
- `typescript-lsp@claude-plugins-official`
  Good when doing TS-heavy work.
- `security-guidance@claude-plugins-official`
  Useful when explicitly doing security review, but not needed in every
  day-to-day session.
- `feature-dev@claude-plugins-official`
  Potentially useful, but overlaps with strong built-in model behavior and the
  existing command set.

## Hold Or Drop

Installed locally at some point, but not strong candidates for the curated
baseline until they prove they earn their keep.

- `code-simplifier@claude-plugins-official`
  Feels redundant unless it demonstrates a concrete advantage in real work.
- `ralph-loop@claude-plugins-official`
  Interesting, but not clearly part of the daily workflow.
- `superpowers@claude-plugins-official`
  Broad and fuzzy. Too hand-wavy for the default stack.
- `taches-cc-resources@taches-cc-resources`
  Specialized and not clearly tied to the current core workflow.

## Install Order On A Fresh Machine

If starting clean, install in this order:

1. `context7@claude-plugins-official`
2. `github@claude-plugins-official`
3. `code-review@claude-plugins-official`
4. `document-skills@anthropic-agent-skills`
5. `playwright@claude-plugins-official`
6. `vercel@claude-plugins-official`
7. `frontend-design@claude-plugins-official`

Then add optional plugins only when there is a real use case.

## Secret And Tool Dependencies

Some plugins only make sense when their adjacent tools or credentials exist:

- `github@claude-plugins-official`
  Needs GitHub auth to be worthwhile.
- `vercel@claude-plugins-official`
  Needs a Vercel token and active Vercel usage.
- `playwright@claude-plugins-official`
  Works best when browser tooling is actually installed.
- `context7@claude-plugins-official`
  No special secret burden, so it is one of the safest defaults.

## Repo Policy

- Keep `claude/settings/settings.json` minimal.
- Do not pre-enable a giant plugin bundle in tracked settings.
- Use this manifest to decide what to install after bootstrap.
- If the actual working set changes, update this file and `AI-STACK.md`
  together.
