# Secrets Strategy

## Policy

1Password is the source of truth for secrets used with this development
environment.

That includes:

- `.env` values for projects
- API keys and tokens
- AWS credentials and related account details
- GitHub credentials and tokens
- SSH key material or recovery data, where appropriate
- other machine-specific credentials that should not live in this repository

## Preferred Storage Model

Use 1Password items as the long-term store for secrets, not local export files
checked into the repo.

Where it fits, use 1Password's API credential-oriented item types for
structured secrets such as:

- provider name
- access key / client ID
- secret / token
- endpoint / region / environment notes

For project-specific `.env` values, use a dedicated 1Password item per project
or per environment instead of scattering plaintext `.env` files across the repo.

## Repo Rule

- Do not commit secrets to this repository.
- Do not treat local shell files as secret storage.
- Do not add new secret-export artifacts as part of the normal bootstrap flow.
- If a bootstrap step needs a secret, the expected source is 1Password.

## Workflow

On a fresh machine or Parallels VM:

1. Install and sign in to 1Password.
2. Retrieve required credentials from 1Password.
3. Use those secrets to complete app logins and CLI auth flows.
4. Recreate project `.env` files from 1Password only when needed.

Examples:

- use 1Password-held AWS credentials with `aws configure`
- use 1Password-held GitHub credentials or token material for `gh auth login`
- use 1Password-held API keys when creating local project `.env` files
- use 1Password-held app credentials for Codex, Claude, and other tools as needed

## Preferred CLI Usage

Use the 1Password CLI where it improves repeatability:

- `op account list` to confirm access
- `op signin` if CLI auth still needs to be established
- `op run --env-file=...` for ephemeral secret-backed commands
- `op inject --in-file ... --out-file ...` when a rendered local file is required

This repo includes:

- `scripts/07-setup-1password.sh`
- `scripts/08-op-inject-template.sh`
- `onepassword/examples/project.env.tpl`
- `SECRETS-CHECKLIST.md`

## Legacy Migration Material

Older secret-migration artifacts were removed from the active tree and are now
recoverable through Git history only. They are not part of the preferred
workflow going forward.

## Future Option

If secret automation becomes part of this repo later, prefer integrating with
1Password directly rather than reintroducing plaintext export files.

For a practical list of what to load into 1Password first, use
`SECRETS-CHECKLIST.md`.
