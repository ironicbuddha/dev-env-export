# 1Password Usage

This directory documents how this repo expects 1Password CLI to be used.

## Workflow

- keep secrets in 1Password
- store project `.env` values as secret references or structured items
- use `op run` for ephemeral runtime secrets
- use `op inject` when a local rendered file is unavoidable

## Common Commands

Sign in or confirm account access:

```bash
op account list
op signin
```

Run a command with secrets loaded from an env file containing secret references:

```bash
op run --env-file=onepassword/examples/project.env.tpl -- env | rg 'OPENAI|GITHUB'
```

Render a local file from a template:

```bash
./scripts/08-op-inject-template.sh \
  --in-file onepassword/examples/project.env.tpl \
  --out-file .env
```

Create missing item stubs in a vault from the repo manifest:

```bash
./scripts/11-create-1password-stubs.sh --vault Private
```

## Secret Reference Pattern

Typical secret references look like:

```text
op://Private/openai/api credential
op://Private/github/personal access token
```

Or, when used in templates with variables:

```text
op://${VAULT:-Private}/openai/api credential
```

See `onepassword/examples/project.env.tpl` for a practical example.
See `onepassword/stubs/core.tsv` for the default item-stub scaffold.
