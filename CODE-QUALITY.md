# Code Quality Baseline

This file defines the default linting and formatting baseline new repos should
start with.

The goal is not to install every possible checker on every machine. The goal is
to make new repos start with boring, reliable quality tooling from day one.

Starter files live in `templates/code-quality/`. Copy or merge from that
directory when bootstrapping a new repo.

## Default Baseline

For the current stack, the default repo-level tools are:

- Markdown: `prettier` + `markdownlint-cli2`
- TypeScript and TSX: `prettier` + `eslint`
- CSS: `prettier` + `stylelint`
- Python: `ruff`

## Tool Roles

- `prettier`
  Format Markdown, CSS, and TypeScript-family files consistently.
- `markdownlint-cli2`
  Catch Markdown structure issues that Prettier will not fix.
- `eslint`
  Lint TypeScript and TSX code.
- `stylelint`
  Lint plain CSS and CSS-adjacent styling rules.
- `ruff`
  Handle both linting and formatting for Python.

## Repo-Level Policy

- Prefer repo-local installs and config, not global machine installs.
- Every new repo should define lint and format commands up front.
- Keep the baseline small enough that people will actually run it.
- Add framework-specific rules only after the baseline is in place.

## Practical Defaults

### New TypeScript Or Frontend Repo

Start with:

- `prettier`
- `markdownlint-cli2`
- `eslint`
- `stylelint`

Typical commands:

- `lint`
- `lint:md`
- `lint:ts`
- `lint:css`
- `format`
- `format:check`

### New Python Repo

Start with:

- `ruff`
- `markdownlint-cli2` if the repo has meaningful Markdown docs
- `prettier` if the repo includes frontend assets or shared Markdown formatting

Typical commands:

- `lint`
- `format`
- `format:check`

### Mixed Repo

Use the combined baseline:

- `prettier`
- `markdownlint-cli2`
- `eslint`
- `stylelint`
- `ruff`

## Package Manager Guidance

- In new TS-heavy repos, install the JS tooling with the repo's chosen package
  manager, usually `pnpm`.
- In Python repos, prefer `ruff` through project-local config and normal project
  tooling. `uv` is a good default when the repo already uses it.
- Do not treat these as machine bootstrap dependencies unless a specific CLI
  proves it needs to be global.

## Short Version

If you start a new repo and do nothing else, start here:

1. `prettier`
2. `markdownlint-cli2`
3. `eslint`
4. `stylelint`
5. `ruff`
