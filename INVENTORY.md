# Dev Environment Inventory - VM1

**Generated:** 2026-01-17
**Source:** Ubuntu 25.10 VM (aarch64, Kernel 6.17.0-8-generic)
**Target:** MacOS VM with Homebrew
**User:** carlo

> **Note:** This inventory represents VM1 (the original export). This configuration has been **merged with VM2** to create the final unified export. See `INVENTORY-VM2.md` for VM2's configuration and `MERGE-REPORT.md` for detailed merge analysis.

---

## Table of Contents
1. [Shell Configuration](#shell-configuration)
2. [Claude Code Configuration](#claude-code-configuration)
3. [Dotfiles](#dotfiles)
4. [CLI Tools](#cli-tools)
5. [Environment Files](#environment-files)
6. [System-Level Dev Tools](#system-level-dev-tools)
7. [IDE/Editor Configuration](#ideeditor-configuration)
8. [Action Items](#action-items)

---

## Shell Configuration

### Files Overview

| File | Status | Notes |
|------|--------|-------|
| `~/.zshrc` | **Customized** | Main shell config with custom functions, aliases, PATH modifications |
| `~/.zprofile` | Does not exist | - |
| `~/.zshenv` | Does not exist | - |
| `~/.profile` | **Customized** | Forces zsh, adds PATH entries, sources codium env |
| `~/.bashrc` | Default Ubuntu | Standard Ubuntu bashrc |

### Oh-My-Zsh Configuration

| Component | Value | Notes |
|-----------|-------|-------|
| Installation | `~/.oh-my-zsh/` | Standard oh-my-zsh installation |
| Theme | `robbyrussell` | Default theme |
| Plugins | `git` | Only git plugin enabled |
| Custom Plugins | None | Only example plugin present |
| Custom Themes | None | Only example theme present |

### Custom Shell Functions

#### `venv()` - Python Virtual Environment Helper
Activates or auto-creates a Python virtual environment in the current directory or given folder.
- Searches for existing venvs (.venv, venv, env)
- Creates `.venv` if none found
- Auto-installs requirements.txt if present

### Custom Aliases

| Alias | Command | Purpose |
|-------|---------|---------|
| `cdsp` | `claude --dangerously-skip-permissions` | Quick Claude Code with no permission prompts |

### PATH Modifications (in order)

```
$HOME/.local/bin
/opt/homebrew/opt/python@3.13/libexec/bin
/opt/homebrew/sbin
/opt/homebrew/bin
$HOME/.npm-global/bin
```

**Note:** The Homebrew paths reference `/opt/homebrew/` which is the standard macOS Apple Silicon path. This config will work on Mac.

### Environment Variables Set in Shell Config

| Variable | Value | Contains Secrets |
|----------|-------|------------------|
| `OPENAI_API_KEY` | `sk-proj-5Ja5...` | **YES - REDACT BEFORE EXPORT** |
| `ZSH` | `$HOME/.oh-my-zsh` | No |
| `ZSH_THEME` | `robbyrussell` | No |
| `NVM_DIR` | `$HOME/.nvm` | No |
| `TMPDIR` | `$HOME/.tmp` | No |

---

## Claude Code Configuration

### Installation

| Component | Location | Version |
|-----------|----------|---------|
| Claude Code Binary | `~/.local/bin/claude` | 2.1.11 |
| Claude Code Config | `~/.claude/` | - |
| Symlink Points To | `~/snap/codium/496/.local/share/claude/versions/2.1.11` | - |

### Settings Files

#### `~/.claude/settings.json`
```json
{
  "statusLine": {
    "type": "command",
    "command": "/home/carlo/.claude/statusline-command.sh"
  },
  "enabledPlugins": {
    "taches-cc-resources@taches-cc-resources": true,
    "frontend-design@claude-plugins-official": true,
    "github@claude-plugins-official": true,
    "feature-dev@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "playwright@claude-plugins-official": true,
    "pyright-lsp@claude-plugins-official": true,
    "vercel@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true,
    "ralph-loop@claude-plugins-official": true
  }
}
```

#### `~/.claude/settings.local.json`
```json
{
  "permissions": {
    "allow": ["WebFetch(domain:docs.anthropic.com)"],
    "deny": [],
    "ask": []
  }
}
```

### Custom Commands

| Command | File | Description |
|---------|------|-------------|
| `/buddy` | `buddy.md` | Switch to sarcastic coding buddy mode with profanity and humor |
| `/casual` | `casual.md` | Casual coding helper with light personality |
| `/debug` | `debug.md` | Focused debugging mode with systematic approach |
| `/pair` | `pair.md` | Activate full pair programming partner mode with personality |
| `/prompt_engineer_command` | `prompt_engineer_command.md` | Transform stream-of-consciousness ideas into optimized XML prompts |
| `/serious` | `serious.md` | Switch back to professional mode |
| `/swear` | `swear.md` | Enable casual profanity and personality |

### Installed Plugins

| Plugin | Source | Purpose |
|--------|--------|---------|
| taches-cc-resources | Custom | Custom resources plugin |
| frontend-design | Official | Frontend design assistance |
| github | Official | GitHub integration |
| feature-dev | Official | Feature development assistance |
| context7 | Official | Context management |
| code-review | Official | Code review assistance |
| typescript-lsp | Official | TypeScript language server |
| security-guidance | Official | Security guidance |
| playwright | Official | Playwright testing |
| pyright-lsp | Official | Python type checking |
| vercel | Official | Vercel deployment |
| code-simplifier | Official | Code simplification |
| ralph-loop | Official | Ralph automation loop |

### Custom Statusline Script

Location: `~/.claude/statusline-command.sh`

Custom bash script that displays:
- Model name (Opus/Sonnet/Haiku + version)
- Context usage progress bar
- Token counts (used/total)
- Git branch and repo name

**Dependencies:** `jq`

### Directory Structure to Preserve

```
~/.claude/
├── commands/           # Custom slash commands (EXPORT)
├── settings.json       # Global settings (EXPORT)
├── settings.local.json # Local permissions (EXPORT)
├── statusline-command.sh # Custom statusline (EXPORT)
├── plugins/            # Plugin cache (WILL REINSTALL)
├── projects/           # Project-specific sessions (DO NOT EXPORT)
├── history.jsonl       # Session history (DO NOT EXPORT)
├── .credentials.json   # Auth credentials (DO NOT EXPORT - SECRETS)
└── cache/              # Cache files (DO NOT EXPORT)
```

---

## Dotfiles

### Git Configuration

#### `~/.gitconfig`

| Setting | Value | Notes |
|---------|-------|-------|
| user.name | Carlo Kruger | Personal name |
| user.email | ironicbuddha@gmail.com | Personal email |
| core.editor | `subl -n -w` | Sublime Text (requires installation) |
| core.autocrlf | input | Unix line endings |
| core.pager | `less -FXR` | Standard pager |
| init.defaultBranch | main | Modern default |
| push.default | simple | Standard push behavior |
| filter.lfs | configured | Git LFS enabled |
| credential (github.com) | gh auth | Uses GitHub CLI for auth |

**Aliases:**
- `st` = status
- `co` = checkout
- `br` = branch
- `ci` = commit
- `cm` = commit -m
- `lg` = log --oneline --graph --decorate
- `last` = log -1 HEAD

#### `~/.gitignore_global`

```
.DS_Store
node_modules/
*.log
.env
.vscode/
.idea/
*.pyc
__pycache__/
```

### Other Dotfiles

| File | Status | Notes |
|------|--------|-------|
| `~/.vimrc` | Does not exist | No vim customization |
| `~/.config/nvim/` | Does not exist | No neovim config |
| `~/.tmux.conf` | Does not exist | No tmux customization |
| `~/.ssh/config` | Does not exist | No SSH config |

### GitHub CLI Configuration

| Setting | Value |
|---------|-------|
| Location | `~/.config/gh/` |
| Git Protocol | HTTPS |
| GitHub User | carlokruger |

---

## CLI Tools

### Core Development Tools

| Tool | Current Version | Install Method | Homebrew Formula | Notes |
|------|-----------------|----------------|------------------|-------|
| Node.js | v20.19.5 | apt (nodejs) | `node` | Also have nvm |
| npm | 10.8.2 | apt (via nodejs) | (with node) | - |
| nvm | via script | `~/.nvm/` | `nvm` | Node v22.18.0 also installed |
| Python | 3.13.7 | apt | `python@3.13` | - |
| pip | 25.1.1 | apt | (with python) | - |
| Git | (system) | apt | `git` | With LFS |
| Docker | 28.2.2 | apt (docker.io) | `docker` | With MCP plugin |
| jq | (system) | apt | `jq` | JSON processor |
| curl | (system) | apt | `curl` | - |
| wget | (system) | apt | `wget` | - |
| zsh | (system) | apt | `zsh` | Default shell |

### Cloud & Infrastructure Tools

| Tool | Current Version | Install Method | Homebrew Formula | Notes |
|------|-----------------|----------------|------------------|-------|
| AWS CLI | 2.28.21 | Manual (`~/.local/aws-cli/`) | `awscli` | - |
| Terraform | 1.9.5 | Manual binary | `terraform` | Outdated (1.14.3 available) |
| GitHub CLI | 2.78.0 | Manual binary | `gh` | - |

### Claude Code

| Tool | Version | Install Method | Homebrew Formula |
|------|---------|----------------|------------------|
| Claude Code | 2.1.11 | npm/snap | `npm install -g @anthropic-ai/claude-code` |

### Build Tools (apt)

| Package | Homebrew Equivalent |
|---------|---------------------|
| build-essential | (Xcode Command Line Tools) |
| gcc | `gcc` |
| g++ | `gcc` (includes g++) |
| make | `make` |

### npm Global Packages

| Package | Version | Notes |
|---------|---------|-------|
| corepack | 0.33.0 | Package manager manager |
| npm | 10.8.2 | Package manager |

### pip User Packages

| Package | Version | Purpose |
|---------|---------|---------|
| annotated-types | 0.7.0 | Type annotations |
| greenlet | 3.2.4 | Concurrency |
| psycopg2-binary | 2.9.10 | PostgreSQL adapter |
| pydantic | 2.11.7 | Data validation |
| pydantic_core | 2.33.2 | Pydantic internals |
| shellingham | 1.5.4 | Shell detection |
| SQLAlchemy | 2.0.43 | ORM |
| typer | 0.17.4 | CLI framework |
| typing-inspection | 0.4.1 | Type inspection |

### Snap Packages

| Package | Notes | Mac Alternative |
|---------|-------|-----------------|
| codium | VSCodium | `brew install --cask vscodium` |
| chromium | Browser | `brew install --cask chromium` |
| firefox | Browser | `brew install --cask firefox` |

---

## Environment Files

### Shell-Defined Environment Variables

| Variable | Contains Secrets | Notes |
|----------|------------------|-------|
| `OPENAI_API_KEY` | **YES** | In ~/.zshrc - REMOVE BEFORE SHARING |

### Project .env Files Found

| File | Contains Secrets | Notes |
|------|------------------|-------|
| `~/dev/stablo-ironicbuddha/.env.production` | Likely | Production config |
| `~/dev/stablo-ironicbuddha/.env.local.example` | No | Example file |
| `~/dev/claude-label-manager/.env.example` | No | Example file |
| `~/dev/ironicbuddha/.env.local.example` | No | Example file |

### AWS Configuration

| File | Contains Secrets | Notes |
|------|------------------|-------|
| `~/.aws/config` | No | Region and profile settings |
| `~/.aws/credentials` | **YES** | AWS access keys - DO NOT EXPORT |

**AWS Profiles Configured:**
- `default` (region: af-south-1)
- `label-manager-setup` (region: us-east-1)
- `label-manager-deploy` (region: us-east-1)

### Claude Code Credentials

| File | Contains Secrets | Notes |
|------|------------------|-------|
| `~/.claude/.credentials.json` | **YES** | Auth tokens - DO NOT EXPORT |

### GitHub CLI Authentication

| File | Contains Secrets | Notes |
|------|------------------|-------|
| `~/.config/gh/hosts.yml` | **YES** | OAuth tokens - DO NOT EXPORT |

---

## System-Level Dev Tools

### Docker Configuration

| Component | Location | Notes |
|-----------|----------|-------|
| Docker Engine | apt (docker.io) | v28.2.2 |
| Docker Config | `~/.docker/config.json` | User config |
| Docker MCP Plugin | `~/.docker/cli-plugins/docker-mcp` | v0.35.0 |

### NVM (Node Version Manager)

| Component | Location | Notes |
|-----------|----------|-------|
| Installation | `~/.nvm/` | Via install script |
| Installed Versions | v22.18.0 | Via nvm |
| System Node | v20.19.5 | Via apt |

---

## IDE/Editor Configuration

### VSCodium (Primary Editor)

**Installation:** Snap package (`codium`)

#### User Settings (`~/.config/VSCodium/User/settings.json`)

```json
{
  "terminal.integrated.defaultProfile.linux": "zsh",
  "terminal.integrated.profiles.linux": {
    "zsh": {
      "path": "/usr/bin/zsh"
    }
  },
  "chatgpt.openOnStartup": true,
  "workbench.viewContainers.activitybar": {
    "codexViewContainer": true
  },
  "cSpell.languageSettings": []
}
```

#### Installed Extensions

| Extension | Publisher | Purpose |
|-----------|-----------|---------|
| anthropic.claude-code | Anthropic | Claude Code integration |
| bradlc.vscode-tailwindcss | Brad Cornes | Tailwind CSS IntelliSense |
| charliermarsh.ruff | Charlie Marsh | Python linter |
| christian-kohler.path-intellisense | Christian Kohler | Path autocompletion |
| davidanson.vscode-markdownlint | David Anson | Markdown linting |
| dbaeumer.vscode-eslint | Dirk Baeumer | ESLint integration |
| eamodio.gitlens | GitKraken | Git blame/history |
| editorconfig.editorconfig | EditorConfig | EditorConfig support |
| ericsia.pythonsnippets3 | Eric Sia | Python snippets |
| esbenp.prettier-vscode | Prettier | Code formatter |
| hbenl.vscode-test-explorer | Holger Benl | Test explorer |
| ms-python.debugpy | Microsoft | Python debugging |
| ms-python.python | Microsoft | Python support |
| ms-vscode.test-adapter-converter | Microsoft | Test adapter |
| openai.chatgpt | OpenAI | ChatGPT integration |
| redhat.vscode-yaml | Red Hat | YAML support |
| shd101wyy.markdown-preview-enhanced | shd101wyy | Markdown preview |
| streetsidesoftware.code-spell-checker | Street Side Software | Spell checker |
| stylelint.vscode-stylelint | Stylelint | CSS linting |

---

## Action Items

### Must Export (Copy to New Machine)

| Item | Source | Target | Notes |
|------|--------|--------|-------|
| ~/.zshrc | Copy | ~/.zshrc | **Remove OPENAI_API_KEY first** |
| ~/.profile | Copy | ~/.zprofile | Adapt for macOS |
| ~/.gitconfig | Copy | ~/.gitconfig | Update excludesfile path |
| ~/.gitignore_global | Copy | ~/.gitignore_global | - |
| ~/.claude/commands/ | Copy | ~/.claude/commands/ | All custom commands |
| ~/.claude/settings.json | Copy | ~/.claude/settings.json | Update statusline path |
| ~/.claude/settings.local.json | Copy | ~/.claude/settings.local.json | - |
| ~/.claude/statusline-command.sh | Copy | ~/.claude/statusline-command.sh | - |
| ~/.aws/config | Copy | ~/.aws/config | Profiles only |
| ~/.config/gh/config.yml | Copy | ~/.config/gh/config.yml | Git protocol config |
| VSCodium settings | Copy | VS Code settings | Adapt terminal paths |

### Secrets to Regenerate on New Machine

| Secret | Location | How to Regenerate |
|--------|----------|-------------------|
| OPENAI_API_KEY | ~/.zshrc | Create new key at platform.openai.com |
| AWS Credentials | ~/.aws/credentials | `aws configure` or create in AWS Console |
| GitHub CLI Auth | ~/.config/gh/hosts.yml | `gh auth login` |
| Claude Code Auth | ~/.claude/.credentials.json | `claude auth login` |

### Homebrew Installation Commands

```bash
# Core tools
brew install git git-lfs node nvm python@3.13 zsh jq curl wget

# Cloud & Infrastructure
brew install awscli terraform gh

# Build tools (via Xcode Command Line Tools)
xcode-select --install

# Docker
brew install --cask docker

# Editors
brew install --cask vscodium

# Browsers
brew install --cask chromium firefox

# Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Claude Code
npm install -g @anthropic-ai/claude-code

# pip packages
pip3 install --user psycopg2-binary pydantic sqlalchemy typer
```

### Linux-Specific Items (Need Mac Alternatives)

| Linux Item | Mac Alternative | Notes |
|------------|-----------------|-------|
| snap packages | Homebrew casks | Use `brew install --cask` |
| apt packages | Homebrew formulas | Use `brew install` |
| docker.io | Docker Desktop | Use `brew install --cask docker` |
| /usr/bin/zsh | /bin/zsh or brew zsh | Check path in terminal config |

### Path Adjustments for macOS

| Current Path | macOS Equivalent |
|--------------|------------------|
| `/usr/bin/zsh` | `/bin/zsh` or `/opt/homebrew/bin/zsh` |
| `/opt/homebrew/` | Already correct for Apple Silicon |
| `~/snap/codium/...` | Not applicable (use Homebrew) |

### Files to NOT Export (Contain Secrets or Machine-Specific)

- `~/.claude/.credentials.json`
- `~/.aws/credentials`
- `~/.config/gh/hosts.yml` (oauth_token)
- `~/.claude/history.jsonl`
- `~/.claude/projects/`
- Any `.env` files with actual secrets

---

## Export Checklist

- [ ] Remove OPENAI_API_KEY from zshrc before copying
- [ ] Update gitconfig excludesfile path for macOS
- [ ] Update terminal paths in VSCodium settings
- [ ] Update statusline-command.sh path in Claude settings
- [ ] Install Homebrew first on new Mac
- [ ] Run Homebrew installation commands
- [ ] Copy dotfiles and configs
- [ ] Re-authenticate: `gh auth login`, `aws configure`, `claude auth login`
- [ ] Install VSCodium extensions
- [ ] Install Claude Code plugins via `/plugins`
