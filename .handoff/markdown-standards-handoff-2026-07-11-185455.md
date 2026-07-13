# Handoff: Markdown standards profile

## Current state

- Repository: `/Volumes/coding/dev/dev-env-export`
- Branch: `feature/subset-dev-env-bootstrap`
- Current commit: `8d20a46 added markdown repos to the project standards`
- The working tree was clean before this handoff file was created.

## Completed work

- Node 26.5 is the default nvm-managed runtime and Next.js apps use 16.2.10.
- `mole` is included in the default Homebrew formula manifest.
- `scripts/13-apply-project-standards.sh` supports a `markdown` profile.
- The Markdown profile creates or safely merges Markdown-only quality tooling:
  `.markdownlint.json`, Prettier config, and a package manifest containing
  `markdownlint-cli2` and Prettier commands.

## Key references

- Markdown profile implementation: `scripts/13-apply-project-standards.sh`
- Markdown-only package template: `templates/code-quality/package.markdown.json`
- Standards policy: `PROJECT-STANDARDS.md`, `CODE-QUALITY.md`, and
  `templates/project-standards/constitution.md`
- Homebrew formula manifest: `manifest/homebrew-packages.sh`
- Bootstrap readiness context: `.handoff/bootstrap-readiness-handoff-2026-07-10-162429.md`

## Validation completed

- `bash -n scripts/13-apply-project-standards.sh`
- JSON validation for `templates/code-quality/package.markdown.json`
- Fresh Markdown-profile application to a temporary repository.
- Markdown-profile merge into a temporary repository with an existing
  `package.json`, confirming existing entries were preserved.
- `git diff --check`.

`markdownlint-cli2` was not installed in this checkout, so targeted linting of
the edited Markdown files was not run.

## Suggested next steps

1. If further changes are needed, start from commit `8d20a46` and retain the
   separate Markdown-only package template rather than reusing the TypeScript
   quality bundle.
2. On a provisioned environment, run the generated profile against a real
   documentation repository, install dependencies with `pnpm`, then run
   `pnpm lint` and `pnpm format:check`.
3. For fresh-machine bootstrap work, continue with the existing readiness
   handoff referenced above.

## Suggested skills

- `apply-project-standards` for changing or applying starter profiles.
- `code-review` for a standards/spec review before extending the profile set.
- `handoff` when ending a further continuity-heavy maintenance session.
