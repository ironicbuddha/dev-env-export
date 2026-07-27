# Bootstrap Testing Gaps and Verification-Seam Review

Status: resolution artifact for
[Identify bootstrap testing gaps and stronger verification seams](https://github.com/ironicbuddha/dev-env-export/issues/27),
captured 2026-07-27.

## Answer

The current suite is useful but uneven. It is strongest at the master runner's
logging/fail-fast interface, a handful of recovery-safe helpers, and Skill Hub
projection behavior. It is weakest where the expensive failures have actually
occurred: stateful package steps, full profile composition, installed-state
verification, and immediate repeat runs.

The green suite does not prove bootstrap convergence:

- the master runner executes stub children under `shared-baseline`, not the
  real install/configuration steps;
- the npm fixture executes one clean install, not a rerun;
- the `uv` fixture models only clean environment creation;
- no automated test executes the Claude, 1Password, or Gemini setup
  entrypoints;
- no automated test executes the smoke-test entrypoint;
- four resilience cases assert source text rather than behavior;
- there is no hosted CI workflow, so the suite is documented but not an
  automatic repository gate.

The testing plan should use each executable script's command-line contract as
the primary test surface, with stateful fake command adapters at the existing
`PATH` seam. Helper tests should remain only where they exercise behavior that
is meaningfully deeper than the entrypoint. Clean-machine acceptance remains a
separate release gate and must not be used to cover deterministic failure and
repeat-run cases that belong in fixtures.

## Evidence Classification

The current evidence falls into five distinct classes. They must be reported
separately because success in one class does not imply success in another.

| Evidence class | What it proves | Current examples | What it does not prove |
| --- | --- | --- | --- |
| Source-policy assertion | Particular text is present or absent. | zsh/cloud smoke policy, non-invasive shell/Node policy, Bun source, Gemini ownership. | That the script produces the intended behavior or error at runtime. |
| Helper behavior | A sourced shell function handles a focused input. | app bundles, cask state, JSON merge, digest, file safety, managed blocks, runtime activation, projection validation. | That an entrypoint calls the helper in the right order, propagates failure, or remains convergent. |
| Step behavior | A production step executable runs in an isolated home with fake external commands. | npm clean install, `uv` clean create, selected dotfiles/shared-shell/Skill Hub cases, one path-check failure. | Full orchestration, cross-step state, or real vendor behavior. |
| Orchestrator behavior | The public bootstrap entrypoint sequences controlled child adapters and records outcomes. | CLT/manual action, child/tee failure, log isolation, Intel/Rosetta rejection. | The real child implementations or `carlo-baseline` composition. |
| Machine acceptance | A public ZIP provisions a clean Apple Silicon machine. | Completed `carlo-baseline` acceptance in issue #20. | Deterministic fault handling, interruption recovery, repeat convergence, or `shared-baseline` acceptance. |

The README currently describes some source-policy assertions as if they prove
runtime smoke behavior. The plan should require test reports and documentation
to use the evidence classes above.

## Current Coverage Matrix

`Behavioral` means the production executable is invoked. `Helper` means only a
shared function is exercised. `Static` means the test greps source text.

| Area | Current coverage | Important missing or wrong-seam behavior | Required seam |
| --- | --- | --- | --- |
| Master entrypoint | Behavioral runner with stub steps: CLT missing/broken, success, child failure, tee failure, log isolation, durable default logs, Intel/Rosetta rejection. | Exact ordered step list for both profiles; profile aliases/missing/invalid input; exact `--profile` forwarding; Carlo-only versus shared-only exclusions; non-1 child status; interruption/signal outcome; postflight/summary integrity after every exit path. | Invoke `00-bootstrap.sh` with a controlled step adapter and assert its exit code, ordered calls, arguments, and complete run artifacts. |
| `00-check-prerequisites.sh` | Behavioral through the master and direct Intel check. | Direct usable/missing/broken/Rosetta matrix; installer command failure; exact manual-action output. | Direct executable test with Apple-tool stubs. |
| `01-install-brew.sh` | Direct Intel rejection plus static non-invasive policy. | Existing versus absent Homebrew; optional update; formula failure; Git LFS failure; partial install and immediate rerun; CLT manual-action propagation. | Direct executable with stateful `brew`, installer, Git, and prerequisite adapters. |
| `02-install-cli-tools.sh` | Helper cask behavior, runtime helper, app-bundle helper, digest helper, and static Bun policy. | Full profile inventories; formula/cask success and failure propagation; transient cask failure; nvm install/default activation; Bun fallback download/digest/extract; `.npmrc` mutation; Oh My Zsh; partial state; immediate rerun. | Direct executable with stateful Homebrew, nvm, npm, GitHub/curl, archive, and filesystem adapters. |
| `03-install-npm-globals.sh` | One behavioral `carlo-baseline` clean-install case. | The claimed rerun does not exist. Missing existing-package skip, `shared-baseline`, version drift, registry failure, partial install, Corepack failure, `.npmrc` safety, and immediate second run. | Direct executable with a stateful npm inventory and call log, run twice against the same isolated home. |
| `04-install-pip-packages.sh` | One behavioral `shared-baseline` clean-create case with every package missing. | Valid existing environment, proven second-run failure, Carlo package set, installed-package skip, wrong interpreter, partial/corrupt environment, package-install failure, version drift, and recovery. | Direct executable with a stateful `uv` adapter plus one focused real-`uv` regression at the same CLI seam. |
| `05-setup-dotfiles.sh` | Behavioral symlink refusal and Carlo file/identity preservation; helper atomic-write coverage. | Complete output inventory, valid no-op rerun, malformed/duplicate managed blocks, non-file targets, backup collision/retention, interruption at each mutation, copy failure, and zsh validation failure. | Direct executable over a filesystem-state table; assert observable files/backups and unchanged foreign state. |
| `06-setup-claude.sh` | JSON/file helpers only. | No entrypoint success, existing merge, missing Python, malformed JSON, legacy migration, unsafe target, partial write, interruption, or rerun coverage. | Direct executable over clean/existing/malformed/foreign homes with injected Python and filesystem failures. |
| `07-setup-1password.sh` | None. | CLI absent, app absent, signed out, signed in, account-query failure, rerun, and executable proof that no auth/credential state is written. | Direct executable with an `op` adapter and a before/after filesystem snapshot. |
| `08-setup-gemini.sh` | Static npm ownership plus shared JSON/file helpers. | No entrypoint success, CLI absence, merge/migration behavior, missing Python, malformed state, unsafe target, interruption, or rerun coverage. | Direct executable over clean/existing/malformed/foreign homes with fake Gemini/Python adapters. |
| `14-install-codex-skills.sh` | Strongest step coverage: valid checkout update/apply, user-managed path, dangling symlink, failed-clone retry; projection helper covers canonical/missing/broken harness links. | Dirty/wrong-origin checkout, fetch/fast-forward/apply failures, invalid staged clone, selected-skill completeness, immediate successful rerun, and explicit proof that non-gating failures remain visible. | Keep the entrypoint seam; make Git and Hub bootstrap adapters stateful and validate both exit status and retained state. |
| `15-setup-shared-shell.sh` | Behavioral injected pre-replace failure followed by success. | Immediate successful rerun/no duplicate blocks, malformed markers, zsh validation failure, non-file targets, and shared-profile composition through the master. | Direct executable filesystem-state table plus orchestrator profile test. |
| `10-check-paths.sh` | One behavioral required-command/app miss under a stubbed shared expectation set. | Valid-state success; both real profile expectation sets; exact Node/npm ownership; managed Python versus fallback; every app/config class; Skill Hub warning; one-required-item-at-a-time failures. | Execute the verifier against a generated installed-state fixture derived from the expectation interface. |
| `12-smoke-test.sh` | Static assertions for interactive zsh and absence of cloud-profile checks. | The entrypoint is never run by automation. Missing full success/failure matrices for both profiles, Python imports, runtime ownership, app/config checks, login-zsh failure, and optional Skill Hub behavior. | Execute the verifier with fake commands/apps/Python/zsh over the same generated installed-state fixture as the path check. |
| Shared helpers | Focused positive/negative cases for several helpers. | Profile normalization; Python resolver/fallback; file backup success/non-file refusal; malformed JSON; managed-marker duplication/syntax failure/rerun; full cask states; helper tests share one shell process and can leak functions/globals between cases. | Run each helper case in a fresh subprocess. Test through the helper interface only when it hides substantial behavior reused by multiple entrypoints. |
| Suite delivery | `/bin/bash tests/run.sh` performs syntax checks and all local contracts in about 30 seconds. | No `.github/workflows` gate, no fresh-process case isolation, no explicit test manifest/coverage report, and first failure stops the suite. | A hosted Apple Silicon-compatible macOS job runs the hermetic suite on every push; local and hosted commands stay identical. |

## Proven False-Negative Loop

The known step-04 failure has a deterministic red-capable loop:

```text
$ uv venv --python /opt/homebrew/opt/python@3.14/bin/python3.14 <new-path>
exit 0
$ uv venv --python /opt/homebrew/opt/python@3.14/bin/python3.14 <same-path>
exit 2: A virtual environment already exists
$ /bin/bash tests/uv_environment_contract_test.sh
exit 0
```

The production failure and the green test cross the same conceptual operation
but not the same state transition. The fixture's `uv` adapter always creates or
reuses the directory successfully, so it cannot go red on the user's exact
repeat-run symptom. This should be the first required red regression in the
implementation plan.

## Target Test Architecture

### 1. Stateful external-command adapters

Use the existing `PATH` seam as a real seam: production uses Homebrew, npm,
`uv`, Git, `curl`, nvm, zsh, and vendor tools; tests use executable adapters
with a small state directory and append-only call log. An adapter must support
scripted outcomes such as absent, present, partial, corrupt, fail-once, and
always-fail. Avoid one-off stubs whose behavior cannot change between the first
and second invocation.

This keeps the step's command-line interface small while hiding external tool
complexity behind test adapters. Do not expose helper internals merely for
tests.

### 2. Fresh-process fixture harness

Provide one harness that creates an isolated `HOME`, `PATH`, app directory,
runtime state, and call log, then invokes one production executable in a fresh
process. Each case asserts only:

- exit status and classified output;
- external calls and their order where contractually relevant;
- final filesystem/tool state;
- backups and untouched foreign state.

Cases must not inherit shell functions, arrays, or environment changes from
earlier cases.

### 3. Step contract tables

Drive each mutating step through the same state table:

1. clean success;
2. immediate second run;
3. already-correct state;
4. partial state;
5. malformed or foreign state;
6. dependency failure before mutation;
7. dependency failure after partial mutation;
8. interruption immediately before atomic promotion.

Not every row applies to observational steps, but every omission should be
explicit. Assertions about retry count, failure class, and recovery guidance
must wait for the logging and resilience reviews to settle those contracts.

### 4. Exact profile orchestration

The master-runner suite should assert the complete sequence and forwarded
arguments for canonical names and aliases:

- `carlo-baseline`: five common steps, five Carlo steps, two verifiers;
- `shared-baseline`: five common steps, shared shell, two verifiers;
- missing or invalid profiles: exit before any child;
- profile-specific steps never run under the other profile.

This is the correct seam for profile composition. Per-step tests should not
duplicate it.

### 5. Generated installed-state verification

Build one fixture model from the profile expectation interface and use it to
test both `10-check-paths.sh` and `12-smoke-test.sh`. For each profile:

- the complete valid state passes;
- removing each required command, app, config, runtime, or Python module fails
  with the responsible item;
- optional/non-gating state remains non-gating but visible;
- wrong Node ownership/version and missing managed Python are distinct;
- installer manifests and verifier expectations are checked as complete sets,
  not a hand-picked list of strings.

This prevents the installer and its two verifiers from drifting independently.

### 6. Separate policy lint from behavior

Source-text checks may remain as fast policy lint when the policy truly is
"this token must never appear." They must be named and reported separately.
Runtime claims about zsh startup, package ownership, destructive behavior, or
cloud access require executable tests at the relevant entrypoint.

### 7. Hosted regression gate

Run the same `/bin/bash tests/run.sh` command in hosted macOS CI on every push.
The hermetic suite must perform no network calls, read no real user
configuration, and write only under its temporary roots. A CI pass is
regression evidence, not clean-machine acceptance.

### 8. Clean-machine acceptance matrix

Keep acceptance outside the test suite and use fresh Apple Silicon snapshots
from the public GitHub ZIP:

- one fresh `shared-baseline` run on an uncontaminated snapshot;
- one fresh `carlo-baseline` run on a separate uncontaminated snapshot;
- an immediate second run of each profile on the same snapshot after first
  success;
- durable external logs and an exact source revision/archive identity;
- explicit manual authentication and optional-install boundaries;
- no credentials or personal auth state in the record.

Deterministic network, interruption, and corrupt-state scenarios belong in the
adapter suite, not in this expensive release gate.

## Priority and Plan Dependencies

| Priority | Required testing improvement | Why |
| --- | --- | --- |
| P0 | Add the red-capable step-04 existing-environment regression, then require it to pass with the eventual idempotency fix. | It is a reproduced user-visible failure that the suite currently misses. |
| P0 | Lock exact profile sequencing/argument forwarding and complete installer-to-verifier expectation consistency for both profiles. | A green stub run can currently omit or misroute profile-specific work. |
| P0 | Establish the stateful adapter/fresh-process harness and use it for steps 01–04 plus both verifiers. | These steps own the highest-cost remote/stateful behavior and the observed failures. |
| P0 | Add hosted macOS CI for the hermetic suite. | The repository currently has no automatic regression gate. |
| P1 | Cover configuration steps 05–08 and 15 across existing, foreign, malformed, interrupted, and repeat state. | These steps mutate user files and carry the strongest recovery-safety obligations. |
| P1 | Complete Skill Hub update/apply/failure and selected-projection cases. | Its non-gating behavior is intentional but must remain safe and observable. |
| P1 | Replace behavioral source-grep assertions with entrypoint tests and isolate helper cases by process. | Current wrong-seam tests can pass when behavior is broken or fail on harmless refactors. |
| P2 | Improve test reporting so evidence class, profile, step, and state transition are visible. | Clear reports make failures actionable without conflating policy lint, fixtures, and acceptance. |

The final implementation plan must sequence the harness before the broad step
matrix. Exact assertions for retries/failure classifications depend on the
logging and resilience reviews. Exact repeat-state outcomes depend on the
idempotency review. The acceptance-rerun procedure should be finalized only
after those three contracts are settled.

## Acceptance Criteria for the Improvement Plan

The testing portion of the final plan is implementation-ready only when it
requires all of the following:

1. Every full-bootstrap step and shared helper is mapped to its correct test
   seam and evidence class.
2. Both profile sequences, aliases, exclusions, and forwarded arguments are
   asserted exactly at the master interface.
3. Every required mutating step has clean, immediate-repeat, dependency-failure,
   and applicable partial/foreign/interrupted-state coverage.
4. The existing-`uv` failure is captured by a deterministic test that fails
   before the fix and passes after it.
5. The complete installed state passes both verifiers for both profiles, while
   removal of each required expectation produces a specific failure.
6. Static policy lint is not reported as executable behavior coverage.
7. Tests run in fresh processes with isolated homes and stateful adapters; they
   make no network calls and do not touch real user configuration.
8. Hosted macOS CI runs the same full suite used locally on every push.
9. Fresh-snapshot ZIP acceptance covers first and immediate second runs for
   both profiles, while preserving manual auth/secret boundaries.
10. Test and acceptance reports state exactly which evidence class passed, so a
    fixture pass cannot be presented as clean-machine acceptance.
