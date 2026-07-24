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
eval "$(op signin)"
```

If the desktop app is already signed in, prefer app integration and use
`op account list` as the first check. Use `op signin -f` only if you explicitly
want terminal-only sign-in behavior.

Run a command with secrets loaded from an env file containing secret references:

```bash
op run --env-file=onepassword/examples/project.env.tpl -- sh -c '
  for name in OPENAI_API_KEY GITHUB_TOKEN; do
    if printenv "$name" >/dev/null; then
      printf "%s=set\n" "$name"
    else
      printf "%s=unset\n" "$name"
    fi
  done
'
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

Stub creation is deliberately explicit and refuses to overwrite existing
items. It is not part of either Bootstrap Profile and Shared Baseline only
documents this workflow; it does not install or configure 1Password.

## Secret Reference Pattern

Typical secret references look like:

```text
op://Private/openai - api credential/api key
op://Private/firecrawl - api credential/api key
op://Private/github - personal access token/personal access token
```

Or, when used in templates with variables:

```text
op://${VAULT:-Private}/openai - api credential/api key
op://${VAULT:-Private}/firecrawl - api credential/api key
```

Current repo convention:

- item titles should match `onepassword/stubs/core.tsv` exactly
- do not use `/` in item titles because 1Password secret references parse `/`
  as a path separator
- field names in secret references should match the actual 1Password field labels exactly
- common field mappings in the repo docs and templates include:
  - `openai - api credential` -> `api key`
  - `anthropic - api credential` -> `api key`
  - `firecrawl - api credential` -> `api key`
    when a project uses `FIRECRAWL_API_KEY`
  - `github - personal access token` -> `personal access token`
  - `aws - main account` -> `access key id`
  - `aws - main account` -> `secret access key`

For GitHub specifically, that PAT item is optional. The repo's default machine
bootstrap path uses `gh auth login --web --git-protocol https` plus
`gh auth setup-git`, which is enough for normal repo and gist work without a
PAT or GitHub App.

See `onepassword/examples/project.env.tpl` for a practical example.
See `onepassword/stubs/core.tsv` for the default item-stub scaffold.
