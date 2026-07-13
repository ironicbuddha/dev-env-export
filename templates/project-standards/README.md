# Project Standards Starter

This starter bundle gives new repos a copy-ready standards baseline.

It is meant to work with the rest of this repo's defaults:

- TypeScript-first apps and services usually use `pnpm` and Node 24.18.0 LTS
- Next.js apps pin `next` to 16.2.10
- Python is mainly for scripting and library-driven cases, usually with `uv`
- Markdown-only repositories use `pnpm`, Prettier, and `markdownlint-cli2`
- frontend hosting usually defaults to Vercel
- backend and infra-heavy workloads usually default to AWS
- secrets should flow through 1Password and platform secret stores

## Files

- `constitution.md`
  Copy this into the new repo root, then trim it to the actual project.

## How To Use It

1. Run `scripts/13-apply-project-standards.sh --repo /path/to/repo --profile <profile>`.
2. Review the generated `constitution.md`.
3. Delete the profile sections that do not apply.
4. Review any code-quality files the script skipped because the target repo
   already had them.
5. Add CI so the commands in the constitution are actually enforced.
6. Add a non-secret environment template and document the secret flow.

## Minimum Day-One Commands

For most repos, define these early:

- `lint`
- `format`
- `test`
- `build`

If the repo uses static typing checks beyond the normal build flow, also add:

- `typecheck`

For Markdown-only repositories, `lint` and `format:check` are the required
day-one commands; add the others only if the repository gains executable code.

## Suggested First Pass By Repo Type

### Next.js Or Vite Repo

- copy `constitution.md`
- merge the TypeScript files from `templates/code-quality/`
- add `vitest`
- add `playwright` for the first critical flow
- decide preview and production deployment early

### TypeScript Service Or Lambda Repo

- copy `constitution.md`
- keep the TypeScript service profile and remove the others
- merge the TypeScript files from `templates/code-quality/`
- add `vitest`
- add contract and integration coverage early
- document the AWS deploy and rollback path before first prod use

### Python Repo

- copy `constitution.md`
- merge `pyproject.toml` and `Makefile.python` guidance from
  `templates/code-quality/`
- add `pytest`
- keep the repo narrow and document why Python is the right fit

### Markdown-Only Repo

- use the `markdown` profile
- install the generated repo-local `pnpm` dependencies
- run `pnpm lint` and `pnpm format:check`
- add those commands to CI

### Mixed Repo

- keep one root `constitution.md`
- be explicit about which part deploys to Vercel and which part deploys to AWS
- define contract and integration tests across the boundary

## Related Docs

- `PROJECT-STANDARDS.md`
- `CODE-QUALITY.md`
- `PACKAGE-MANAGERS.md`
- `DEV-STACK.md`
