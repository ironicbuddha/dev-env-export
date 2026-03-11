# Codex Configuration

Tracked Codex configuration lives here.

Current intended target on macOS:

- `codex/config.toml` -> `~/.codex/config.toml`

Notes:

- Keep this directory limited to portable Codex defaults.
- Do not commit `auth.json`, history files, caches, logs, or project trust
  state.
- The Codex CLI supports `codex login` for authentication and `codex app` for
  launching or installing the desktop app.
