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

Where to get it:

- Username and email come from your existing GitHub account.
- Create a PAT in GitHub account settings under developer or personal access
  token controls.
- Recovery codes come from GitHub account security settings if 2FA is enabled.
- If you already authenticate successfully with GitHub elsewhere, treat that as
  a hint that the token or account already exists and should be recovered, not
  recreated blindly.

### AWS

Recommended 1Password item:

- `aws / main account`

Suggested fields:

- account ID
- access key id
- secret access key
- default region
- preferred profile name
- common role names
- console URL
- MFA recovery notes

Notes:

- `aws configure` is part of the bootstrap follow-up flow.
- If you use multiple accounts, create one item per account or environment.

Where to get it:

- Account ID and console URL come from the AWS console.
- Access keys come from IAM user security credentials if you still use IAM
  user-based access.
- If you use SSO or role assumption, store the account, role, and profile notes
  instead of pretending there is one magic long-lived key for everything.
- Default region and common profile names come from how you already use AWS in
  real projects.

### OpenAI

Recommended 1Password item:

- `openai / api credential`

Suggested fields:

- api key
- organization ID
- project ID
- usage notes

Where to get it:

- Create API keys in the OpenAI platform account you actually bill through.
- Organization and project IDs come from the same platform context.
- If you already have working project `.env` files or a live app using OpenAI,
  recover the existing key and IDs first before minting extras.

### Anthropic

Recommended 1Password item:

- `anthropic / api credential`

Suggested fields:

- api key
- workspace or account notes
- usage notes

Where to get it:

- Create API keys in the Anthropic console for the account or workspace you use
  for API access.
- Workspace notes should reflect the billing or team context the key belongs to.
- As with OpenAI, recover existing working credentials before spraying new ones
  everywhere.

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

Where to get it:

- Existing keys can usually be recovered from `~/.ssh`, GitHub SSH settings, or
  another machine you already use.
- New keys can be generated directly in 1Password or with `ssh-keygen` if you
  still prefer file-backed keys.
- Public keys can be recovered from the private key or from account settings
  where they are already registered.

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

Where to get it:

- Recovery codes come from each provider's account security or MFA section.
- Backup email and MFA notes should reflect the actual recovery path you use,
  not what you think you might set up later.
- Add support links only if they help you recover access faster under pressure.

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

Where to get it:

- Create the token in your Vercel account settings.
- Team ID or slug comes from the team or project context you deploy under.
- If minor projects are the main Vercel users, only create this if you actually
  need CLI or API access.

### npm

Recommended item:

- `npm / automation token`

Suggested fields:

- token
- registry URL
- package scope notes

Where to get it:

- Create an automation token in your npm account settings only if you publish or
  automate package access.
- If you do not publish packages, skip this item entirely.

### Docker Hub

Recommended item:

- `docker hub / personal token`

Suggested fields:

- username
- token
- registry notes

Where to get it:

- Create the token in Docker Hub account settings if you actually push or pull
  from private registries.
- If Docker is purely local for you, this may not be worth creating yet.

### Terraform

Recommended item:

- `terraform / cloud token`

Suggested fields:

- token
- organization
- workspace notes

Where to get it:

- Create the token in Terraform Cloud or Enterprise only if you are actively
  using standalone Terraform workflows.
- If Terraform is no longer a default tool in this repo, this item probably
  belongs in the optional bucket, not the first wave.

### Figma

Recommended item:

- `figma / personal access token`

Suggested fields:

- token
- team notes
- MCP usage notes

Where to get it:

- Create the token in Figma developer or personal access token settings.
- Only create this if design-to-code or Figma MCP work is actually part of your
  current workflow.

### Google Or Gemini

Recommended item:

- `google / gemini api key`

Suggested fields:

- API key
- project ID
- usage notes

Where to get it:

- Create the key in the Google AI or Google Cloud project you actually intend
  to use.
- Store the project ID alongside it so the key is not detached from its billing
  and quota context.

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

Where to get it:

- Recover values from the project's existing `.env` files, deployment platform,
  cloud console, database provider, and current hosting config.
- Create new secrets only when a project actually needs a fresh local, staging,
  or production value.
- Do not rotate or recreate working production secrets casually just because
  you are organizing 1Password.

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
