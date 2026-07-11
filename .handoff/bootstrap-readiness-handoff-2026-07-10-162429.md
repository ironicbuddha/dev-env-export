# Bootstrap Readiness Handoff

## Metadata

- source_repo: `/Volumes/coding/dev/dev-env-export`
- created_at: `2026-07-10 16:24:29 SAST`
- branch: `feature/subset-dev-env-bootstrap`
- head: `143a5c9` (`Package agent direction in repo`)
- focus: Resolve the bootstrap readiness findings, then perform the first clean
  macOS-machine validation.

## Current Assessment

The Shared Baseline is suitable for a supervised fresh Apple Silicon macOS VM
test. Neither profile is ready for unattended acceptance reporting yet.

No fresh-machine run was performed in this session. The active profile work is
three commits ahead of `main`; see `git log main..HEAD` and
`docs/adr/0001-bootstrap-profiles.md` for the implementation history and
profile design.

## Findings To Address

1. `scripts/00-bootstrap.sh:481-489` exits with status `0` after the Xcode
   Command Line Tools manual-action condition. It reports the condition in the
   logs, but an external runner will see a successful bootstrap. Decide and
   implement a non-zero, documented manual-action exit contract.
2. `scripts/15-setup-shared-shell.sh:30-34` removes every following line when
   a managed-block begin marker lacks its end marker. Guard against malformed
   markers before rewriting user shell files.
3. `scripts/01-install-brew.sh:43-47` writes a Homebrew shellenv line, then
   `scripts/15-setup-shared-shell.sh:52-62` adds a second equivalent block on
   a fresh Shared Baseline. Consolidate ownership of this initialization.
4. `./scripts/run_markdownlint_repo.sh --check` fails with 36 errors in
   `reference/constitution.md`. This is already present on `main`, but it
   leaves the repo-level Markdown check red.
5. The current machine fails Carlo Baseline verification because `docker` is
   absent from `PATH`, although Homebrew reports the `docker` formula installed
   and Docker Desktop is present. `scripts/12-smoke-test.sh --profile
   carlo-baseline` fails only that command check. Resolve or explain this local
   linkage state before using the current machine as a Carlo acceptance
   baseline.

## Evidence Collected

- Clean working tree before this handoff; `git diff --check main...HEAD` and
  `bash -n scripts/*.sh scripts/lib/*.sh manifest/homebrew-packages.sh` pass.
- Profile aliases and invalid-profile rejection pass for bootstrap, package,
  path-check, and smoke-test scripts.
- Every formula and cask declared by `manifest/homebrew-packages.sh` currently
  resolves through Homebrew.
- `./scripts/10-check-paths.sh --profile shared-baseline` and
  `./scripts/12-smoke-test.sh --profile shared-baseline` pass on the current
  provisioned machine.
- Shared shell setup was verified idempotent with ordinary existing `.zprofile`
  and `.zshrc` content. A deliberately malformed begin marker reproduced the
  truncation risk above.
- Bootstrap log directories are ignored by `.gitignore`.

## Recommended Sequence

1. Fix and add focused shell-level coverage for the manual-action exit,
   malformed managed-block handling, and duplicate Homebrew initialization.
2. Decide whether the reference constitution must conform to the repository
   Markdown rule; fix it or explicitly exclude it from the documented gate.
3. Reconcile the current machine's Docker formula linkage and rerun Carlo
   path/smoke checks.
4. Create a clean Apple Silicon macOS VM, acquire the checkout through GitHub
   Desktop, and run the Shared Baseline first:

   ```bash
   DEV_ENV_TRACE_STEPS=1 \
   ./scripts/00-bootstrap.sh --profile shared-baseline
   ```

   Preserve the generated `logs/bootstrap-*` directory and record each manual
   prompt, installed version, and smoke-test result.
5. Only after Shared Baseline passes cleanly, run the Carlo Baseline on a
   separate disposable VM or an explicitly approved clean test account.

## Suggested Skills

- `tdd`: add focused regression coverage for shell behavior before changing the
  bootstrap scripts.
- `code-review`: review the implementation diff from `main` after remediation.
- `handoff`: refresh this record after the fresh-VM run with the log path and
  final verdict.

## Existing Context

`CONTEXT.md` still points to an older external handoff from before the profile
implementation. This handoff is intentionally repo-local under `.handoff/` as
requested by the current handoff skill. Do not treat the older handoff's claim
that no implementation exists as current.
