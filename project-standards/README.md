# Project Standards Catalogue Foundation

This package owns the catalogue, exact-root inspection, and shared verification
foundations for the
successor Project Standards Bootstrapper. It validates immutable Catalogue
Releases, resolves closed Bootstrap Configurations against their exact
catalogue version and digest, produces read-only Detected Repository State, and
reduces exact-bound evidence to fail-closed Requirement Evaluations.

The fixture Catalogue Entries are deliberately illustrative. They prove the
foundation contracts without pretending to be the complete first Catalogue
Release; later delivery tickets own the Core Baseline, Workloads, and
Capabilities themselves.

## Trust Boundary

The public library seam is:

- `loadCatalogueRelease(releaseDirectory)` for schema, digest, stable-ID,
  provenance, migration, extension, and composition validation;
- `resolveBootstrapConfiguration(release, configuration)` for exact-pin
  validation, Policy Choice default resolution, scope validation,
  applicability, `requires`, `refines`, and `incompatibleWith` composition;
- `validateProjectStandardsDocument(kind, document)` for the closed durable
  document and Detected Repository State schemas;
- `calculateCatalogueReleaseDigest(releaseDirectory)` for release authoring.
- `inspectRepositoryRoot(root)` for an exact, fingerprinted, read-only view of
  filesystem state, exact Git HEAD/index/ref identities, Git relationships,
  ownership boundaries, hazards, and evidence-based Initialization or Adoption
  eligibility.
- `evaluateVerificationRequirements(release, resolvedConfiguration, request)`
  for deterministic `satisfied`, `waived`, `failed`, or `incomplete`
  Requirement Evaluations and a `verified`, `failed`, or `incomplete` run
  outcome.

Inspection never redirects a selected subdirectory to its parent Git root,
follows a symlink, selects a run mode, infers durable policy or scope, or reads
file contents into output. Regular-file contents and link targets contribute
only fingerprints. Worktrees, submodules (including deinitialized gitlinks),
nested repositories, and arbitrary external Git directories remain explicit
boundaries. Git is invoked with optional locks disabled so inspection does not
refresh the index, and ambient `GIT_*` variables are scrubbed so they cannot
redirect inspection away from the selected root. Conventional placeholders and
ignorable OS/editor metadata may support an Initialization recommendation, but
remain untouched.

The reducer accepts only closed Verification Requests and Verification Evidence.
Evidence is content-addressed and bound to the exact rule, requirement, scope,
repository state, resolved configuration, Catalogue Release, bootstrapper,
schema set, declared inputs, horizon, invocation, toolchain, time, and
secret-safe output. Each evidence digest must also match a separate
orchestrator-pinned authenticity binding for the exact local run or immutable
external reference; recomputing an evidence record's self-hash cannot move that
pin. Attributable review and Manual-State Evidence additionally
enforce the catalogue's Authority Class, independence, assurance, and freshness
declarations. A Baseline run proves a Delivery Requirement's declared gate; a
Delivery run names the exact affected requirement scopes, reuses still-valid
Baseline Evidence, and requires fresh Delivery Evidence only for those changes.

Only a complete set of `satisfied` or visibly `waived` evaluations with no
Conflict, Catalogue Incompatibility, drift, missing authority, or failed
invariant reports `verified`. Missing, stale, errored, tampered, ambiguous, or
unauthorized evidence fails closed. Repeating an unchanged request is a
write-free deterministic re-verification.

## Content Addressing

The Catalogue Release digest is SHA-256 over RFC 8785 canonical JSON with this
shape:

```json
{
  "documents": [
    { "path": "<stable relative path>", "value": "<parsed JSON>" }
  ],
  "release": "<release.json without catalogueDigest>"
}
```

`documents` is sorted by path and contains every declared schema, Catalogue
Entry, migration, fixture, Source Guidance record, support-evidence record, and
extension registration. The digest field is excluded to avoid a self-reference.
Changing any governed byte-level JSON value changes the release identity.

Fixture configurations use `__CATALOGUE_DIGEST__` as an authoring token because
embedding a release's digest inside content covered by that same digest would
be recursive. A fixture runner must replace the token with the loaded release
digest before resolving that configuration.

## Commands

Install and verify the package with its exact pnpm pin:

```bash
corepack pnpm install --frozen-lockfile
corepack pnpm typecheck
corepack pnpm test
```

The thin executable adapter exposes machine-readable operations:

```bash
corepack pnpm exec project-standards-catalogue \
  inspect /exact/repository/root

corepack pnpm exec project-standards-catalogue \
  validate-release fixtures/valid/foundation-release

corepack pnpm exec project-standards-catalogue \
  calculate-digest fixtures/valid/foundation-release

corepack pnpm exec project-standards-catalogue \
  resolve-configuration fixtures/valid/foundation-release config.json

corepack pnpm exec project-standards-catalogue \
  evaluate-verification fixtures/valid/foundation-release \
  config.json verification-request.json
```

Inspection and validation failures emit typed JSON on stderr and exit `2`;
usage errors exit `64`. `inspect` emits the closed
`detected-repository-state` schema with an `initialize` or `adopt`
recommendation plus its evidence. The recommendation is not a selected mode or
authorization to mutate the root. `evaluate-verification` emits the reducer's
machine-readable result and uses the exact same engine as the public library
seam.
