# AI Stack

## Baseline

Carlo Baseline installs Codex CLI, Claude Code, and Gemini CLI. Shared Baseline
installs only Codex CLI, without Carlo configuration, personas, skills, MCP
defaults, plugins, or local AI state.

Codex keeps durable YOLO defaults: `approval_policy = "never"` and
`sandbox_mode = "danger-full-access"`. The tracked configuration deliberately
does not pin a model or reasoning effort. Buddy Mode, Claude commands, and
statusline helpers are Carlo-only portable configuration.

## Portable configuration boundary

Bootstrap applies only narrow portable defaults and keeps backups when it
changes a regular configuration file. It does not copy or replace
authentication, hooks, agents, plugins, trust state, sessions, caches, local
skills, or project state. Complete authentication explicitly after bootstrap.

## Skills and extensions

The public [Skill Hub](https://github.com/ironicbuddha/skills-hub) is the
canonical source of reusable skills. Carlo Baseline applies its named
`carlo-baseline` profile through `scripts/14-install-codex-skills.sh`; the Hub
projects the selected skills through `~/.agents/skills`, `~/.codex/skills`, and
`~/.claude/skills`. The Hub may contain more skills than the selected machine
projection.

No plugins or MCP servers are installed by default. Prefer standalone CLIs or
Skill Hub skills; Context7 should use that path rather than a default MCP or
plugin. `mcp/` is a manually applied catalogue for genuine MCP-only needs.

OpenSpec, GSD v2, OpenCode, and 21st.dev Agents are not baseline tooling. Use
them only as project-specific/manual choices and keep their state out of this
repository.

## Document and OCR tools

The shared document/OCR baseline is Pandoc, Poppler, Tesseract, ImageMagick,
and the bootstrap-owned `uv` environment's document libraries. Prefer native
parsers and PDF text extraction; use OCR as a fallback for scans or degraded
text.

## Audit

Run `./scripts/09-inventory-ai-tooling.sh` to report non-secret AI-tool drift.
It is an audit tool, not a mechanism for copying live machine state into Git.
