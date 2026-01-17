# SECRETS WARNING

## THIS EXPORT CONTAINS SENSITIVE INFORMATION

This export was created with the understanding that sensitive files would be included. Review ALL files carefully before using on the new machine.

---

## Files Containing Secrets

### HIGH PRIORITY - API Keys

| File | Secret Type | Action Required |
|------|-------------|-----------------|
| `shell/zshrc` (line ~12) | `OPENAI_API_KEY` | **ROTATE immediately** at platform.openai.com |

### Environment Files

| File | Contents | Risk Level |
|------|----------|------------|
| `env/stablo-ironicbuddha.env.production` | Sanity project IDs | Low (semi-public) |

---

## Files NOT Exported (Already Secured)

The following files contain secrets and were intentionally NOT included in this export:

| File | Secret Type | How to Regenerate |
|------|-------------|-------------------|
| `~/.aws/credentials` | AWS access keys | `aws configure` or AWS Console |
| `~/.config/gh/hosts.yml` | GitHub OAuth token | `gh auth login` |
| `~/.claude/.credentials.json` | Claude auth tokens | `claude auth login` |

---

## Before Using on New Machine

### Step 1: Review All Files

```bash
# Search for potential secrets in the export
grep -r "sk-" ~/dev-env-export/        # OpenAI keys
grep -r "AKIA" ~/dev-env-export/        # AWS access keys
grep -r "ghp_" ~/dev-env-export/        # GitHub tokens
grep -r "password" ~/dev-env-export/    # Passwords
grep -r "secret" ~/dev-env-export/      # Generic secrets
grep -r "token" ~/dev-env-export/       # Generic tokens
```

### Step 2: Rotate Exposed Credentials

1. **OpenAI API Key** (in `shell/zshrc`)
   - Go to: https://platform.openai.com/api-keys
   - Revoke the old key
   - Create a new key
   - Update `~/.zshrc` on the new machine

### Step 3: Re-authenticate Services

On the new Mac, run these commands to set up fresh credentials:

```bash
# AWS
aws configure
# Enter new access key ID and secret

# GitHub
gh auth login
# Follow the prompts

# Claude Code
claude auth login
# Follow the prompts
```

### Step 4: Verify No Secrets in Git

```bash
# Make sure export folder is not tracked
cd ~/dev-env-export
git status  # Should show "not a git repository"
```

---

## After Migration is Complete

1. **Delete the export folder** from both machines:
   ```bash
   rm -rf ~/dev-env-export
   rm -f ~/dev-env-export.zip
   ```

2. **Verify old credentials are revoked**:
   - OpenAI API keys
   - Any other exposed credentials

3. **Check for any copies**:
   - Cloud storage (Google Drive, Dropbox, iCloud)
   - USB drives
   - Email attachments

---

## Security Checklist

- [ ] Reviewed all files in `shell/` directory
- [ ] Reviewed all files in `env/` directory
- [ ] Reviewed all files in `dotfiles/` directory
- [ ] Rotated OPENAI_API_KEY
- [ ] Re-authenticated AWS (`aws configure`)
- [ ] Re-authenticated GitHub (`gh auth login`)
- [ ] Re-authenticated Claude (`claude auth login`)
- [ ] Deleted export folder from source machine
- [ ] Deleted export folder from target machine
- [ ] Deleted any zip files or copies
- [ ] Verified export is not in any git repository

---

## Questions?

If you're unsure whether a file contains sensitive information, assume it does and:
1. Do NOT use it directly
2. Recreate the configuration manually
3. Use fresh credentials

**When in doubt, regenerate credentials rather than reuse them.**
