# Project Standards Catalogue Foundation

This package owns the issue #13 foundation for the successor Project Standards
Bootstrapper. It validates immutable Catalogue Releases and resolves closed
Bootstrap Configurations against their exact catalogue version and digest.

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
  document schemas;
- `calculateCatalogueReleaseDigest(releaseDirectory)` for release authoring.

This foundation reports only `valid` or `invalid`. It cannot report a Verified
Baseline. The shared evidence and acceptance reducer is a later slice, so
failed, stale, drifted, missing-authority, or absent evidence has no path to a
success claim here.

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
  validate-release fixtures/valid/foundation-release

corepack pnpm exec project-standards-catalogue \
  calculate-digest fixtures/valid/foundation-release

corepack pnpm exec project-standards-catalogue \
  resolve-configuration fixtures/valid/foundation-release config.json
```

Validation failures emit JSON on stderr and exit `2`; usage errors exit `64`.
