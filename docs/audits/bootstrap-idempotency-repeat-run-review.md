# Bootstrap Idempotency and Repeat-Run Safety Review

Status: resolution artifact for
[Assess bootstrap idempotency and repeat-run safety](https://github.com/ironicbuddha/dev-env-export/issues/30),
captured 2026-07-28.

## Answer

The bootstrap is not yet convergent as a whole. Its strongest paths already
have the right shape: managed shell blocks replace one validated marker region,
recovery-safe copies compare before writing, Homebrew formulae and usable casks
are skipped, exact nvm-owned Node is activated, and new Skill Hub checkouts are
staged before promotion. Those paths should be retained and deepened.

The proven blocker is step 04. It always invokes `uv venv`, so an identical
second run fails against the valid environment created by the first. Both
Bootstrap Profiles share this failure. The next most serious defect is the
duplicated `.npmrc` rewrite in steps 02 and 03: it mutates a user-owned file
without the shared backup and target-type checks, follows a symlink while
reading, then can replace that symlink with a regular file.

The improvement plan must define convergence at state-aware adapter seams, not
as "rerun the same shell command." Each adapter must inspect ownership and
health, select one reviewed transition, verify the observable result, and
return a stable disposition. Immediate reruns against unchanged desired inputs
must succeed with no semantic change, no new backups, and no destructive
cleanup. Version changes must occur only under an explicit declared policy,
not because a presence probe happened to contact a newer upstream.

This review settles the repeat-state and ownership rules required by the final
plan. It does not implement them.

## Diagnostic Feedback Loop

The focused real-`uv` command remains a tight, deterministic, agent-runnable
signal for the exact repeat-run failure:

```console
$ uv venv --python /opt/homebrew/opt/python@3.14/bin/python3.14 \
    <valid-existing-managed-environment>
error: Failed to create virtual environment
  Caused by: A virtual environment already exists at: \
  <valid-existing-managed-environment>
$ echo $?
2
```

It was rerun during this review against the retained disposable reproduction
and again exited `2`. The interpreter, target, and desired package set had not
changed. The only changed input was that the first successful invocation had
created a valid environment.

The current fixture still exits `0` because its fake `uv` accepts every create
request. The later implementation must first make that fixture stateful and
red-capable; this planning review must not hide the defect by adding
`uv venv --clear`.

## Convergence Vocabulary

Every mutating adapter must classify current state before acting. These states
are shared across package, runtime, checkout, projection, and filesystem
adapters:

| State | Meaning | Required disposition |
| --- | --- | --- |
| `absent` | No target or registration exists. | Create from validated inputs, record ownership where the bootstrap may later repair it, verify, and return `changed`. |
| `valid_exact` | Bootstrap-managed state exactly matches the declared desired state. | Do not mutate, download, back up, or create staging; verify cheaply and return `satisfied`. |
| `valid_compatible` | Usable state satisfies an explicit capability or range policy but is not byte-for-byte or version-exact. | Preserve it and return `satisfied_compatible`; never silently claim ownership. |
| `managed_version_drift` | A bootstrap-owned target is healthy but differs from an explicit exact or range requirement. | Apply only the declared upgrade, downgrade, or retain policy, verify, and report the version transition. |
| `managed_invalid` | Ownership is proven, but state is partial, corrupt, unusable, or uses the wrong required runtime. | Preserve evidence; quarantine and rebuild only when the adapter's reviewed contract proves that action safe. Otherwise stop with `managed_state_invalid`. |
| `foreign_conflict` | State exists but is user-owned, symlinked, the wrong target type, wrong origin, dirty, or otherwise outside bootstrap authority. | Preserve it unchanged and stop required work, or report an explicit optional degradation. Never replace, merge, delete, or adopt it silently. |
| `unknown` | Inspection cannot establish health or ownership. | Preserve and stop. Unknown state never inherits the repair rights of managed state. |
| `interrupted` | A prior operation has an unfinished durable cursor or owned staging. | Reinspect and reclassify the final target. Remove only proven run-owned staging; never resume mutation from the cursor alone. |

`interrupted` is an observation about the prior run, not permission to repair.
After inspection, the target must become one of the other states before any
new action.

The run recorder should use the changed/no-change/conflict dispositions above
alongside the stable failure classes from the
[resilience review](bootstrap-resilience-recovery-review.md). Vendor messages
and exit codes remain evidence rather than state classifications.

## Global Repeat-Run Invariants

The final plan must require these invariants across both Bootstrap Profiles:

1. An immediate second run from the same bootstrap source, profile, declared
   versions, and selected Skill Hub profile exits successfully.
2. That second run performs no semantic mutation, creates no backup, leaves no
   staging, and reports each managed target as `satisfied` or
   `satisfied_compatible`.
3. The desired state is closed over explicit inputs: source identity, profile,
   package requirement policy, runtime versions, configuration content, and
   selected Skill Hub source/profile. A moving upstream is not an implicit
   desired-state change.
4. Every mutating operation has one owner-aware inspect/act/verify adapter.
   Step scripts call intent-level interfaces and do not duplicate state tests
   or direct repair logic.
5. A command returning success is insufficient. The adapter verifies the
   externally observable target, version or capability, ownership, and target
   type before reporting success.
6. Package managers may retain valid work completed before a later failure.
   Recovery is forward-only; the bootstrap does not pretend independent
   package systems or user files are one rollback transaction.
7. Only proven run-owned staging may be removed automatically. Backups, logs,
   caches, user state, foreign state, and ambiguous partial state are retained.
8. Repeated failure does not widen authority. No rerun copies credentials,
   authentication, cloud profiles, Git identity, a master `.env`, or personal
   configuration outside the selected profile.
9. Verification steps are observational. They must not create `~/.nvm`,
   download shims, update package metadata, invoke authentication, or mutate
   login-shell state while checking it.
10. A rerun uses the same complete profile sequence. Resume-by-skipping remains
    out of scope until every skipped step and dependency has a proven state
    probe; this review does not authorize it.

## Ownership Model

Repair authority must come from evidence, not path location.

| Ownership class | Examples | Allowed behavior |
| --- | --- | --- |
| Bootstrap-owned | Managed Python environment with a validated ownership manifest; run-owned staging; a checkout recorded as acquired by this bootstrap. | Enforce its declared exact or compatible state; quarantine invalid state only under the adapter's tested repair contract. |
| Co-managed | Marker-delimited zsh blocks; recursively merged Claude/Gemini JSON; `.npmrc` with only the incompatible keys owned by the bootstrap. | Change only the declared region or keys, preserve surrounding user content, and retain an immutable pre-mutation backup. |
| User-owned | Git identity; credentials and authentication; unmarked config content; existing repositories and symlinks; cloud profiles. | Observe or preserve. Never overwrite or infer permission from a familiar path. |
| Vendor-managed | Homebrew formula/cask records, nvm runtimes, npm packages, Corepack shims. | Use the vendor adapter to inspect and converge supported state; do not delete vendor state or caches outside that contract. |
| Compatible foreign | A usable pre-existing Bun, cask app bundle, or other capability satisfying a declared presence policy without bootstrap ownership. | Accept as `satisfied_compatible` where the policy permits; do not upgrade, repair, or relabel it as managed. |

Allowlisted Carlo configuration destinations may be adopted on first write only
through the existing product contract: preserve the regular file in a unique
immutable backup, validate and atomically promote the repo candidate, then
record that the destination is managed. Symlink and non-regular targets are
always foreign conflicts. Shared Baseline never adopts Carlo configuration.

## Version-Drift Contract

Every package declaration must state one of three policies. A bare name cannot
silently mean whichever policy a caller assumes:

- `present`: any usable installed version satisfies the declaration; ordinary
  reruns do not upgrade it;
- `range`: a declared semantic range satisfies; drift outside it is a managed
  transition with an explicit upgrade or retain decision;
- `exact`: only the declared version satisfies; install, activation, and
  verification must all agree.

The current improvement plan should preserve these product decisions:

- Node is `exact` at `24.18.0`; other installed Node versions may coexist, but
  the default alias and active runtime must both resolve to the exact
  nvm-owned version.
- Current unversioned Homebrew formulae, casks, npm globals, and Python package
  declarations are `present`. Normal reruns do not run opportunistic upgrades.
  An explicit refresh mode may update a package only through the same
  inspect/verify adapter and must report the before/after versions.
- Homebrew metadata refresh remains explicit through
  `DEV_ENV_REFRESH_BREW=1`; it is not part of ordinary convergence.
- Skill Hub remote advancement is version drift, not a no-op rerun. A normal
  rerun preserves the validated current checkout and reapplies/verifies the
  selected profile without fetching a newer revision. An explicit refresh
  may fast-forward a proven bootstrap-owned, clean default-branch checkout and
  must record the before/after commits.
- Repo-managed configuration is exact for fully managed files and
  key/region-exact for co-managed files. Source-content changes produce one
  backed-up transition; an immediate rerun creates no further backup.

If a future source revision needs stricter package reproducibility, it must
change the declaration to `range` or `exact` rather than reinterpret a
historical `present` declaration.

## Side-Effect Disposition Matrix

| Area | Valid or absent state | Partial, corrupt, or drifted state | Foreign or interrupted state | Required repeat invariant |
| --- | --- | --- | --- | --- |
| Durable run artifacts | Every invocation creates a new private run directory; prior logs remain immutable. | An unfinished prior run stays marked incomplete and linked from the new run. | A foreign log directory or permission conflict stops before mutation. | A rerun creates only its own diagnostic artifacts; it never rewrites or prunes earlier evidence. |
| Command Line Tools | A usable selected compiler is a no-op; absence remains `manual_action`. | Selected-but-unusable remains manual/local repair, not an installer loop. | GUI/install state is never inferred or deleted. | Re-probe compiler usability once and never repeat the GUI request blindly. |
| Homebrew installation | A runnable expected Homebrew is compatible; absence invokes one source-identified install. | A partial prefix is inspected after failure and left for an explicit vendor/manual recovery decision. | Unexpected prefix, target type, permissions, or ownership is preserved. | Ordinary reruns do not reinstall or update Homebrew. |
| Formulae | Installed usable formulae satisfy current `present` declarations; absent items install independently. | Retain valid earlier installs; classify the failed formula after a post-probe. Explicit refresh owns version transitions. | Ambiguous vendor state stops that required operation without rollback. | The same manifest rerun makes no install calls for satisfied formulae. |
| Casks and app bundles | A usable registered cask or compatible app bundle satisfies; absence installs. | Reinstall only when Homebrew registration proves vendor ownership and the app bundle is unusable; verify afterward. | Unregistered or unproven unusable bundles are preserved as conflicts. | A valid app causes no reinstall; one failed cask does not erase valid prior apps. |
| Bun fallback | A usable foreign Bun may satisfy `present`; a bootstrap-owned exact installed binary verifies as valid. | Invalid bootstrap-owned binary may be quarantined only with ownership evidence; install uses same-filesystem staging and atomic promotion. | Unknown or symlinked final targets are preserved. Interrupted temporary files are removed only when run-owned. | `command -v` alone is insufficient to grant overwrite or repair rights. |
| Oh My Zsh | A usable expected installation is compatible; absence may run the declared installer. | Partial bootstrap-owned install stops for inspected recovery; no blind second remote installer execution. | Pre-existing unknown directory is preserved and reported. | A valid directory causes no network request; source refresh is explicit. |
| nvm and Node | Exact nvm-owned Node plus exact default alias is satisfied; absence installs the exact runtime and alias. | Valid runtime with wrong alias repairs only the alias; corrupt managed runtime stops for adapter recovery. | Non-nvm active Node is preserved but cannot satisfy the required runtime. Unknown `$NVM_DIR` is not adopted destructively. | Both profile reruns activate and verify exact Node without reinstalling it. |
| npm globals and Corepack | Each declared package and required shim is independently probed; absent state installs/enables only that item. | Presence-only packages retain valid versions; failed lifecycle state is re-probed before any retry. Broken shims are repaired only through Corepack ownership. | Foreign globals or shims are not deleted. Ambiguous lifecycle residue stops automatic retry. | A partial first run resumes at missing items; valid packages are not reinstalled. |
| Managed Python environment | Absence creates an ownership-marked environment with the required interpreter and manifest; a healthy owned environment is reused. | Wrong-interpreter, partial, or corrupt owned state is quarantined and rebuilt only after evidence-preserving classification. Package drift follows each declaration policy. | A pre-existing unmarked environment, symlink, non-directory, or unknown target is preserved as a conflict. Interrupted owned staging is disposable; the final target is reinspected. | Both profiles accept a valid existing environment, install only missing/out-of-policy packages, and never invoke `--clear`. |
| Managed shell blocks | Absent markers are inserted; one valid exact block is a no-op. | Duplicate, nested, or unbalanced markers are a managed-state conflict requiring human resolution. | Symlink/non-file targets are preserved. Candidate files are same-filesystem and disposable before promotion. | Repeated runs leave surrounding user text byte-stable and create no backup when the candidate is unchanged. |
| Fully managed config files | Absent allowlisted files are created; exact files are no-ops. A changed source replaces an adopted/managed regular file with one immutable backup. | Invalid candidates never promote. Existing managed drift is replaced only after backup and validation. | Symlink/non-file destinations are preserved. Interrupted candidates are removed only when run-owned. | Backup names are unique by run and mutation; no backup is overwritten by another path or same-second run. |
| Merged JSON/TOML config | Missing destinations use the recovery-safe writer. Existing valid documents merge deterministically while preserving user-owned keys outside the declared overlay. | Malformed source is internal failure; malformed destination is preserved as conflict. Missing merge runtime leaves a visible degraded/required outcome rather than false success. | Symlink/non-file state is preserved. Cross-filesystem temporary output is forbidden. | Merge output is schema-valid and stable; the second merge is byte-identical and creates no backup. |
| Legacy config migrations | A file without the legacy pattern is a no-op. A matched regular file is migrated from a validated candidate with an immutable backup. | Malformed input is preserved and reported per file; one failure cannot erase earlier backups. | Symlink, non-file, or unproven path is preserved. Interrupted direct in-place writes are forbidden. | Migrations carry a version/id so they run once and remain observable without repeatedly rewriting files. |
| Git identity and secrets | Existing or absent personal state remains outside automatic convergence. | Missing auth is manual completion, not managed drift. | All credentials, auth state, cloud profiles, and identities are foreign to bootstrap repair. | A rerun neither creates nor changes secret- or identity-bearing state. |
| Skill Hub checkout | Absent state clones into staging, validates, promotes, and records ownership. A valid current checkout is reused. | Explicit refresh may fast-forward a clean owned checkout; dirty, divergent, wrong-branch, or invalid state is preserved and degraded. | Unmarked, wrong-origin, symlinked, or otherwise user-managed paths are preserved. Interrupted clone staging is disposable only when owned. | Normal reruns do not fetch moving upstream state and never replace an existing checkout. |
| Skill Hub projection | The canonical real agents directory and Claude/Codex directory symlinks must resolve to readable selected skills. Exact projection is a no-op. | Missing/broken bootstrap-owned links or managed selected entries may be repaired by the Hub profile, then fully reverified. | Real directories, symlinks to foreign targets, and unproven entries are preserved and reported as optional degradation. | Reapplying one selection produces the exact managed projection without nesting links or copying editable skill trees. |
| Path and smoke verifiers | Read-only probes return satisfied, required failure, or visible optional degradation. | A failed expectation names the responsible setup adapter or manual boundary. | User/plugin shell side effects are reported, not repaired. | Verification creates no directories, files, aliases, shims, package metadata, auth state, or network mutation. |

## Managed Python Environment Contract

The managed environment adapter is the first implementation slice after the
shared test harness because it owns the current red failure.

Its small external interface should express intent: ensure the
bootstrap-owned Python environment and declared package set. Internally it
must:

1. Inspect the target type without following a symlink.
2. Require an ownership manifest before destructive repair. The manifest
   records schema version, environment path, creating bootstrap source/run,
   interpreter identity/version, and last applied package requirements.
3. Validate `pyvenv.cfg`, the environment Python executable, interpreter
   version/identity, `uv` usability, and the declared packages.
4. Reuse `valid_exact` and `valid_compatible` state without invoking
   `uv venv`.
5. Install only missing or out-of-policy packages and verify imports/package
   metadata afterward.
6. Treat an unmarked existing environment as foreign even when it occupies the
   default path. Offer a different managed path or a precise manual adoption
   decision; never clear it.
7. Quarantine an invalid owned environment with a unique retained name before
   creating and validating a replacement. Promotion and manifest writes must
   be atomic on the destination filesystem.
8. If package installation fails, retain the owned environment, reclassify its
   health, name installed/missing/uncertain packages, and resume forward on the
   next run.

Changing the Homebrew Python patch version within the declared Python `3.14`
line is `valid_compatible` only if the environment's interpreter is runnable
and the package set verifies. A change outside the declared interpreter policy
is `managed_version_drift`; it must not trigger an unrecorded destructive
recreation.

## `.npmrc` Contract

Steps 02 and 03 currently contain separate copies of
`strip_npmrc_conflicts`. The final plan must replace both with one co-managed
file adapter invoked through one intent-level interface:
ensure nvm-compatible npm configuration.

The adapter owns only active `prefix` and `globalconfig` assignments. It must:

- preserve comments, whitespace, ordering, and every unrelated line;
- treat absence or a regular file without active conflicting assignments as a
  no-op;
- refuse symlinks and non-regular targets without reading through or replacing
  them;
- build the candidate beside `.npmrc`, validate the candidate with npm's config
  parser where safe, create one unique immutable backup, atomically promote,
  and verify that conflicting active keys are gone;
- leave an empty regular file rather than deleting a user-owned path as an
  incidental cleanup;
- create no backup on the second run;
- run before nvm activation at one canonical seam so steps 02 and 03 cannot
  diverge or each claim the same mutation.

The adapter must not remove credentials, registry settings, auth tokens, or
other npm configuration, and diagnostics must not print the file contents.

## Configuration-Write Contract

The existing recovery-safe file and managed-shell helpers are the base for one
deep managed-artifact adapter. The final plan should replace parallel
per-script copy/merge implementations rather than layer another wrapper around
them.

The adapter's external interface should support only the intent variants the
callers need:

- install one exact managed file;
- merge one declared JSON/TOML overlay;
- replace one validated managed shell block;
- apply one versioned migration.

Its implementation owns target-type refusal, ownership/adoption, candidate
creation beside the target, validation, unique immutable backups, atomic
promotion, post-verification, and cleanup of run-owned candidates. A backup
identifier must include the globally unique run id and a per-mutation sequence
or target digest; timestamps and basenames alone are insufficient.

Multi-file steps remain forward-recoverable, not transactional. If the third
file fails, the first two valid promoted files stay in place, every original
backup remains distinct, and the next run reinspects each destination.

## Profile-Specific Conclusions

Both profiles share the same hard convergence boundary through steps 01–04.
The managed Python fix, `.npmrc` adapter, package declaration policies, exact
runtime checks, observational verifiers, and run-level repeat contract are
therefore common P0 work.

`carlo-baseline` additionally requires:

- recovery-safe exact/co-managed writes across dotfiles, Codex, Claude, and
  Gemini;
- preserved Git identity and all manual authentication boundaries;
- a versioned, backed-up Gemini legacy migration;
- a proven-owned, explicit-refresh Skill Hub checkout plus exact projection
  verification;
- no automatic repair of first-launch application or account state.

`shared-baseline` additionally requires:

- only the two declared shared shell blocks;
- no Carlo file adoption, Oh My Zsh, Claude/Gemini configuration, 1Password
  setup, or Skill Hub projection;
- the same common package/runtime environment safety;
- an immediate rerun that leaves all non-marker user shell content unchanged.

## Priority and Plan Dependencies

| Priority | Required improvement | Why and dependency |
| --- | --- | --- |
| P0 | Establish the shared state/disposition vocabulary and package requirement policy in the stateful test harness. | Every adapter, recorder event, rerun assertion, and recovery action depends on one meaning for valid, drifted, managed, and foreign state. |
| P0 | Implement the managed Python environment adapter and red valid-existing-environment regression without `--clear`. | It is the proven repeat-run blocker for both profiles. |
| P0 | Replace both `.npmrc` mutations with one co-managed recovery-safe adapter. | The duplicated current path can replace user-owned symlinks and retains no immutable backup. |
| P0 | Deepen the managed-artifact adapter and route every exact, merge, shell-block, TOML, and migration write through it. | User configuration currently has inconsistent target, staging, backup, interruption, and repeat behavior. |
| P0 | Make verifiers side-effect-free and add immediate second-run acceptance for both exact profile sequences. | A convergence claim is false if verification mutates state or only one profile is rerun. |
| P1 | Add explicit `present`/`range`/`exact` package declarations and state-aware Homebrew/cask, nvm/npm/Corepack, and Bun adapters. | Current name-presence checks cannot distinguish compatible state, required drift, or foreign ownership. |
| P1 | Record bootstrap ownership and make Skill Hub and remote-source refresh explicit. | Current origin/path checks do not prove ownership, and normal reruns can pull moving upstream state. |
| P1 | Replace direct Homebrew and Oh My Zsh remote installer execution with source-identified, post-probed adapters. | Partial remote mutation cannot be safely classified by directory presence alone. |
| P1 | Reconcile changed/no-change/conflict dispositions with the run recorder, operation policy, and same-profile recovery guidance. | Repeat behavior must be visible and use the failure vocabulary already selected by the logging and resilience reviews. |
| P2 | Report drift and retained compatible foreign capabilities without automatically adopting or upgrading them. | This improves maintenance visibility without broadening bootstrap authority. |

The final synthesis should order the shared harness and vocabulary before broad
adapter migration, then deliver the managed Python and `.npmrc` slices first.
Run-recorder/coordinator work can proceed in parallel only where its schema is
already fixed; stateful adapters and recovery-safe writes must land before
automatic retry or hard stall termination is enabled for their operations.

## Acceptance Criteria for the Improvement Plan

The idempotency portion of the final plan is implementation-ready only when it
requires all of the following:

1. Every mutating operation declares its desired state, ownership evidence,
   inspection states, allowed transitions, verification, and recovery
   disposition.
2. A shared vocabulary distinguishes absent, exact, compatible, managed drift,
   managed invalid, foreign, unknown, and interrupted state.
3. Every package declaration has an explicit `present`, `range`, or `exact`
   policy; ordinary reruns perform no implicit upgrades.
4. The real and fake `uv` suites cover absent, valid existing, immediate
   second run, wrong interpreter, missing package, package drift, partial,
   corrupt, foreign, symlink, permission, and interrupted state without
   automatic clearing.
5. One `.npmrc` adapter preserves unrelated content, refuses foreign target
   types, retains an immutable backup, remains secret-safe, and is a no-op on
   its immediate second invocation.
6. All managed config and standalone-binary writes use same-filesystem staging,
   validation, unique immutable backup where applicable, atomic promotion,
   post-verification, and ownership-bounded cleanup.
7. Managed shell, JSON/TOML overlay, exact-file, and versioned-migration tests
   cover exact, user-modified, malformed, symlink, non-file, backup collision,
   interrupted, and immediate-repeat state.
8. Homebrew, cask, nvm/Node, npm/Corepack, Bun, remote installer, and Skill Hub
   adapters preserve valid prior work, distinguish compatible foreign state,
   and never repair unknown or unproven-owned state.
9. Skill Hub normal reruns do not fetch moving upstream state; explicit refresh
   records before/after revisions and applies only to a clean proven-owned
   checkout. Projection verification proves resolved readable selected skills
   through every harness root.
10. Both exact profile sequences pass in isolated stateful fixtures on the
    first run and immediate second run. The second run reports no semantic
    mutation, backup, staging, install, or implicit refresh.
11. Path and smoke verification are proven observational through before/after
    filesystem and adapter-call snapshots.
12. Partial failure and interruption fixtures prove forward recovery: valid
    completed work remains, owned staging may be removed, final targets are
    reinspected, and foreign/unknown state is untouched.
13. A recorded clean Apple Silicon ZIP-first acceptance runs
    `shared-baseline` twice on one fresh snapshot and `carlo-baseline` twice on
    a separate fresh snapshot, with exact source identities and no copied
    secret or authentication state.
14. Reports distinguish hermetic regression evidence from real-machine
    acceptance and list changed, satisfied, compatible, degraded, conflicting,
    and uncertain targets without exposing user configuration or secrets.

## Audit Limits

- This is a planning artifact. It does not change bootstrap behavior, package
  versions, user configuration, Skill Hub state, or cleanup policy.
- Existing local fixtures are regression evidence, not clean-machine
  acceptance.
- The version-policy defaults above preserve current install intent. Exact
  package pins or broader upgrade policy require an explicit source change.
- Authentication, identity, credentials, cloud profiles, master environment
  files, user-owned checkouts, symlinks, and foreign configuration remain
  outside automatic repair.
- Package-manager rollback, cross-file rollback, automatic backup pruning, and
  resume-by-skipping are deliberately excluded.
