# Code Quality Starter

This starter bundle is the copy-and-merge baseline for new repos.

For testing, deployment, security, and delivery guidance, pair it with
`templates/project-standards/constitution.md` or `PROJECT-STANDARDS.md`.

Use the files that match the repo you are creating:

- frontend or TS repo:
  - `.prettierrc.json`
  - `.prettierignore`
  - `.markdownlint.json`
  - `eslint.config.mjs`
  - `stylelint.config.mjs`
  - `package.quality.json`
- Python repo:
  - `.prettierrc.json` and `.markdownlint.json` if the repo has meaningful docs
  - `pyproject.toml`
  - `Makefile.python`
- Markdown-only repo:
  - `.prettierrc.json`
  - `.prettierignore`
  - `.markdownlint.json`
  - `package.markdown.json`
- mixed repo:
  - use both sets and merge them into the repo's real config files

## Install Guidance

### TypeScript Or Frontend Repo

Merge `package.quality.json` into the repo's real `package.json`, then install
the listed dev dependencies with the repo's package manager.

This bundle assumes `pnpm` for examples because that is the default for new
TS-heavy repos here.

### Python Repo

Merge the Ruff section from `pyproject.toml` into the repo's real
`pyproject.toml`.

If the repo uses `uv`, keep the provided `dependency-groups` entry. Otherwise,
add `ruff` to the repo's normal dev dependency mechanism and keep the
`[tool.ruff]` sections.

`Makefile.python` gives a minimal `lint`, `format`, and `format-check` path for
`uv`-first repos. Adjust it if the project uses Poetry, Hatch, or a different
runner.

### Markdown-Only Repo

Use `package.markdown.json` as the `package.json` starter, or merge it into an
existing `package.json`. It provides repo-local `prettier` and
`markdownlint-cli2` with `lint`, `lint:md`, `format`, and `format:check`
commands.
