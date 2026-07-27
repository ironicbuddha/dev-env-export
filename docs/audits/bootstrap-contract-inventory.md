# Bootstrap Contract and Failure-Mode Inventory

Status: evidence inventory for
[Wayfinder task #26](https://github.com/ironicbuddha/dev-env-export/issues/26),
captured 2026-07-27.

## Scope

This audit describes the current observable contracts, side effects, external
dependencies, failure modes, recovery expectations, and test seams for the full
bootstrap. It is an input to the testing, logging, resilience, and idempotency
reviews in issues
[#27](https://github.com/ironicbuddha/dev-env-export/issues/27) through
[#30](https://github.com/ironicbuddha/dev-env-export/issues/30); it does not
select or implement improvements.

The evidence base is:

- current scripts and shared libraries under [`scripts/`](../../scripts);
- the contract suite under [`tests/`](../../tests);
- the completed fresh-machine acceptance recorded in
  [issue #20](https://github.com/ironicbuddha/dev-env-export/issues/20);
- the locally retained failed repeat run in
  `tmp/bootstrap-20260727-185607-4rB7Kg/`;
- a focused local reproduction of the existing-`uv`-environment failure.

The full `carlo-baseline` sequence is five common install steps, five
profile-specific steps, and two verification steps. The `shared` profile
substitutes the shared shell step for the five Carlo-specific steps.

## Top-Level Contract

[`scripts/00-bootstrap.sh`](../../scripts/00-bootstrap.sh) is the entry point.
It requires an explicit profile, admits only native Apple Silicon macOS, runs
steps in order, and stops on the first failed child or failed log pipeline.
Each invocation gets a unique durable log directory with:

- a combined bootstrap log;
- one log per started step;
- preflight and postflight environment snapshots;
- a tab-separated step-status ledger;
- a machine-readable summary.

The runner forwards the profile only to the package-install and verification
steps that consume it. Exit status `20` is reserved for the recoverable
Command Line Tools installation boundary; other failed steps currently collapse
to their shell exit status. Completion still requires documented human actions
for account authentication and other personal state.

## Twelve-Step Coverage Matrix

| Step | Observable contract and side effects | External dependencies and failure modes | Rerun and recovery expectation | Existing automated evidence |
| --- | --- | --- | --- | --- |
| `00-check-prerequisites.sh` | Requires native `arm64`, Command Line Tools selection, `xcrun`, and a runnable compiler before mutation starts. Initiates the Apple installer when CLT is absent. | Apple installer UI, `xcode-select`, `xcrun`, and `clang`; missing or broken CLT returns the manual-action exit, while Intel or Rosetta execution is rejected. | Rerun after the user completes CLT installation. No repo-owned state needs rollback. | Master-runner fixtures cover missing CLT, broken CLT, success ordering, Intel rejection, and Rosetta rejection. |
| `01-install-brew.sh` | Installs or loads Homebrew, optionally updates it, installs the formula manifest, and runs global Git LFS initialization. | Network, GitHub/Homebrew installer, taps, bottles, disk, and Homebrew state; direct package-manager failures abort. There is no retry or timeout policy at this layer. | Formula installation is delegated to Homebrew's convergence behavior. A partial package-manager run is expected to be resumed by rerunning the whole bootstrap. | Prerequisite coverage reaches the step boundary, but Homebrew install/update/formula behavior has no isolated contract fixture. |
| `02-install-cli-tools.sh` | Installs required formulae and profile casks, repairs registered-but-unlaunchable casks, installs the exact nvm-managed Node runtime, installs or validates Bun, normalizes conflicting user npm settings, and installs Oh My Zsh for `carlo-baseline`. | Homebrew, GitHub APIs/releases, `curl`, `jq`, `shasum`, `unzip`, nvm, npm, remote installers, app bundles, and vendor availability. Any required cask or remote-install failure aborts the whole step. | Already-installed formulae and valid apps are skipped. Broken registered casks are reinstalled. Bun downloads are staged and digest-checked. The `.npmrc` rewrite is a direct temporary-file move without the shared backup/symlink guard. | Unit fixtures cover app-bundle state, cask failure/repair, Bun source selection, digest verification, and exact Node ownership. There is no complete fake package-manager run or transient-network policy test. |
| `03-install-npm-globals.sh` | Reloads Homebrew and nvm, enforces Node `24.18.0`, removes conflicting npm prefix settings, installs missing global CLI packages, and enables Corepack. | nvm, exact Node availability, npm registry, package install lifecycle scripts, user `.npmrc`, and Corepack. Registry or install failure aborts. Presence checks do not enforce declared package versions. | Existing package names are skipped; a partial registry run is resumed by rerunning. The duplicated `.npmrc` rewrite has the same recovery limitations as step 02. | One end-to-end fixture proves first install then no-op rerun against a fake npm implementation. Version drift, partial installs, and `.npmrc` hazards are not covered. |
| `04-install-pip-packages.sh` | Uses Homebrew Python `3.14`, creates the managed environment at `~/.local/share/dev-env-bootstrap/python`, and installs declared packages through `uv`. | Homebrew Python, `uv`, package index/network, native build dependencies, and the managed environment directory. The unconditional `uv venv` command fails when that environment already exists. | The script currently handles a clean create only. It does not classify a valid existing environment, a partially created environment, or a corrupt environment before recreating it. Package presence checks do not enforce declared versions. | One fixture covers clean environment creation and package installation. It does not run the script twice. The 2026-07-27 repeat run and a focused real-`uv` reproduction prove the missing rerun contract. |
| `05-setup-dotfiles.sh` | `carlo-baseline` only. Preserves an existing `.gitconfig`, links managed dotfiles where safe, copies GitHub/Zed/Warp config, creates required directories, and writes validated managed zsh blocks atomically with backups. | User filesystem shape, symlinks, existing identities, zsh syntax, and destination permissions. Unsafe target types or invalid managed-block state abort instead of overwriting. | Existing user identity is preserved. Managed shell writes use backup, validation, and atomic replace. Safe reruns converge; foreign or malformed targets require human resolution. | Fixtures cover symlink creation, preserving existing files and Git identity, unsafe target refusal, and atomic shell-block failure recovery. The whole step is not exercised as one fixture. |
| `06-setup-claude.sh` | `carlo-baseline` only. Installs tracked Codex and Claude defaults, merges JSON where Python is available, installs commands/helpers, and updates managed shell state. | Python for JSON merges, user filesystem state, JSON validity, zsh syntax, and legacy config shapes. Some missing merge capability is warning-only. Legacy mutation paths and first writes do not all use one recovery-safe writer. | Shared file-safety and JSON helpers provide backup/atomic behavior on covered paths. Other copy or legacy-edit paths have distinct behavior, so recovery is path-specific rather than a single module contract. | JSON merge and file-safety helpers have focused tests. There is no full-step fixture covering clean, existing, malformed, symlinked, and interrupted Claude/Codex configurations. |
| `07-setup-1password.sh` | `carlo-baseline` only. Verifies the CLI boundary and reports account-sign-in state without writing credentials or copying authentication state. A missing desktop app is informational; a missing `op` CLI is fatal. | 1Password app/CLI installation, account configuration, and user authentication. Authentication remains explicitly manual. | Safe to rerun because it is primarily observational. Recovery is installation or human sign-in, not secret automation. | No direct step contract fixture. Secret non-copying is a documented boundary rather than an executable invariant. |
| `08-setup-gemini.sh` | `carlo-baseline` only. Requires the nvm-managed Gemini CLI, installs the tracked persona and settings defaults, merges existing JSON when possible, and migrates legacy agent metadata. | Exact Node/nvm state, Gemini package availability, Python for merges/migrations, JSON validity, filesystem shape, and legacy content. Some merge/migration inability is warning-only. | Existing settings are merged rather than replaced when the supported merge path is available. Legacy agent rewrites are direct in-place mutations and do not share the atomic backup interface. | A static contract asserts Gemini is installed through the nvm-managed npm path; shared JSON helpers are tested separately. No full clean/rerun/failure fixture exists. |
| `14-setup-skill-hub.sh` | `carlo-baseline` only. Acquires or fast-forwards a validated Skill Hub checkout and asks the Hub to own canonical cross-harness projections. It refuses dirty, invalid, symlinked, or unexpected checkouts. | GitHub/network, Git, the Hub repository, source/profile validity, and the Hub bootstrap script. Acquisition, update, or apply failures are intentionally warning-only so the wider machine bootstrap can continue. | New clones are staged before promotion. Existing checkouts require a clean expected repository and fast-forward-only update. Failed Hub work is retried independently on the next full run. | Seven fixtures cover clone retry, invalid-source preservation, projection success, already-valid projections, replacement, target conflicts, and missing source skills. |
| `10-check-paths.sh` | Resolves the selected profile's expected commands, exact runtime ownership, app bundles, managed Python, and Skill Hub projection; accumulates hard misses before exiting. | Login environment, Homebrew, nvm, app bundles, filesystem targets, and runtime resolvers. Missing Skill Hub projection is warning-only. Python resolution can fall back to Homebrew Python when the managed environment is absent. | Observational except that shared runtime loading may create the nvm directory. Failures direct the user back to the responsible setup step. | One fixture proves a required executable miss fails. Exact Node and app-bundle helpers are covered separately; the complete expectation matrix is not executed in a hermetic profile fixture. |
| `12-smoke-test.sh` | Runs command/version probes, app/config checks, Python module imports, exact runtime checks, and an interactive login-zsh probe. It deliberately excludes cloud authentication as a success condition. | All installed CLIs, dynamic loaders, managed Python packages, user shell startup, app bundles, and local config. Missing Skill Hub projection is informational. | Observational and intended to be safe on any repeat. Login-shell side effects originate in user/plugin startup code and are outside its recovery control. | One fixture proves the smoke test uses interactive zsh and does not make cloud calls. Runtime helpers have separate coverage; a complete clean-profile smoke fixture is absent. |

The alternative `shared` profile runs
[`15-setup-shared-shell.sh`](../../scripts/15-setup-shared-shell.sh) in place of
steps 05 through 14. It installs only shared managed shell state, using the same
validated atomic managed-block writer. Its failure-recovery path is covered by
the shared-shell atomicity fixture.

## Shared Module and Interface Seams

| Seam | Current contract | Consumers | Downstream questions |
| --- | --- | --- | --- |
| Run recorder | Unique directory, per-step logs, status ledger, snapshots, summary, child/tee exit capture, fail-fast ordering. | Entry point and every step. | Which data is needed to diagnose/restart safely; which values are sensitive; how archive/ZIP source revision is identified; how failure classes and resumability are represented. |
| Prerequisite adapter | Read-only native-platform and CLT gate plus one manual-action status. | Steps 00 and entry-point UX. | Whether all human-recoverable boundaries need distinct stable outcomes and tests. |
| Package-manager adapters | Direct calls to Homebrew, cask, npm, uv, Git, `curl`, and vendor installers, with per-script skip logic. | Steps 01–04 and 14. | Retry/timeout policy, transient versus permanent failure classification, partial-state inspection, and hermetic fakes at command boundaries. |
| Recovery-safe file writer | Refuse symlinks/non-files, back up, validate, stage, and atomically replace. | Strongest in steps 05 and 15; partial use in 06 and 08. | Which config writes must use one consistent interface; backup retention/collision behavior; interruption and malformed-input tests. |
| JSON merge | Recursive dictionaries, unique list append, incoming scalar override. | Claude/Codex and Gemini config. | Schema validity, transactional whole-step behavior, provenance of merged keys, and explicit behavior when Python or valid JSON is unavailable. |
| Runtime resolver | Loads Homebrew/nvm, enforces exact Node, prefers the managed Python environment, and can fall back to Homebrew Python. | Package steps and both verification steps. | Whether install verification should distinguish intended managed state from a usable fallback; whether observation should be side-effect-free. |
| Expectations registry | Central command, cask, bundle, runtime, and Python expectations by profile. | Install manifests and steps 10/12. | How to mechanically prove the installer and both verifiers agree on every required item and gating level. |
| Skill Hub adapter | Validated staged acquisition, safe existing-checkout rules, Hub-owned projection, and deliberately non-gating failure. | Step 14 and both verifiers. | Whether non-gating state is sufficiently visible and actionable without changing the established optional boundary. |

These are the useful module boundaries for the downstream reviews. The most
important shallow boundary is package orchestration: several large scripts
combine state inspection, network calls, mutation, and user-facing reporting,
which leaves no single independently testable contract for convergence or
failure classification. The strongest deep boundary is managed shell writing,
where validation, backup, and atomic replacement are already centralized.

## Run Evidence

### Fresh-machine success

Issue [#20](https://github.com/ironicbuddha/dev-env-export/issues/20)
records one clean Apple Silicon ZIP-first `carlo-baseline` run in which all 12
steps passed. It establishes the release acceptance contract, including the
manual authentication boundary. It does not establish repeat-run behavior.

### Repeat-run failure

The latest locally preserved run,
`tmp/bootstrap-20260727-185607-4rB7Kg/`, ran for 6,490 seconds. Steps 00
through 03 passed, including a 6,484-second CLI and app install step, and step
04 failed immediately:

```text
Caused by: A virtual environment already exists at:
/Users/carlo/.local/share/dev-env-bootstrap/python
```

A focused real-`uv` reproduction produced the same exit status `2` when
`uv venv --python <homebrew-python> <existing-managed-env>` was invoked for a
second time. The full contract suite nevertheless passes because
[`tests/uv_environment_contract_test.sh`](../../tests/uv_environment_contract_test.sh)
only models the clean creation path.

### Logging provenance

The failed run's environment snapshot records the source directory as
`/Users/carlo/dev/dev-env-export-main`, but contains no repository commit,
branch, archive digest, or release identifier. For a ZIP/non-Git checkout this
means the logs cannot independently identify the exact bootstrap source that
produced them. The status ledger does clearly identify the failing step and its
log, but the summary does not expose the child's distinct failure class beyond
exit status `1`.

### Current automated baseline

`/bin/bash tests/run.sh` passes:

- 9 master-bootstrap contract tests;
- 18 resilience contract tests;
- 1 npm-global rerun test;
- 1 clean-create `uv` environment test;
- 7 Skill Hub contract tests;
- the project-standards contract.

This baseline is valuable regression evidence, but it is not evidence that all
steps are convergent or that remote/package-manager failures are recoverable.

## Handoff to the Four Downstream Reviews

| Review | Concrete seams to inspect |
| --- | --- |
| Testing, issue #27 | Build a profile-to-step-to-expectation coverage map; distinguish static assertions, helper tests, full-step fixtures, entry-point fixtures, and real-machine acceptance; add missing repeat, partial-state, malformed-state, and failure-injection cases to the plan. |
| Logging, issue #28 | Evaluate source provenance, stable failure classification, restart guidance, long-step progress, redaction/privacy, package-manager command context, non-gating warning visibility, and correlation between summary, status ledger, and step logs. |
| Resilience, issue #29 | Inventory every remote and package-manager call; classify transient/permanent/manual failures; examine retry, timeout, staging, rollback, interruption, and optional-subsystem behavior while preserving the current secret and recovery-safe boundaries. |
| Idempotency, issue #30 | Define convergence for each side effect; test first run, immediate second run, version drift, partial creation, corrupt state, foreign state, and interrupted write; begin with the proven `uv venv` defect and duplicated `.npmrc` mutation. |

## Audit Limits

- This artifact records behavior and seams; it does not prescribe severity,
  priority, or implementation order.
- The fresh-machine success is acceptance evidence, while local fakes remain
  regression evidence rather than a substitute for that release gate.
- Authentication state, credentials, cloud profiles, master environment files,
  and personal identity remain outside automated transfer or repair.
- Skill Hub setup remains deliberately non-gating unless a later decision
  explicitly changes that product contract.
