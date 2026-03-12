# Secrets Checklist

Use this checklist to populate 1Password with the secrets and credentials that
matter for this dev environment.

This is not a list of things to commit. It is a list of things to store in
1Password so a fresh macOS machine or Parallels VM can be brought online
without hunting through old laptops, browser sessions, or random notes.

## Priority Order

Start with these before anything else:

1. GitHub
2. AWS
3. OpenAI
4. Anthropic
5. SSH
6. Vercel
7. active project `.env` sets

## Core Accounts

### GitHub

Recommended 1Password item:

- `github / personal access token`

Suggested fields:

- username
- email
- personal access token
- token scope notes
- primary orgs
- recovery codes

Notes:

- `gh auth login` is part of the bootstrap follow-up flow.
- If you use fine-grained tokens, store one item per purpose instead of
  cramming them all into one blob.

### AWS

Recommended 1Password item:

- `aws / main account`

Suggested fields:

- account ID
- access key ID
- secret access key
- default region
- preferred profile name
- common role names
- console URL
- MFA recovery notes

Notes:

- `aws configure` is part of the bootstrap follow-up flow.
- If you use multiple accounts, create one item per account or environment.

### OpenAI

Recommended 1Password item:

- `openai / api credential`

Suggested fields:

- API key
- organization ID
- project ID
- usage notes

### Anthropic

Recommended 1Password item:

- `anthropic / api credential`

Suggested fields:

- API key
- workspace or account notes
- usage notes

## Access And Identity

### SSH

Recommended 1Password item:

- `ssh / primary developer key`

Suggested fields:

- private key
- public key
- passphrase
- key type
- comment or email
- hosts or usage notes

Notes:

- If you use 1Password-managed SSH keys, store the key as a first-class SSH
  item rather than a generic note.

### Machine Recovery

Recommended 1Password items:

- `recovery / github`
- `recovery / aws`
- `recovery / openai`
- `recovery / anthropic`

Suggested fields:

- recovery codes
- backup email
- MFA notes
- support links

## Common Developer Services

Create these as needed based on what you actually use:

### Vercel

Recommended item:

- `vercel / personal token`

Suggested fields:

- token
- team ID
- team slug
- project notes

### npm

Recommended item:

- `npm / automation token`

Suggested fields:

- token
- registry URL
- package scope notes

### Docker Hub

Recommended item:

- `docker hub / personal token`

Suggested fields:

- username
- token
- registry notes

### Terraform

Recommended item:

- `terraform / cloud token`

Suggested fields:

- token
- organization
- workspace notes

### Figma

Recommended item:

- `figma / personal access token`

Suggested fields:

- token
- team notes
- MCP usage notes

### Google Or Gemini

Recommended item:

- `google / gemini api key`

Suggested fields:

- API key
- project ID
- usage notes

## Common Project Secrets

For each active project, create separate items per environment:

- `project-name / local env`
- `project-name / staging env`
- `project-name / production env`

Suggested fields:

- `DATABASE_URL`
- `DIRECT_URL`
- `REDIS_URL`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GITHUB_TOKEN`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `VERCEL_TOKEN`
- `JWT_SECRET`
- `SESSION_SECRET`
- `WEBHOOK_SECRET`
- `SENTRY_DSN`
- callback URLs
- team IDs
- environment notes

Notes:

- Keep one 1Password item per project and environment instead of one giant
  cursed mega-item.
- Use `op inject` or `op run` when you need a local `.env` or ephemeral secret
  loading.

## Good Things To Store Even Though They Are Not API Keys

- GitHub recovery codes
- AWS MFA recovery details
- SSH key passphrases
- app-specific passwords
- license keys
- database connection strings
- service account JSON or cert material, if applicable
- local environment notes such as regions, callback URLs, and vault names

## Naming Pattern

Keep names boring and predictable:

- `provider / credential type`
- `provider / environment`
- `project-name / local env`
- `project-name / production env`

Examples:

- `github / personal access token`
- `aws / main account`
- `openai / api credential`
- `anthropic / api credential`
- `vercel / personal token`
- `figma / personal access token`
- `my-app / local env`
- `my-app / production env`

## Repo Alignment

This checklist matches the current bootstrap flow in this repo:

- `gh auth login`
- `aws configure`
- `codex login`
- `claude auth login`
- `op inject`
- `op run`

See `SECRETS.md` for the policy and `onepassword/README.md` for the CLI usage
pattern.
