#!/usr/bin/env node

import { readFile } from "node:fs/promises";

import {
  calculateCatalogueReleaseDigest,
  CatalogueValidationError,
  evaluateVerificationRequirements,
  inspectRepositoryRoot,
  loadCatalogueRelease,
  RepositoryInspectionError,
  resolveBootstrapConfiguration,
  type VerificationRequest,
  type VerificationResult,
} from "./index.js";

const verificationExitCodes = {
  verified: 0,
  failed: 1,
  incomplete: 3,
} as const satisfies Readonly<Record<VerificationResult["outcome"], number>>;

function usage(): never {
  throw new Error(
    "Usage: project-standards-catalogue <inspect <root>|validate-release <release-dir>|calculate-digest <release-dir>|resolve-configuration <release-dir> <configuration.json>|evaluate-verification <release-dir> <configuration.json> <verification-request.json>>",
  );
}

async function run(arguments_: readonly string[]): Promise<unknown> {
  const [command, releaseRoot, configurationPath, requestPath, ...extra] =
    arguments_;
  if (command === undefined || releaseRoot === undefined || extra.length > 0) {
    usage();
  }

  if (command === "inspect") {
    if (configurationPath !== undefined || requestPath !== undefined) usage();
    return {
      schemaVersion: "1.0.0",
      status: "inspected",
      detectedRepositoryState: await inspectRepositoryRoot(releaseRoot),
    };
  }

  if (command === "calculate-digest") {
    if (configurationPath !== undefined || requestPath !== undefined) usage();
    return {
      schemaVersion: "1.0.0",
      catalogueDigest: await calculateCatalogueReleaseDigest(releaseRoot),
    };
  }

  const release = await loadCatalogueRelease(releaseRoot);
  if (command === "validate-release") {
    if (configurationPath !== undefined || requestPath !== undefined) usage();
    return {
      schemaVersion: "1.0.0",
      status: "valid",
      catalogueVersion: release.document.catalogueVersion,
      catalogueDigest: release.document.catalogueDigest,
      entryIds: [...release.entries.keys()].sort(),
    };
  }

  if (
    command === "resolve-configuration" ||
    command === "evaluate-verification"
  ) {
    if (
      configurationPath === undefined ||
      (command === "resolve-configuration" && requestPath !== undefined) ||
      (command === "evaluate-verification" && requestPath === undefined)
    ) {
      usage();
    }
    const configuration = JSON.parse(
      await readFile(configurationPath, "utf8"),
    ) as unknown;
    const resolved = await resolveBootstrapConfiguration(
      release,
      configuration,
    );
    if (command === "resolve-configuration") {
      return {
        schemaVersion: "1.0.0",
        status: "valid",
        catalogueVersion: release.document.catalogueVersion,
        catalogueDigest: release.document.catalogueDigest,
        resolved,
      };
    }
    if (requestPath === undefined) usage();
    const request = JSON.parse(
      await readFile(requestPath, "utf8"),
    ) as VerificationRequest;
    return evaluateVerificationRequirements(release, resolved, request);
  }

  usage();
}

try {
  const arguments_ = process.argv.slice(2);
  const output = await run(arguments_);
  process.stdout.write(`${JSON.stringify(output)}\n`);
  if (arguments_[0] === "evaluate-verification") {
    process.exitCode =
      verificationExitCodes[(output as VerificationResult).outcome];
  }
} catch (error) {
  if (error instanceof RepositoryInspectionError) {
    process.stderr.write(
      `${JSON.stringify({
        schemaVersion: "1.0.0",
        status: "invalid",
        code: error.code,
        path: error.path,
        message: error.message,
      })}\n`,
    );
    process.exitCode = 2;
  } else if (error instanceof CatalogueValidationError) {
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
