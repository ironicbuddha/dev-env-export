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
  - format-on-save enabled with Zed's native formatter auto-selection
  - Markdown, TypeScript-family files, and CSS explicitly opt into format-on-save
  - visible tab diagnostics so lint and type issues are easier to spot
  - inline edit predictions disabled in favor of explicit Codex/Claude use
  - Codex and Claude thread shortcuts in the keymap
- TypeScript and CSS diagnostics come from Zed's built-in language-server
  support.
- Markdown formatting works out of the box, but Markdown lint diagnostics still
  need an added extension or language server because Zed has no built-in
  Markdown language server.

Tracked keybindings:

- `cmd-alt-c` starts a new Codex thread in the agent panel
- `cmd-alt-a` starts a new Claude Code thread in the agent panel

Keep this directory focused on portable user config, not caches or machine-
specific state.
