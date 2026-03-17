# Codex Configuration

Tracked Codex configuration lives here.

Current intended target on macOS:

- `codex/config.toml` -> `~/.codex/config.toml`

Notes:

- Keep this directory limited to portable Codex defaults.
- Use `codex/SKILLS.md` for the current skill inventory and for the repo policy
  on vendored versus install-on-build skills.
- Use `codex/STATUSLINE.md` for the current Codex statusline/context helper
  design.
- Use `codex/codex-wrapper.sh` when you want to launch Codex with task/check/cmd
  metadata already wired into the status helper.
- Do not commit `auth.json`, history files, caches, logs, or project trust
  state.
- The Codex CLI supports `codex login` for authentication and `codex app` for
  launching or installing the desktop app.
