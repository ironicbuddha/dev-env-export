<objective>
Create a comprehensive inventory of the current Ubuntu development environment configuration.

This inventory will be used to replicate the environment on a new MacOS VM, so we need to capture everything that makes this dev setup work - from shell config to CLI tools to Claude Code customizations.
</objective>

<context>
Current environment: Ubuntu Linux VM
Target environment: MacOS VM (will use Homebrew for package management)
Purpose: Template this VM's configuration for replication

Key areas to inventory:

- Shell configuration (zsh)
- Claude Code configuration (commands, plugins, MCP servers, settings)
- Dotfiles (git, vim, tmux, etc.)
- CLI tools and applications
- Environment variables and .env files
- Any other dev tooling customizations
  </context>

<requirements>
Thoroughly investigate and document the following categories:

1. **Shell Configuration**
   - ~/.zshrc and any sourced files
   - ~/.zprofile, ~/.zshenv if they exist
   - Oh-my-zsh or other framework configs
   - Custom aliases, functions, PATH modifications
   - Shell plugins and themes

2. **Claude Code Configuration**
   - ~/.claude/ directory contents
   - Custom slash commands
   - Installed plugins/extensions
   - MCP server configurations
   - settings.json or equivalent config files
   - Any project-level .claude/ configs

3. **Dotfiles**
   - ~/.gitconfig and ~/.gitignore_global
   - ~/.vimrc or ~/.config/nvim/
   - ~/.tmux.conf
   - ~/.ssh/config (structure only, not keys)
   - Any other ~/.[config] files that appear customized

4. **CLI Tools & Applications**
   - List all manually installed CLI tools (not system defaults)
   - Node.js/npm global packages
   - Python/pip global packages
   - Go binaries
   - Rust/cargo binaries
   - Any other language-specific tooling

5. **Environment & Secrets**
   - ~/.env files or global environment configs
   - Any .env files in common project locations
   - Environment variables set in shell configs

6. **System-Level Dev Tools**
   - Docker configuration
   - Database clients/tools
   - Cloud CLI tools (aws, gcloud, az, etc.)
   - Any IDE/editor configs outside of dotfiles
     </requirements>

<implementation>
Use bash commands to discover and catalog each category:

```bash
# Example discovery commands to run:
ls -la ~/.claude/
cat ~/.zshrc
which node npm python pip go cargo rustc
npm list -g --depth=0
pip list --user
ls -la ~/.*
```

For each item found, note:

- The file path or tool name
- Whether it's default or customized
- Any dependencies or prerequisites
- The equivalent Homebrew package (if known)
  </implementation>

<output>
Create a detailed inventory file at: `~/dev-env-export/INVENTORY.md`

Structure the inventory as:

```markdown
# Dev Environment Inventory

Generated: [date]
Source: Ubuntu VM

## Shell Configuration

| File     | Status     | Notes                |
| -------- | ---------- | -------------------- |
| ~/.zshrc | Customized | [key customizations] |

## Claude Code Configuration

[list all configs and their purposes]

## Dotfiles

[table of files with customization status]

## CLI Tools

### Homebrew Equivalents

| Tool | Current Install Method | Brew Formula |
| ---- | ---------------------- | ------------ |

### npm Global Packages

[list]

### pip Global Packages

[list]

## Environment Files

| File | Contains Secrets | Notes |
| ---- | ---------------- | ----- |

## Action Items

[any tools that may not have direct Mac equivalents]
```

Also create: `~/dev-env-export/` directory structure for the export phase.
</output>

<verification>
Before completing, verify:
- All major config directories have been checked (~/.claude, ~/.config, ~/.local, etc.)
- The inventory includes Homebrew formula names where possible
- Files with secrets are clearly marked
- Any Linux-specific tools are flagged with Mac alternatives
</verification>

<success_criteria>

- Comprehensive INVENTORY.md created at ~/dev-env-export/
- All categories from requirements are covered
- Each item includes enough context for the export phase
- Mac/Homebrew equivalents identified where applicable
  </success_criteria>
