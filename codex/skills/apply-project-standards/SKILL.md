---
name: apply-project-standards
description: Apply the dev-env-export project standards starter into a target repository. Use this skill when the user wants to start a new repo with Carlo's TypeScript-first constitution, testing, deployment, security, and operations baseline, or asks to copy or load that starter into another repo with a `next`, `vite`, `ts-service`, `python`, or `mixed` profile.
---

# Apply Project Standards

This skill applies the repo's standard new-project starter into another repo.

Use the deterministic helper script instead of manually re-creating the same
starter files by hand.

## When To Use This Skill

Use this skill when the user:

- asks to start a repo with this environment's standard baseline
- wants the `constitution.md` starter loaded into another repo
- wants the test, deploy, security, and operations baseline copied into a repo
- asks to apply or run `scripts/13-apply-project-standards.sh`

## Workflow

### 1. Work from the repo root

Make sure you are in the `dev-env-export` repo root or can reach:

- `scripts/13-apply-project-standards.sh`
- `templates/project-standards/constitution.md`
- `templates/code-quality/`
- `agent-direction/AGENTS.md`
- `agent-direction/CLAUDE.md`

### 2. Determine the target repo and profile

Figure out the target repo path and pick the right profile:

- `next`
- `vite`
- `ts-service`
- `python`
- `mixed`

Default to a TypeScript profile unless the workload clearly justifies Python.

### 3. Prefer the script

Run:

```bash
./scripts/13-apply-project-standards.sh --repo /path/to/repo --profile <profile>
```

Use `--dry-run` first when:

- the target repo already has substantial config
- the user wants to preview changes first
- you expect file conflicts

Use `--force` only when the user clearly wants repo files overwritten.

### 4. Review the script output

After the script runs:

- note any skipped files
- note any warnings
- tell the user what was merged versus what still needs manual review
- confirm whether `AGENTS.md` and `CLAUDE.md` were written, skipped, or backed
  up because these are part of the standard agent direction baseline

Typical follow-up points:

- all non-`--constitution-only` runs deploy the shared agent direction files
  from `agent-direction/`
- TypeScript repos get the starter lint and format config plus a `package.json`
  quality merge
- Python repos may still need Ruff wired into the repo's actual dependency flow
- every repo still needs the generated `constitution.md` trimmed to the real
  project shape

### 5. If the user wants the skill installed

Use:

```bash
./scripts/14-install-codex-skills.sh --skill apply-project-standards
```

That links the repo-vendored skill into `~/.codex/skills` and, by default, the
shared `~/.agents/skills` directory too.
