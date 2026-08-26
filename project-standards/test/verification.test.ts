import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, realpath, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import canonicalizeModule from "canonicalize";

import {
  type BootstrapConfiguration,
  CatalogueValidationError,
  evaluateCommittedVerificationRequirements,
  evaluateVerificationRequirements,
  exactGitIndexEntries,
  inspectRepositoryRoot,
  loadCatalogueRelease,
  resolveBootstrapConfiguration,
  type RuleWaiverDocument,
  type VerificationEvidenceDocument,
  type VerificationRequest,
} from "../src/index.js";

const packageRoot = join(dirname(fileURLToPath(import.meta.url)), "../..");
const execFileAsync = promisify(execFile);
const canonicalize = canonicalizeModule as unknown as (
  value: unknown,
) => string | undefined;

function projectDeliveryContractContent(
  waivers: readonly RuleWaiverDocument[],
): string {
  const visibleWaivers = waivers.map(
    (waiver) =>
      [
        `- ${waiver.id}@${waiver.version}`,
        `  - Digest: ${waiver.digest}`,
        `  - Affected obligations: ${waiver.requirementIds.join(", ")}`,
        `  - Compensating controls: ${waiver.compensatingControls
          .map(({ requirementId }) => requirementId)
          .join(", ")}`,
        `  - Expires: ${waiver.validity.expiresAt}`,
      ].join("\n"),
  );
  return [
    "# Project Delivery Contract",
    "",
    "## Active Rule Waivers",
    ...(visibleWaivers.length === 0 ? ["None."] : visibleWaivers),
    "",
  ].join("\n");
}

function projectDeliveryContractFor(
  waivers: readonly RuleWaiverDocument[],
): VerificationRequest["projectDeliveryContract"] {
  return {
    artifactId: "artifact/core/project-delivery-contract",
    ownerLayerId: "core",
    locator: "constitution.md",
    ownership: "whole-file",
    fingerprint: `sha256:${createHash("sha256")
      .update(projectDeliveryContractContent(waivers))
      .digest("hex")}`,
    verificationState: "matching",
  };
}

function execFileResult(
  file: string,
  arguments_: readonly string[],
): Promise<Readonly<{ exitCode: number; stdout: string; stderr: string }>> {
  return new Promise((resolve) => {
    execFile(file, arguments_, (error, stdout, stderr) => {
      resolve({
        exitCode: typeof error?.code === "number" ? error.code : 0,
        stdout,
        stderr,
      });
    });
  });
}

function digest(value: unknown): string {
  const canonical = canonicalize(value);
  assert.ok(canonical);
  return `sha256:${createHash("sha256").update(canonical).digest("hex")}`;
}

async function capabilityVerificationFixture(): Promise<{
  request: VerificationRequest;
  resolved: Awaited<ReturnType<typeof resolveBootstrapConfiguration>>;
  release: Awaited<ReturnType<typeof loadCatalogueRelease>>;
}> {
  const base = await verificationFixture();
  const configuration: BootstrapConfiguration = {
    ...base.resolved.configuration,
    capabilities: [
      {
        id: "service-tests",
        kind: "example-tests",
        scope: { kind: "workload", workloadIds: ["service"] },
        choices: {},
      },
    ],
  };
  const resolved = await resolveBootstrapConfiguration(
    base.release,
    configuration,
  );
  const configurationDigest = digest(resolved.configuration);
  const scope = { kind: "workload", id: "service" } as const;
  const template = base.request.evidence[0]!;
  const makeEvidence = (
    overrides: Partial<Omit<VerificationEvidenceDocument, "evidenceDigest">> &
      Pick<
        VerificationEvidenceDocument,
        "id" | "ruleId" | "requirementId" | "kind" | "result"
      >,
  ): VerificationEvidenceDocument =>
    redigestEvidence(template, {
      configurationDigest,
      scope,
      declaredInputsDigest: `sha256:${"d".repeat(64)}`,
      invocation: {
        executable: "project-standards-catalogue",
        arguments: ["evaluate-verification"],
        workingDirectory: "services/api",
        declaredEnvironmentInputs: [],
      },
      toolchain: { name: "project-standards-catalogue", version: "0.1.0" },
      ...overrides,
    });
  const baseEvidence = base.request.evidence.map((evidence) =>
    redigestEvidence(evidence, { configurationDigest }),
  );
  const gateEvidence = makeEvidence({
    id: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f2450",
    ruleId: "rule/example-tests/direct-tests",
    requirementId: "requirement/example-tests/test-command-gate",
    kind: "deterministic-check",
    result: "passed",
    invocation: {
      executable: "pnpm",
      arguments: ["test"],
      workingDirectory: "services/api",
      declaredEnvironmentInputs: [],
    },
    toolchain: { name: "pnpm", version: "11.22.0" },
    artifactObservations: [
      {
        artifactId: "artifact/example-tests/test-command",
        ownerLayerId: "service-tests",
        locator: "services/api/package.json#scripts.test",
        fingerprint: `sha256:${"d".repeat(64)}`,
      },
      {
        artifactId: "artifact/example-tests/direct-tests-suppression",
        ownerLayerId: "service-tests",
        locator: "services/api/eslint.config.mjs#direct-tests-waiver",
        fingerprint: `sha256:${"d".repeat(64)}`,
      },
    ],
  });
  const reviewEvidence = makeEvidence({
    id: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f2451",
    ruleId: "rule/example-tests/direct-tests",
    requirementId: "requirement/example-tests/direct-tests-review",
    kind: "attributable-review",
    result: "accepted",
    actor: {
      kind: "human",
      identity: "reviewer@example.com",
      authorityClass: "authority/project-policy",
    },
    reviewedMaterialDigest: `sha256:${"d".repeat(64)}`,
    rationale: "Critical paths are directly covered.",
    findings: ["The failure path is exercised."],
    dispositions: ["accepted"],
    questionConclusions: [
      {
        questionId: "question/example-tests/direct-tests",
        conclusion: "accepted",
      },
    ],
    artifactObservations: [],
  });
  const manualEvidence = makeEvidence({
    id: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f2452",
    ruleId: "rule/example-tests/direct-tests",
    requirementId: "requirement/example-tests/manual-assurance",
    kind: "manual-state",
    result: "verified",
    actor: {
      kind: "human",
      identity: "reviewer@example.com",
      authorityClass: "authority/project-policy",
    },
    rationale: "The exact gate state was read back.",
    manualState: {
      target: "services/api test gate",
      stateDigest: `sha256:${"d".repeat(64)}`,
      assurance: "machine-readback",
    },
    invocation: {
      executable: "pnpm",
      arguments: ["test"],
      workingDirectory: "services/api",
      declaredEnvironmentInputs: [],
    },
    toolchain: { name: "pnpm", version: "11.22.0" },
    artifactObservations: [],
  });
  const evidence = [...baseEvidence, gateEvidence, reviewEvidence, manualEvidence];
  return {
    release: base.release,
    resolved,
    request: {
      ...base.request,
      authorities: [
        {
          authorityClass: "authority/project-policy",
          identities: ["reviewer@example.com"],
          externalDecisionReferences: [],
        },
      ],
      subjects: [
        {
          requirementId: "requirement/example-tests/direct-tests-review",
          scope,
          authorIdentities: ["author@example.com"],
          authorityClasses: [],
        },
      ],
      requirementInputs: [
        ...base.request.requirementInputs,
        ...evidence.slice(2).map((item) => ({
          requirementId: item.requirementId,
          scope: item.scope,
          digest: item.declaredInputsDigest,
        })),
      ],
      evidence,
      evidenceAuthenticity: authenticityFor(evidence),
      manifest: {
        ...base.request.manifest,
        configurationDigest,
        artifacts: [
          ...base.request.manifest.artifacts.map((artifact) =>
            artifact.artifactId === "artifact/core/configuration"
              ? { ...artifact, fingerprint: configurationDigest }
              : artifact,
          ),
          {
            artifactId: "artifact/example-tests/test-command",
            ownerLayerId: "service-tests",
            locator: "services/api/package.json#scripts.test",
            ownership: "structured-fragment" as const,
            fingerprint: gateEvidence.declaredInputsDigest,
            verificationState: "matching" as const,
          },
          {
            artifactId: "artifact/example-tests/direct-tests-suppression",
            ownerLayerId: "service-tests",
            locator: "services/api/eslint.config.mjs#direct-tests-waiver",
            ownership: "structured-fragment" as const,
            fingerprint: gateEvidence.declaredInputsDigest,
            verificationState: "matching" as const,
          },
        ],
        evidence: manifestEvidenceFor(evidence),
      },
    },
  };
}

function redigestEvidence(
  evidence: VerificationEvidenceDocument,
  overrides: Partial<Omit<VerificationEvidenceDocument, "evidenceDigest">>,
): VerificationEvidenceDocument {
  const { evidenceDigest: _evidenceDigest, ...content } = evidence;
  const updated = { ...content, ...overrides };
  return { ...updated, evidenceDigest: digest(updated) };
}

function authenticityFor(
  evidence: readonly VerificationEvidenceDocument[],
): VerificationRequest["evidenceAuthenticity"] {
  return evidence.map((item) => ({
    evidenceId: item.id,
    evidenceDigest: item.evidenceDigest,
    source: {
      kind: "local-execution",
      runId: "018f47ac-10d2-7c85-bd62-0c742b1f2400",
      bootstrapperDigest: item.bootstrapperDigest,
    },
  }));
}

function manifestEvidenceFor(
  evidence: readonly VerificationEvidenceDocument[],
): VerificationRequest["manifest"]["evidence"] {
  return evidence.map((item) => ({
    evidenceId: item.id,
    digest: item.evidenceDigest,
    result: item.result,
    observedAt: item.observedAt,
    ...(item.validUntil === undefined ? {} : { validUntil: item.validUntil }),
    ...(item.output.immutableReference === undefined
      ? {}
      : { immutableReference: item.output.immutableReference }),
  }));
}

function withWaiverState(
  request: VerificationRequest,
  waivers: readonly RuleWaiverDocument[],
  managedSuppressions: VerificationRequest["managedSuppressions"] = [],
  predecessorWaivers: readonly RuleWaiverDocument[] = [],
): VerificationRequest {
  const evaluatedAt = Date.parse(request.evaluatedAt);
  const activeWaivers = waivers.filter(
    (waiver) =>
      waiver.status === "active" &&
      Date.parse(waiver.validity.startsAt) <= evaluatedAt &&
      Date.parse(waiver.validity.expiresAt) > evaluatedAt,
  );
  const projectDeliveryContract = projectDeliveryContractFor(activeWaivers);
  const suppressionArtifacts = managedSuppressions.map(
    ({ artifact }) => artifact,
  );
  return {
    ...request,
    waivers,
    waiverHistory: predecessorWaivers,
    waiverAuthenticity: [...waivers, ...predecessorWaivers].map((waiver) => ({
      waiverId: waiver.id,
      version: waiver.version,
      digest: waiver.digest,
      source: {
        kind: "committed-record",
        path: `.project-standards/waivers/${waiver.id.slice("waiver/".length)}.json`,
        revision: request.repository.revision,
        repositoryStateDigest: waiver.validity.repositoryStateDigest,
      },
    })),
    managedSuppressions,
    projectDeliveryContract,
    manifest: {
      ...request.manifest,
      artifacts: [
        ...request.manifest.artifacts.filter(
          (artifact) =>
            artifact.artifactId !==
              "artifact/core/project-delivery-contract" &&
            !suppressionArtifacts.some(
              (suppressionArtifact) =>
                suppressionArtifact.artifactId === artifact.artifactId &&
                suppressionArtifact.ownerLayerId === artifact.ownerLayerId &&
                suppressionArtifact.locator === artifact.locator,
            ),
        ),
        projectDeliveryContract,
        ...suppressionArtifacts,
      ],
      activeWaivers: activeWaivers.map((waiver) => ({
        waiverId: waiver.id,
        version: waiver.version,
        digest: waiver.digest,
      })),
      managedSuppressions: managedSuppressions.map((suppression) => ({
        suppressionId: suppression.id,
        waiverId: suppression.waiverId,
        waiverVersion: suppression.waiverVersion,
        artifactId: suppression.artifact.artifactId,
        ownerLayerId: suppression.artifact.ownerLayerId,
        locator: suppression.artifact.locator,
        fingerprint: suppression.artifact.fingerprint,
      })),
    },
  };
}

function withEvidence(
  request: VerificationRequest,
  evidence: readonly VerificationEvidenceDocument[],
): VerificationRequest {
  return {
    ...request,
    evidence,
    evidenceAuthenticity: authenticityFor(evidence),
    manifest: {
      ...request.manifest,
      evidence: manifestEvidenceFor(evidence),
    },
  };
}

function evaluationFor(
  result: Awaited<ReturnType<typeof evaluateVerificationRequirements>>,
  requirementId: string,
) {
  const evaluation = result.requirements.find(
    (candidate) => candidate.requirementId === requirementId,
  );
  assert.ok(evaluation);
  return evaluation;
}

async function verificationFixture(): Promise<{
  request: VerificationRequest;
  resolved: Awaited<ReturnType<typeof resolveBootstrapConfiguration>>;
  release: Awaited<ReturnType<typeof loadCatalogueRelease>>;
}> {
  const release = await loadCatalogueRelease(
    join(packageRoot, "fixtures/valid/foundation-release"),
  );
  const configuration: BootstrapConfiguration = {
    $schema:
      "https://schemas.ironicbuddha.dev/project-standards/v1/configuration.schema.json",
    schemaVersion: "1.0.0" as const,
    catalogueVersion: release.document.catalogueVersion,
    catalogueDigest: release.document.catalogueDigest,
    core: { kind: "core", choices: {} },
    workloads: [
      {
        id: "service",
        kind: "example-service",
        root: "services/api",
        choices: {},
      },
    ],
    capabilities: [],
    extensions: {},
  };
  const resolved = await resolveBootstrapConfiguration(release, configuration);
  const scope = { kind: "repository", id: "repository" } as const;
  const repository = {
    identity: "github.com/ironicbuddha/example",
    revision: "a".repeat(40),
    stateDigest: `sha256:${"3".repeat(64)}`,
  } as const;
  const evidenceWithoutDigest = {
    $schema:
      "https://schemas.ironicbuddha.dev/project-standards/v1/verification-evidence.schema.json",
    schemaVersion: "1.0.0",
    id: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f24f8",
    ruleId: "rule/core/exact-catalogue-pin",
    requirementId: "requirement/core/exact-catalogue-pin",
    scope,
    repository,
    configurationDigest: digest(resolved.configuration),
    catalogueVersion: release.document.catalogueVersion,
    catalogueDigest: release.document.catalogueDigest,
    bootstrapperVersion: "0.1.0",
    bootstrapperDigest: `sha256:${"8".repeat(64)}`,
    schemaDigests: release.schemaDigests,
    declaredInputsDigest: `sha256:${"6".repeat(64)}`,
    artifactObservations: [],
    verificationHorizon: "baseline",
    invocation: {
      executable: "project-standards-catalogue",
      arguments: [
        "resolve-configuration",
        ".project-standards/catalogue",
        ".project-standards/config.json",
      ],
      workingDirectory: ".",
      declaredEnvironmentInputs: [],
    },
    toolchain: {
      name: "project-standards-catalogue",
      version: "0.1.0",
    },
    kind: "deterministic-check",
    result: "passed",
    attempts: 1,
    observedAt: "2026-08-26T08:00:00Z",
    output: { digest: `sha256:${"7".repeat(64)}` },
  } as const;
  const evidence: VerificationEvidenceDocument = {
    ...evidenceWithoutDigest,
    evidenceDigest: digest(evidenceWithoutDigest),
  };
  const serviceEvidenceWithoutDigest = {
    ...evidenceWithoutDigest,
    id: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f24f9",
    ruleId: "rule/example-service/package-check",
    requirementId: "requirement/example-service/package-check",
    scope: { kind: "workload", id: "service" } as const,
    declaredInputsDigest: `sha256:${"a".repeat(64)}`,
    artifactObservations: [
      {
        artifactId: "artifact/example-service/package",
        ownerLayerId: "service",
        locator: "services/api/package.json",
        fingerprint: `sha256:${"a".repeat(64)}`,
      },
    ],
    invocation: {
      executable: "pnpm",
      arguments: ["test"],
      workingDirectory: "services/api",
      declaredEnvironmentInputs: [],
    },
    toolchain: { name: "pnpm", version: "11.22.0" },
  };
  const serviceEvidence: VerificationEvidenceDocument = {
    ...serviceEvidenceWithoutDigest,
    evidenceDigest: digest(serviceEvidenceWithoutDigest),
  };
  const projectDeliveryContract = projectDeliveryContractFor([]);
  const request: VerificationRequest = {
    $schema:
      "https://schemas.ironicbuddha.dev/project-standards/v1/verification-request.schema.json",
    schemaVersion: "1.0.0",
    horizon: "baseline",
    evaluatedAt: "2026-08-26T08:00:01Z",
    repository,
    bootstrapper: {
      version: "0.1.0",
      digest: `sha256:${"8".repeat(64)}`,
    },
    schemaDigests: evidence.schemaDigests,
    affectedRequirements: [],
    requirementInputs: [
      {
        requirementId: evidence.requirementId,
        scope,
        digest: evidence.declaredInputsDigest,
      },
      {
        requirementId: serviceEvidence.requirementId,
        scope: serviceEvidence.scope,
        digest: serviceEvidence.declaredInputsDigest,
      },
    ],
    authorities: [],
    subjects: [],
    blockers: [],
    evidence: [evidence, serviceEvidence],
    evidenceAuthenticity: authenticityFor([evidence, serviceEvidence]),
    waivers: [],
    waiverHistory: [],
    waiverAuthenticity: [],
    projectDeliveryContract,
    manifest: {
      $schema:
        "https://schemas.ironicbuddha.dev/project-standards/v1/manifest.schema.json",
      schemaVersion: "1.0.0",
      configurationDigest: digest(resolved.configuration),
      catalogueVersion: release.document.catalogueVersion,
      catalogueDigest: release.document.catalogueDigest,
      bootstrapperVersion: "0.1.0",
      bootstrapperDigest: `sha256:${"8".repeat(64)}`,
      schemaDigests: release.schemaDigests,
      artifacts: [
        {
          artifactId: "artifact/core/configuration",
          ownerLayerId: "core",
          locator: ".project-standards/config.json",
          ownership: "whole-file",
          fingerprint: digest(resolved.configuration),
          verificationState: "matching",
        },
        projectDeliveryContract,
        {
          artifactId: "artifact/example-service/package",
          ownerLayerId: "service",
          locator: "services/api/package.json",
          ownership: "structured-fragment",
          fingerprint: serviceEvidence.declaredInputsDigest,
          verificationState: "matching",
        },
      ],
      evidence: manifestEvidenceFor([evidence, serviceEvidence]),
      activeWaivers: [],
      managedSuppressions: [],
    },
    managedSuppressions: [],
  };
  return { request, release, resolved };
}

async function writeCommittedVerificationFixture(
  root: string,
  configuration: BootstrapConfiguration,
  request: VerificationRequest,
): Promise<string> {
  const standardsRoot = join(root, ".project-standards");
  const waiverRoot = join(standardsRoot, "waivers");
  const runRoot = join(standardsRoot, "run");
  await Promise.all([
    mkdir(waiverRoot, { recursive: true }),
    mkdir(runRoot, { recursive: true }),
  ]);
  const requestPath = join(runRoot, "verification-request.json");
  await Promise.all([
    writeFile(
      join(standardsRoot, "config.json"),
      `${JSON.stringify(configuration, null, 2)}\n`,
    ),
    writeFile(
      join(standardsRoot, "manifest.json"),
      `${JSON.stringify(request.manifest, null, 2)}\n`,
    ),
    writeFile(requestPath, `${JSON.stringify(request, null, 2)}\n`),
    writeFile(
      join(root, "constitution.md"),
      projectDeliveryContractContent(request.waivers),
    ),
    ...request.waivers.map((waiver) =>
      writeFile(
        join(waiverRoot, `${waiver.id.slice("waiver/".length)}.json`),
        `${JSON.stringify(waiver, null, 2)}\n`,
      ),
    ),
  ]);
  return requestPath;
}

async function initializeGitFixture(root: string): Promise<void> {
  await execFileAsync("git", ["init", root]);
  await execFileAsync("git", [
    "-C",
    root,
    "config",
    "user.email",
    "tests@example.com",
  ]);
  await execFileAsync("git", [
    "-C",
    root,
    "config",
    "user.name",
    "Project Standards Tests",
  ]);
  await execFileAsync("git", [
    "-C",
    root,
    "commit",
    "--allow-empty",
    "-m",
    "source state",
  ]);
}

async function commitGitFixture(root: string, message: string): Promise<string> {
  await execFileAsync("git", [
    "-C",
    root,
    "add",
    "-A",
    "--",
    ".project-standards",
    "constitution.md",
    ":(exclude).project-standards/run",
  ]);
  await execFileAsync("git", [
    "-C",
    root,
    "commit",
    "--only",
    "-m",
    message,
    "--",
    ".project-standards",
    "constitution.md",
    ":(exclude).project-standards/run",
  ]);
  const { stdout } = await execFileAsync("git", [
    "-C",
    root,
    "rev-parse",
    "HEAD",
  ]);
  return stdout.trim();
}

async function bindVerificationRequestToGitSource(
  root: string,
  request: VerificationRequest,
): Promise<VerificationRequest> {
  const { stdout } = await execFileAsync("git", [
    "-C",
    root,
    "rev-parse",
    "HEAD",
  ]);
  const detected = await inspectRepositoryRoot(root);
  const entries = new Map(
    detected.filesystem.entries.map((entry) => [entry.path, entry]),
  );
  const relevantDirtyPaths = detected.git.dirtyPaths
    .filter(
      ({ path, originalPath }) =>
        !path.startsWith(".project-standards/run/") ||
        (originalPath !== undefined &&
          !originalPath.startsWith(".project-standards/run/")),
    )
    .map(({ path, indexState, worktreeState, originalPath }) => ({
      path,
      indexState,
      worktreeState,
      fingerprint: entries.get(path)?.fingerprint ?? "absent",
      ...(originalPath === undefined ? {} : { originalPath }),
    }));
  const relevantIndexEntries = await exactGitIndexEntries(
    root,
    relevantDirtyPaths.flatMap(({ path, originalPath }) => [
      path,
      ...(originalPath === undefined ? [] : [originalPath]),
    ]),
  );
  const repository = {
    identity: `file://${await realpath(root)}`,
    revision: stdout.trim(),
    stateDigest: digest({
      identity: `file://${await realpath(root)}`,
      revision: stdout.trim(),
      relevantDirtyPaths,
      relevantIndexEntries,
    }),
  };
  const evidence = request.evidence.map((item) =>
    redigestEvidence(item, { repository }),
  );
  const waiverHistory = request.waiverHistory;
  const waivers = request.waivers.map((waiver) => {
    const predecessor = waiverHistory.find(
      ({ id, version }) => id === waiver.id && version === waiver.version - 1,
    );
    const content = {
      ...waiver,
      ...(predecessor === undefined
        ? {}
        : { supersedesDigest: predecessor.digest }),
      validity: {
        ...waiver.validity,
        repositoryStateDigest: repository.stateDigest,
      },
    };
    const { digest: _digest, ...withoutDigest } = content;
    return { ...withoutDigest, digest: digest(withoutDigest) };
  });
  return withWaiverState(
    {
      ...request,
      repository,
      evidence,
      evidenceAuthenticity: authenticityFor(evidence),
      manifest: {
        ...request.manifest,
        evidence: manifestEvidenceFor(evidence),
      },
    },
    waivers,
    request.managedSuppressions,
    waiverHistory,
  );
}

test("exact-bound passing deterministic evidence verifies the baseline", async () => {
  const { release, request, resolved } = await verificationFixture();

  const result = await evaluateVerificationRequirements(
    release,
    resolved,
    request,
  );

  assert.equal(result.outcome, "verified");
  assert.deepEqual(result.requirements, [
    {
      layerId: "core",
      ruleId: "rule/core/exact-catalogue-pin",
      requirementId: "requirement/core/exact-catalogue-pin",
      scope: { kind: "repository", id: "repository" },
      phase: "baseline",
      kind: "deterministic-check",
      evaluation: "satisfied",
      reason: "deterministic-check-passed",
      evidenceId: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f24f8",
    },
    {
      layerId: "service",
      ruleId: "rule/example-service/package-check",
      requirementId: "requirement/example-service/package-check",
      scope: { kind: "workload", id: "service" },
      phase: "baseline",
      kind: "deterministic-check",
      evaluation: "satisfied",
      reason: "deterministic-check-passed",
      evidenceId: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f24f9",
    },
  ]);
  assert.deepEqual(result.waivers, []);

  const incompleteManifest = await evaluateVerificationRequirements(
    release,
    resolved,
    {
      ...request,
      manifest: {
        ...request.manifest,
        artifacts: request.manifest.artifacts.filter(
          ({ artifactId }) => artifactId !== "artifact/example-service/package",
        ),
      },
    },
  );
  assert.equal(incompleteManifest.outcome, "incomplete");

  const falseArtifactFingerprint = await evaluateVerificationRequirements(
    release,
    resolved,
    {
      ...request,
      manifest: {
        ...request.manifest,
        artifacts: request.manifest.artifacts.map((artifact) =>
          artifact.artifactId === "artifact/example-service/package"
            ? { ...artifact, fingerprint: `sha256:${"f".repeat(64)}` }
            : artifact,
        ),
      },
    },
  );
  assert.equal(falseArtifactFingerprint.outcome, "incomplete");
});

test("failed, errored, missing, stale, and tampered evidence fail closed", async (t) => {
  const fixture = await verificationFixture();
  const coreEvidence = fixture.request.evidence[0]!;
  const requirementId = coreEvidence.requirementId;

  await t.test("failed evidence is failed", async () => {
    const request = withEvidence(fixture.request, [
        redigestEvidence(coreEvidence, { result: "failed" }),
        fixture.request.evidence[1]!,
    ]);
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      request,
    );
    assert.equal(result.outcome, "failed");
    assert.equal(evaluationFor(result, requirementId).evaluation, "failed");
  });

  await t.test("errored evidence is incomplete", async () => {
    const request = withEvidence(fixture.request, [
        redigestEvidence(coreEvidence, { result: "error" }),
        fixture.request.evidence[1]!,
    ]);
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      request,
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, requirementId).evaluation, "incomplete");
  });

  await t.test("missing evidence is incomplete", async () => {
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      withEvidence(fixture.request, [fixture.request.evidence[1]!]),
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, requirementId).reason, "evidence-missing");
  });

  await t.test("repository drift invalidates evidence", async () => {
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      {
        ...fixture.request,
        repository: {
          ...fixture.request.repository,
          stateDigest: `sha256:${"b".repeat(64)}`,
        },
      },
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, requirementId).reason, "evidence-stale");
  });

  await t.test("content-digest tampering invalidates evidence", async () => {
    const tampered = {
      ...coreEvidence,
      output: { digest: `sha256:${"c".repeat(64)}` },
    };
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      {
        ...fixture.request,
        evidence: [tampered, fixture.request.evidence[1]!],
      },
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, requirementId).reason, "evidence-invalid");
  });

  await t.test("a substituted verifier command is invalid", async () => {
    const substituted = redigestEvidence(coreEvidence, {
      invocation: {
        ...coreEvidence.invocation,
        arguments: ["pretend-everything-passed"],
      },
    });
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      withEvidence(fixture.request, [
        substituted,
        fixture.request.evidence[1]!,
      ]),
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, requirementId).reason, "evidence-invalid");
  });

  await t.test("a self-rehashed record cannot replace its pinned authenticity", async () => {
    const rewritten = redigestEvidence(coreEvidence, {
      output: { digest: `sha256:${"d".repeat(64)}` },
    });
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      {
        ...fixture.request,
        evidence: [rewritten, fixture.request.evidence[1]!],
      },
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, requirementId).reason, "evidence-invalid");
  });
});

test("closed evidence schemas reject undeclared fields before reduction", async () => {
  const fixture = await verificationFixture();
  const invalidEvidence = {
    ...fixture.request.evidence[0]!,
    secretValue: "not-on-my-watch",
  };
  const invalidRequest = {
    ...fixture.request,
    evidence: [invalidEvidence, fixture.request.evidence[1]!],
  } as unknown as VerificationRequest;

  await assert.rejects(
    evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      invalidRequest,
    ),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "schema-invalid",
  );
});

test("unconsumed evidence prevents a Verified Baseline", async (t) => {
  const fixture = await verificationFixture();
  for (const [name, evidenceId] of [
    ["with a distinct identity", "evidence/018f47ac-10d2-7c85-bd62-0c742b1f2500"],
    ["when reusing a consumed identity", fixture.request.evidence[0]!.id],
  ] as const) {
    await t.test(name, async () => {
      const unrelatedEvidence = redigestEvidence(
        fixture.request.evidence[0]!,
        {
          id: evidenceId,
          ruleId: "rule/unrelated/unknown-rule",
          requirementId: "requirement/unrelated/unknown-requirement",
        },
      );
      const evidence = [...fixture.request.evidence, unrelatedEvidence];
      const request =
        evidenceId === fixture.request.evidence[0]!.id
          ? { ...fixture.request, evidence }
          : withEvidence(fixture.request, evidence);

      const result = await evaluateVerificationRequirements(
        fixture.release,
        fixture.resolved,
        request,
      );

      assert.equal(result.outcome, "incomplete");
    });
  }
});

test("Conflict, Catalogue Incompatibility, drift, and missing authority block verification", async (t) => {
  const fixture = await verificationFixture();
  for (const [kind, outcome] of [
    ["conflict", "failed"],
    ["catalogue-incompatibility", "failed"],
    ["drift", "failed"],
    ["missing-authority", "incomplete"],
  ] as const) {
    await t.test(kind, async () => {
      const result = await evaluateVerificationRequirements(
        fixture.release,
        fixture.resolved,
        {
          ...fixture.request,
          blockers: [{ kind, id: `blocker/${kind}`, message: `${kind} remains` }],
        },
      );
      assert.equal(result.outcome, outcome);
    });
  }
});

test("unchanged baseline verification is a deterministic no-op", async () => {
  const fixture = await verificationFixture();
  const first = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    fixture.request,
  );
  const second = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    fixture.request,
  );

  assert.deepEqual(second, first);
  assert.equal(second.outcome, "verified");
});

test("attributable review and manual-state evidence enforce authority, independence, and assurance", async (t) => {
  const fixture = await capabilityVerificationFixture();
  const accepted = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    fixture.request,
  );
  assert.equal(accepted.outcome, "verified");
  assert.equal(
    evaluationFor(
      accepted,
      "requirement/example-tests/direct-tests-review",
    ).reason,
    "review-accepted",
  );
  assert.equal(
    evaluationFor(accepted, "requirement/example-tests/manual-assurance").reason,
    "manual-state-verified",
  );

  await t.test("missing review authority is incomplete", async () => {
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      { ...fixture.request, authorities: [] },
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(
      evaluationFor(
        result,
        "requirement/example-tests/direct-tests-review",
      ).reason,
      "authority-missing",
    );
  });

  await t.test("review by the subject author violates independence", async () => {
    const review = fixture.request.evidence.find(
      ({ requirementId }) =>
        requirementId === "requirement/example-tests/direct-tests-review",
    )!;
    const authoredReview = redigestEvidence(review, {
      actor: {
        kind: "human",
        identity: "author@example.com",
        authorityClass: "authority/project-policy",
      },
    });
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      withEvidence(
        {
          ...fixture.request,
        authorities: [
          {
            authorityClass: "authority/project-policy",
            identities: ["reviewer@example.com", "author@example.com"],
            externalDecisionReferences: [],
          },
        ],
        },
        fixture.request.evidence.map((item) =>
          item.id === review.id ? authoredReview : item,
        ),
      ),
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(
      evaluationFor(
        result,
        "requirement/example-tests/direct-tests-review",
      ).reason,
      "independence-violated",
    );
  });

  await t.test("attestation cannot replace required machine read-back", async () => {
    const manual = fixture.request.evidence.find(
      ({ requirementId }) =>
        requirementId === "requirement/example-tests/manual-assurance",
    )!;
    const attestation = redigestEvidence(manual, {
      result: "attested",
      manualState: { ...manual.manualState!, assurance: "named-attestation" },
    });
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      withEvidence(
        fixture.request,
        fixture.request.evidence.map((item) =>
          item.id === manual.id ? attestation : item,
        ),
      ),
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(
      evaluationFor(result, manual.requirementId).reason,
      "evidence-invalid",
    );
  });

  await t.test("catalogue freshness windows cannot be extended", async () => {
    const review = fixture.request.evidence.find(
      ({ requirementId }) =>
        requirementId === "requirement/example-tests/direct-tests-review",
    )!;
    const stale = redigestEvidence(review, {
      observedAt: "2026-08-24T08:00:00Z",
      validUntil: "2026-08-27T08:00:00Z",
    });
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      withEvidence(
        fixture.request,
        fixture.request.evidence.map((item) =>
          item.id === review.id ? stale : item,
        ),
      ),
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, review.requirementId).reason, "evidence-stale");
  });

  await t.test("review evidence must conclude every catalogue question", async () => {
    const review = fixture.request.evidence.find(
      ({ requirementId }) =>
        requirementId === "requirement/example-tests/direct-tests-review",
    )!;
    const wrongQuestions = redigestEvidence(review, {
      questionConclusions: [
        {
          questionId: "question/example-tests/something-else",
          conclusion: "accepted",
        },
      ],
    });
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      withEvidence(
        fixture.request,
        fixture.request.evidence.map((item) =>
          item.id === review.id ? wrongQuestions : item,
        ),
      ),
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, review.requirementId).reason, "evidence-invalid");
  });

  await t.test("review and manual evidence bind the exact material fingerprint", async () => {
    const changed = fixture.request.evidence.map((item) => {
      if (item.kind === "attributable-review") {
        return redigestEvidence(item, {
          reviewedMaterialDigest: `sha256:${"e".repeat(64)}`,
        });
      }
      if (item.kind === "manual-state") {
        return redigestEvidence(item, {
          manualState: {
            ...item.manualState!,
            stateDigest: `sha256:${"f".repeat(64)}`,
          },
        });
      }
      return item;
    });
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      withEvidence(fixture.request, changed),
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(
      evaluationFor(
        result,
        "requirement/example-tests/direct-tests-review",
      ).reason,
      "evidence-invalid",
    );
    assert.equal(
      evaluationFor(result, "requirement/example-tests/manual-assurance").reason,
      "evidence-invalid",
    );
  });

  await t.test("named-identity authority cannot use an external decision", async () => {
    const review = fixture.request.evidence.find(
      ({ kind }) => kind === "attributable-review",
    )!;
    const externallyResolved = redigestEvidence(review, {
      actor: {
        kind: "human",
        identity: "unresolved@example.com",
        authorityClass: "authority/project-policy",
        externalDecisionReference: "decision/123",
      },
    });
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      withEvidence(
        {
          ...fixture.request,
          authorities: [
            {
              authorityClass: "authority/project-policy",
              identities: [],
              externalDecisionReferences: ["decision/123"],
            },
          ],
        },
        fixture.request.evidence.map((item) => {
          if (item.id === review.id) return externallyResolved;
          return item.actor === undefined
            ? item
            : redigestEvidence(item, {
                actor: {
                  ...item.actor,
                  externalDecisionReference: "decision/123",
                },
              });
        }),
      ),
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, review.requirementId).reason, "authority-missing");
  });

  await t.test("external-decision authority accepts an exact referenced decision", async () => {
    const entryId = "entry/capability/example-tests";
    const entry = fixture.release.entries.get(entryId);
    assert.ok(entry);
    const release = {
      ...fixture.release,
      entries: new Map(fixture.release.entries).set(entryId, {
        ...entry,
        authorityClasses: entry.authorityClasses.map((authority) =>
          authority.id === "authority/project-policy"
            ? { ...authority, resolution: "verifiable-external-decision" as const }
            : authority,
        ),
      }),
    };
    const review = fixture.request.evidence.find(
      ({ kind }) => kind === "attributable-review",
    )!;
    const externallyResolved = redigestEvidence(review, {
      actor: {
        kind: "human",
        identity: "reviewer@example.com",
        authorityClass: "authority/project-policy",
        externalDecisionReference: "decision/123",
      },
    });
    const result = await evaluateVerificationRequirements(
      release,
      fixture.resolved,
      withEvidence(
        {
          ...fixture.request,
          authorities: [
            {
              authorityClass: "authority/project-policy",
              identities: [],
              externalDecisionReferences: ["decision/123"],
            },
          ],
        },
        fixture.request.evidence.map((item) => {
          if (item.id === review.id) return externallyResolved;
          return item.actor === undefined
            ? item
            : redigestEvidence(item, {
                actor: {
                  ...item.actor,
                  externalDecisionReference: "decision/123",
                },
              });
        }),
      ),
    );
    assert.equal(result.outcome, "verified", JSON.stringify(result));
  });

  await t.test("separate-authority rejects the subject's authority class", async () => {
    const entryId = "entry/capability/example-tests";
    const entry = fixture.release.entries.get(entryId);
    assert.ok(entry);
    const release = {
      ...fixture.release,
      entries: new Map(fixture.release.entries).set(entryId, {
        ...entry,
        requirements: entry.requirements.map((requirement) =>
          requirement.id === "requirement/example-tests/direct-tests-review"
            ? { ...requirement, independence: "separate-authority" as const }
            : requirement,
        ),
      }),
    };
    const result = await evaluateVerificationRequirements(
      release,
      fixture.resolved,
      {
        ...fixture.request,
        subjects: fixture.request.subjects.map((subject) => ({
          ...subject,
          authorityClasses: ["authority/project-policy"],
        })),
      },
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(
      evaluationFor(
        result,
        "requirement/example-tests/direct-tests-review",
      ).reason,
      "independence-violated",
    );
  });

  await t.test("duplicate logical bindings fail closed instead of depending on order", async () => {
    const review = fixture.request.evidence.find(
      ({ kind }) => kind === "attributable-review",
    )!;
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      {
        ...fixture.request,
        requirementInputs: [
          ...fixture.request.requirementInputs,
          {
            requirementId: review.requirementId,
            scope: review.scope,
            digest: `sha256:${"f".repeat(64)}`,
          },
        ],
        authorities: [
          ...fixture.request.authorities,
          {
            authorityClass: "authority/project-policy",
            identities: [],
            externalDecisionReferences: [],
          },
        ],
        subjects: [
          ...fixture.request.subjects,
          {
            requirementId: review.requirementId,
            scope: review.scope,
            authorIdentities: ["reviewer@example.com"],
            authorityClasses: ["authority/project-policy"],
          },
        ],
      },
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, review.requirementId).evaluation, "incomplete");
  });

  await t.test("named attestation requires an attributable human attestation", async () => {
    const entryId = "entry/capability/example-tests";
    const entry = fixture.release.entries.get(entryId);
    assert.ok(entry);
    const release = {
      ...fixture.release,
      entries: new Map(fixture.release.entries).set(entryId, {
        ...entry,
        requirements: entry.requirements.map((requirement) =>
          requirement.id === "requirement/example-tests/manual-assurance"
            ? {
                ...requirement,
                manualState: {
                  ...requirement.manualState!,
                  assurance: "named-attestation" as const,
                },
              }
            : requirement,
        ),
      }),
    };
    const manual = fixture.request.evidence.find(
      ({ kind }) => kind === "manual-state",
    )!;
    const attested = redigestEvidence(manual, {
      result: "attested",
      manualState: { ...manual.manualState!, assurance: "named-attestation" },
    });
    const accepted = await evaluateVerificationRequirements(
      release,
      fixture.resolved,
      withEvidence(
        fixture.request,
        fixture.request.evidence.map((item) =>
          item.id === manual.id ? attested : item,
        ),
      ),
    );
    assert.equal(accepted.outcome, "verified");
    assert.equal(evaluationFor(accepted, manual.requirementId).reason, "manual-state-attested");

    const notVerified = redigestEvidence(attested, {
      result: "not-verified",
    });
    const disproved = await evaluateVerificationRequirements(
      release,
      fixture.resolved,
      withEvidence(
        fixture.request,
        fixture.request.evidence.map((item) =>
          item.id === manual.id ? notVerified : item,
        ),
      ),
    );
    assert.equal(disproved.outcome, "failed");
    assert.equal(
      evaluationFor(disproved, manual.requirementId).reason,
      "manual-state-not-verified",
    );

    const provider = redigestEvidence(attested, {
      result: "verified",
      actor: { ...attested.actor!, kind: "provider" },
    });
    const rejected = await evaluateVerificationRequirements(
      release,
      fixture.resolved,
      withEvidence(
        fixture.request,
        fixture.request.evidence.map((item) =>
          item.id === manual.id ? provider : item,
        ),
      ),
    );
    assert.equal(rejected.outcome, "incomplete");
    assert.equal(evaluationFor(rejected, manual.requirementId).reason, "evidence-invalid");
  });

  await t.test("machine read-back errors remain incomplete", async () => {
    const manual = fixture.request.evidence.find(
      ({ kind }) => kind === "manual-state",
    )!;
    const errored = redigestEvidence(manual, { result: "error" });
    const result = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      withEvidence(
        fixture.request,
        fixture.request.evidence.map((item) =>
          item.id === manual.id ? errored : item,
        ),
      ),
    );
    assert.equal(result.outcome, "incomplete");
    assert.equal(evaluationFor(result, manual.requirementId).reason, "manual-state-error");
  });
});

test("baseline verification proves a delivery gate but delivery requires fresh change evidence", async () => {
  const fixture = await capabilityVerificationFixture();
  const baseline = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    fixture.request,
  );
  assert.equal(
    evaluationFor(baseline, "requirement/example-tests/direct-tests").reason,
    "delivery-gate-satisfied",
  );

  const deliveryEvidence = fixture.request.evidence.map((evidence) =>
    redigestEvidence(evidence, { verificationHorizon: "delivery" }),
  );
  const delivery = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withEvidence(
      {
        ...fixture.request,
        horizon: "delivery",
        affectedRequirements: [
          {
            requirementId: "requirement/example-tests/direct-tests",
            scope: { kind: "workload", id: "service" },
          },
        ],
        requirementInputs: [
          ...fixture.request.requirementInputs,
          {
            requirementId: "requirement/example-tests/direct-tests",
            scope: { kind: "workload", id: "service" },
            digest: `sha256:${"1".repeat(64)}`,
          },
        ],
      },
      deliveryEvidence,
    ),
  );
  assert.equal(delivery.outcome, "incomplete");
  assert.equal(
    evaluationFor(delivery, "requirement/example-tests/direct-tests").reason,
    "evidence-missing",
  );

  const gate = fixture.request.evidence.find(
    ({ requirementId }) =>
      requirementId === "requirement/example-tests/test-command-gate",
  )!;
  const deliveryInput = `sha256:${"1".repeat(64)}`;
  const directEvidence = redigestEvidence(gate, {
    id: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f2453",
    requirementId: "requirement/example-tests/direct-tests",
    declaredInputsDigest: deliveryInput,
    artifactObservations: [],
    verificationHorizon: "delivery",
  });
  const scopedDeliveryRequest = {
    ...fixture.request,
    horizon: "delivery" as const,
    affectedRequirements: [
      {
        requirementId: directEvidence.requirementId,
        scope: directEvidence.scope,
      },
    ],
    requirementInputs: [
      ...fixture.request.requirementInputs,
      {
        requirementId: directEvidence.requirementId,
        scope: directEvidence.scope,
        digest: deliveryInput,
      },
    ],
  } as unknown as VerificationRequest;
  const scopedDelivery = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withEvidence(scopedDeliveryRequest, [
      ...fixture.request.evidence,
      directEvidence,
    ]),
  );
  assert.equal(scopedDelivery.outcome, "verified");
  assert.equal(
    evaluationFor(
      scopedDelivery,
      "requirement/example-tests/direct-tests",
    ).reason,
    "deterministic-check-passed",
  );

  const unknownAffected = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    {
      ...scopedDeliveryRequest,
      affectedRequirements: [
        {
          requirementId: "requirement/example-tests/unknown-change",
          scope: { kind: "workload", id: "service" },
        },
      ],
      evidence: fixture.request.evidence,
      evidenceAuthenticity: authenticityFor(fixture.request.evidence),
    },
  );
  assert.equal(unknownAffected.outcome, "incomplete");
});

test("workload-scoped capability requirements expand once per workload", async () => {
  const fixture = await capabilityVerificationFixture();
  const entryId = "entry/capability/example-tests";
  const entry = fixture.release.entries.get(entryId);
  assert.ok(entry);
  const release = {
    ...fixture.release,
    entries: new Map(fixture.release.entries).set(entryId, {
      ...entry,
      requires: [],
    }),
  };
  const configuration: BootstrapConfiguration = {
    ...fixture.resolved.configuration,
    workloads: [
      ...fixture.resolved.configuration.workloads,
      {
        id: "worker",
        kind: "example-service",
        root: "services/worker",
        choices: {},
      },
    ],
    capabilities: fixture.resolved.configuration.capabilities.map(
      (capability) => ({
        ...capability,
        scope: {
          kind: "workload" as const,
          workloadIds: ["service", "worker"],
        },
      }),
    ),
  };
  const resolved = await resolveBootstrapConfiguration(
    release,
    configuration,
  );
  const configurationDigest = digest(resolved.configuration);
  const serviceScope = {
    kind: "workload",
    id: "service",
  } as const;
  const servicePackage = fixture.request.evidence.find(
    ({ requirementId }) =>
      requirementId === "requirement/example-service/package-check",
  )!;
  const workerPackage = redigestEvidence(servicePackage, {
    id: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f2454",
    scope: { kind: "workload", id: "worker" },
    configurationDigest,
    declaredInputsDigest: `sha256:${"b".repeat(64)}`,
    invocation: {
      ...servicePackage.invocation,
      workingDirectory: "services/worker",
    },
  });
  const evidence = [
    ...fixture.request.evidence.map((item) =>
      redigestEvidence(item, {
        configurationDigest,
        ...(item.ruleId === "rule/example-tests/direct-tests"
          ? { scope: serviceScope }
          : {}),
      }),
    ),
    workerPackage,
  ];
  const workerWaiverWithoutDigest = {
    $schema:
      "https://schemas.ironicbuddha.dev/project-standards/v1/rule-waiver.schema.json",
    schemaVersion: "1.0.0" as const,
    id: "waiver/worker-review",
    version: 1,
    layerId: "service-tests",
    ruleId: "rule/example-tests/direct-tests",
    scope: { kind: "workload", id: "worker" } as const,
    requirementIds: ["requirement/example-tests/direct-tests-review"],
    managedSuppressionIds: [],
    reasonClass: "temporary-tooling-gap",
    reasonEvidence: [`sha256:${"2".repeat(64)}`],
    risk: "The worker review is temporarily unavailable.",
    riskReviewedAt: "2026-08-26T07:10:00Z",
    compensatingControls: [
      {
        requirementId: "requirement/example-tests/test-command-gate",
        evidenceIds: ["evidence/018f47ac-10d2-7c85-bd62-0c742b1f2450"],
      },
    ],
    requester: {
      kind: "human" as const,
      identity: "author@example.com",
      authorityClass: "authority/project-policy",
      actedAt: "2026-08-26T07:00:00Z",
    },
    approvals: [
      {
        kind: "human" as const,
        identity: "reviewer@example.com",
        authorityClass: "authority/project-policy",
        actedAt: "2026-08-26T07:10:00Z",
      },
    ],
    remediation: "Obtain and record the worker review.",
    validity: {
      startsAt: "2026-08-26T07:00:00Z",
      expiresAt: "2026-08-27T07:00:00Z",
      repositoryStateDigest: fixture.request.repository.stateDigest,
      configurationDigest,
      catalogueDigest: release.document.catalogueDigest,
    },
    upgradeDisposition: "revalidate" as const,
    status: "active" as const,
  };
  const workerWaiver: RuleWaiverDocument = {
    ...workerWaiverWithoutDigest,
    digest: digest(workerWaiverWithoutDigest),
  };
  const requestWithoutWaiver: VerificationRequest = {
    ...fixture.request,
    requirementInputs: evidence.map((item) => ({
      requirementId: item.requirementId,
      scope: item.scope,
      digest: item.declaredInputsDigest,
    })),
    subjects: fixture.request.subjects.map((subject) => ({
      ...subject,
      scope: serviceScope,
    })),
    evidence,
    evidenceAuthenticity: authenticityFor(evidence),
    manifest: {
      ...fixture.request.manifest,
      configurationDigest,
      evidence: manifestEvidenceFor(evidence),
    },
  };
  const request = withWaiverState(requestWithoutWaiver, [workerWaiver]);
  const result = await evaluateVerificationRequirements(
    release,
    resolved,
    request,
  );

  assert.equal(result.outcome, "incomplete");
  assert.equal(
    result.requirements.filter(
      ({ requirementId }) =>
        requirementId === "requirement/example-tests/test-command-gate",
    ).length,
    2,
  );
  assert.equal(
    result.requirements.find(
      ({ requirementId, scope }) =>
        requirementId === "requirement/example-tests/test-command-gate" &&
        scope.id === "worker",
    )?.reason,
    "evidence-missing",
  );
  assert.equal(
    result.requirements.find(
      ({ requirementId, scope }) =>
        requirementId === "requirement/example-tests/direct-tests" &&
        scope.id === "worker",
    )?.reason,
    "evidence-missing",
  );
  assert.equal(
    result.requirements.find(
      ({ requirementId, scope }) =>
        requirementId === "requirement/example-tests/direct-tests-review" &&
        scope.id === "worker",
    )?.evaluation,
    "incomplete",
  );
});

test("an exact active governed waiver remains visible and distinct from satisfaction", async () => {
  const fixture = await capabilityVerificationFixture();
  const reviewRequirement = "requirement/example-tests/direct-tests-review";
  const reviewEvidence = fixture.request.evidence.find(
    ({ requirementId }) => requirementId === reviewRequirement,
  )!;
  const configurationDigest = digest(fixture.resolved.configuration);
  const waiverWithoutDigest = {
    $schema:
      "https://schemas.ironicbuddha.dev/project-standards/v1/rule-waiver.schema.json",
    schemaVersion: "1.0.0" as const,
    id: "waiver/direct-tests-review",
    version: 1,
    layerId: "service-tests",
    ruleId: "rule/example-tests/direct-tests",
    scope: { kind: "workload", id: "service" } as const,
    requirementIds: [reviewRequirement],
    managedSuppressionIds: [],
    reasonClass: "temporary-tooling-gap",
    reasonEvidence: [`sha256:${"2".repeat(64)}`],
    risk: "A human review is temporarily unavailable.",
    riskReviewedAt: "2026-08-26T07:10:00Z",
    compensatingControls: [
      {
        requirementId: "requirement/example-tests/test-command-gate",
        evidenceIds: ["evidence/018f47ac-10d2-7c85-bd62-0c742b1f2450"],
      },
    ],
    requester: {
      kind: "human" as const,
      identity: "author@example.com",
      authorityClass: "authority/project-policy",
      actedAt: "2026-08-26T07:00:00Z",
    },
    approvals: [
      {
        kind: "human" as const,
        identity: "reviewer@example.com",
        authorityClass: "authority/project-policy",
        actedAt: "2026-08-26T07:10:00Z",
      },
    ],
    remediation: "Obtain and record the attributable review.",
    validity: {
      startsAt: "2026-08-26T07:00:00Z",
      expiresAt: "2026-08-27T07:00:00Z",
      repositoryStateDigest: fixture.request.repository.stateDigest,
      configurationDigest,
      catalogueDigest: fixture.release.document.catalogueDigest,
    },
    upgradeDisposition: "revalidate" as const,
    status: "active" as const,
  };
  const waiver: RuleWaiverDocument = {
    ...waiverWithoutDigest,
    digest: digest(waiverWithoutDigest),
  };
  const activeWaiverRequest = withWaiverState(
    withEvidence(
      fixture.request,
      fixture.request.evidence.filter(({ id }) => id !== reviewEvidence.id),
    ),
    [waiver],
  );
  const result = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    activeWaiverRequest,
  );

  assert.equal(result.outcome, "verified");
  assert.equal(evaluationFor(result, reviewRequirement).evaluation, "waived");
  assert.deepEqual(result.waivers, [
    {
      waiverId: "waiver/direct-tests-review",
      version: 1,
      digest: waiver.digest,
      ruleId: "rule/example-tests/direct-tests",
      scope: { kind: "workload", id: "service" },
      requirementIds: [reviewRequirement],
      compensatingControlRequirementIds: [
        "requirement/example-tests/test-command-gate",
      ],
      managedSuppressionIds: [],
      risk: "A human review is temporarily unavailable.",
      remediation: "Obtain and record the attributable review.",
      expiresAt: "2026-08-27T07:00:00Z",
    },
  ]);

  for (const [name, invalidRequest] of [
    [
      "missing committed-record binding",
      { ...activeWaiverRequest, waiverAuthenticity: [] },
    ],
    [
      "wrong committed-record path",
      {
        ...activeWaiverRequest,
        waiverAuthenticity: activeWaiverRequest.waiverAuthenticity.map(
          (binding) => ({
            ...binding,
            source: {
              ...binding.source,
              path: ".project-standards/waivers/different-waiver.json",
            },
          }),
        ),
      },
    ],
    [
      "missing manifest reference",
      {
        ...activeWaiverRequest,
        manifest: { ...activeWaiverRequest.manifest, activeWaivers: [] },
      },
    ],
  ] as const) {
    const invalidResult = await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      invalidRequest,
    );
    assert.equal(invalidResult.outcome, "incomplete", name);
  }

  const committedRoot = await mkdtemp(join(tmpdir(), "committed-waiver-"));
  await initializeGitFixture(committedRoot);
  const committedActiveWaiverRequest =
    await bindVerificationRequestToGitSource(
      committedRoot,
      activeWaiverRequest,
    );
  await writeCommittedVerificationFixture(
    committedRoot,
    fixture.resolved.configuration,
    committedActiveWaiverRequest,
  );
  await commitGitFixture(committedRoot, "active waiver");
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        committedActiveWaiverRequest,
        committedRoot,
      )
    ).outcome,
    "verified",
  );
  const { digest: _committedWaiverDigest, ...committedWaiverContent } =
    committedActiveWaiverRequest.waivers[0]!;
  const tamperedWaiverWithoutDigest = {
    ...committedWaiverContent,
    risk: "A caller tried to replace the committed risk statement.",
  };
  await writeFile(
    join(
      committedRoot,
      ".project-standards/waivers/direct-tests-review.json",
    ),
    `${JSON.stringify(
      {
        ...tamperedWaiverWithoutDigest,
        digest: digest(tamperedWaiverWithoutDigest),
      },
      null,
      2,
    )}\n`,
  );
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        committedActiveWaiverRequest,
        committedRoot,
      )
    ).outcome,
    "failed",
  );
  const hiddenContract = `${projectDeliveryContractContent(
    committedActiveWaiverRequest.waivers,
  )}\n<!-- stale waiver/hidden@1 -->\n`;
  const hiddenContractArtifact = {
    ...committedActiveWaiverRequest.projectDeliveryContract,
    fingerprint: `sha256:${createHash("sha256")
      .update(hiddenContract)
      .digest("hex")}`,
  };
  const hiddenContractRequest: VerificationRequest = {
    ...committedActiveWaiverRequest,
    projectDeliveryContract: hiddenContractArtifact,
    manifest: {
      ...committedActiveWaiverRequest.manifest,
      artifacts: committedActiveWaiverRequest.manifest.artifacts.map((artifact) =>
        artifact.artifactId === "artifact/core/project-delivery-contract"
          ? hiddenContractArtifact
          : artifact,
      ),
    },
  };
  await writeCommittedVerificationFixture(
    committedRoot,
    fixture.resolved.configuration,
    hiddenContractRequest,
  );
  await writeFile(join(committedRoot, "constitution.md"), hiddenContract);
  await commitGitFixture(committedRoot, "hide stale waiver in contract comment");
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        hiddenContractRequest,
        committedRoot,
      )
    ).outcome,
    "incomplete",
  );
  const duplicateContract = `${projectDeliveryContractContent(
    committedActiveWaiverRequest.waivers,
  )}\n## Active Rule Waivers\n\nNone.\n`;
  const duplicateContractArtifact = {
    ...committedActiveWaiverRequest.projectDeliveryContract,
    fingerprint: `sha256:${createHash("sha256")
      .update(duplicateContract)
      .digest("hex")}`,
  };
  const duplicateContractRequest: VerificationRequest = {
    ...committedActiveWaiverRequest,
    projectDeliveryContract: duplicateContractArtifact,
    manifest: {
      ...committedActiveWaiverRequest.manifest,
      artifacts: committedActiveWaiverRequest.manifest.artifacts.map((artifact) =>
        artifact.artifactId === "artifact/core/project-delivery-contract"
          ? duplicateContractArtifact
          : artifact,
      ),
    },
  };
  await writeCommittedVerificationFixture(
    committedRoot,
    fixture.resolved.configuration,
    duplicateContractRequest,
  );
  await writeFile(join(committedRoot, "constitution.md"), duplicateContract);
  await commitGitFixture(committedRoot, "duplicate active waiver section");
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        duplicateContractRequest,
        committedRoot,
      )
    ).outcome,
    "incomplete",
  );

  const wrongLayerWithoutDigest = {
    ...waiverWithoutDigest,
    layerId: "other-tests",
  };
  const wrongLayer: RuleWaiverDocument = {
    ...wrongLayerWithoutDigest,
    digest: digest(wrongLayerWithoutDigest),
  };
  const wrongLayerResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withWaiverState(
      withEvidence(
        fixture.request,
        fixture.request.evidence.filter(({ id }) => id !== reviewEvidence.id),
      ),
      [wrongLayer],
    ),
  );
  assert.equal(wrongLayerResult.outcome, "incomplete");

  const gateWaiverWithoutDigest = {
    ...waiverWithoutDigest,
    id: "waiver/test-command-gate",
    requirementIds: ["requirement/example-tests/test-command-gate"],
    risk: "The baseline gate is temporarily waived.",
    remediation: "Restore and prove the baseline gate.",
  };
  const gateWaiver: RuleWaiverDocument = {
    ...gateWaiverWithoutDigest,
    digest: digest(gateWaiverWithoutDigest),
  };
  const gateWaiverResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withWaiverState(fixture.request, [gateWaiver]),
  );
  assert.equal(gateWaiverResult.outcome, "incomplete");
  assert.equal(
    evaluationFor(
      gateWaiverResult,
      "requirement/example-tests/direct-tests",
    ).reason,
    "delivery-gate-unsatisfied",
  );

  const deliveryWaiverWithoutDigest = {
    ...waiverWithoutDigest,
    id: "waiver/direct-tests-delivery",
    requirementIds: ["requirement/example-tests/direct-tests"],
    risk: "Delivery verification is temporarily unavailable.",
    remediation: "Run and record delivery verification.",
  };
  const deliveryWaiver: RuleWaiverDocument = {
    ...deliveryWaiverWithoutDigest,
    digest: digest(deliveryWaiverWithoutDigest),
  };
  const deliveryWaiverResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withWaiverState(fixture.request, [deliveryWaiver]),
  );
  assert.equal(deliveryWaiverResult.outcome, "verified");
  assert.equal(
    evaluationFor(
      deliveryWaiverResult,
      "requirement/example-tests/direct-tests",
    ).evaluation,
    "waived",
  );

  const entryId = "entry/capability/example-tests";
  const entry = fixture.release.entries.get(entryId);
  assert.ok(entry);
  const externalRelease = {
    ...fixture.release,
    entries: new Map(fixture.release.entries).set(entryId, {
      ...entry,
      authorityClasses: entry.authorityClasses.map((authority) =>
        authority.id === "authority/project-policy"
          ? { ...authority, resolution: "verifiable-external-decision" as const }
          : authority,
      ),
    }),
  };
  const externalWithoutDigest = {
    ...waiverWithoutDigest,
    approvals: [
      {
        ...waiverWithoutDigest.approvals[0]!,
        externalDecisionReference: "decision/waiver-123",
      },
    ],
  };
  const externalWaiver: RuleWaiverDocument = {
    ...externalWithoutDigest,
    digest: digest(externalWithoutDigest),
  };
  const externalEvidence = fixture.request.evidence
    .filter(({ id }) => id !== reviewEvidence.id)
    .map((item) =>
      item.actor === undefined
        ? item
        : redigestEvidence(item, {
            actor: {
              ...item.actor,
              externalDecisionReference: "decision/waiver-123",
            },
          }),
    );
  const externalResult = await evaluateVerificationRequirements(
    externalRelease,
    fixture.resolved,
    withWaiverState(
      {
        ...withEvidence(fixture.request, externalEvidence),
      authorities: [
        {
          authorityClass: "authority/project-policy",
          identities: [],
          externalDecisionReferences: ["decision/waiver-123"],
        },
      ],
      },
      [externalWaiver],
    ),
  );
  assert.equal(externalResult.outcome, "verified");

  const splitAuthorityWithoutDigest = {
    ...waiverWithoutDigest,
    approvals: [
      {
        ...waiverWithoutDigest.approvals[0]!,
        identity: waiverWithoutDigest.requester.identity,
      },
      {
        ...waiverWithoutDigest.approvals[0]!,
        identity: "unauthorized-reviewer@example.com",
      },
    ],
  };
  const splitAuthorityWaiver: RuleWaiverDocument = {
    ...splitAuthorityWithoutDigest,
    digest: digest(splitAuthorityWithoutDigest),
  };
  const splitAuthorityResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withWaiverState(
      {
        ...withEvidence(
        fixture.request,
        fixture.request.evidence.filter(({ id }) => id !== reviewEvidence.id),
      ),
      authorities: [
        {
          authorityClass: "authority/project-policy",
          identities: [
            waiverWithoutDigest.requester.identity,
            "reviewer@example.com",
          ],
          externalDecisionReferences: [],
        },
      ],
      },
      [splitAuthorityWaiver],
    ),
  );
  assert.equal(splitAuthorityResult.outcome, "incomplete");

  const excessiveWithoutDigest = {
    ...waiverWithoutDigest,
    validity: {
      ...waiverWithoutDigest.validity,
      expiresAt: "2026-10-27T07:00:00Z",
    },
  };
  const excessive: RuleWaiverDocument = {
    ...excessiveWithoutDigest,
    digest: digest(excessiveWithoutDigest),
  };
  const excessiveResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withWaiverState(
      withEvidence(
        fixture.request,
        fixture.request.evidence.filter(({ id }) => id !== reviewEvidence.id),
      ),
      [excessive],
    ),
  );
  assert.equal(excessiveResult.outcome, "incomplete");
  assert.equal(
    evaluationFor(excessiveResult, reviewRequirement).evaluation,
    "incomplete",
  );

  const unsupportedWithoutDigest = {
    ...waiverWithoutDigest,
    compensatingControls: [
      {
        requirementId: "requirement/example-tests/test-command-gate",
        evidenceIds: ["evidence/018f47ac-10d2-7c85-bd62-0c742b1f2499"],
      },
    ],
  };
  const unsupported: RuleWaiverDocument = {
    ...unsupportedWithoutDigest,
    digest: digest(unsupportedWithoutDigest),
  };
  const unsupportedResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withWaiverState(
      withEvidence(
        fixture.request,
        fixture.request.evidence.filter(({ id }) => id !== reviewEvidence.id),
      ),
      [unsupported],
    ),
  );
  assert.equal(unsupportedResult.outcome, "incomplete");

  const predecessorGateEvidence = fixture.request.evidence.find(
    ({ requirementId }) =>
      requirementId === "requirement/example-tests/test-command-gate",
  );
  assert.ok(predecessorGateEvidence);
  const renewalGateEvidence = redigestEvidence(predecessorGateEvidence, {
    id: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f2470",
    observedAt: "2026-08-26T07:35:00Z",
  });
  const renewalEvidence = [
    ...fixture.request.evidence.filter(
      ({ id }) =>
        id !== reviewEvidence.id && id !== predecessorGateEvidence.id,
    ),
    renewalGateEvidence,
  ];
  const renewalWithoutDigest = {
    ...waiverWithoutDigest,
    version: 2,
    supersedes: `${waiverWithoutDigest.id}@1`,
    supersedesDigest: waiver.digest,
    riskReviewedAt: "2026-08-26T07:35:00Z",
    requester: {
      ...waiverWithoutDigest.requester,
      actedAt: "2026-08-26T07:30:00Z",
    },
    approvals: waiverWithoutDigest.approvals.map((approval) => ({
      ...approval,
      actedAt: "2026-08-26T07:40:00Z",
    })),
    compensatingControls: [
      {
        requirementId: "requirement/example-tests/test-command-gate",
        evidenceIds: [renewalGateEvidence.id],
      },
    ],
    validity: {
      ...waiverWithoutDigest.validity,
      startsAt: "2026-08-26T07:30:00Z",
    },
  };
  const renewal: RuleWaiverDocument = {
    ...renewalWithoutDigest,
    digest: digest(renewalWithoutDigest),
  };
  const renewalRequest = withWaiverState(
    withEvidence(fixture.request, renewalEvidence),
    [renewal],
    [],
    [waiver],
  );
  const renewalResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    renewalRequest,
  );
  assert.equal(renewalResult.outcome, "verified");
  assert.equal(
    evaluationFor(renewalResult, reviewRequirement).evaluation,
    "waived",
  );
  assert.equal(renewalResult.waivers[0]?.version, 2);

  const reusedEvidenceWithoutDigest = {
    ...renewalWithoutDigest,
    compensatingControls: waiverWithoutDigest.compensatingControls,
  };
  const reusedEvidence: RuleWaiverDocument = {
    ...reusedEvidenceWithoutDigest,
    digest: digest(reusedEvidenceWithoutDigest),
  };
  assert.equal(
    (
      await evaluateVerificationRequirements(
        fixture.release,
        fixture.resolved,
        withWaiverState(
          withEvidence(
            fixture.request,
            fixture.request.evidence.filter(
              ({ id }) => id !== reviewEvidence.id,
            ),
          ),
          [reusedEvidence],
          [],
          [waiver],
        ),
      )
    ).outcome,
    "incomplete",
  );

  const renewalRoot = await mkdtemp(join(tmpdir(), "committed-renewal-"));
  await initializeGitFixture(renewalRoot);
  const committedPredecessorRequest = await bindVerificationRequestToGitSource(
    renewalRoot,
    withWaiverState(
      withEvidence(
        fixture.request,
        fixture.request.evidence.filter(({ id }) => id !== reviewEvidence.id),
      ),
      [waiver],
    ),
  );
  await writeCommittedVerificationFixture(
    renewalRoot,
    fixture.resolved.configuration,
    committedPredecessorRequest,
  );
  const predecessorRevision = await commitGitFixture(renewalRoot, "waiver v1");
  assert.equal(predecessorRevision.length, 40);
  const committedRenewalRequest = await bindVerificationRequestToGitSource(
    renewalRoot,
    {
      ...renewalRequest,
      waiverHistory: [committedPredecessorRequest.waivers[0]!],
    },
  );
  await writeCommittedVerificationFixture(
    renewalRoot,
    fixture.resolved.configuration,
    committedRenewalRequest,
  );
  await commitGitFixture(renewalRoot, "waiver v2");
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        committedRenewalRequest,
        renewalRoot,
      )
    ).outcome,
    "verified",
  );
  const unauthenticatedPredecessorRequest: VerificationRequest = {
    ...committedRenewalRequest,
    waiverAuthenticity: committedRenewalRequest.waiverAuthenticity.map(
      (binding) =>
        binding.version === 1
          ? {
              ...binding,
              source: {
                ...binding.source,
                revision: "f".repeat(40),
              },
            }
          : binding,
    ),
  };
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        unauthenticatedPredecessorRequest,
        renewalRoot,
      )
    ).outcome,
    "incomplete",
  );

  const predecessorTree = (
    await execFileAsync("git", [
      "-C",
      renewalRoot,
      "rev-parse",
      `${predecessorRevision}^{tree}`,
    ])
  ).stdout.trim();
  const unreachablePredecessorRevision = (
    await execFileAsync("git", [
      "-C",
      renewalRoot,
      "commit-tree",
      predecessorTree,
      "-m",
      "unreachable waiver predecessor",
    ])
  ).stdout.trim();
  const unreachablePredecessorRequest: VerificationRequest = {
    ...committedRenewalRequest,
    waiverAuthenticity: committedRenewalRequest.waiverAuthenticity.map(
      (binding) =>
        binding.version === 1
          ? {
              ...binding,
              source: {
                ...binding.source,
                revision: unreachablePredecessorRevision,
              },
            }
          : binding,
    ),
  };
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        unreachablePredecessorRequest,
        renewalRoot,
      )
    ).outcome,
    "incomplete",
  );

  const staleApprovalWithoutDigest = {
    ...renewalWithoutDigest,
    approvals: renewalWithoutDigest.approvals.map((approval) => ({
      ...approval,
      actedAt: "2026-08-26T07:20:00Z",
    })),
  };
  const staleApproval: RuleWaiverDocument = {
    ...staleApprovalWithoutDigest,
    digest: digest(staleApprovalWithoutDigest),
  };
  const staleApprovalResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withWaiverState(
      withEvidence(fixture.request, renewalEvidence),
      [staleApproval],
      [],
      [waiver],
    ),
  );
  assert.equal(staleApprovalResult.outcome, "incomplete");

  const staleControlWithoutDigest = {
    ...renewalWithoutDigest,
    riskReviewedAt: "2026-08-26T08:00:01Z",
    requester: {
      ...renewalWithoutDigest.requester,
      actedAt: "2026-08-26T08:00:01Z",
    },
    approvals: renewalWithoutDigest.approvals.map((approval) => ({
      ...approval,
      actedAt: "2026-08-26T08:00:01Z",
    })),
    validity: {
      ...renewalWithoutDigest.validity,
      startsAt: "2026-08-26T08:00:01Z",
      expiresAt: "2026-08-27T08:00:01Z",
    },
  };
  const staleControl: RuleWaiverDocument = {
    ...staleControlWithoutDigest,
    digest: digest(staleControlWithoutDigest),
  };
  const staleControlResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withWaiverState(
      withEvidence(fixture.request, renewalEvidence),
      [staleControl],
      [],
      [waiver],
    ),
  );
  assert.equal(staleControlResult.outcome, "incomplete");

  const brokenLineageWithoutDigest = {
    ...renewalWithoutDigest,
    supersedes: `${waiverWithoutDigest.id}@7`,
  };
  const brokenLineage: RuleWaiverDocument = {
    ...brokenLineageWithoutDigest,
    digest: digest(brokenLineageWithoutDigest),
  };
  const brokenLineageResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    withWaiverState(
      withEvidence(fixture.request, renewalEvidence),
      [brokenLineage],
      [],
      [waiver],
    ),
  );
  assert.equal(brokenLineageResult.outcome, "incomplete");
  assert.equal(
    evaluationFor(brokenLineageResult, reviewRequirement).evaluation,
    "incomplete",
  );

  const wrongPredecessorDigestWithoutDigest = {
    ...renewalWithoutDigest,
    supersedesDigest: `sha256:${"f".repeat(64)}`,
  };
  const wrongPredecessorDigest: RuleWaiverDocument = {
    ...wrongPredecessorDigestWithoutDigest,
    digest: digest(wrongPredecessorDigestWithoutDigest),
  };
  const wrongPredecessorDigestResult =
    await evaluateVerificationRequirements(
      fixture.release,
      fixture.resolved,
      withWaiverState(
        withEvidence(fixture.request, renewalEvidence),
        [wrongPredecessorDigest],
        [],
        [waiver],
      ),
    );
  assert.equal(wrongPredecessorDigestResult.outcome, "incomplete");
});

test("Managed Suppressions derive exact authority from one active Rule Waiver", async (t) => {
  const fixture = await capabilityVerificationFixture();
  const suppressionId = "suppression/example-tests/direct-tests-exclusion";
  const artifactId = "artifact/example-tests/direct-tests-suppression";
  const reviewRequirement = "requirement/example-tests/direct-tests-review";
  const gateRequirement = "requirement/example-tests/test-command-gate";
  const gateEvidence = fixture.request.evidence.find(
    ({ requirementId }) => requirementId === gateRequirement,
  );
  assert.ok(gateEvidence);
  const release = fixture.release;
  const configurationDigest = digest(fixture.resolved.configuration);
  const waiverWithoutDigest = {
    $schema:
      "https://schemas.ironicbuddha.dev/project-standards/v1/rule-waiver.schema.json",
    schemaVersion: "1.0.0" as const,
    id: "waiver/direct-tests-suppression",
    version: 1,
    layerId: "service-tests",
    ruleId: "rule/example-tests/direct-tests",
    scope: { kind: "workload", id: "service" } as const,
    requirementIds: [reviewRequirement],
    managedSuppressionIds: [suppressionId],
    reasonClass: "temporary-tooling-gap",
    reasonEvidence: [`sha256:${"2".repeat(64)}`],
    risk: "Direct-test review is temporarily suppressed.",
    riskReviewedAt: "2026-08-26T07:10:00Z",
    compensatingControls: [
      {
        requirementId: gateRequirement,
        evidenceIds: [gateEvidence.id],
      },
    ],
    requester: {
      kind: "human" as const,
      identity: "author@example.com",
      authorityClass: "authority/project-policy",
      actedAt: "2026-08-26T07:00:00Z",
    },
    approvals: [
      {
        kind: "human" as const,
        identity: "reviewer@example.com",
        authorityClass: "authority/project-policy",
        actedAt: "2026-08-26T07:10:00Z",
      },
    ],
    remediation: "Restore direct-test review and remove the suppression.",
    validity: {
      startsAt: "2026-08-26T07:00:00Z",
      expiresAt: "2026-08-27T07:00:00Z",
      repositoryStateDigest: fixture.request.repository.stateDigest,
      configurationDigest,
      catalogueDigest: fixture.release.document.catalogueDigest,
    },
    upgradeDisposition: "revalidate" as const,
    status: "active" as const,
  };
  const waiver = {
    ...waiverWithoutDigest,
    digest: digest(waiverWithoutDigest),
  };
  const managedSuppression = {
    id: suppressionId,
    waiverId: waiver.id,
    waiverVersion: waiver.version,
    scope: waiver.scope,
    artifact: {
      artifactId,
      ownerLayerId: "service-tests",
      locator: "services/api/eslint.config.mjs#direct-tests-waiver",
      ownership: "structured-fragment" as const,
      fingerprint: gateEvidence.declaredInputsDigest,
      verificationState: "matching" as const,
    },
    verificationEvidenceId: gateEvidence.id,
  };
  const evidence = fixture.request.evidence.filter(
    ({ requirementId }) => requirementId !== reviewRequirement,
  );
  const waiverRequest = withEvidence(fixture.request, evidence);
  const request = withWaiverState(
    waiverRequest,
    [waiver],
    [managedSuppression],
  );

  const accepted = await evaluateVerificationRequirements(
    release,
    fixture.resolved,
    request,
  );
  assert.equal(accepted.outcome, "verified");
  assert.equal(evaluationFor(accepted, reviewRequirement).evaluation, "waived");
  assert.deepEqual(
    (
      accepted as unknown as {
        managedSuppressions: readonly Readonly<{
          suppressionId: string;
          evaluation: string;
          waiverId: string;
          waiverVersion: number;
          artifact?: typeof managedSuppression.artifact;
        }>[];
      }
    ).managedSuppressions,
    [
      {
        suppressionId,
        evaluation: "active",
        reason: "active-waiver",
        waiverId: waiver.id,
        waiverVersion: 1,
        ruleId: waiver.ruleId,
        scope: waiver.scope,
        artifact: managedSuppression.artifact,
      },
    ],
  );
  const conflictingGateEvidence = redigestEvidence(gateEvidence, {
    artifactObservations: [
      ...gateEvidence.artifactObservations,
      {
        ...gateEvidence.artifactObservations[0]!,
        fingerprint: `sha256:${"f".repeat(64)}`,
      },
    ],
  });
  const conflictingObservationResult = await evaluateVerificationRequirements(
    release,
    fixture.resolved,
    withEvidence(
      request,
      evidence.map((item) =>
        item.id === gateEvidence.id ? conflictingGateEvidence : item,
      ),
    ),
  );
  assert.equal(conflictingObservationResult.outcome, "incomplete");

  const repeated = await evaluateVerificationRequirements(
    release,
    fixture.resolved,
    request,
  );
  assert.deepEqual(repeated, accepted);

  const layeredConfiguration: BootstrapConfiguration = {
    ...fixture.resolved.configuration,
    capabilities: [
      {
        id: "other-tests",
        kind: "example-tests",
        scope: { kind: "workload", workloadIds: ["service"] },
        choices: {},
      },
      ...fixture.resolved.configuration.capabilities,
    ],
  };
  const layeredResolved = await resolveBootstrapConfiguration(
    release,
    layeredConfiguration,
  );
  const layeredConfigurationDigest = digest(layeredResolved.configuration);
  const layeredEvidence = fixture.request.evidence.map((item) =>
    redigestEvidence(item, {
      configurationDigest: layeredConfigurationDigest,
      ...(item.id === gateEvidence.id
        ? {
            artifactObservations: [
              ...item.artifactObservations,
              ...item.artifactObservations.map((observation) => ({
                ...observation,
                ownerLayerId: "other-tests",
              })),
            ],
          }
        : {}),
    }),
  );
  const layeredWaiverWithoutDigest = {
    ...waiverWithoutDigest,
    validity: {
      ...waiverWithoutDigest.validity,
      configurationDigest: layeredConfigurationDigest,
    },
  };
  const layeredWaiver = {
    ...layeredWaiverWithoutDigest,
    digest: digest(layeredWaiverWithoutDigest),
  };
  const layeredGateEvidence = layeredEvidence.find(
    ({ id }) => id === gateEvidence.id,
  );
  assert.ok(layeredGateEvidence);
  const layeredSuppression = {
    ...managedSuppression,
    waiverId: layeredWaiver.id,
    waiverVersion: layeredWaiver.version,
    verificationEvidenceId: layeredGateEvidence.id,
    artifact: {
      ...managedSuppression.artifact,
      fingerprint: layeredGateEvidence.declaredInputsDigest,
    },
  };
  const layeredBaseRequest = withEvidence(fixture.request, layeredEvidence);
  const layeredRequest = withWaiverState(
    {
      ...layeredBaseRequest,
      manifest: {
        ...layeredBaseRequest.manifest,
        configurationDigest: layeredConfigurationDigest,
        artifacts: [
          ...layeredBaseRequest.manifest.artifacts.map((artifact) =>
            artifact.artifactId === "artifact/core/configuration"
              ? { ...artifact, fingerprint: layeredConfigurationDigest }
              : artifact,
          ),
          {
            artifactId: "artifact/example-tests/test-command",
            ownerLayerId: "other-tests",
            locator: "services/api/package.json#scripts.test",
            ownership: "structured-fragment" as const,
            fingerprint: layeredGateEvidence.declaredInputsDigest,
            verificationState: "matching" as const,
          },
          {
            artifactId: "artifact/example-tests/direct-tests-suppression",
            ownerLayerId: "other-tests",
            locator: "services/api/eslint.config.mjs#direct-tests-waiver",
            ownership: "structured-fragment" as const,
            fingerprint: layeredGateEvidence.declaredInputsDigest,
            verificationState: "matching" as const,
          },
        ],
      },
    },
    [layeredWaiver],
    [layeredSuppression],
  );
  const layeredResult = await evaluateVerificationRequirements(
    release,
    layeredResolved,
    layeredRequest,
  );
  assert.equal(layeredResult.outcome, "verified");
  assert.equal(layeredResult.managedSuppressions[0]?.evaluation, "active");

  for (const fixtureId of [
    "fixture/verification/valid-suppression",
    "fixture/verification/invalid-binding",
    "fixture/verification/suppression-drift",
    "fixture/verification/no-op",
  ]) {
    const executableFixture = release.fixtures.get(fixtureId) as
      | Readonly<{
          expectation: "verified" | "incomplete";
          document: Readonly<{
            binding: "exact" | "missing";
            suppression: "matching" | "drifted";
            repetitions: 1 | 2;
          }>;
        }>
      | undefined;
    assert.ok(executableFixture, fixtureId);
    const suppression =
      executableFixture.document.suppression === "matching"
        ? managedSuppression
        : {
            ...managedSuppression,
            artifact: {
              ...managedSuppression.artifact,
              verificationState: "drifted" as const,
            },
          };
    const boundRequest = withWaiverState(
      waiverRequest,
      [waiver],
      [suppression],
    );
    const executableRequest =
      executableFixture.document.binding === "exact"
        ? boundRequest
        : { ...boundRequest, waiverAuthenticity: [] };
    const firstResult = await evaluateVerificationRequirements(
      release,
      fixture.resolved,
      executableRequest,
    );
    assert.equal(firstResult.outcome, executableFixture.expectation, fixtureId);
    for (
      let repetition = 1;
      repetition < executableFixture.document.repetitions;
      repetition += 1
    ) {
      assert.deepEqual(
        await evaluateVerificationRequirements(
          release,
          fixture.resolved,
          executableRequest,
        ),
        firstResult,
        fixtureId,
      );
    }
  }

  const cases = [
    {
      name: "missing suppression",
      request: withWaiverState(waiverRequest, [waiver]),
    },
    {
      name: "scope exceeds waiver",
      request: withWaiverState(waiverRequest, [waiver], [
          {
            ...managedSuppression,
            scope: { kind: "workload" as const, id: "worker" },
          },
        ]),
    },
    {
      name: "managed artifact drift",
      request: withWaiverState(waiverRequest, [waiver], [
          {
            ...managedSuppression,
            artifact: {
              ...managedSuppression.artifact,
              verificationState: "drifted" as const,
            },
          },
        ]),
    },
    {
      name: "artifact evidence mismatch",
      request: withWaiverState(waiverRequest, [waiver], [
          {
            ...managedSuppression,
            artifact: {
              ...managedSuppression.artifact,
              fingerprint: `sha256:${"f".repeat(64)}`,
            },
          },
        ]),
    },
    {
      name: "orphaned suppression",
      request: withWaiverState(waiverRequest, [], [managedSuppression]),
    },
    {
      name: "expired waiver",
      request: withWaiverState(
        waiverRequest,
        [
          {
            ...waiver,
            status: "expired" as const,
            digest: digest({ ...waiverWithoutDigest, status: "expired" }),
          },
        ],
        [managedSuppression],
      ),
    },
  ] as const;
  for (const testCase of cases) {
    await t.test(testCase.name, async () => {
      const result = await evaluateVerificationRequirements(
        release,
        fixture.resolved,
        testCase.request as unknown as VerificationRequest,
      );
      assert.equal(result.outcome, "incomplete");
      assert.equal(
        (
          result as unknown as {
            managedSuppressions: readonly Readonly<{ evaluation: string }>[];
          }
        ).managedSuppressions.some(
          ({ evaluation }) => evaluation === "incomplete",
        ),
        true,
      );
    });
  }

  const expiredWithoutDigest = {
    ...waiverWithoutDigest,
    status: "expired" as const,
  };
  const restored = await evaluateVerificationRequirements(
    release,
    fixture.resolved,
    withWaiverState(
      fixture.request,
      [
        {
          ...expiredWithoutDigest,
          digest: digest(expiredWithoutDigest),
        },
      ],
    ),
  );
  assert.equal(restored.outcome, "verified");
  assert.deepEqual(restored.waivers, []);
  assert.deepEqual(restored.managedSuppressions, []);
});

test("catalogue CLI independently evaluates an exact verification request", async () => {
  const fixture = await verificationFixture();
  const runRoot = await mkdtemp(join(tmpdir(), "verification-run-"));
  await initializeGitFixture(runRoot);
  const committedRequest = await bindVerificationRequestToGitSource(
    runRoot,
    fixture.request,
  );
  const requestPath = await writeCommittedVerificationFixture(
    runRoot,
    fixture.resolved.configuration,
    committedRequest,
  );
  await commitGitFixture(runRoot, "verified baseline");

  const { stdout, stderr } = await execFileAsync(process.execPath, [
    join(packageRoot, "dist/src/cli.js"),
    "evaluate-verification",
    join(packageRoot, "fixtures/valid/foundation-release"),
    runRoot,
    requestPath,
  ]);

  assert.equal(stderr, "");
  const result = JSON.parse(stdout) as { outcome: string; requirements: unknown[] };
  assert.equal(result.outcome, "verified");
  assert.equal(result.requirements.length, 2);

  const ambientGitOverride = await execFileAsync(
    process.execPath,
    [
      join(packageRoot, "dist/src/cli.js"),
      "evaluate-verification",
      join(packageRoot, "fixtures/valid/foundation-release"),
      runRoot,
      requestPath,
    ],
    {
      env: {
        ...process.env,
        GIT_DIR: join(runRoot, "hostile-ambient-git-directory"),
        GIT_WORK_TREE: join(runRoot, "hostile-ambient-work-tree"),
      },
    },
  );
  assert.equal(JSON.parse(ambientGitOverride.stdout).outcome, "verified");

  const forgedRepositoryRequestPath = join(
    runRoot,
    ".project-standards/run/forged-repository-request.json",
  );
  await writeFile(
    forgedRepositoryRequestPath,
    `${JSON.stringify(
      {
        ...committedRequest,
        repository: {
          ...committedRequest.repository,
          revision: "f".repeat(40),
        },
      },
      null,
      2,
    )}\n`,
  );
  const forgedRepository = await execFileResult(process.execPath, [
    join(packageRoot, "dist/src/cli.js"),
    "evaluate-verification",
    join(packageRoot, "fixtures/valid/foundation-release"),
    runRoot,
    forgedRepositoryRequestPath,
  ]);
  assert.equal(forgedRepository.exitCode, 1);
  assert.equal(JSON.parse(forgedRepository.stdout).outcome, "failed");

  const dirtySourcePath = join(runRoot, "notes.txt");
  await writeFile(dirtySourcePath, "first dirty source bytes\n");
  const dirtyBoundRequest = await bindVerificationRequestToGitSource(
    runRoot,
    committedRequest,
  );
  await writeCommittedVerificationFixture(
    runRoot,
    fixture.resolved.configuration,
    dirtyBoundRequest,
  );
  await commitGitFixture(runRoot, "bind dirty source bytes");
  const dirtyBound = await execFileResult(process.execPath, [
    join(packageRoot, "dist/src/cli.js"),
    "evaluate-verification",
    join(packageRoot, "fixtures/valid/foundation-release"),
    runRoot,
    requestPath,
  ]);
  assert.equal(dirtyBound.exitCode, 0);
  assert.equal(JSON.parse(dirtyBound.stdout).outcome, "verified");

  await writeFile(dirtySourcePath, "different dirty source bytes\n");
  const changedDirtyBytes = await execFileResult(process.execPath, [
    join(packageRoot, "dist/src/cli.js"),
    "evaluate-verification",
    join(packageRoot, "fixtures/valid/foundation-release"),
    runRoot,
    requestPath,
  ]);
  assert.equal(changedDirtyBytes.exitCode, 1);
  assert.equal(JSON.parse(changedDirtyBytes.stdout).outcome, "failed");

  await writeFile(
    join(runRoot, "constitution.md"),
    "# Project Delivery Contract\n\nTampered after manifest promotion.\n",
  );
  const driftedContract = await execFileResult(process.execPath, [
    join(packageRoot, "dist/src/cli.js"),
    "evaluate-verification",
    join(packageRoot, "fixtures/valid/foundation-release"),
    runRoot,
    requestPath,
  ]);
  assert.equal(driftedContract.exitCode, 1);
  assert.equal(JSON.parse(driftedContract.stdout).outcome, "failed");
});

test("committed verification binds staged bytes independently of working-tree bytes", async () => {
  const fixture = await verificationFixture();
  const runRoot = await mkdtemp(join(tmpdir(), "verification-index-binding-"));
  await initializeGitFixture(runRoot);
  const trackedPath = join(runRoot, "tracked.txt");
  await writeFile(trackedPath, "committed bytes\n");
  await execFileAsync("git", ["-C", runRoot, "add", "tracked.txt"]);
  await execFileAsync("git", ["-C", runRoot, "commit", "-m", "tracked source"]);

  await writeFile(trackedPath, "first staged bytes\n");
  await execFileAsync("git", ["-C", runRoot, "add", "tracked.txt"]);
  const stableWorkingTreeBytes = "stable working-tree bytes\n";
  await writeFile(trackedPath, stableWorkingTreeBytes);
  const boundRequest = await bindVerificationRequestToGitSource(
    runRoot,
    fixture.request,
  );
  await writeCommittedVerificationFixture(
    runRoot,
    fixture.resolved.configuration,
    boundRequest,
  );
  await commitGitFixture(runRoot, "promote staged-state binding");
  assert.match(
    (await execFileAsync("git", ["-C", runRoot, "status", "--short"])).stdout,
    /^MM tracked\.txt$/mu,
  );
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        boundRequest,
        runRoot,
      )
    ).outcome,
    "verified",
  );

  await writeFile(trackedPath, "different staged bytes\n");
  await execFileAsync("git", ["-C", runRoot, "add", "tracked.txt"]);
  await writeFile(trackedPath, stableWorkingTreeBytes);
  assert.match(
    (await execFileAsync("git", ["-C", runRoot, "status", "--short"])).stdout,
    /^MM tracked\.txt$/mu,
  );
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        boundRequest,
        runRoot,
      )
    ).outcome,
    "failed",
  );
});

test("committed verification keeps relevant rename origins bound inside runtime paths", async () => {
  const fixture = await verificationFixture();
  const runRoot = await mkdtemp(join(tmpdir(), "verification-runtime-rename-"));
  await initializeGitFixture(runRoot);
  const trackedPath = join(runRoot, "tracked.txt");
  const runtimeRoot = join(runRoot, ".project-standards/run");
  const runtimePath = join(runtimeRoot, "tracked.txt");
  const originalLines = Array.from(
    { length: 100 },
    (_, index) => `stable tracked line ${index}`,
  );
  await writeFile(trackedPath, `${originalLines.join("\n")}\n`);
  await execFileAsync("git", ["-C", runRoot, "add", "tracked.txt"]);
  await execFileAsync("git", ["-C", runRoot, "commit", "-m", "tracked source"]);

  await mkdir(runtimeRoot, { recursive: true });
  await execFileAsync("git", [
    "-C",
    runRoot,
    "mv",
    "tracked.txt",
    ".project-standards/run/tracked.txt",
  ]);
  const boundRequest = await bindVerificationRequestToGitSource(
    runRoot,
    fixture.request,
  );
  await writeCommittedVerificationFixture(
    runRoot,
    fixture.resolved.configuration,
    boundRequest,
  );
  await commitGitFixture(runRoot, "promote runtime-rename binding");
  assert.match(
    (await execFileAsync("git", ["-C", runRoot, "status", "--short"])).stdout,
    /^R  tracked\.txt -> \.project-standards\/run\/tracked\.txt$/mu,
  );
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        boundRequest,
        runRoot,
      )
    ).outcome,
    "verified",
  );

  const changedLines = [...originalLines];
  changedLines[50] = "changed staged line 50";
  await writeFile(runtimePath, `${changedLines.join("\n")}\n`);
  await execFileAsync("git", [
    "-C",
    runRoot,
    "add",
    ".project-standards/run/tracked.txt",
  ]);
  assert.match(
    (await execFileAsync("git", ["-C", runRoot, "status", "--short"])).stdout,
    /^R  tracked\.txt -> \.project-standards\/run\/tracked\.txt$/mu,
  );
  assert.equal(
    (
      await evaluateCommittedVerificationRequirements(
        fixture.release,
        boundRequest,
        runRoot,
      )
    ).outcome,
    "failed",
  );
});

test("catalogue CLI distinguishes failed and incomplete verification outcomes", async (t) => {
  const fixture = await verificationFixture();
  const runRoot = await mkdtemp(join(tmpdir(), "verification-exit-status-"));
  await initializeGitFixture(runRoot);

  const cases = [
    {
      name: "failed",
      exitCode: 1,
      request: {
        ...fixture.request,
        blockers: [
          {
            kind: "conflict" as const,
            id: "blocker/conflict",
            message: "Conflict remains",
          },
        ],
      },
    },
    {
      name: "incomplete",
      exitCode: 3,
      request: withEvidence(fixture.request, fixture.request.evidence.slice(1)),
    },
  ] as const;

  for (const testCase of cases) {
    await t.test(testCase.name, async () => {
      const committedRequest = await bindVerificationRequestToGitSource(
        runRoot,
        testCase.request,
      );
      const requestPath = await writeCommittedVerificationFixture(
        runRoot,
        fixture.resolved.configuration,
        committedRequest,
      );
      await commitGitFixture(runRoot, `${testCase.name} verification`);
      const result = await execFileResult(process.execPath, [
        join(packageRoot, "dist/src/cli.js"),
        "evaluate-verification",
        join(packageRoot, "fixtures/valid/foundation-release"),
        runRoot,
        requestPath,
      ]);

      assert.equal(result.stderr, "");
      assert.equal(result.exitCode, testCase.exitCode);
      assert.equal(JSON.parse(result.stdout).outcome, testCase.name);
    });
  }
});
