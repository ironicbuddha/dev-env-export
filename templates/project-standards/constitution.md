# {{PROJECT_NAME}} Constitution

This file defines how this repo is built, tested, secured, and shipped.

It is intentionally opinionated toward Carlo's current stack:

- TypeScript as the default for application and service code
- Next.js or Vite
- Node.js on AWS for backend workloads
- Python for scripting and library-driven edge cases
- AWS
- Vercel
- 1Password-backed secret handling

Fill in the placeholders, delete the sections that do not apply, and keep the
result short enough that humans and agents will actually read it.

## Project Profile

- Project type: `{{web-app | api | lambda | worker | library | documentation | mixed}}`
- Primary language: `{{TypeScript | Python | Markdown | mixed}}`
- Frontend stack: `{{Next.js | Vite | none}}`
- Backend shape: `{{node-service | lambda | worker | python-script | none}}`
- Package manager: `{{pnpm | npm | uv}}`
- Deployment target: `{{Vercel | AWS | Vercel + AWS | other}}`
- Data sensitivity: `{{low | moderate | high}}`
- Runtime versions: `{{fill in}}`

## Core Standards

### 1. Code And Dependency Standards

- TypeScript repos run in strict mode.
- TypeScript is the default choice for new application and service code in this
  environment.
- Python repos use `ruff` and keep typed boundaries where practical.
- Python should be used mainly for scripting, automation, and cases where the
  library support is materially better.
- The repo uses one package manager and one lockfile per package boundary.
- Lint, format, test, and build commands are defined early.
- Public interfaces and non-obvious logic are documented.
- Major architectural decisions get short ADRs or equivalent notes.

### 2. Testing Strategy

- Business logic gets unit tests.
- Database, storage, queue, auth, and third-party boundaries get integration
  tests.
- Critical user or operator flows get end-to-end or smoke coverage.
- Public APIs, webhooks, and similar interfaces get contract coverage.
- Behavior changes ship with test changes.
- The default coverage target is 80% for app or service code.
- Auth, permissions, destructive actions, billing, and deployment paths require
  direct tests even if overall coverage passes.

### 3. Deployment And Release Standards

- Local development is documented and repeatable.
- There is at least one non-production environment before production.
- Deployments run through versioned automation.
- Builds are reproducible from committed config.
- Database migrations are versioned and have a rollback or recovery plan.
- Environment variables are documented without committing secrets.
- The release path is explicit: `{{describe branch, tag, or main-based flow}}`.

### 4. Security Standards

- Secrets live in 1Password or platform secret stores, never in Git.
- Request and config boundaries validate data explicitly.
- Auth and authorization rules are documented where relevant.
- Production access uses least privilege.
- Logs must not leak tokens, secrets, or unnecessary sensitive data.
- Dependency and platform vulnerability scanning is enabled.

### 5. Observability And Operations

- Services and jobs emit structured logs.
- User-facing apps and important backends have error tracking.
- Long-running services expose health or readiness checks.
- Production-critical paths have visible failure reporting.
- Debuggable IDs exist where they materially help trace requests or jobs.

### 6. Documentation And AI Guidance

- `README.md` covers setup, test, and deploy basics.
- This `constitution.md` stays current when the workflow changes.
- The repo keeps a non-secret environment template.
- If the repo relies on AI coding agents, it includes repo-local agent guidance.

## Delivery Gates

Pull requests should not merge unless these pass:

- lint
- test
- build
- typecheck where the repo uses one
- security checks are not red for high-severity issues

For deployable apps and services, also require:

- preview deploy or deployable artifact generation where practical
- validation of migrations or deploy-time changes

For a Markdown-only repository, require `lint` and `format:check`; tests,
builds, and type checks apply only when the repository adds executable code.

## Profile Addenda

Keep the section that applies. Delete the rest.

### Next.js App

- Use `pnpm` unless there is a documented reason not to.
- Pin `next` to version `16.2.10`.
- Use TypeScript strict mode.
- Use `vitest` for unit tests and React Testing Library for component behavior.
- Use `playwright` for critical user journeys.
- Default to Vercel previews and production deploys.
- Keep server-only secrets and logic out of client bundles.

### TypeScript API, Lambda, Or Service

- Use `pnpm` unless there is a documented reason not to.
- Use TypeScript strict mode.
- Use `vitest`.
- Add contract tests for routes, events, and webhooks.
- Add integration tests around AWS, persistence, and auth boundaries.
- Document deployment, rollback, and secret ownership early.

### Vite Frontend

- Use `pnpm` unless there is a documented reason not to.
- Use TypeScript strict mode.
- Use `vitest` and React Testing Library for UI logic.
- Use `playwright` for key workflows.
- Document the deployment target up front.

### Python Script Or Library-Driven Worker

- Prefer `uv` unless the repo already has a justified alternative.
- Use `ruff` and `pytest`.
- Use this path only when Python is the pragmatic fit for the workload.
- Test the external systems and libraries the script or worker touches.
- Document the AWS runtime model early.
- Use health checks for long-running services and smoke checks for worker paths.

### Markdown-Only Repository

- Use `pnpm` for the repo-local Markdown tooling.
- Keep `.markdownlint.json`, Prettier configuration, and the lockfile in Git.
- Define `lint`, `lint:md`, `format`, and `format:check` commands.
- Run `lint` and `format:check` in CI.

### Mixed Vercel Plus AWS Repo

- Be explicit about what deploys to Vercel and what deploys to AWS.
- Keep one root standard for shared expectations.
- Test the boundary between frontend and backend with contracts and integration
  coverage.
- Document environment ownership and secret flow clearly.

## Exceptions

If this repo deviates from the default baseline, document:

- what differs
- why it differs
- what compensating control replaces the default

## Versioning

- Version: `{{0.1.0}}`
- Ratified: `{{YYYY-MM-DD}}`
- Last amended: `{{YYYY-MM-DD}}`
