#!/usr/bin/env node

import { readFile } from "node:fs/promises";

import {
  calculateCatalogueReleaseDigest,
  CatalogueValidationError,
  loadCatalogueRelease,
  resolveBootstrapConfiguration,
} from "./index.js";

function usage(): never {
  throw new Error(
    "Usage: project-standards-catalogue <validate-release|calculate-digest|resolve-configuration> <release-dir> [configuration.json]",
  );
}

async function run(arguments_: readonly string[]): Promise<unknown> {
  const [command, releaseRoot, configurationPath, ...extra] = arguments_;
  if (command === undefined || releaseRoot === undefined || extra.length > 0) {
    usage();
  }

  if (command === "calculate-digest") {
    if (configurationPath !== undefined) usage();
    return {
      schemaVersion: "1.0.0",
      catalogueDigest: await calculateCatalogueReleaseDigest(releaseRoot),
    };
  }

  const release = await loadCatalogueRelease(releaseRoot);
  if (command === "validate-release") {
    if (configurationPath !== undefined) usage();
    return {
      schemaVersion: "1.0.0",
      status: "valid",
      catalogueVersion: release.document.catalogueVersion,
      catalogueDigest: release.document.catalogueDigest,
      entryIds: [...release.entries.keys()].sort(),
    };
  }

  if (command === "resolve-configuration") {
    if (configurationPath === undefined) usage();
    const configuration = JSON.parse(
      await readFile(configurationPath, "utf8"),
    ) as unknown;
    const resolved = await resolveBootstrapConfiguration(
      release,
      configuration,
    );
    return {
      schemaVersion: "1.0.0",
      status: "valid",
      catalogueVersion: release.document.catalogueVersion,
      catalogueDigest: release.document.catalogueDigest,
      resolved,
    };
  }

  usage();
}

try {
  const output = await run(process.argv.slice(2));
  process.stdout.write(`${JSON.stringify(output)}\n`);
} catch (error) {
  if (error instanceof CatalogueValidationError) {
    process.stderr.write(
      `${JSON.stringify({
        schemaVersion: "1.0.0",
        status: "invalid",
        code: error.code,
        documentPath: error.documentPath,
        message: error.message,
        details: error.details,
      })}\n`,
    );
    process.exitCode = 2;
  } else {
    process.stderr.write(
      `${JSON.stringify({
        schemaVersion: "1.0.0",
        status: "usage-error",
        message: error instanceof Error ? error.message : String(error),
      })}\n`,
    );
    process.exitCode = 64;
  }
}
