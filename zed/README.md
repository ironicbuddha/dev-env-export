# Zed Configuration

Place tracked Zed user configuration here.

Current intended targets on macOS:

- `zed/settings.json` -> `~/Library/Application Support/Zed/settings.json`
- `zed/keymap.json` -> `~/Library/Application Support/Zed/keymap.json`

Notes:

- Zed's user data directory on macOS is `~/Library/Application Support/Zed`.
- The Zed CLI can be installed from Zed itself with `Cmd+Shift+P`, then
  `cli: install`.
- The `zed --wait` flag is suitable for tools like Git once the CLI is
  installed.
- The tracked defaults in this repo are intentionally opinionated:
  - fast autosave after short idle time
  - format-on-save through language servers
  - inline edit predictions disabled in favor of explicit Codex/Claude use
  - Codex and Claude thread shortcuts in the keymap

Tracked keybindings:

- `cmd-alt-c` starts a new Codex thread in the agent panel
- `cmd-alt-a` starts a new Claude Code thread in the agent panel

Keep this directory focused on portable user config, not caches or machine-
specific state.
