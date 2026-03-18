# Gemini Configuration

Tracked Gemini CLI configuration lives here.

Current intended targets on macOS:

- `gemini/GEMINI.md` -> `~/.gemini/GEMINI.md`
- `gemini/settings.json` -> merged into `~/.gemini/settings.json`

Notes:

- Keep this directory limited to portable Gemini CLI defaults.
- Do not commit OAuth tokens, account caches, session state, project state, or
  trust decisions from `~/.gemini`.
- `scripts/08-setup-gemini.sh` is the repo-managed setup step that applies
  these defaults and preserves existing local auth and runtime state when
  practical.
- Shared agent skills currently resolve through `~/.agents/skills`, which lets
  Gemini discover the same skill set linked for the rest of the local agent
  tooling layer.
