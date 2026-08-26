# Project Standards Catalogue Foundation

This package owns the catalogue and exact-root inspection foundations for the
successor Project Standards Bootstrapper. It validates immutable Catalogue
Releases, resolves closed Bootstrap Configurations against their exact
catalogue version and digest, and produces read-only Detected Repository State.

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
  filesystem state, Git relationships, ownership boundaries, hazards, and
  evidence-based Initialization or Adoption eligibility.

Inspection never redirects a selected subdirectory to its parent Git root,
follows a symlink, selects a run mode, infers durable policy or scope, or reads
file contents into output. Regular-file contents and link targets contribute
only fingerprints. Git is invoked with optional locks disabled so inspection
does not refresh the index. Conventional placeholders and ignorable OS/editor
metadata may support an Initialization recommendation, but remain untouched.

This foundation reports only catalogue validity or an `inspected` snapshot. It
cannot report a Verified Baseline. The shared evidence and acceptance reducer
is a later slice, so failure, Conflict, drift, missing authority, or absent
evidence has no path to a success claim here.

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
```

Inspection and validation failures emit typed JSON on stderr and exit `2`;
usage errors exit `64`. `inspect` emits the closed
`detected-repository-state` schema with an `initialize` or `adopt`
recommendation plus its evidence. The recommendation is not a selected mode or
authorization to mutate the root.
