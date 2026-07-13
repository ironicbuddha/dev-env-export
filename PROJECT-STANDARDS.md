# Project Standards Baseline

This file defines the default engineering standard new repos should start with
in this environment.

It complements `CODE-QUALITY.md`.

- `CODE-QUALITY.md` covers the starter lint and format toolchain.
- This file covers testing, deployment, security, observability, and delivery
  expectations.

If a new repo needs a copy-ready starter, use
`templates/project-standards/constitution.md` and trim it to fit the project.

## Default Fit

These are the default assumptions behind this baseline:

- TypeScript-first apps and services: `pnpm`, TypeScript strict mode, Next.js,
  Vite, or Node.js services
- Markdown-only repositories: `pnpm`, Prettier, and `markdownlint-cli2`
- Python: mainly for scripting, automation, and cases where the library
  support is materially better
- Frontend hosting: Vercel by default for Next.js frontends
- Cloud and backend workloads: AWS by default, with TypeScript as the default
  application/runtime choice
- Secrets source of truth: 1Password
- Repo quality tooling: repo-local installs, not machine-global installs

The default runtime is Node 24.18.0 LTS. New Next.js apps pin `next` to version
16.2.10 unless a documented compatibility constraint requires a different
version.

This baseline is opinionated on purpose. Projects can differ, but the default
should be boring and explicit rather than improvised.

## Non-Negotiable Defaults

### 1. Repo Setup

Every new repo should define the following on day one:

- one package manager and one lockfile
- runtime versions pinned in the repo
- `lint`, `format`, `test`, and `build` commands where applicable
- a `README.md` with local setup, test, and deploy notes
- a `.env.example`, `.env.template`, or equivalent non-secret config example
- a repo-local standards file, usually `constitution.md`

If the repo is expected to use AI coding agents heavily, add a repo-local
guidance file such as `AGENTS.md` early instead of letting agent behavior drift.

In this environment, default to TypeScript for new application and service
repos unless there is a concrete reason not to. Python is the exception path,
not the default path.

### 2. Testing Strategy

The default testing model is:

- unit tests for business logic and pure utilities
- integration tests for database, queue, storage, auth, and third-party
  boundaries
- end-to-end tests for critical user or operator flows
- contract tests for public APIs, webhooks, or other explicit interfaces

Default expectations:

- behavior changes ship with test changes
- tests should be deterministic and CI-friendly
- the default line-coverage target is 80% for application or service code
- high-risk paths require direct tests even if the global coverage number passes

High-risk paths include:

- authentication and authorization
- billing or payments
- destructive mutations
- permission checks
- deployment or infrastructure automation
- data import and export

Recommended stack defaults:

- Next.js or Vite UI repos:
  - `vitest`
  - React Testing Library where UI components matter
  - `playwright` for critical flows
- TypeScript service, API, Lambda, or worker repos:
  - `vitest`
  - integration tests around AWS, database, queue, storage, and auth
    boundaries
  - contract tests for public routes, events, and webhooks
- Python repos:
  - `pytest`
  - use them mainly for scripting, automation, or library-driven workloads
  - focus tests around the exact external boundaries the script or worker owns

### 3. Deployment And Environments

Every new app or service repo should define its deployment model early.

Minimum expectations:

- local development is documented and repeatable
- there is at least one non-production environment before production
- deployments run through versioned automation, not click-ops
- builds are reproducible from committed config
- environment-specific config is explicit
- database migrations are versioned
- there is a rollback or recovery path

Default hosting stance:

- Next.js frontend: Vercel unless there is a strong reason not to
- TypeScript service, Lambda, worker, or microservice workload: AWS by default
- Python service or worker: use selectively when Python is the pragmatic fit
- split frontend and backend is fine if the boundary is documented and tested

For AWS-backed projects:

- prefer infrastructure defined in versioned config
- do not let console drift become the real source of truth
- use least-privilege IAM roles and scoped credentials

For Vercel-backed projects:

- use preview deployments on pull requests when practical
- separate environment variables by environment
- keep server-only secrets out of client bundles

### 4. Security Baseline

Every new repo should start with a practical security posture, not an
afterthought.

Default rules:

- secrets live in 1Password or the platform secret store, never in Git
- all request and input boundaries validate data explicitly
- auth and authorization rules are documented where they matter
- dependency vulnerability scanning is enabled in CI or the platform
- logs must not leak secrets, tokens, or unnecessary sensitive data
- production credentials and admin access use least privilege

Stack-specific defaults:

- TypeScript web apps and services should validate server boundaries with `zod`
  or an equivalent schema layer
- Python scripts and services should validate request and config boundaries
  with explicit schemas or typed parsing
- public web apps should define sane security headers and content handling

### 5. Observability And Operations

If a repo ships something that runs, it should also explain how that thing is
observed and debugged.

Default expectations:

- structured logs for services, jobs, and deploy hooks
- health checks or readiness checks for long-running services
- error tracking for user-facing apps and important backends
- request IDs, job IDs, or trace IDs where that materially helps debugging
- alerting or at least visible failure reporting for production-critical paths

### 6. Documentation And Decision Records

New repos should be explicit about why they exist and how they work.

Default minimum:

- `README.md`
- `constitution.md`
- deployment notes
- secret and environment-variable flow

If the project has meaningful architectural choices, capture them in short
ADRs or equivalent decision notes instead of relying on tribal memory.

## CI/CD Quality Gates

The default merge gate for active application or service repos is:

- lint passes
- format check passes where enforced
- tests pass
- build passes
- type check passes where the repo uses one
- security scanning is not red for high-severity issues

If the repo deploys user-facing software, add:

- preview deployment or deployable artifact generation on pull requests
- production deploy automation for the main branch or release flow

For Markdown-only repositories, the required gate is `lint` plus
`format:check`; test, build, type-check, deployment, and security gates apply
only after executable code or a deployable surface is added.

## Recommended Project Profiles

### Next.js Product App

Use this when the repo owns a web product or internal app.

Default shape:

- `pnpm`
- TypeScript strict mode
- `eslint`, `prettier`, `markdownlint-cli2`, `stylelint`
- `vitest` for unit tests
- React Testing Library for component behavior
- `playwright` for critical auth and workflow coverage
- Vercel previews and production deploys
- backend integrations tested at the route and contract level

### TypeScript API, Lambda, Or Service

Use this when the repo owns backend APIs, Lambdas, queues, workers, or
microservice-style application code.

Default shape:

- `pnpm`
- TypeScript strict mode
- `vitest`
- contract tests for routes, events, and webhooks
- integration tests around AWS, persistence, and auth boundaries
- deployment automation defined early
- AWS runtime, secret flow, and rollback path documented up front

### Vite Frontend

Use this when the repo is a frontend app, admin UI, or embedded client.

Default shape:

- `pnpm`
- TypeScript strict mode
- same quality baseline as Next.js repos
- `vitest` and React Testing Library for UI logic
- `playwright` for key workflows
- deployment target documented up front, usually Vercel, S3 plus CDN, or an
  app-specific platform

### Python Script Or Library-Driven Worker

Use this when Python is justified by scripting ergonomics or materially better
library support.

Default shape:

- `uv`
- `ruff`
- `pytest`
- narrow scope and explicit runtime ownership
- integration coverage around the external systems the script or worker touches
- reproducible build or packaging flow
- AWS deployment notes and runtime expectations documented early

### Markdown-Only Repository

Use this when the repository primarily contains documentation, specifications,
or other Markdown content.

Default shape:

- `pnpm`
- repo-local `prettier` and `markdownlint-cli2`
- `.prettierrc.json`, `.prettierignore`, and `.markdownlint.json` committed
- `lint`, `lint:md`, `format`, and `format:check` commands
- `lint` and `format:check` enforced in CI

### Mixed Repo

Use this when the repo contains both UI and backend code.

Default shape:

- one clear package-manager strategy per subproject
- shared standards documented in one root `constitution.md`
- contract tests across frontend and backend boundaries
- deployment ownership clear for each deployable unit

## Standard New-Repo Flow

When starting a new repo in this environment:

1. Run `scripts/13-apply-project-standards.sh --repo /path/to/repo --profile <profile>`.
2. Default to a TypeScript profile unless the repo is Markdown-only or Python
   is justified by the workload.
3. Review and trim the generated `constitution.md`.
4. Review any skipped files or merge warnings from the script output.
5. Define the repo scripts and CI checks on day one.
6. Document the deployment target and secret flow before the first production
   deploy.
7. Add the first critical-path tests before the project gets large enough to
   resent them.

## Short Version

New repos here should not start from vibes.

They should start with:

- TypeScript by default
- a standards file
- a small quality-tool baseline
- an explicit testing plan
- an explicit deployment plan
- explicit secret handling
- explicit operational expectations
