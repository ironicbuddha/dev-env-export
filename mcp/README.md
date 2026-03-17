# MCP Defaults

This directory tracks the curated MCP server baseline for this repo.

The goal is not to mirror every MCP server installed on one machine. The goal
is to keep a small, deliberate default set worth carrying to a fresh machine or
fresh agent setup.

The editable source of truth for the server list lives in `mcp/servers.yaml`.
Keep the policy here, and edit the actual default or optional server entries in
that manifest file.

## Default Source

The default source for MCP servers in this environment is the Docker library.

- Prefer the Docker-distributed version of an MCP server first.
- Treat Docker Desktop as the default management path for local MCP servers.
- Fall back to vendor-specific or manual installs only when the Docker library
  does not provide the server you need, or is meaningfully behind.

## Server Manifest

Use `mcp/servers.yaml` for:

- the default MCP server list
- the optional MCP server list
- the default source selector for where MCP servers should come from

## Baseline Rules

- Keep the default set small and intentional.
- Prefer the Docker library as the first source for MCP servers.
- Do not add a server just because it was installed once on one machine.
- If a server needs auth, document the secret dependency in `SECRETS.md` and
  `SECRETS-CHECKLIST.md`.
- If a server is only useful for one kind of project, prefer keeping it
  optional.
- Update `mcp/servers.yaml`, this file, and `AI-STACK.md` together when the
  default set changes.

## Current Intent

For a fresh-machine rebuild, the default assumption should be:

1. source MCP servers from the Docker library first
2. add optional servers only when the workflow actually calls for them
3. keep live per-machine experimentation out of Git unless it proves it belongs
