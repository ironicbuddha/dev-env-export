# Package Managers

This repo uses different package managers at different layers on purpose.

The goal is not to crown one package manager king of the universe. The goal is
to keep each layer boring and reliable.

## Source Of Truth

- Homebrew is the primary machine-level package manager.
- Homebrew installs `nvm`, and `nvm` manages the active Node runtime.
- `npm` remains available for compatibility and global CLI installs.
- `pnpm` is the preferred package manager for new TypeScript-first projects.
- `uv` is the preferred fast package tool for modern Python workflows when it
  fits the project.

## Machine-Level Policy

Use Homebrew for machine bootstrap:

- CLI tools
- GUI apps
- runtime managers such as `nvm`
- language runtimes where the repo intentionally manages them outside `nvm`

Do not try to replace Homebrew with `pnpm`, `npm`, or random curl-pipe
installers just because a tool technically supports it.

## Node And JavaScript Policy

### Let `nvm` Own Node

Do not install Node from Homebrew in the default bootstrap path.

In this repo:

- Homebrew owns `nvm`
- `nvm` owns the active Node versions
- `npm` global CLIs should install under the active `nvm` Node

That keeps Node versioning boring and avoids a split-brain fight between
Homebrew Node and `nvm` Node.

### Keep `npm`

Do not remove `npm` from the machine.

Reasons:

- it ships naturally with Node
- it is still the compatibility baseline for the broader ecosystem
- this repo currently uses it for global CLI installs under `nvm`
- some tools and docs still assume it exists

### Prefer `pnpm` For New TS Projects

Use `pnpm` by default for new projects that are primarily:

- Next.js
- Vite
- TypeScript-heavy frontend work
- Node.js and TypeScript backend work
- monorepos or workspace-heavy repos

Reasons:

- better workspace ergonomics
- better disk reuse
- generally better fit for modern frontend and monorepo workflows

### Do Not Mix `npm` And `pnpm` Inside The Same Repo

One project gets one package manager.

Rules:

- one lockfile
- one install command family
- set `"packageManager"` in `package.json`
- do not run `npm install` in a `pnpm` repo
- do not run `pnpm install` in an `npm` repo unless you are intentionally
  migrating it

## How `pnpm` Should Be Provided

Do not bolt on weird global `pnpm` setup unless you actually need it.

Preferred path:

- enable Corepack
- let projects declare their package manager explicitly
- use `pnpm` through the Node toolchain rather than inventing another machine
  bootstrap snowflake

This repo already enables Corepack in `scripts/03-install-npm-globals.sh`.

## Global CLI Policy

Keep global CLI installs simple:

- Codex CLI via `npm`
- Claude Code via `npm`
- Vercel CLI via `npm`

That keeps the machine bootstrap stable and avoids turning package-manager
preferences into a global-runtime mess.

## Repo Quality Tooling Policy

Do not confuse repo quality tooling with machine bootstrap tooling.

Default rule:

- install lint and format tooling in the repo, not globally

For the current stack, new repos should usually start with:

- `prettier`
- `markdownlint-cli2`
- `eslint`
- `stylelint`
- `ruff`

See `CODE-QUALITY.md` for the repo-level baseline and when to use each tool.

## Practical Defaults

Use these defaults unless a project gives you a good reason not to:

- machine bootstrap: Homebrew
- Node runtime manager: `nvm` (installed by Homebrew)
- global Node CLIs: `npm`
- new TypeScript app or service: `pnpm`
- existing `npm` project: leave it on `npm`
- Python package workflows: prefer `uv` when it fits, otherwise normal project
  virtualenv tooling

## Migration Stance

Do not mass-convert old `npm` repos to `pnpm` for ideology points.

Migrate only when:

- the repo is active enough to justify it
- the workspace benefits are real
- the lockfile churn is worth the pain
- the team will actually stick to the new workflow

## Short Version

- keep Homebrew primary
- keep `npm`
- use `pnpm` for new TS-heavy repos
- do not mix `npm` and `pnpm` in one project
- let Corepack do the boring work
