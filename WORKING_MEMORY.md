# Working Memory

Last updated: 2026-03-18

## Current State

- The repo is aligned around a macOS / Parallels bootstrap flow with Homebrew,
  `nvm`, Warp, Zed, Codex, Claude, Gemini, GSD v2, Docker Desktop, and
  1Password.
- The primary fresh-machine entrypoint is `./scripts/00-bootstrap.sh`.
- The worktree is currently clean on `main`.
- `origin/main` is at commit `fbdd4b4` (`Improve bootstrap logging diagnostics`).

## What Landed Recently

### `f7dcc54` Adopt GSD v2 baseline and track env template

- The repo now treats GSD v2 (`gsd` via `gsd-pi`) as the primary GSD path.
- Bootstrap and verification scripts were updated to install and check `gsd`.
- The tracked shell config now removes the oh-my-zsh git-plugin `gsd` alias so
  the CLI resolves correctly.
- The 1Password example env template is tracked under
  `onepassword/examples/project.env.tpl`.
- The tracked Codex defaults were synced to the current portable baseline,
  including `model_reasoning_effort = "xhigh"`.

### `fbdd4b4` Improve bootstrap logging diagnostics

- `scripts/00-bootstrap.sh` now writes:
  - `bootstrap.log`
  - `environment.txt`
  - `step-status.tsv`
  - `summary.txt`
  - one log file per step
- The bootstrap wrapper now records richer preflight and postflight machine
  context, per-step timing, exit codes, and clearer outcome summaries.
- Optional trace mode exists via `DEV_ENV_TRACE_STEPS=1`.
- `README.md` documents the richer logging artifacts and trace mode.

## Verification Snapshot

- `bash -n` passed for the primary bootstrap scripts after the logging changes.
- The bootstrap wrapper was exercised in temp harnesses for:
  - a full success path
  - the Xcode Command Line Tools manual-action path (`exit 20`)
- `markdownlint-cli2` passed across tracked Markdown files when the logging
  docs were finalized.
- Earlier repo baseline checks on the current machine also passed:
  - `./scripts/09-inventory-ai-tooling.sh`
  - `./scripts/10-check-paths.sh`
  - `./scripts/12-smoke-test.sh`

## Important Notes

- The repo-level docs (`README.md`, `AGENTS.md`, and `CONTEXT.md`) are aligned
  with the current macOS / GSD v2 direction.
- The main remaining validation gap is a real fresh-VM bootstrap run after the
  logging improvements.
- Exhaustive logging lives in `scripts/00-bootstrap.sh`; direct standalone runs
  of steps `01` through `08` are still less useful for postmortems.

## Next Recommended Action

- On the fresh VM, run:

```bash
DEV_ENV_TRACE_STEPS=1 ./scripts/00-bootstrap.sh
```

- If Xcode Command Line Tools interrupts the flow, finish that install, rerun
  the bootstrap, and keep the resulting `logs/bootstrap-*` directory if
  anything goes sideways.
