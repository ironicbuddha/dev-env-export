# Working Memory

Last updated: 2026-03-16

## Current State

- The repo is now aligned around a macOS bootstrap flow with Homebrew, `nvm`,
  Warp, Zed, Codex, Claude, and 1Password.
- The machine has been brought up to the repo baseline closely enough that the
  verification scripts now pass:
  - `./scripts/10-check-paths.sh`
  - `./scripts/12-smoke-test.sh`
- Tracked Zed and Warp config files have been installed into the live home
  directory.
- Docker Desktop is installed at `/Applications/Docker.app`.
- The Docker CLI is installed via the `docker` Homebrew formula.
- `uv`, `vercel`, and the expected nvm-managed Node 22 toolchain are present.

## Repo Changes In Flight

These files currently have local modifications and are not committed yet:

- `README.md`
- `manifest/homebrew-packages.sh`
- `scripts/02-install-cli-tools.sh`
- `scripts/03-install-npm-globals.sh`
- `scripts/05-setup-dotfiles.sh`
- `scripts/10-check-paths.sh`
- `scripts/12-smoke-test.sh`

## What Was Fixed

1. The bootstrap and verification scripts now prefer the repo's nvm-managed
   Node 22 before any `nvm default` alias, which avoids falling back to
   `system` Node by accident.
2. `scripts/05-setup-dotfiles.sh` now merges tracked Codex defaults into an
   existing `~/.codex/config.toml` instead of preserving stale config forever.
3. `scripts/12-smoke-test.sh` again supports both `/opt/homebrew` and
   `/usr/local` lookup paths.
4. Step 2 now models Docker more sanely:
   - Docker CLI from the `docker` formula
   - Docker Desktop app from the cask
   - no reliance on the cask's privileged symlink step
5. Step 2 now treats app bundles already present in `/Applications` as a valid
   preserved state instead of warning noisily on reruns.
6. Step 2 now has a Bun fallback:
   - try Homebrew first
   - if Homebrew rejects Bun because Command Line Tools are too old, download
     the official Bun release binary and install it into a writable bin dir

## Machine-Specific Caveat

- Bun currently exists at `/opt/homebrew/bin/bun`, but it is not Homebrew-owned
  on this machine.
- Reason: `brew install oven-sh/bun/bun` fails with "Your Command Line Tools
  are too outdated."
- `softwareupdate -l` reported no newer update available during this session.
- The repo now handles this case automatically with a fallback binary install,
  so bootstrap still completes in a usable state.

If the machine later gets refreshed Command Line Tools, Bun can be handed back
to Homebrew ownership with:

```bash
rm /opt/homebrew/bin/bun
brew install oven-sh/bun/bun
```

## Verification Snapshot

Current verification outcome:

- `./scripts/10-check-paths.sh` passes
- `./scripts/12-smoke-test.sh` passes

Smoke-test assumptions still worth remembering:

- it checks install/config presence, not login state
- Zed CLI install is still a manual in-app follow-up
- auth flows like `gh auth login`, `aws configure`, `codex login`, and
  `claude auth login` are still separate from bootstrap

## Useful Next Steps

- Commit the current repo changes once they are reviewed.
- Decide whether `WORKING_MEMORY.md` should remain a tracked handoff file or
  stay as a temporary working artifact.
- If desired, clean up the Homebrew-owned `node` warning on this machine with:

```bash
brew uninstall node
```
