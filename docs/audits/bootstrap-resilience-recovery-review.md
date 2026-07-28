# Bootstrap Resilience and Recovery Review

Status: resolution artifact for
[Assess bootstrap resilience and recovery behavior](https://github.com/ironicbuddha/dev-env-export/issues/29),
captured 2026-07-28.

## Answer

The bootstrap is fail-fast, retains useful per-run evidence, and already has
strong recovery-safe behavior at a few seams. It is not yet resilient as one
system. External operations are invoked directly, failure classes collapse to
shell statuses, there is no shared retry or deadline policy, concurrent runs
are not excluded, and interruption recovery depends on each script's incidental
behavior.

The improvement plan must not solve this with a generic command retry wrapper.
Retries are safe only when an operation is read-only, runs against disposable
staging, or has a state-aware adapter that can prove a second attempt will not
damage or erase valid state. The proven `uv` failure is the clearest warning:
the vendor suggests `--clear`, but applying that hint automatically would
replace a valid managed environment rather than recover it.

The plan should require four cooperating deep modules:

1. A run coordinator owns the single-run lock, signal handling, child-process
   lifecycle, and durable interrupted/incomplete state.
2. The run recorder defined by the
   [logging review](bootstrap-logging-diagnostic-review.md) owns structured
   events, attempts, progress, outcomes, and recovery guidance.
3. A small operation-policy module applies explicit retry, deadline, and
   interaction policies and returns stable classified outcomes.
4. State-aware adapters hide inspection, mutation, verification, and safe
   cleanup for Homebrew formulae and casks, nvm/npm, `uv`, Git/HTTP acquisition,
   and managed filesystem artifacts.

Callers should ask for a desired result such as an ensured cask, runtime,
Python environment, or Skill Hub checkout. They should not reproduce vendor
exit-code interpretation, partial-state detection, or retry loops.

## Diagnostic Feedback Loop

The focused real-`uv` loop is deterministic, agent-runnable, and exercises the
same command seam as step 04:

```console
$ repro_dir="$(mktemp -d "${TMPDIR:-/tmp}/dev-env-uv-rerun-repro.XXXXXX")"
$ uv venv --python /opt/homebrew/opt/python@3.14/bin/python3.14 "$repro_dir/env"
Creating virtual environment at: .../env
$ uv venv --python /opt/homebrew/opt/python@3.14/bin/python3.14 "$repro_dir/env"
error: Failed to create virtual environment
  Caused by: A virtual environment already exists at: .../env
$ echo $?
2
```

The first invocation exits `0`; the identical second invocation exits `2`.
The interpreter and target are unchanged, and the remaining difference is the
valid environment created by the first call. This minimizes the incident to an
unconditional create operation that cannot distinguish valid existing managed
state from failure state.

The current contract test still passes because its fake `uv` always accepts
creation:

```console
$ /bin/bash tests/uv_environment_contract_test.sh
ok 1 - document_stack_uses_bootstrap_owned_uv_environment
1..1
```

This is the first required red regression for the later implementation. This
review does not change the script or make a destructive `--clear` decision.
Valid, partial, corrupt, foreign, and version-drift dispositions belong to the
idempotency review.

## Evidence and Current Strengths

The review uses:

- the
  [bootstrap contract inventory](bootstrap-contract-inventory.md);
- the
  [testing and verification-seam review](bootstrap-testing-gap-review.md);
- the
  [logging and diagnostic review](bootstrap-logging-diagnostic-review.md);
- current scripts and shared libraries under [`scripts/`](../../scripts);
- the retained repeat-run artifacts under
  `tmp/bootstrap-20260727-185607-4rB7Kg/`;
- the earlier Affinity cask connection-reset evidence summarized in the
  contract inventory;
- the focused real-`uv` reproduction above.

Existing strengths to preserve are:

- native Apple Silicon and Command Line Tools checks happen before package
  mutation;
- every invocation has isolated durable logs and the runner stops after a
  failed required step;
- required casks are verified as usable application bundles and broken
  registrations have an explicit repair path;
- the Bun fallback stages downloads, requires a published digest, and validates
  the ZIP before installation;
- managed shell blocks validate syntax, back up the prior file, and promote a
  candidate atomically;
- the shared file writer refuses symlinks and non-files and uses same-directory
  staging for final promotion;
- new Skill Hub clones use disposable staging, existing checkouts require the
  expected origin and branch, and updates are fast-forward only;
- authentication, credentials, identity, cloud profiles, and secret material
  remain manual.

These are local strengths, not a complete recovery model. In particular, a
retained run spent 6,484 seconds in step 02 and then failed immediately at the
valid existing `uv` environment. The runner could identify the failed step but
could not classify the operation, state, safe recovery action, or whether the
long package step needed to run again.

## Failure and Recovery Inventory

| Area | Current exposure | Unsafe or stuck residue | Required recovery contract |
| --- | --- | --- | --- |
| Master runner | Only an `EXIT` trap; no active-run lock, explicit signal forwarding, or durable operation cursor. A child status normally becomes top-level exit `1`. | Concurrent invocations can mutate the same paths. `SIGKILL` or power loss can leave only an in-progress run with no final explanation. | Acquire one per-user run lock before mutation, atomically record current work before launch, forward `HUP`, `INT`, and `TERM` to the child process group, and preserve the signal-derived outcome. Recognize stale incomplete runs on the next invocation. |
| Xcode Command Line Tools | Missing or unusable tools return the distinct manual-action status `20`; the GUI installer is requested opportunistically. | The installer may already be open, cancelled, or leave a selected but unusable toolchain. | Keep this as manual action, never loop the GUI prompt, re-probe actual compiler usability, and provide the same-profile rerun command. |
| Homebrew bootstrap | Executes the current remote installer body and then checks only whether `brew` is discoverable. | Network interruption, installer prompt cancellation, partial prefix creation, permissions, or a changed upstream installer may leave ambiguous state. | Announce interaction before launch, record source identity, re-probe the prefix after failure, and never blindly retry a partially mutating installer. Stop with a manual or managed-state recovery action. |
| Formula installs and update | Direct `brew update` and `brew install`; no shared retry, deadline, or post-failure classification. | Download caches, locks, partial pours/builds, or one installed subset. | Use a Homebrew adapter that probes before and after each formula. Retry only a classified transient failure after the post-probe proves another install is safe. Do not roll back already valid formulae. |
| Cask installs and repairs | A connection reset aborts the profile. Registered but unusable apps are reinstalled. | Partial downloads, registered casks without usable bundles, permissions or `sudo` prompts, or a failed reinstall after old state changed. | Treat each cask as its own operation. Re-probe registration and bundle usability after failure, retry a transient fetch only when safe, identify interactive waits, and stop with the exact cask repair command when state is ambiguous. |
| Bun fallback | Metadata, archive, digest, and ZIP are staged, but the validated binary is installed directly at the final path. | An interruption during final copy can leave an executable-looking partial binary that a later `command -v bun` check accepts. | Stage the final executable on the destination filesystem, verify it there, promote atomically, and verify the installed binary before declaring success. Cleanup may remove only run-owned staging. |
| Remote shell installers | Homebrew and Oh My Zsh use fetched script bodies. They have no common source pin, timeout, or partial-state contract. | Upstream drift and partially mutated directories are not distinguishable from a clean absence. | Replace direct fetch-and-execute paths with an adapter that records an immutable source identity, stages where the vendor supports it, and probes post-state. No automatic retry after ambiguous mutation. |
| nvm and Node | `nvm install` is direct; exact activated Node is verified. The default alias failure is ignored. | A partially downloaded runtime, a valid runtime without the desired alias, or a failed activation. | Separate runtime installation, aliasing, and activation into classified operations. Verify exact ownership and version after each; retain a valid existing runtime and report alias failure rather than hiding it. |
| npm globals and Corepack | Each missing package is installed directly; registry, lifecycle, and shim failures abort. Existing package names are accepted without version checks. | Some packages may be valid while another is partial or failed; lifecycle scripts may leave tool-owned state. | Probe and verify each package independently. Retry registry transport failures only after an installed-state probe. Never repeat unknown lifecycle mutation generically. Preserve successful packages and name the exact failed package. |
| Managed Python environment | Step 04 always invokes `uv venv`, so a valid existing environment is fatal. Package installs have no post-failure environment classification. | Valid, partial, corrupt, wrong-interpreter, foreign, and permission-denied targets collapse into one create failure. | Give the environment adapter an ownership and health probe. Never execute `--clear` from vendor output. Preserve valid state; quarantine or recreate only a proven bootstrap-owned invalid target under the disposition selected by the idempotency review. |
| Package downloads and indexes | `curl`, Homebrew, npm, `uv`, Git, and vendor tools each use their own defaults. | DNS/TLS errors, resets, HTTP throttling, stalled streams, and upstream outages appear as unrelated shell failures. | Normalize failure classes and attempts around the vendor command while retaining raw output. Use explicit connect and progress deadlines and adapter-specific safe retry rules. |
| User configuration | The shared writer and shell writer are strong, but `.npmrc`, first JSON copies, legacy Claude path edits, and Gemini agent rewrites bypass the common interface. | Interrupted direct writes, cross-filesystem moves, unretained originals, and multi-file partial completion. Multiple writes to the same file can also overwrite the first backup within one run. | Route every user-file mutation through one recovery-safe writer: refuse foreign target types, stage beside the target, validate, create an immutable unique backup, promote atomically, and retain cleanup evidence. Do not attempt cross-file rollback. |
| Skill Hub | Clone staging and fast-forward-only updates are strong. All acquisition/application failures deliberately return overall success. | Dirty/wrong-origin state is preserved safely, but degraded capability can disappear from final outcome. Interrupted update/application state is only visible in raw output. | Preserve the non-gating product boundary, classify the warning, re-probe checkout and projection state, summarize the exact independent retry, and never replace foreign state. |
| Authentication and first-run work | Authentication is manual, and the bootstrap only observes limited status. | CLI checks may wait on desktop integration; a user may mistake unauthenticated state for a bootstrap failure. | Mark these operations interactive/manual, never retry or automate sign-in, never capture secret-bearing arguments or output, and keep them outside required machine convergence unless explicitly documented. |
| Verifiers | The path and smoke steps observe many tools after mutation. Some version commands and login-shell startup can invoke external or user code. | A verifier failure may be caused by installed state, shell side effects, or upstream behavior and currently looks like another required step failure. | Verifiers must remain non-mutating, classify the failed expectation and responsible setup adapter, and avoid hidden network/auth prompts. Recovery guidance points to the adapter or manual boundary, not a destructive fix. |

## Stable Failure Classes

The run recorder and operation-policy module should use a closed, testable
class vocabulary. Vendor messages and exit codes remain evidence, not the
contract.

| Class | Examples | Default recovery |
| --- | --- | --- |
| `transient_external` | DNS failure, connection reset, connect/progress timeout, HTTP `408`, `425`, `429`, or `5xx`, temporary registry or remote lock | Retry only under the operation's safe policy; otherwise rerun the named operation or profile. |
| `manual_action` | Command Line Tools UI, `sudo`/GUI prompt, authentication, license or first-launch requirement | Stop or wait explicitly; complete the human action, then re-probe and rerun. |
| `local_precondition` | Unsupported platform, missing prerequisite, permission denied, disk full, read-only destination | Do not retry. Correct the local condition, then rerun. |
| `managed_state_invalid` | Partial or corrupt bootstrap-owned environment, unusable app registration, invalid managed config | Stop after evidence-preserving inspection. Follow the adapter's explicit repair or quarantine action. |
| `foreign_state_conflict` | Symlink/non-file destination, dirty or wrong-origin checkout, unowned target | Never replace automatically. Ask the user to resolve or select another target. |
| `integrity_failure` | Missing/mismatched digest, malformed archive, source identity mismatch | Do not promote or execute. Remove only owned staging, retain safe evidence, and do not retry unchanged bytes blindly. |
| `interrupted` | `HUP`, `INT`, `TERM`, killed child, stale run with an unfinished operation | Stop new work, forward termination, retain state, and present the exact safe re-probe/rerun action. |
| `concurrent_run` | Another live bootstrap holds the per-user mutation lock | Do not start mutation. Point to the active run and wait or stop it manually. |
| `internal_failure` | Script invariant, recorder failure, missing step, pipeline/logging failure | Stop. Preserve the raw status and do not disguise the failure as an external retry case. |
| `optional_degraded` | Skill Hub acquisition/application failed after safe attempts | Continue only because the subsystem is explicitly non-gating; aggregate the warning and independent recovery action. |

Each event should also carry a stable, narrower code such as
`network_reset`, `http_rate_limited`, `disk_full`, `uv_environment_invalid`, or
`skill_hub_wrong_origin`. The class drives policy; the code drives precise
diagnosis and tests.

## Retry and Deadline Contract

There must be no repo-wide `retry "$@"` function. Every operation selects one
named policy, and every retry produces its own start/end event.

### Retry eligibility

- Read-only metadata probes and downloads into fresh run-owned staging may make
  three attempts total, with delays of 2 and 8 seconds.
- A staged clone or fetch may use the same policy. A failed clone retry starts
  from a new owned staging directory; it never edits the final destination.
- A package-manager mutation may make at most one automatic retry, and only
  after its adapter classifies the failure as transient and a post-failure
  probe proves the target is absent, valid, or otherwise safe for the same
  vendor command.
- Integrity failures, foreign conflicts, permissions, disk exhaustion,
  unsupported state, manual actions, authentication, and ambiguous partial
  mutations are never automatically retried.
- Optional operations use the same safety rules as required operations. Their
  final disposition differs; their mutation safety does not.
- An interrupted operation is never automatically restarted in the same
  process.

HTTP `408`, `425`, `429`, and `5xx` responses are retry candidates for
otherwise safe requests. Other `4xx` responses are permanent unless the
adapter names and tests an exception. A server `Retry-After` value takes
precedence when it is present and bounded by the operation policy.

### Deadline and progress policy

- Connection establishment for repo-owned HTTP requests has a 15-second
  deadline.
- Small metadata requests have a two-minute per-attempt wall-clock deadline.
- Artifact transfers use a two-minute no-progress deadline rather than one
  small global wall-clock limit; the adapter may set a larger documented value
  for a known large artifact.
- Noninteractive package operations emit raw progress and a structured
  heartbeat after five minutes without a completed sub-operation. After 20
  minutes without raw or structured progress, the coordinator terminates the
  child gracefully, waits 10 seconds, then force-terminates it if necessary.
- Explicitly interactive operations are marked `awaiting_user` and are exempt
  from the no-progress termination deadline while still recording elapsed
  time.
- There is no whole-bootstrap wall-clock timeout. Deadlines apply at the
  operation seam so a 12-step run cannot be killed while useful progress is
  occurring.

The 20-minute stall value is a starting implementation contract, not proof
that every vendor is safe to terminate at that point. Each stateful adapter
must prove its post-termination probe and recovery behavior in a fixture before
the hard deadline is enabled for that vendor.

## Interruption and Concurrent-Run Contract

The run coordinator must:

1. acquire a per-user mutation lock before the first mutating step;
2. store run id, process id, profile, source identity, and start time in that
   lock;
3. reject a second live run without performing setup work;
4. archive a stale lock only after proving its process is absent and linking it
   to the incomplete prior run;
5. atomically mark a step and operation `in_progress` before starting its child;
6. trap `HUP`, `INT`, and `TERM`, mark the run interrupted, forward the signal
   to the child process group, wait for it, and perform no further mutation;
7. preserve signal-derived status such as `130` or `143` instead of collapsing
   it to `1`;
8. leave a durable in-progress marker that a later invocation recognizes when
   `SIGKILL` or power loss prevents cleanup;
9. remove the active lock only after durable final state is written.

Recovery is forward-only by default. The bootstrap does not attempt to roll
back Homebrew, npm, `uv`, nvm, Git, or a group of configuration files as one
transaction. It may delete only staging paths created and proven owned by the
current operation before promotion. Existing backups, vendor caches, and
ambiguous partial state remain available for inspection.

The initial plan should continue to recommend rerunning the same Bootstrap
Profile after the named blocker is resolved. It must not add resume-by-skipping
until the idempotency review proves every skipped step's state probe and
dependency assumptions.

## Managed-State Recovery Rules

Every state-aware adapter should implement this internal lifecycle:

1. **Inspect** without mutation and classify absent, valid, invalid managed,
   foreign/conflicting, or unknown state.
2. **Act** only from states for which the desired transition is defined.
3. **Verify** the externally observable result, not merely the command status.
4. **Recover** by naming a safe retry, manual action, retained backup, or
   explicit stop. Recovery never executes an unreviewed vendor hint.

This lifecycle is internal to each adapter, not a large interface callers must
learn. The external interfaces should stay intent-level, such as:

- ensure a Homebrew formula or usable cask;
- ensure the exact nvm-owned runtime;
- ensure one global npm package;
- ensure the bootstrap-owned Python environment and package set;
- ensure the validated Skill Hub checkout and projection;
- install or merge one managed file safely.

Ownership is required for destructive repair. A path being under `$HOME` or
having the expected name is not ownership evidence. Suitable evidence includes
a bootstrap marker, a manifest recorded by the adapter, an exact expected
origin, or prior run state that proves the bootstrap created it. Unknown and
foreign state is preserved.

For user files and standalone binaries, the recovery-safe writer must:

- refuse symlink and non-regular targets unless a separately reviewed adapter
  owns that target type;
- create candidates on the destination filesystem;
- validate candidates before promotion;
- write immutable backups with unique per-run and per-mutation names;
- promote with an atomic rename;
- verify the promoted result;
- leave the original target intact on any pre-promotion failure;
- remove only run-owned temporary candidates;
- never prune backups automatically.

## Manual and Secret Boundary

Resilience work must not broaden bootstrap authority. The implementation plan
must continue to forbid:

- copying credentials, authentication state, cloud profiles, personal
  identity, a master `.env`, or 1Password item contents;
- automating `op signin`, GitHub, cloud, Codex, Claude, Gemini, or Google
  authentication;
- capturing secret-bearing arguments, environment values, or authentication
  output in traces or diagnostics;
- replacing foreign files, directories, symlinks, repositories, or skill
  projections;
- automatically running destructive suggestions such as `uv venv --clear`;
- deleting retained backups or logs as part of recovery.

Authentication and first-launch work is a manual completion boundary, not an
external failure eligible for retries.

## Priority and Plan Dependencies

| Priority | Required improvement | Why and dependency |
| --- | --- | --- |
| P0 | Establish the stable failure classes, codes, recovery dispositions, and operation event fields in the run recorder. | All retry, deadline, test, and user guidance depends on one vocabulary. Reconcile directly with the logging schema. |
| P0 | Add the single-run lock, durable operation cursor, explicit signal forwarding, and stale-incomplete-run recognition. | Prevents concurrent mutation and makes interruption distinguishable from ordinary failure. |
| P0 | Define and test the managed Python environment adapter, beginning with the red valid-existing-environment reproduction. | It is the current proven rerun blocker. Exact valid/partial/corrupt dispositions depend on the idempotency review. |
| P0 | Extend the recovery-safe writer to every user-config mutation and standalone binary promotion. | These mutations can damage user-owned state and cannot rely on package-manager convergence. |
| P1 | Add the operation-policy module and state-aware Homebrew/cask, nvm/npm, Git/HTTP, and Skill Hub adapters. | Enables bounded safe retries and precise recovery without exposing vendor complexity to step scripts. |
| P1 | Replace or isolate direct remote-script execution and record immutable source identity. | Current remote installer paths have ambiguous source and partial-state behavior. |
| P1 | Add operation-level progress, interaction notices, connect/progress deadlines, and warning aggregation. | Reconciles resilience with the logging review and prevents silent multi-hour stalls. |
| P1 | Make verification observational and map each failed expectation back to the responsible adapter or manual boundary. | Avoids network/auth surprises and destructive generic recovery advice. |
| P2 | Add explicit disk-capacity preflight and retained-staging size guidance. | Improves failure prevention without blocking the core recovery contracts. |

The final synthesis ticket can be created only after
[Assess bootstrap idempotency and repeat-run safety](https://github.com/ironicbuddha/dev-env-export/issues/30)
settles state convergence, version drift, valid reruns, and partial/corrupt
dispositions. That review should reuse the module seams and failure vocabulary
here rather than inventing a separate recovery model.

## Acceptance Criteria for the Improvement Plan

The resilience portion of the final plan is implementation-ready only when it
requires all of the following:

1. Every external or mutating operation selects a stable failure class/code,
   retry/deadline policy, gating level, and recovery disposition.
2. Retry tests cover fail-once success, always-fail exhaustion, non-retryable
   failure, post-failure state that forbids retry, and `Retry-After`.
3. Deadline tests cover connection timeout, stalled metadata, stalled artifact,
   long operation with continued progress, interactive waiting, graceful
   termination, and forced termination.
4. The runner rejects concurrent mutation, recognizes stale locks, preserves
   signal statuses, and identifies a run left incomplete by untrappable death.
5. The exact child process group is terminated on interruption and no later
   step starts.
6. State-aware adapters inspect before mutation and verify observable state
   afterward; raw command success alone is insufficient.
7. The `uv` suite deterministically covers valid existing, partial, corrupt,
   foreign, wrong-interpreter, package-install failure, and immediate second-run
   state without automatic clearing.
8. Homebrew formula/cask, nvm/npm, Git/HTTP, and Skill Hub fixtures cover
   transient, permanent, manual, integrity, permission, interrupted, and
   ambiguous partial-state paths applicable to each adapter.
9. All managed user-file and standalone-binary writes use same-filesystem
   staging, validation, immutable backup where applicable, atomic promotion,
   post-verification, and ownership-bounded cleanup.
10. Required failures stop the run; optional failures continue only under an
    explicit product decision and remain visible in the final degraded outcome.
11. Recovery output names the failed operation, completed and uncertain work,
    retained state, exact safe next action, same-profile rerun command, and
    relevant relative log.
12. No resilience path copies, repairs, retries, logs, or deletes identity,
    authentication, credential, secret, foreign, or unproven-owned state.
13. Both Bootstrap Profiles pass hermetic interruption, timeout, retry, and
    failure-classification fixtures.
14. A recorded clean Apple Silicon ZIP-first rerun proves the final recovery
    summary and retry behavior against real external tools. Local fixtures
    remain regression evidence, not a substitute for acceptance.

## Audit Limits

- This is a planning artifact. It does not implement retries, timeouts, state
  repair, or runner changes.
- The idempotency review owns exact repeat-state and version-drift
  dispositions. This review owns how failures are classified, stopped,
  surfaced, and recovered safely.
- Vendor-specific timeout values may be widened only with evidence and a
  corresponding fixture; they must not silently fall back to no policy.
- Package-manager rollback is deliberately excluded. Forward recovery and
  state verification are safer than pretending independent external systems
  form one transaction.
