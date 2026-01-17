<objective>
Merge the configuration from this VM with an existing INVENTORY.md from another machine, and update the installation scripts to create a unified dev environment setup that works across both configurations.

This is phase 3 of the environment migration. We have successfully captured this VM's configuration, and now need to intelligently merge it with configurations from other VMs to create a master setup that accommodates all machines.
</objective>

<context>
Current VM export location: ~/dev-env-export/
Current VM inventory: ~/dev-env-export/INVENTORY.md
Existing installation scripts: ~/dev-env-export/scripts/*.sh

The user has another INVENTORY.md from a different VM that needs to be merged with this one. The goal is to create unified installation scripts that will work for setting up either VM configuration.

@INVENTORY.md - Current VM's detailed inventory
@scripts/ - Existing installation scripts that need updating
@README.md - Documentation that may need updates
</context>

<requirements>
Thoroughly analyze and merge the configurations from both VMs:

1. **Identify the Other VM's Inventory**
   - Ask the user for the location of the other INVENTORY.md file
   - Read and parse both inventory files
   - Compare the two inventories systematically

2. **Analyze Differences and Overlaps**
   Create a comparison that identifies:
   - Tools/packages present in both VMs (common baseline)
   - Tools/packages unique to VM1 (this VM)
   - Tools/packages unique to VM2 (other VM)
   - Configurations that differ (same tool, different version/settings)
   - Environment variables that differ
   - Shell customizations that differ

3. **Merge Strategy - Keep Both with Annotations**
   When conflicts exist (same tool/config with different values):
   - Document both versions side-by-side
   - Add clear annotations explaining the difference
   - Provide conditional logic in scripts where appropriate
   - Note which VM each config came from

4. **Update Installation Scripts**
   Modify the scripts in ~/dev-env-export/scripts/ to:

   **01-install-brew.sh**
   - Ensure all brew formulas from both VMs are included
   - Add comments indicating which VM requires which packages

   **02-install-cli-tools.sh**
   - Merge CLI tool lists
   - Handle version differences with brew versioning or comments
   - Group by: required-by-both, vm1-specific, vm2-specific

   **03-install-npm-globals.sh**
   - Combine all npm global packages
   - Note version differences if any

   **04-install-pip-packages.sh**
   - Merge Python package lists
   - Document version conflicts

   **05-setup-dotfiles.sh**
   - Handle dotfile differences intelligently
   - Create merged versions where possible
   - Provide both versions with suffixes where conflicts exist (.zshrc-vm1, .zshrc-vm2)

   **06-setup-claude.sh**
   - Merge Claude Code configurations
   - Combine custom commands from both VMs
   - Union of enabled plugins

5. **Create Merge Documentation**
   Generate: `~/dev-env-export/MERGE-REPORT.md`

   Structure:
   ```markdown
   # VM Configuration Merge Report

   Generated: [date]
   Source VM 1: [this VM details]
   Source VM 2: [other VM details]

   ## Summary
   - Common packages: [count]
   - VM1-specific: [count]
   - VM2-specific: [count]
   - Conflicts resolved: [count]

   ## Common Baseline
   [tools/configs present in both]

   ## VM-Specific Configurations

   ### VM1 Only
   [detailed list with reasons to include]

   ### VM2 Only
   [detailed list with reasons to include]

   ## Conflicts and Resolutions

   ### [Tool/Config Name]
   - VM1 version: [details]
   - VM2 version: [details]
   - Resolution: [how it's handled in scripts]
   - Recommendation: [suggested approach]

   ## Installation Script Changes
   [summary of what was modified in each script]

   ## Manual Decision Points
   [list any conflicts that require user input]
   ```

6. **Update README.md**
   - Add section explaining the merge
   - Note that scripts now support multiple VM configurations
   - Document any conditional installation steps
   - Add guidance on which packages are required vs optional
</requirements>

<implementation>
Step-by-step process:

1. **Ask for the other INVENTORY.md location**
   Use the AskUserQuestion tool to get the file path

2. **Parse both inventories**
   Read and extract structured data from both INVENTORY.md files:
   - Shell configs and customizations
   - CLI tools and versions
   - npm packages
   - pip packages
   - Claude Code configurations
   - Environment variables
   - Dotfiles

3. **Create comparison data structures**
   Build maps/sets for each category:
   ```
   common_tools = intersection(vm1_tools, vm2_tools)
   vm1_unique = vm1_tools - vm2_tools
   vm2_unique = vm2_tools - vm1_tools
   conflicts = tools in both but with different versions/configs
   ```

4. **Update each installation script**
   For each script:
   - Read current content
   - Identify sections to update
   - Add merged package lists with annotations
   - Use comments to indicate VM-specific packages:
     ```bash
     # Common to both VMs
     brew install git node python

     # VM1-specific (Ubuntu 25.10)
     brew install tool-x  # Required for VM1 workflow

     # VM2-specific
     brew install tool-y  # Required for VM2 workflow
     ```
   - Preserve script structure and error handling

5. **Handle dotfile conflicts**
   For conflicting dotfiles:
   - Create merged versions when possible (union of configs)
   - For incompatible differences, include both with suffixes
   - Update setup-dotfiles.sh to handle selection

6. **Generate MERGE-REPORT.md**
   Document the entire merge process with statistics and details

7. **Update README.md**
   Add merge information and multi-VM setup guidance
</implementation>

<output>
Update the following files in ~/dev-env-export/:

- `./scripts/01-install-brew.sh` - Updated with merged package list
- `./scripts/02-install-cli-tools.sh` - Updated with merged CLI tools
- `./scripts/03-install-npm-globals.sh` - Updated with merged npm packages
- `./scripts/04-install-pip-packages.sh` - Updated with merged pip packages
- `./scripts/05-setup-dotfiles.sh` - Updated to handle merged/conflicting dotfiles
- `./scripts/06-setup-claude.sh` - Updated with merged Claude configs
- `./MERGE-REPORT.md` - Comprehensive merge analysis and documentation
- `./README.md` - Updated with multi-VM setup information

For conflicting dotfiles, create:
- `./shell/zshrc-merged` (if .zshrc differs)
- `./dotfiles/[filename]-vm1` and `./dotfiles/[filename]-vm2` (for unmerge-able conflicts)
</output>

<verification>
Before completing, verify:

- Both INVENTORY.md files have been thoroughly compared
- All categories from both inventories are covered in the merge
- Every conflict is documented in MERGE-REPORT.md with resolution strategy
- All installation scripts include packages from both VMs
- Scripts have clear comments indicating VM-specific vs common packages
- README.md accurately reflects the merged configuration
- No data from either VM has been lost in the merge
- The unified scripts will successfully set up either VM configuration
</verification>

<success_criteria>
- MERGE-REPORT.md created with comprehensive comparison
- All 6 installation scripts updated with merged configurations
- Conflicts documented with "keep both" annotations
- Scripts include clear comments about VM-specific packages
- README.md updated with multi-VM setup guidance
- Export folder is ready to set up either VM configuration
- User has clear visibility into what came from which VM
</success_criteria>
