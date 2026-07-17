# Audit bootstrap resilience, observability, and prerequisite order

Type: research
Status: resolved
Blocked by: None - can start immediately

## Question

Across the complete tracked codebase at `origin/main`, what concrete defects or
gaps weaken bootstrap resilience, robustness, and logging, and does the install
sequence enforce Xcode Command Line Tools early enough for every downstream
installation that relies on them?

## Comments

- Claimed in this task for a full structured review. The local `main` checkout
  is seven commits behind `origin/main`; remote-head inspection is therefore the
  canonical review surface.

## Answer

The audit reviewed all 121 tracked files at `origin/main` (`324bf14`) and
resolved with a **Not ready** verdict. The full rendered report and per-reviewer
artifacts are at
`/tmp/compound-engineering/ce-code-review/20260717-090229-a4fcd7fe/`.

Validated route, in priority order:

1. Remove the secret-printing 1Password verification example.
2. Move a usable Xcode Command Line Tools preflight ahead of Homebrew and lock
   the exit-20/manual-action contract with a shell failure-injection harness.
3. Create one profile-expectations source and one runtime-environment helper,
   then use them to close the cask, OpenSpec/PATH, Node-version, real-zsh, and
   broken-app-bundle false-green paths.
4. Protect user state by handling destination symlinks explicitly and replacing
   shell startup files through validated, backed-up, atomic writes.
5. Give every bootstrap invocation a unique artifact directory so logs,
   statuses, and summaries always describe one run.
6. Consolidate the duplicated JSON merge implementation and verify Bun fallback
   archives before installing them.

The report contains 15 stable findings: seven P1 and eight P2. Ten were
confirmed by independent per-finding validators and five by direct mechanical
verification. One generic mutable-installer hardening suggestion was rejected
by validation and excluded.

Verification completed: `/bin/bash -n` passed for all tracked shell and manifest
files in an exported `origin/main` tree. ShellCheck was not installed, and no
fresh macOS VM acceptance run was performed.

## Implementation Follow-Through

The remediation route was implemented on
`feature/bootstrap-prerequisite-run-contracts` in two slices:

1. Commit `52b5f5b` resolved findings #2, #8, and #9 with the prerequisite
   gate, exit-20 contract, unique run artifacts, and bootstrap failure harness.
2. The follow-through resolves findings #1, #3-#7, and #10-#15 with shared
   profile/runtime helpers, gating casks and path checks, exact Node and real
   zsh verification, launchable app-bundle checks, symlink-safe and atomic
   user-file writes, one JSON merge helper, and verified Bun fallback assets.

Final local verification:

- `/bin/bash tests/run.sh` passed 17 contract tests: 6 bootstrap contracts and
  11 resilience contracts.
- `/bin/bash -n` passed for all shell, manifest, and test scripts.
- `zsh -n` passed for the tracked `shell/zprofile` and `shell/zshrc`.
- Markdown lint passed for every changed or newly tracked Markdown artifact.
- The repository-wide Markdown check remains blocked by 36 pre-existing issues
  in untouched `reference/constitution.md`.

A clean macOS machine or Parallels VM acceptance bootstrap is still required;
that environment-level check remains outside this implementation task.
