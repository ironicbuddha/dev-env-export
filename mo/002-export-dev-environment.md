<objective>
Export all dev environment configuration files to ~/dev-env-export/ and generate Homebrew installation scripts for MacOS migration.

This is phase 2 of the environment migration. The inventory has been created - now we need to actually copy the files and create the setup scripts.
</objective>

<context>
Source: Ubuntu Linux VM
Target: MacOS VM with Homebrew
Inventory location: ~/dev-env-export/INVENTORY.md
Export location: ~/dev-env-export/

IMPORTANT: .env files and secrets WILL be included. A prominent warning will be added to review these before use on the new machine.
</context>

<requirements>
Based on the inventory, export all configuration files and create installation scripts:

1. **Copy Configuration Files**
   Organize exports into subdirectories:

   ```
   ~/dev-env-export/
   ├── INVENTORY.md (from phase 1)
   ├── README.md (setup instructions)
   ├── SECRETS-WARNING.md
   ├── shell/
   │   ├── zshrc
   │   ├── zprofile
   │   └── [other shell configs]
   ├── claude/
   │   ├── commands/
   │   ├── plugins/
   │   ├── settings/
   │   └── mcp/
   ├── dotfiles/
   │   ├── gitconfig
   │   ├── gitignore_global
   │   ├── vimrc
   │   └── [others]
   ├── env/
   │   └── [.env files - HANDLE WITH CARE]
   └── scripts/
       ├── 01-install-brew.sh
       ├── 02-install-cli-tools.sh
       ├── 03-install-npm-globals.sh
       ├── 04-install-pip-packages.sh
       ├── 05-setup-dotfiles.sh
       └── 06-setup-claude.sh
   ```

2. **Generate Installation Scripts**
   Each script should be executable and idempotent (safe to run multiple times).

   **01-install-brew.sh**
   - Install Homebrew if not present
   - Install core CLI tools via brew

   **02-install-cli-tools.sh**
   - All CLI tools from inventory with brew formulas
   - Include `brew install` and `brew install --cask` as appropriate

   **03-install-npm-globals.sh**
   - All global npm packages
   - Consider using volta or nvm for Node version management

   **04-install-pip-packages.sh**
   - All global pip packages
   - Consider using pyenv for Python version management

   **05-setup-dotfiles.sh**
   - Symlink or copy dotfiles to appropriate locations
   - Backup existing files before overwriting

   **06-setup-claude.sh**
   - Copy Claude Code configs to ~/.claude/
   - Set up any required MCP servers

3. **Create Documentation**

   **README.md** should include:
   - Overview of what's included
   - Step-by-step setup instructions
   - Order to run scripts
   - Manual steps required
   - Known differences between Linux and Mac configs

   **SECRETS-WARNING.md**:

   ```markdown
   # ⚠️ SECRETS WARNING ⚠️

   This export contains files with sensitive information:

   [list all .env files and files with potential secrets]

   BEFORE using on new machine:

   1. Review ALL files in env/ directory
   2. Rotate any exposed credentials
   3. Update secrets to new machine-specific values
   4. Do NOT commit this folder to version control
   5. Delete after migration is complete
   ```

   </requirements>

<implementation>
For each configuration file:
1. Read the original file
2. Copy to appropriate subdirectory in ~/dev-env-export/
3. Note any Linux-specific paths that need Mac adjustment

For installation scripts:

- Use `#!/bin/bash` with `set -e` for error handling
- Add comments explaining each section
- Include version pinning where important
- Add echo statements for progress feedback

Handle path differences:

- Linux: ~/.local/bin → Mac: ~/bin or /usr/local/bin
- Linux package names → Homebrew formula names
- Any Linux-specific configs that need Mac equivalents
  </implementation>

<output>
Complete the ~/dev-env-export/ directory with:
- All configuration files organized by category
- All installation scripts in scripts/
- README.md with full setup instructions
- SECRETS-WARNING.md listing sensitive files

The result should be a self-contained folder that can be:

1. Zipped and transferred to the Mac
2. Unzipped
3. Scripts run in order to recreate the environment
   </output>

<verification>
Before completing, verify:
- All files from inventory have been exported
- All scripts have proper shebang and are marked executable (chmod +x)
- README includes complete setup sequence
- SECRETS-WARNING lists every file containing potential secrets
- No hardcoded Linux-specific paths remain in config files (or are documented)
</verification>

<success_criteria>

- ~/dev-env-export/ contains all config files organized by category
- All 6 installation scripts created and executable
- README.md provides clear step-by-step setup guide
- SECRETS-WARNING.md lists all sensitive files
- Export is ready to zip and transfer to MacOS
  </success_criteria>
