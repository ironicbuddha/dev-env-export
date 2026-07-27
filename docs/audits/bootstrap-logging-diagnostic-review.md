# Bootstrap Logging and Diagnostic Quality Review

Status: resolution artifact for
[Assess bootstrap logging and diagnostic quality](https://github.com/ironicbuddha/dev-env-export/issues/28),
captured 2026-07-27.

## Answer

The bootstrap has a solid durable-log foundation: every valid invocation gets
a private unique directory outside the extracted ZIP, terminal output is
captured, completed steps have per-step logs and durations, logging-pipeline
failure is gating, and Command Line Tools has a distinct manual-action outcome.
Those choices made the latest repeat-run failure diagnosable.

The diagnostic contract is not yet recovery-oriented. It identifies the failed
step, but not the failed operation, stable failure class, safe next action,
completed/remaining work, non-gating warnings, exact bootstrap source, or
whether an interrupted run is resumable. Long operations have only step-level
timestamps, environment snapshots are local-sensitive and lack a share-safe
path, and profile/step completion guidance is duplicated enough to drift.

The improvement plan should deepen the run recorder into one module with a
small event interface. That module should own outcome taxonomy, timestamps,
structured run state, human summaries, warning aggregation, source identity,
privacy classification, and recovery guidance. Raw vendor output remains in
per-step logs, but it should no longer be the only place where the cause or
next action is visible.

## What Already Works

- The default parent, `~/Library/Logs/dev-env-bootstrap`, survives deletion of
  an extracted ZIP checkout.
- `mktemp -d` gives each invocation an isolated directory. The inspected run
  directory is mode `0700`, so files with mode `0644` remain inaccessible
  through the private directory to other local users.
- The main log, per-step logs, environment snapshots, status ledger, and
  summary are named consistently and printed at run start or exit.
- The step-status ledger records start/end time, duration, step, exit code,
  outcome label, and log path for every completed step.
- The runner preserves child-versus-tee status in the logging-failure label and
  fails rather than claiming success when `tee` fails.
- Manual Command Line Tools work uses exit `20` and prints the action plus exact
  rerun command.
- `DEV_ENV_TRACE_STEPS=1` provides an opt-in low-level investigation mode.

These are the parts to retain. The plan should extend the recorder rather than
replace durable logs with an external logging service or require software that
does not exist at ZIP-first startup.

## Evidence From the Latest Run

The locally retained run
`tmp/bootstrap-20260727-185607-4rB7Kg/` is compact—831 lines and about 31 KB
across all artifacts—and clearly shows:

- total duration `01:48:10`;
- steps 00 through 03 completed;
- step 02 consumed 6,484 seconds;
- step 04 failed immediately;
- the step-04 log contains the real `uv` error.

It also demonstrates the current diagnostic gaps:

| Observation | Evidence | Consequence |
| --- | --- | --- |
| Long-step resolution stops at the step. | Step 02 lasted 6,484 seconds, but its 186-line log has timestamps only at step start and end. | The artifacts cannot identify which cask download, installer, password prompt, or postinstall consumed the time or whether the process was making progress. |
| Failure classification is flattened. | The summary says `failed_step=04-install-pip-packages.sh`, `exit_status=1`, and `failed(1)`. | The existing-environment state and the vendor exit `2` are visible only in raw output, with no stable state-conflict code. |
| Vendor guidance can be unsafe or incomplete. | Raw `uv` suggests clearing the environment; the wrapper says only that creation failed. | A user has no repo-owned, recovery-safe instruction and may follow a destructive vendor hint. |
| Non-gating failures disappear from summary state. | An isolated invalid Skill Hub checkout emits two `[WARN]` lines and exits `0`. The master records zero-exit steps as `ok`. | A run can complete with degraded optional capability while the summary reports no warning count or degraded outcome. |
| Source identity is absent for ZIP runs. | The snapshot has `repo_root` but no Git revision, archive digest, release id, or source-tree digest. | A shared log bundle cannot establish which bootstrap code produced it. |
| The run id is not fully unique. | `run_id=20260727-185607`, while the directory adds random suffix `4rB7Kg`. | Two runs started in one second can have the same run id even though their directories differ. |
| Copied bundles retain stale absolute paths. | Summary and status files point to the original machine's log directory. | Artifact links are not directly usable after a bundle is copied for diagnosis. |
| Local-sensitive context is captured by default. | Snapshot fields include home, user, uid, hostnames, full PATH, PWD/repo path, `uname`, disk/uptime data, Git status, and Homebrew config. | The complete bundle should not be pasted into a public issue without review and redaction. |

The summary has no fields for source identity, warning count, failure code,
recovery action, current operation, completed steps, or remaining steps.

## Artifact-by-Artifact Review

| Artifact or surface | Current value | Gaps | Required contract |
| --- | --- | --- | --- |
| Terminal output | Shows raw progress, step result, artifact paths, and final outcome. | High-volume duplicate step output; no compact failure block; no operation duration/heartbeat; prompts are not explicitly distinguished from hangs. | Keep live raw output, but add one stable final block with outcome, current/failed operation, cause, safe action, exact rerun, warnings, and summary path. |
| `bootstrap.log` | Complete terminal transcript and easiest single file to inspect. | Duplicates every per-step log; raw output has inconsistent levels/codes and no line/operation timestamps; trace mode can be noisy and sensitive. | Treat as human transcript generated from structured events plus raw tool output, not as the only diagnostic truth. |
| Per-step logs | Narrow the investigation and include step metadata/outcome. | No operation timing, attempt count, progress heartbeat, or explicit waiting-for-user state; graceful end trailer is not guaranteed after abrupt termination. | Record operation start/end, target, attempt, elapsed time, and last-progress timestamp while retaining raw vendor output. |
| `step-status.tsv` | Reliable compact ledger for steps that reached `record_step_status`. | Completed steps only; absolute log path; no changed/no-op counts, warning/degraded state, failure code, or incomplete-current-step row. | Make it schema-versioned and portable, with relative log name, disposition, changed/no-op/warning counts, and explicit started/incomplete/ended state. |
| `summary.txt` | Human- and shell-readable run outcome, duration, failed step, profile, paths, and embedded step ledger. | Written only on exit; no live state, source identity, warning aggregation, failed operation, safe recovery, progress, completed/remaining list, or completion guidance. It is written after postflight probing. | Atomically update a canonical run-state/summary at start, step start, step end, and exit. Finalization must not depend on best-effort environment probes succeeding. |
| `environment.txt` | Useful pre/post runtime and machine comparison. | Duplicated verbose data, personally identifying paths/hostnames, Git filenames, and unrestricted command output; no privacy label or sanitization path. | Split essential share-safe facts from local-sensitive diagnostics, label sensitivity, and provide deterministic sanitization before sharing. |
| Step messages | Often name the package/config being changed and use `[SKIP]`, `[INSTALL]`, `[WARN]`, and `[MISS]`. | Vocabulary and formatting differ across scripts; warning/error disposition is inferred from exit status; generic errors discard dependency detail. | Emit stable severity, disposition, code, operation, target, and recovery fields through one recorder interface. |
| Completion guidance | Master prints profile-specific manual follow-up after success. | Guidance is only in transcript, not summary; individual steps also print `Next:` instructions that conflict with orchestration. Step 04 points shared runs to Carlo step 05, step 08 points to non-orchestrated step 09, and shared completion recommends `vercel login` even Vercel is not a Shared Baseline requirement. | One profile-aware completion/recovery module owns next actions. Standalone step guidance must know whether the step is orchestrated. |
| Pre-log errors | Usage and profile errors are concise. | Parsing and log-directory-creation failures occur before durable capture. | Document terminal-only validation failures or initialize a minimal recorder early enough to preserve actionable startup failures without obscuring usage output. |

## Outcome and Message Taxonomy

The current run outcomes—`completed`, `manual_action_required`, `failed`, and
internal `in_progress`—are too coarse. Step statuses add `logging_failed`, but
warnings and optional degradation remain free-form text.

The plan should require orthogonal fields rather than an ever-growing list of
combined strings:

- **severity**: informational, warning, error;
- **disposition**: satisfied/no-change, changed, optional-skipped,
  degraded-non-gating, manual-action, required-failure, interrupted,
  logging-failure;
- **stable code**: identifies the operation or state class without parsing
  prose;
- **operation and target**: for example package install plus package name;
- **attempt**: current and maximum, once resilience policy is defined;
- **recovery**: retry step/run, perform manual action then retry, resolve
  conflicting state, do not retry, or none;
- **message**: concise human explanation;
- **raw log reference**: relative artifact and optional line/event pointer.

Exact failure codes, retry counts, and repeat-state dispositions must be
finalized with the resilience and idempotency reviews. The logging contract
should carry them, not invent them independently.

Recommended run outcomes are:

- completed;
- completed with warnings/degraded optional capability;
- manual action required;
- required failure;
- interrupted/incomplete;
- logging failure.

Optional work that was deliberately not requested is neither a warning nor a
failure.

## Long-Running and Partial Progress

Step 02 bundles formula checks, many casks, nvm, Node, Bun, and shell tooling
behind one step duration. The plan should require:

1. `operation_start` before every remote install, repair, migration, or
   verification that can block;
2. `operation_end` with elapsed time and disposition;
3. position such as `cask 17/26`;
4. an explicit notice before commands that may request `sudo`, open a GUI, or
   require human input;
5. a low-noise heartbeat only when a long operation has produced no structured
   progress for a defined interval;
6. the current operation and last-progress time in atomically updated run
   state.

Raw package-manager progress should remain visible. The recorder should add
structure around it rather than timestamp every vendor output line.

On abrupt termination, the last durable state must remain
`interrupted/incomplete`, with the last started operation and last successful
step. A later inspection must be able to distinguish incomplete from failed
and completed even when the EXIT trap never ran.

## Privacy, Redaction, and Sharing

The private run directory is a good local default, but permission alone does
not make the contents safe to paste elsewhere.

The plan should define two products:

1. **Local diagnostic bundle** — private, detailed, never uploaded
   automatically, marked as containing local-sensitive metadata.
2. **Shareable diagnostic bundle** — generated only by an explicit command,
   retaining source/profile/outcome/versions/events while removing or replacing
   usernames, hostnames, home/repo/log paths, Git status filenames, and other
   nonessential identifiers.

Both products must:

- never dump the full environment;
- never capture credentials, auth tokens, cloud profiles, `op` item output,
  master environment files, or secret-bearing command arguments;
- identify which fields were removed;
- keep recovery evidence and source identity after sanitization.

Trace mode must print a prominent local-sensitive warning before execution and
mark the bundle accordingly. Because `bash -x` expands arguments and variables,
the plan must not claim trace output is automatically safe to share.

Log retention should remain explicit and non-destructive. Document size and
manual cleanup; do not silently prune durable evidence or recovery backups.

## Target Run Recorder Module

Create one deep run-recorder module with a bootstrap-safe shell interface. It
must not require Homebrew, Python, Node, or `jq`, because it starts before those
tools exist.

The external interface should stay small:

- begin/end run;
- begin/end step;
- begin/end operation;
- emit classified event;
- update recovery/completion guidance.

Its implementation owns:

- terminal rendering;
- the human transcript;
- raw per-step output capture;
- a schema-versioned, append-only structured event file in a format available
  to stock macOS shell;
- atomic current run state and final summary;
- warning/degradation aggregation;
- unique run/source identity;
- relative artifact references;
- privacy labels and shareable-bundle sanitization.

Step scripts should report intent and outcome through this interface. External
commands remain true external dependencies whose raw output is captured by the
recorder. Do not expose recorder internals through every step merely to make
tests easier.

## Priority and Plan Dependencies

| Priority | Required improvement | Why |
| --- | --- | --- |
| P0 | Define the structured event/run-state schema, stable outcome fields, unique run id, and source identity. | Every later diagnostic, test, retry, and acceptance assertion depends on one durable vocabulary. |
| P0 | Add compact failure/recovery summaries with failed operation, underlying status, completed/remaining work, warnings, and safe exact next action. | Current summaries identify a step but still force raw-log interpretation and can surface unsafe vendor hints. |
| P0 | Make in-progress state atomic and interruption-aware. | The current summary is exit-only and cannot reliably represent power loss, forced termination, or a missing end trailer. |
| P0 | Define privacy classes, trace-mode warnings, and an explicit shareable sanitized bundle. | Current snapshots contain personal machine metadata and paths that should not be pasted publicly. |
| P1 | Instrument long operations with start/end duration, position, interaction notices, and low-noise heartbeat. | The 6,484-second package step cannot currently be decomposed or distinguished from a hang. |
| P1 | Surface non-gating warnings and optional degradation in final outcome/summary. | Skill Hub and other warning paths can exit zero and disappear behind `ok`. |
| P1 | Centralize profile-aware recovery and completion guidance and suppress conflicting orchestrated `Next:` messages. | Current guidance has verified profile and sequence drift. |
| P1 | Make artifact references portable and add a stable latest-run discovery pointer without deleting older runs. | Copied bundles retain stale absolute paths, and users should not need to search timestamp directories. |
| P2 | Add explicit retention/size guidance and richer before/after change counts. | This improves maintenance and signal without blocking core recovery. |

The event taxonomy must be reconciled with
[Assess bootstrap resilience and recovery behavior](https://github.com/ironicbuddha/dev-env-export/issues/29)
before retry/failure codes are fixed. Changed/no-change/conflict dispositions
must be reconciled with
[Assess bootstrap idempotency and repeat-run safety](https://github.com/ironicbuddha/dev-env-export/issues/30).
The executable logging tests should reuse the stateful adapter architecture
from
[Identify bootstrap testing gaps and stronger verification seams](https://github.com/ironicbuddha/dev-env-export/issues/27).

## Acceptance Criteria for the Improvement Plan

The logging portion of the final plan is implementation-ready only when it
requires all of the following:

1. Every run has a schema version, globally unique run id, profile, exact
   source identity, privacy class, start/end time, and stable outcome.
2. Current run state is atomically durable from run start through each
   step/operation and remains identifiable as incomplete after abrupt death.
3. Final failure output and summary name the failed step and operation,
   underlying statuses, stable failure class, completed/remaining work, safe
   recovery action, exact rerun command, and relevant relative log.
4. Non-gating warnings are counted and summarized; a degraded run cannot appear
   indistinguishable from a warning-free completion.
5. Every long remote or interactive operation records start/end duration,
   target, position, last progress, and a low-noise heartbeat policy.
6. The summary and status ledger use portable relative artifact references,
   while the terminal may additionally show the original absolute directory.
7. One profile-aware source owns manual-action and completion guidance;
   orchestrated steps do not emit conflicting `Next:` instructions.
8. The local bundle is private and clearly marked local-sensitive; an explicit
   deterministic sanitizer produces a useful shareable bundle with personal
   fields removed and no secret-bearing data captured.
9. Trace mode is opt-in, visibly marked sensitive, and never described as safe
   to share without sanitization.
10. Contract tests cover completed, completed-with-warning, manual-action,
    required failure, logging failure, interruption, stale/copied paths,
    Git/ZIP source identity, privacy sanitization, and long-operation events.
11. Clean-machine acceptance records the exact source and proves the final
    summary alone is sufficient to identify outcome, degraded capability,
    manual work, and the safe next action.
