# Dev Environment Export

**Exported:** 2026-01-17
**Source:** Ubuntu VMs (aarch64) - **Merged from VM1 + VM2**
**Target:** macOS with Homebrew (Apple Silicon)
**User:** carlo

---

## Overview

This export contains a **merged configuration** from two Ubuntu development VMs, combining the best of both environments into a unified set of installation scripts for macOS deployment.

**Configuration Sources:**
- **VM1** (Ubuntu 25.10): Full production environment with cloud tools, extensive VSCodium extensions, and pip packages
- **VM2** (Ubuntu 25.04): Enhanced Claude Code setup with 24 custom commands including thinking frameworks

See `INVENTORY.md` (VM1), `INVENTORY-VM2.md` (VM2), and `MERGE-REPORT.md` for detailed comparison.

### What's Included

| Directory | Contents |
|-----------|----------|
| `shell/` | Zsh configuration files (.zshrc, .zprofile) |
| `claude/` | Claude Code settings, custom commands, statusline script |
| `dotfiles/` | Git, AWS, and GitHub CLI configurations |
| `editor/` | VSCodium/VS Code settings and extension list |
| `env/` | Environment files (review for secrets!) |
| `scripts/` | Automated installation scripts |

---

## Quick Start

### 1. Transfer to Mac

```bash
# On Linux VM - create archive
cd ~
zip -r dev-env-export.zip dev-env-export/

# Transfer to Mac (via USB, cloud storage, scp, etc.)
# Then on Mac:
cd ~
unzip dev-env-export.zip
cd dev-env-export
```

### 2. Run Installation Scripts (in order)

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run each script in order
./scripts/01-install-brew.sh      # Homebrew + core tools
./scripts/02-install-cli-tools.sh  # Dev tools + applications
./scripts/03-install-npm-globals.sh # npm packages + Claude Code
./scripts/04-install-pip-packages.sh # Python packages
./scripts/05-setup-dotfiles.sh     # Copy configuration files
./scripts/06-setup-claude.sh       # Set up Claude Code
```

### 3. Post-Installation Steps

After running all scripts, complete these manual steps:

```bash
# Restart your terminal to load new shell configuration
exec zsh

# Authenticate services
gh auth login          # GitHub CLI
aws configure          # AWS credentials (if needed)
claude auth login      # Claude Code

# Install VSCodium extensions
cat editor/extensions-list.txt | grep -v '^#' | xargs -L1 codium --install-extension

# Install Claude Code plugins (inside Claude Code)
# Run: /plugins and enable the plugins listed below
```

---

## Detailed Contents

### Shell Configuration (`shell/`)

| File | Target Location | Description |
|------|-----------------|-------------|
| `zshrc` | `~/.zshrc` | Main shell config with aliases, functions, PATH |
| `zprofile` | `~/.zprofile` | Login shell config (replaces .profile) |

**Custom Functions:**
- `venv()` - Activate or create Python virtual environments
- `cdsp` alias - Run Claude Code without permission prompts

**PATH entries configured:**
- `~/.local/bin`
- `/opt/homebrew/bin` and `/opt/homebrew/sbin`
- `/opt/homebrew/opt/python@3.13/libexec/bin`
- `~/.npm-global/bin`

### Claude Code Configuration (`claude/`)

| File | Target Location | Description |
|------|-----------------|-------------|
| `settings/settings.json` | `~/.claude/settings.json` | Global settings + enabled plugins (VM1) |
| `settings/settings.local.json` | `~/.claude/settings.local.json` | Permission settings |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Custom statusline (VM1) |
| `commands/*.md` | `~/.claude/commands/` | **24 custom slash commands (merged from both VMs)** |
| `commands/consider/*.md` | `~/.claude/commands/consider/` | **12 thinking framework commands (VM2)** |

**Custom Commands (24 total):**
- Core modes: `/buddy`, `/casual`, `/debug`, `/pair`, `/serious`, `/swear`
- Command creation: `/prompt_engineer_command`, `/create-prompt`, `/create-slash-command`, `/create-agent-skill`, `/create-hook`, `/create-meta-prompt`, `/create-plan`, `/create-subagent`
- Project management: `/add-to-todos`, `/check-todos`, `/whats-next`, `/run-plan`, `/run-prompt`
- Quality assurance: `/audit-skill`, `/audit-slash-command`, `/audit-subagent`, `/heal-skill`

**Consider Commands (12 thinking frameworks from VM2):**
- `/consider:10-10-10` - Evaluate across time horizons
- `/consider:5-whys` - Root cause analysis
- `/consider:eisenhower-matrix` - Prioritization matrix
- `/consider:first-principles` - Fundamental reasoning
- `/consider:inversion` - Solve problems backwards
- `/consider:occams-razor` - Simplest explanation
- `/consider:one-thing` - Highest-leverage action
- `/consider:opportunity-cost` - Trade-off analysis
- `/consider:pareto` - 80/20 rule
- `/consider:second-order` - Consequences of consequences
- `/consider:swot` - Strengths/weaknesses/opportunities/threats
- `/consider:via-negativa` - Improve by removing

**Enabled Plugins (VM1):**
- taches-cc-resources (custom)
- frontend-design, github, feature-dev, context7, code-review
- typescript-lsp, security-guidance, playwright, pyright-lsp
- vercel, code-simplifier, ralph-loop

### Dotfiles (`dotfiles/`)

| File | Target Location | Description |
|------|-----------------|-------------|
| `gitconfig` | `~/.gitconfig` | Git aliases, user info, LFS config |
| `gitignore_global` | `~/.gitignore_global` | Global ignore patterns |
| `aws-config` | `~/.aws/config` | AWS profiles (no credentials) |
| `gh-config.yml` | `~/.config/gh/config.yml` | GitHub CLI settings |

### Editor Configuration (`editor/`)

| File | Target Location | Description |
|------|-----------------|-------------|
| `vscodium-settings.json` | See file header | VSCodium/VS Code settings |
| `extensions-list.txt` | N/A | List of extensions to install |

### Environment Files (`env/`)

| File | Description |
|------|-------------|
| `stablo-ironicbuddha.env.production` | Sanity CMS config for stablo project |
| `README-ENV.md` | Documentation about env files |

---

## Linux to Mac Differences

### Path Changes

| Linux Path | macOS Path |
|------------|------------|
| `/usr/bin/zsh` | `/bin/zsh` or `/opt/homebrew/bin/zsh` |
| `/home/carlo/` | `/Users/carlo/` |
| `~/.local/bin/gh` | `/opt/homebrew/bin/gh` |

### Package Manager Equivalents

| Linux (apt/snap) | macOS (Homebrew) |
|------------------|------------------|
| `apt install nodejs` | `brew install node` |
| `snap install codium` | `brew install --cask vscodium` |
| `apt install docker.io` | `brew install --cask docker` |
| `apt install build-essential` | `xcode-select --install` |

### Notes

1. **Homebrew paths** in the exported configs already use `/opt/homebrew/` which is correct for Apple Silicon Macs
2. **Snap** is not available on macOS - all snap packages have Homebrew cask equivalents
3. **Docker** runs as Docker Desktop on macOS (GUI app) vs daemon on Linux

---

## Installed Tools Summary

### CLI Tools (via Homebrew)
- git, git-lfs, jq, curl, wget, zsh
- node, nvm, python@3.13
- awscli, terraform, gh
- make, gcc

### Applications (via Homebrew Cask)
- Docker Desktop (VM1)
- VSCodium (both VMs)
- Chromium, Firefox (both VMs)
- Sublime Text (VM1)
- GitKraken (VM2) - Git GUI client

### npm Global Packages
- @anthropic-ai/claude-code
- corepack

### pip Packages
- pydantic, sqlalchemy, typer
- psycopg2-binary, greenlet
- annotated-types, typing-inspection, shellingham

---

## Troubleshooting

### Claude Code not found after installation
Ensure `~/.npm-global/bin` is in your PATH:
```bash
export PATH="$HOME/.npm-global/bin:$PATH"
```

### Homebrew commands not found
For Apple Silicon Macs, run:
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Oh My Zsh not loading
Ensure `$ZSH` is set correctly in `~/.zshrc`:
```bash
export ZSH="$HOME/.oh-my-zsh"
```

### Git credential helper errors
Re-authenticate with GitHub CLI:
```bash
gh auth login
```

---

## Security Reminders

1. **Review SECRETS-WARNING.md** before using on new machine
2. **Rotate the OPENAI_API_KEY** in `~/.zshrc` after migration
3. **Re-authenticate** all services (AWS, GitHub, Claude) on new machine
4. **Delete this export folder** after migration is complete
5. **Do NOT commit** this folder to version control

---

## Merge Information

This export represents a **merged configuration** from two VMs:

**VM1 Contributions:**
- Complete cloud tooling (Docker, AWS CLI, Terraform, GitHub CLI)
- 9 pip packages for Python development
- 20+ VSCodium extensions
- Claude Code plugin configuration and custom statusline
- AWS and GitHub CLI configurations
- Original 7 Claude commands

**VM2 Contributions:**
- Extended Claude command library (24 commands total, adding 17 new)
- 12 thinking framework commands in `/consider` subdirectory
- GitKraken Git GUI application

**Result:** A comprehensive development environment that combines the production readiness of VM1 with the enhanced Claude Code capabilities of VM2.

For detailed merge analysis, see:
- `INVENTORY.md` - VM1 full configuration
- `INVENTORY-VM2.md` - VM2 full configuration
- `MERGE-REPORT.md` - Detailed comparison and merge decisions

## File Checksums

For verification, here are the file counts:

```
shell/       2 files
claude/      38 files (settings + statusline + 24 commands + 12 consider commands)
dotfiles/    4 files
editor/      2 files
env/         2 files
scripts/     6 files
docs/        3 files (INVENTORY.md, INVENTORY-VM2.md, MERGE-REPORT.md)
```

Total: ~57 configuration files + documentation
