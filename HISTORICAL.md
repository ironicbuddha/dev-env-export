# Historical Archive

This repo used to contain a larger set of Ubuntu VM inventory, merge, prompt,
and migration artifacts from its earlier life as a VM export project.

Those files have been removed from the active tree so the repo stays focused on
the current macOS/Parallels bootstrap workflow.

Use them for reference only when you need to answer questions such as:

- what existed on the original Ubuntu VMs
- how the first merged export was assembled
- which older tools or settings may still need to be migrated or removed

## Removed Legacy Files

- `INVENTORY.md`
- `INVENTORY-VM2.md`
- `MERGE-REPORT.md`
- `MERGE-SUMMARY.md`
- `FINAL-VERIFICATION.txt`
- `SECRETS-WARNING.md`
- `scripts/07-import-secrets.sh`
- `prompts/003-merge-vm-configs.md`
- `prompts/004-capture-and-merge-vm2.md`
- `mo/001-inventory-dev-environment.md`
- `mo/002-export-dev-environment.md`
- `mo/ralph-wiggum.md`

They remain recoverable through Git history.

Useful commands:

```bash
git log --stat -- INVENTORY.md
git show HEAD~1:INVENTORY.md
git show <commit>:scripts/07-import-secrets.sh
```

## Current Source Of Truth

For the repo's active direction, use:

1. `CONTEXT.md`
2. `AGENTS.md`
3. current repository contents
4. `README.md`

## Maintenance Rule

If a legacy file disagrees with the current repo state, treat it as recoverable
history, not as a reason to drag the repo back toward the old Ubuntu setup.
