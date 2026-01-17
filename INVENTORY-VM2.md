# Dev Environment Inventory - VM2

**Generated:** 2026-01-17
**Source:** Ubuntu 25.04 (Plucky Puffin) - aarch64, Kernel 6.14.0-36-generic
**Machine:** This Machine (VM2)
**User:** carlo

---

## Table of Contents
1. [Shell Configuration](#shell-configuration)
2. [Claude Code Configuration](#claude-code-configuration)
3. [Dotfiles](#dotfiles)
4. [CLI Tools](#cli-tools)
5. [System-Level Dev Tools](#system-level-dev-tools)
6. [IDE/Editor Configuration](#ideeditor-configuration)
7. [Key Differences from VM1](#key-differences-from-vm1)

---

## Shell Configuration

### Files Overview

| File | Status | Notes |
|------|--------|-------|
| `~/.zshrc` | **Customized** | Main shell config with custom functions, aliases, PATH modifications |
| `~/.zprofile` | Does not exist | - |
| `~/.zshenv` | Does not exist | - |
| `~/.profile` | **Customized** | Forces zsh, adds PATH entries |
| `~/.bashrc` | Default Ubuntu | Standard Ubuntu bashrc |

### Oh-My-Zsh Configuration

| Component | Value | Notes |
|-----------|-------|-------|
| Installation | `~/.oh-my-zsh/` | Standard oh-my-zsh installation |
| Theme | `robbyrussell` | Default theme |
| Plugins | `git` | Only git plugin enabled |

### Custom Shell Functions

#### `venv()` - Python Virtual Environment Helper
Activates or auto-creates a Python virtual environment in the current directory or given folder.
- Searches for existing venvs (.venv, venv, env)
- Creates `.venv` if none found
- Auto-installs requirements.txt if present
- Upgrades pip automatically

### Custom Aliases

| Alias | Command | Purpose |
|-------|---------|---------|
| `cdsp` | `claude --dangerously-skip-permissions` | Quick Claude Code with no permission prompts |

### PATH Modifications (in order)

```
$HOME/.local/bin
$HOME/.npm-global/bin
/opt/homebrew/bin
/opt/homebrew/sbin
/opt/homebrew/opt/python@3.13/libexec/bin
/usr/local/sbin
/usr/local/bin
/usr/sbin
/usr/bin
/sbin
/bin
/usr/games
/usr/local/games
/snap/bin
```

**Note:** The Homebrew paths reference `/opt/homebrew/` but Homebrew is NOT actually installed on this machine. These are legacy paths from configuration that was copied.

### Environment Variables Set in Shell Config

| Variable | Value | Contains Secrets |
|----------|-------|------------------|
| `ZSH` | `$HOME/.oh-my-zsh` | No |
| `ZSH_THEME` | `robbyrussell` | No |
| `NVM_DIR` | `$HOME/.nvm` | No |
| `PATH` | See above | No |

**No API keys or secrets found in shell config (clean!)**

---

## Claude Code Configuration

### Installation

| Component | Location | Version |
|-----------|----------|---------|
| Claude Code Binary | `~/.local/bin/claude` | 2.1.11 |
| Claude Code Config | `~/.claude/` | - |

### Settings Files

#### `~/.claude/settings.json`
**Does not exist** - Using default settings

#### `~/.claude/settings.local.json`
```json
{
  "permissions": {
    "allow": [
      "WebFetch(domain:docs.anthropic.com)"
    ],
    "deny": [],
    "ask": []
  }
}
```

### Custom Commands (24 files)

**Main Commands:**
| Command | File | Description |
|---------|------|-------------|
| `/add-to-todos` | `add-to-todos.md` | Add todo item to TO-DOS.md with context |
| `/audit-skill` | `audit-skill.md` | Audit skill for YAML compliance |
| `/audit-slash-command` | `audit-slash-command.md` | Audit slash command file |
| `/audit-subagent` | `audit-subagent.md` | Audit subagent configuration |
| `/buddy` | `buddy.md` | Switch to sarcastic coding buddy mode |
| `/casual` | `casual.md` | Casual coding helper with light personality |
| `/check-todos` | `check-todos.md` | List outstanding todos |
| `/create-agent-skill` | `create-agent-skill.md` | Create or edit Claude Code skills |
| `/create-hook` | `create-hook.md` | Expert guidance on Claude Code hooks |
| `/create-meta-prompt` | `create-meta-prompt.md` | Create optimized prompts for Claude-to-Claude pipelines |
| `/create-plan` | `create-plan.md` | Create hierarchical project plans |
| `/create-prompt` | `create-prompt.md` | Create a new prompt that another Claude can execute |
| `/create-slash-command` | `create-slash-command.md` | Create a new slash command |
| `/create-subagent` | `create-subagent.md` | Create specialized Claude Code subagents |
| `/debug` | `debug.md` | Focused debugging mode with systematic approach |
| `/heal-skill` | `heal-skill.md` | Heal skill documentation by applying corrections |
| `/pair` | `pair.md` | Activate full pair programming partner mode |
| `/prompt_engineer_command` | `prompt_engineer_command.md` | Transform stream-of-consciousness ideas into optimized XML prompts |
| `/run-plan` | `run-plan.md` | Execute a PLAN.md file directly |
| `/run-prompt` | `run-prompt.md` | Delegate one or more prompts to fresh sub-task contexts |
| `/serious` | `serious.md` | Switch back to professional mode |
| `/swear` | `swear.md` | Enable casual profanity and personality |
| `/whats-next` | `whats-next.md` | Analyze conversation and create handoff document |

**Consider Commands (12 files in consider/ subdirectory):**
- `/consider:10-10-10` - Evaluate decisions across three time horizons
- `/consider:5-whys` - Drill to root cause by asking why repeatedly
- `/consider:eisenhower-matrix` - Apply urgent/important matrix to prioritize
- `/consider:first-principles` - Break down to fundamentals
- `/consider:inversion` - Solve problems backwards
- `/consider:occams-razor` - Find simplest explanation
- `/consider:one-thing` - Identify the single highest-leverage action
- `/consider:opportunity-cost` - Analyze what you give up by choosing
- `/consider:pareto` - Apply Pareto's principle (80/20 rule)
- `/consider:second-order` - Think through consequences of consequences
- `/consider:swot` - Map strengths, weaknesses, opportunities, threats
- `/consider:via-negativa` - Improve by removing rather than adding

### Custom Statusline Script

**Does not exist** - Using default Claude Code statusline

### Directory Structure

```
~/.claude/
├── commands/           # Custom slash commands (24 files)
│   └── consider/       # Consider subcommands (12 files)
├── settings.local.json # Local permissions
├── plugins/            # Plugin cache
├── projects/           # Project-specific sessions
├── history.jsonl       # Session history
├── .credentials.json   # Auth credentials (SECRETS)
└── cache/              # Cache files
```

**Missing compared to VM1:**
- `settings.json` (global settings)
- `statusline-command.sh` (custom statusline)

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
| core.excludesfile | `/Users/carlo/.gitignore_global` | **macOS path (incorrect for this VM)** |
| color.ui | auto | Color output |
| init.defaultBranch | main | Modern default |
| push.default | simple | Standard push behavior |
| filter.lfs | configured | Git LFS enabled |

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

**Not configured** - `~/.config/gh/` does not exist

---

## CLI Tools

### Core Development Tools

| Tool | Current Version | Install Method | Location | Notes |
|------|-----------------|----------------|----------|-------|
| Node.js | v20.19.6 | apt (nodejs) | `/usr/bin/node` | System install |
| npm | 10.8.2 | apt (via nodejs) | `/usr/bin/npm` | System install |
| nvm | via script | `~/.nvm/` | N/A | Node v22.18.0 also installed |
| Python | 3.13.3 | apt | `/usr/bin/python3` | System install |
| pip | 25.0 | apt | `/usr/bin/pip3` | System install |
| Git | 2.48.1 | apt | `/usr/bin/git` | With LFS |
| Docker | **NOT INSTALLED** | - | - | - |
| jq | 1.7 | apt | `/usr/bin/jq` | JSON processor |
| curl | (system) | apt | `/usr/bin/curl` | - |
| wget | (system) | apt | `/usr/bin/wget` | - |
| zsh | (system) | apt | `/usr/bin/zsh` | Default shell |

### Cloud & Infrastructure Tools

| Tool | Status | Notes |
|------|--------|-------|
| AWS CLI | **NOT INSTALLED** | - |
| Terraform | **NOT INSTALLED** | - |
| GitHub CLI | **NOT INSTALLED** | - |

### Claude Code

| Tool | Version | Install Method | Location |
|------|---------|----------------|----------|
| Claude Code | 2.1.11 | npm global | `~/.local/bin/claude` |

### npm Global Packages

| Package | Version | Notes |
|---------|---------|-------|
| corepack | 0.34.1 | Package manager manager |
| npm | 10.8.2 | Package manager |

**Claude Code not installed as global npm package** - Installed via different method

### pip User Packages

**No user packages installed** - All packages are system-wide via apt

### Snap Packages

| Package | Version | Notes |
|---------|---------|-------|
| codium | 1.105.17075 | VSCodium (classic) |
| chromium | 142.0.7444.175 | Browser |
| firefox | 145.0.2-1 | Browser |
| gitkraken | 4.0.2 | Git GUI client |

---

## System-Level Dev Tools

### Docker Configuration

**Docker NOT installed on this machine**

### NVM (Node Version Manager)

| Component | Location | Notes |
|-----------|----------|-------|
| Installation | `~/.nvm/` | Via install script |
| Installed Versions | v22.18.0 | Via nvm |
| System Node | v20.19.6 | Via apt |

**No Homebrew NVM integration** - Homebrew not installed

---

## IDE/Editor Configuration

### VSCodium (Primary Editor)

**Installation:** Snap package (`codium`) - Version 1.105.17075

#### User Settings (`~/.config/VSCodium/User/settings.json`)

```json
{
    "terminal.integrated.defaultProfile.linux": "zsh",
    "terminal.integrated.profiles.linux": {
        "zsh": {
            "path": "/usr/bin/zsh"
        }
    }
}
```

**Minimal configuration** - Only terminal profile set

#### Installed Extensions (4 total)

| Extension | Publisher | Purpose |
|-----------|-----------|---------|
| anthropic.claude-code | Anthropic | Claude Code integration |
| ericsia.pythonsnippets3 | Eric Sia | Python snippets |
| ms-python.debugpy | Microsoft | Python debugging |
| ms-python.python | Microsoft | Python support |

**Much smaller extension set than VM1** (VM1 had 20+ extensions)

---

## Key Differences from VM1

### Major Differences

| Aspect | VM1 | VM2 (This Machine) |
|--------|-----|-------------------|
| **OS Version** | Ubuntu 25.10 | Ubuntu 25.04 |
| **Kernel** | 6.17.0-8-generic | 6.14.0-36-generic |
| **Homebrew** | Referenced in config | **Not actually installed** |
| **Docker** | Installed (v28.2.2) | **Not installed** |
| **AWS CLI** | Installed (v2.28.21) | **Not installed** |
| **Terraform** | Installed (v1.9.5) | **Not installed** |
| **GitHub CLI** | Installed (v2.78.0) | **Not installed** |
| **Python Version** | 3.13.7 | 3.13.3 |
| **Node Version** | v20.19.5 | v20.19.6 |
| **pip Packages** | 9 user packages | 0 user packages |
| **VSCodium Extensions** | 20+ extensions | 4 extensions |
| **Claude Commands** | 7 commands | 24 commands (incl. consider) |
| **Claude settings.json** | Present (with plugins) | **Missing** |
| **Claude statusline** | Custom script | **Missing** |
| **Snap packages** | codium, chromium, firefox | codium, chromium, firefox, gitkraken |

### Configuration Anomalies

1. **Homebrew paths in config but Homebrew not installed**
   - `~/.zshrc` references `/opt/homebrew/` paths
   - These directories don't exist on this machine
   - Appears to be copy-pasted from macOS config

2. **Git excludesfile points to macOS path**
   - `core.excludesfile = /Users/carlo/.gitignore_global`
   - Should be `/home/carlo/.gitignore_global` for Linux

3. **Shell config expects Homebrew-installed nvm**
   - `.zshrc` sources `/opt/homebrew/opt/nvm/nvm.sh`
   - This path doesn't exist (nvm installed via script instead)

### Installed Tools Summary

**Only on VM1:**
- Docker (v28.2.2)
- AWS CLI (v2.28.21)
- Terraform (v1.9.5)
- GitHub CLI (v2.78.0)
- All pip user packages (pydantic, sqlalchemy, typer, etc.)
- Most VSCodium extensions
- Claude Code plugins configuration
- Custom statusline script

**Only on VM2:**
- GitKraken (snap package)
- Extended Claude command set (consider/ commands)
- More recent snap package versions

**Common to Both:**
- Node.js (system + nvm)
- Python 3.13
- Git with LFS
- jq, curl, wget, zsh
- Oh-My-Zsh with robbyrussell theme
- VSCodium (via snap)
- Chromium, Firefox (via snap)
- Basic Claude Code setup
- Git configuration
- Global gitignore
- venv() function
- cdsp alias

---

## Export Notes

### What Works on VM2

- Basic development with Node.js and Python
- Git operations
- Claude Code with custom commands
- VSCodium for editing
- Web browsing (Chromium, Firefox)

### What Doesn't Work on VM2

- Homebrew commands (referenced but not installed)
- Docker operations
- AWS deployments
- Terraform infrastructure
- GitHub CLI operations
- Advanced Python packages (pydantic, sqlalchemy, etc.)

### Configuration Cleanup Needed

1. Remove Homebrew paths from `.zshrc` (not installed)
2. Fix git excludesfile path in `.gitconfig`
3. Update nvm sourcing in `.zshrc` (use script path, not Homebrew)
4. Install missing cloud tools if needed
5. Add Claude `settings.json` with plugin configuration
6. Add custom statusline script

---

## Recommendations for VM2

### If Keeping Linux (Ubuntu)

1. **Remove Homebrew references** from shell config
2. **Fix git config** to use Linux paths
3. **Install missing tools** via apt:
   ```bash
   sudo apt install docker.io awscli terraform gh
   ```
4. **Install pip packages** user-level:
   ```bash
   pip3 install --user pydantic sqlalchemy typer psycopg2-binary
   ```
5. **Add Claude settings.json** from VM1
6. **Add statusline script** from VM1 (if desired)

### If Migrating to macOS

Follow the existing export scripts in `./scripts/` - they are designed for macOS with Homebrew.

---

## Summary

VM2 is a **partially configured development machine** with:
- ✅ Basic development tools (Node, Python, Git)
- ✅ Claude Code with extensive command library
- ✅ Minimal editor setup
- ❌ Missing cloud/infrastructure tools (Docker, AWS, Terraform, GitHub CLI)
- ❌ Configuration inconsistencies (Homebrew paths on Linux)
- ❌ Missing pip packages
- ❌ Missing Claude plugins configuration

VM2 appears to be a **test/experimental machine** while VM1 is the **fully configured production environment**.
