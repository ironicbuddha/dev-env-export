<objective>
Capture the development environment configuration of THIS current machine (VM2) and intelligently merge it with the existing VM1 configuration to create unified installation scripts that support both environments.

This is the continuation of the dev environment export process. VM1's configuration has already been captured and exported to this folder. Now we need to inventory VM2 (the current machine), compare it with VM1, and create merged installation scripts.
</objective>

<context>
Existing files from VM1:
- ./INVENTORY.md - VM1's complete configuration inventory
- ./scripts/*.sh - Installation scripts based on VM1's config
- ./README.md - Setup documentation for VM1
- ./shell/, ./claude/, ./dotfiles/, ./env/, ./editor/ - VM1's actual config files

Current situation:
- We are running on VM2 (a different machine than VM1)
- Need to capture VM2's configuration
- Need to merge VM2's config with VM1's existing setup
- Goal: Create universal scripts that work for both VMs

@INVENTORY.md
@scripts/
@README.md
</context>

<requirements>
This is a two-phase task that must be completed thoroughly:

## Phase 1: Capture VM2 Configuration

Inventory THIS machine's complete dev environment:

1. **System Information**
   - OS version and kernel (uname -a, /etc/os-release)
   - Architecture (x86_64 vs aarch64)
   - Username

2. **Shell Configuration**
   - ~/.zshrc and all sourced files
   - ~/.zprofile, ~/.profile, ~/.zshenv
   - Oh-my-zsh configuration (theme, plugins)
   - Custom functions and aliases
   - PATH modifications
   - Environment variables (note which contain secrets)

3. **Claude Code Configuration**
   - ~/.claude/ directory structure
   - Custom slash commands in ~/.claude/commands/
   - Enabled plugins/skills
   - Settings files (settings.json, settings.local.json)
   - Custom statusline if present

4. **Dotfiles**
   - ~/.gitconfig and ~/.gitignore_global
   - ~/.aws/config (not credentials)
   - ~/.config/gh/config.yml
   - Any other customized dotfiles

5. **CLI Tools & Package Managers**
   - Homebrew packages: `brew list` (if brew installed)
   - npm global packages: `npm list -g --depth=0`
   - pip packages: `pip list` or `pip3 list`
   - Manually installed tools in ~/.local/bin
   - Identify Homebrew formula names for each tool

6. **Editor Configuration**
   - VSCodium/VS Code settings
   - Installed extensions list

7. **Environment Files**
   - Any .env files (mark which contain secrets)

## Phase 2: Compare VM1 and VM2

Thoroughly analyze both inventories to identify:

1. **Common Baseline** - Packages/configs in BOTH VMs
2. **VM1-Specific** - Only in VM1's INVENTORY.md
3. **VM2-Specific** - Only in this machine (VM2)
4. **Conflicts** - Same tool but different versions or configurations

For each category, document:
- Exact package/tool names
- Versions where applicable
- Configuration differences
- Homebrew formula names

## Phase 3: Merge and Update Installation Scripts

Update ALL scripts in ./scripts/ to support both VMs:

**01-install-brew.sh**
- Include all Homebrew formulas from both VMs
- Add clear comments: "# Common to both VMs", "# VM1-specific", "# VM2-specific"

**02-install-cli-tools.sh**
- Merge CLI tools from both VMs
- Group by commonality
- Document version differences in comments

**03-install-npm-globals.sh**
- Union of all npm packages from both VMs
- Note if versions differ

**04-install-pip-packages.sh**
- Union of all pip packages from both VMs
- Note version conflicts

**05-setup-dotfiles.sh**
- For identical configs: keep single version
- For different configs: create both with suffixes (-vm1, -vm2) and document choice
- Update script to handle conditional setup

**06-setup-claude.sh**
- Merge Claude commands (union of both sets)
- Merge enabled plugins (union)
- Handle conflicting settings

## Phase 4: Documentation

1. **Create ./INVENTORY-VM2.md**
   - Complete inventory of THIS machine
   - Same structure as INVENTORY.md for easy comparison

2. **Create ./MERGE-REPORT.md**
   ```markdown
   # VM Configuration Merge Report

   ## Source VMs
   - VM1: [details from INVENTORY.md]
   - VM2: [details from this machine]

   ## Summary Statistics
   - Common packages: X
   - VM1-specific packages: Y
   - VM2-specific packages: Z
   - Conflicts resolved: N

   ## Common Baseline
   [detailed list]

   ## VM1-Specific Items
   [list with notes on why included]

   ## VM2-Specific Items
   [list with notes on why included]

   ## Conflicts and Resolutions
   [for each conflict: both versions, resolution strategy]

   ## Installation Script Changes
   [summary of updates to each script]
   ```

3. **Update ./README.md**
   - Add "Multi-VM Support" section
   - Explain that scripts now support both VM1 and VM2
   - Document any conditional setup steps
   - Note which packages are common vs VM-specific
</requirements>

<implementation>
Execute systematically:

1. **Capture VM2 configuration** using bash commands:
   ```bash
   # System info
   uname -a
   cat /etc/os-release

   # Shell config
   cat ~/.zshrc
   cat ~/.profile
   ls -la ~/.oh-my-zsh/

   # Claude Code
   ls -la ~/.claude/
   ls ~/.claude/commands/
   cat ~/.claude/settings.json

   # Tools
   brew list  # if available
   npm list -g --depth=0
   pip3 list

   # And so on...
   ```

2. **Parse and structure** VM2's config data

3. **Read VM1's INVENTORY.md** completely to extract its configuration

4. **Compare systematically** - create sets/maps for each category:
   - common = VM1 ∩ VM2
   - vm1_only = VM1 - VM2
   - vm2_only = VM2 - VM1
   - conflicts = items in both but different

5. **Update each script** preserving existing structure:
   - Read current script content
   - Identify where to add VM2 packages
   - Add with clear section comments
   - Maintain error handling and idempotency

6. **Handle dotfile merging intelligently**:
   - If configs are compatible: merge into single version
   - If incompatible: keep both with suffixes
   - Document the choice

7. **Create comprehensive documentation** so the user understands exactly what came from which VM
</implementation>

<output>
Create/update these files:

- `./INVENTORY-VM2.md` - Complete inventory of this machine
- `./MERGE-REPORT.md` - Detailed merge analysis and documentation
- `./scripts/01-install-brew.sh` - Updated with VM2 packages
- `./scripts/02-install-cli-tools.sh` - Updated with VM2 tools
- `./scripts/03-install-npm-globals.sh` - Updated with VM2 npm packages
- `./scripts/04-install-pip-packages.sh` - Updated with VM2 pip packages
- `./scripts/05-setup-dotfiles.sh` - Updated to handle merged configs
- `./scripts/06-setup-claude.sh` - Updated with VM2 Claude configs
- `./README.md` - Updated with multi-VM information

For conflicting dotfiles, also create:
- `./shell/[filename]-vm2` or merged versions as needed
- `./dotfiles/[filename]-vm2` or merged versions as needed
</output>

<verification>
Before completing, verify:

- VM2 configuration is completely captured in INVENTORY-VM2.md
- Both INVENTORY.md and INVENTORY-VM2.md have been thoroughly compared
- MERGE-REPORT.md documents every difference and conflict
- All 6 installation scripts updated with VM2's packages
- Scripts have clear comments showing which packages are for which VM
- No configuration data lost from either VM1 or VM2
- README.md accurately describes the multi-VM setup
- The unified scripts can successfully set up either VM1 or VM2 configurations
</verification>

<success_criteria>
- INVENTORY-VM2.md created with complete VM2 configuration
- MERGE-REPORT.md provides comprehensive comparison with statistics
- All installation scripts updated to support both VMs
- Clear annotations in scripts showing common vs VM-specific packages
- README.md updated with multi-VM setup guidance
- User has full visibility into what came from VM1 vs VM2
- Export folder is ready to recreate either VM environment
</success_criteria>
