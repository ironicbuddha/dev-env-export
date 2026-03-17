# Code Quality Starter

This starter bundle is the copy-and-merge baseline for new repos.

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
