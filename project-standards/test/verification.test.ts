import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import canonicalizeModule from "canonicalize";

import {
  type BootstrapConfiguration,
  CatalogueValidationError,
  evaluateVerificationRequirements,
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

function withEvidence(
  request: VerificationRequest,
  evidence: readonly VerificationEvidenceDocument[],
): VerificationRequest {
  return {
    ...request,
    evidence,
    evidenceAuthenticity: authenticityFor(evidence),
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
  };
  return { request, release, resolved };
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
    ruleId: "rule/example-tests/direct-tests",
    scope: { kind: "workload", id: "worker" } as const,
    requirementIds: ["requirement/example-tests/direct-tests-review"],
    reasonClass: "temporary-tooling-gap",
    reasonEvidence: [`sha256:${"2".repeat(64)}`],
    risk: "The worker review is temporarily unavailable.",
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
    },
    approvals: [
      {
        kind: "human" as const,
        identity: "reviewer@example.com",
        authorityClass: "authority/project-policy",
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
  const request: VerificationRequest = {
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
    waivers: [workerWaiver],
  };
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
    ruleId: "rule/example-tests/direct-tests",
    scope: { kind: "workload", id: "service" } as const,
    requirementIds: [reviewRequirement],
    reasonClass: "temporary-tooling-gap",
    reasonEvidence: [`sha256:${"2".repeat(64)}`],
    risk: "A human review is temporarily unavailable.",
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
    },
    approvals: [
      {
        kind: "human" as const,
        identity: "reviewer@example.com",
        authorityClass: "authority/project-policy",
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
  const result = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    {
      ...withEvidence(
        fixture.request,
        fixture.request.evidence.filter(({ id }) => id !== reviewEvidence.id),
      ),
      waivers: [waiver],
    },
  );

  assert.equal(result.outcome, "verified");
  assert.equal(evaluationFor(result, reviewRequirement).evaluation, "waived");
  assert.deepEqual(result.waivers, [
    {
      waiverId: "waiver/direct-tests-review",
      version: 1,
      requirementId: reviewRequirement,
      scope: { kind: "workload", id: "service" },
      expiresAt: "2026-08-27T07:00:00Z",
    },
  ]);

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
    { ...fixture.request, waivers: [gateWaiver] },
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
    { ...fixture.request, waivers: [deliveryWaiver] },
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
    {
      ...withEvidence(fixture.request, externalEvidence),
      authorities: [
        {
          authorityClass: "authority/project-policy",
          identities: [],
          externalDecisionReferences: ["decision/waiver-123"],
        },
      ],
      waivers: [externalWaiver],
    },
  );
  assert.equal(externalResult.outcome, "verified");

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
    {
      ...withEvidence(
        fixture.request,
        fixture.request.evidence.filter(({ id }) => id !== reviewEvidence.id),
      ),
      waivers: [excessive],
    },
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
    {
      ...withEvidence(
        fixture.request,
        fixture.request.evidence.filter(({ id }) => id !== reviewEvidence.id),
      ),
      waivers: [unsupported],
    },
  );
  assert.equal(unsupportedResult.outcome, "incomplete");

  const renewalWithoutDigest = {
    ...waiverWithoutDigest,
    version: 2,
    supersedes: `${waiverWithoutDigest.id}@1`,
  };
  const renewal: RuleWaiverDocument = {
    ...renewalWithoutDigest,
    digest: digest(renewalWithoutDigest),
  };
  const renewalResult = await evaluateVerificationRequirements(
    fixture.release,
    fixture.resolved,
    {
      ...withEvidence(
        fixture.request,
        fixture.request.evidence.filter(({ id }) => id !== reviewEvidence.id),
      ),
      waivers: [renewal],
    },
  );
  assert.equal(renewalResult.outcome, "incomplete");
  assert.equal(
    evaluationFor(renewalResult, reviewRequirement).evaluation,
    "incomplete",
  );
});

test("catalogue CLI independently evaluates an exact verification request", async () => {
  const fixture = await verificationFixture();
  const runRoot = await mkdtemp(join(tmpdir(), "verification-run-"));
  const configurationPath = join(runRoot, "configuration.json");
  const requestPath = join(runRoot, "verification-request.json");
  await Promise.all([
    writeFile(
      configurationPath,
      `${JSON.stringify(fixture.resolved.configuration, null, 2)}\n`,
    ),
    writeFile(requestPath, `${JSON.stringify(fixture.request, null, 2)}\n`),
  ]);

  const { stdout, stderr } = await execFileAsync(process.execPath, [
    join(packageRoot, "dist/src/cli.js"),
    "evaluate-verification",
    join(packageRoot, "fixtures/valid/foundation-release"),
    configurationPath,
    requestPath,
  ]);

  assert.equal(stderr, "");
  const result = JSON.parse(stdout) as { outcome: string; requirements: unknown[] };
  assert.equal(result.outcome, "verified");
  assert.equal(result.requirements.length, 2);
});
