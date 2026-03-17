# Codex Statusline Sketch

This is a pragmatic v1 design for giving Codex sessions more useful ambient
context, even though an official Codex statusline hook is not clearly
documented yet.

## Goal

Show the small set of facts that actually changes how you work:

- what repo you are in
- what branch and git state you are on
- whether the tree is dirty or staged
- what Codex model, reasoning, sandbox, and approval settings are active
- whether MCP is configured
- what the current task or latest verification status is

## Current Helpers

Use [statusline-context.sh](/Users/carlo/dev/dev-env-export/codex/statusline-context.sh)
as the main renderer, and use
[statusline-compact.sh](/Users/carlo/dev/dev-env-export/codex/statusline-compact.sh)
for tmux, Warp, or other narrow status surfaces.

It prints a one-line summary sourced from:

- `~/.codex/config.toml`
- the current git repo
- `codex mcp list`
- optional environment variables you set in the shell

When stdout is a TTY, the helper also adds color:

- cyan for model and multi-agent state
- blue for repo and task labels
- green for safe or healthy signals
- yellow for caution states such as a dirty tree or workspace-write sandbox
- red for disruptive states such as merge/rebase or danger-full-access
- magenta for `approval:never` because it deserves to feel slightly unhinged

Pretty output:

```text
[mdl gpt-5.4/high] [git dev-env-export:main] [ws d3/s1/normal] [sbx danger] [ask never] [mcp 0] [ma on] [task skills-doc] [check md:clean]
```

Compact output:

```text
dev-env-export:main d3/s1/normal gpt-5.4/high sbx:danger ask:never mcp:0 ma:on task:skills-doc check:md:clean
```

## Fields

- `model/reasoning`
  Reads `model` and `model_reasoning_effort` from `~/.codex/config.toml`.
- `repo:branch`
  Uses the current git repo and branch, or short SHA if detached.
- `ws`
  Compact workspace state segment with dirty count, staged count, and
  `normal`/`merge`/`rebase`.
- `sandbox`
  Reads `sandbox_mode` from Codex config.
- `approval`
  Reads `approval_policy` from Codex config.
- `mcp`
  Counts entries returned by `codex mcp list`.
- `multi`
  Reads `features.multi_agent` from Codex config.
- `task`
  Optional short label from `CODEX_STATUS_TASK`.
- `check`
  Optional verification summary from `CODEX_STATUS_LAST_CHECK`.
- `cmd`
  Optional recent command summary from `CODEX_STATUS_LAST_CMD`.

## Suggested Wiring

Until Codex exposes or documents a native statusline command hook, the useful
places to surface this are:

- shell prompt segment while working in a Codex repo
- tmux status segment
- Warp or terminal statusline command
- a small wrapper script that exports task/check metadata before launching Codex

The wrapper now exists as
[codex-wrapper.sh](/Users/carlo/dev/dev-env-export/codex/codex-wrapper.sh).

## Suggested V2 Signals

If Codex later exposes richer session metadata, add:

- context-window usage percentage
- active profile name
- current plan step
- last tool used
- long-running command indicator
- cloud or local-provider mode
- live MCP connection health instead of just configured count

## Example Launch Wrapper

```bash
./codex/codex-wrapper.sh \
  --task "skills-doc" \
  --check "md:clean" \
  --cmd "lint:ok" \
  --preview-status \
  --status-format pretty
```

For tmux or Warp, use the compact renderer:

```bash
./codex/statusline-compact.sh
```

Or integrate that script into the terminal surface you actually use.
