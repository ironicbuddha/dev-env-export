import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { cp, mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import {
  type BootstrapConfiguration,
  calculateCatalogueReleaseDigest,
  CatalogueValidationError,
  loadCatalogueRelease,
  resolveBootstrapConfiguration,
  validateProjectStandardsDocument,
} from "../src/index.js";

const releaseSchema =
  "https://schemas.ironicbuddha.dev/project-standards/v1/catalogue-release.schema.json";
const packageRoot = join(dirname(fileURLToPath(import.meta.url)), "../..");
const execFileAsync = promisify(execFile);

function foundationConfiguration(
  release: Awaited<ReturnType<typeof loadCatalogueRelease>>,
  overrides: Readonly<{
    coreChoices?: Readonly<Record<string, string | boolean | number>>;
    workloads?: BootstrapConfiguration["workloads"];
    capabilities?: BootstrapConfiguration["capabilities"];
    extensions?: Readonly<Record<string, unknown>>;
  }> = {},
): BootstrapConfiguration {
  return {
    $schema:
      "https://schemas.ironicbuddha.dev/project-standards/v1/configuration.schema.json",
    schemaVersion: "1.0.0",
    catalogueVersion: release.document.catalogueVersion,
    catalogueDigest: release.document.catalogueDigest,
    core: { kind: "core", choices: overrides.coreChoices ?? {} },
    workloads:
      overrides.workloads ??
      [
        {
          id: "service",
          kind: "example-service",
          root: "services/api",
          choices: {},
        },
      ],
    capabilities:
      overrides.capabilities ??
      [
        {
          id: "service-tests",
          kind: "example-tests",
          scope: { kind: "workload", workloadIds: ["service"] },
          choices: {},
        },
      ],
    extensions: overrides.extensions ?? {},
  };
}

async function mutateFoundationRelease(
  documentPath: string,
  mutate: (document: Record<string, unknown>) => void,
): Promise<string> {
  const releaseRoot = await mkdtemp(join(tmpdir(), "catalogue-release-"));
  await cp(
    join(packageRoot, "fixtures/valid/foundation-release"),
    releaseRoot,
    { recursive: true },
  );
  const absoluteDocumentPath = join(releaseRoot, documentPath);
  const document = JSON.parse(
    await readFile(absoluteDocumentPath, "utf8"),
  ) as Record<string, unknown>;
  mutate(document);
  await writeFile(
    absoluteDocumentPath,
    `${JSON.stringify(document, null, 2)}\n`,
  );

  const releasePath = join(releaseRoot, "release.json");
  const release = JSON.parse(
    await readFile(releasePath, "utf8"),
  ) as Record<string, unknown>;
  release.catalogueDigest = await calculateCatalogueReleaseDigest(releaseRoot);
  await writeFile(releasePath, `${JSON.stringify(release, null, 2)}\n`);
  return releaseRoot;
}

function validVerificationEvidence(): Record<string, unknown> {
  return {
    $schema:
      "https://schemas.ironicbuddha.dev/project-standards/v1/verification-evidence.schema.json",
    schemaVersion: "1.0.0",
    id: "evidence/018f47ac-10d2-7c85-bd62-0c742b1f24f8",
    ruleId: "rule/core/exact-catalogue-pin",
    requirementId: "requirement/core/exact-catalogue-pin",
    scope: { kind: "repository", id: "repository" },
    repository: {
      identity: "github.com/ironicbuddha/example",
      revision: "a".repeat(40),
      stateDigest: `sha256:${"3".repeat(64)}`,
    },
    configurationDigest: `sha256:${"4".repeat(64)}`,
    catalogueVersion: "1.0.0",
    catalogueDigest: `sha256:${"5".repeat(64)}`,
    declaredInputsDigest: `sha256:${"6".repeat(64)}`,
    invocation: {
      executable: "project-standards-catalogue",
      arguments: ["validate-release"],
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
    observedAt: "2026-08-25T00:00:00Z",
    output: { digest: `sha256:${"7".repeat(64)}` },
  };
}

test("Catalogue Release rejects fields outside its closed schema", async () => {
  const releaseRoot = await mkdtemp(join(tmpdir(), "catalogue-release-"));
  await mkdir(releaseRoot, { recursive: true });
  await writeFile(
    join(releaseRoot, "release.json"),
    JSON.stringify({
      $schema: releaseSchema,
      schemaVersion: "1.0.0",
      catalogueVersion: "1.0.0",
      catalogueDigest: `sha256:${"0".repeat(64)}`,
      schemas: [releaseSchema],
      entries: [],
      migrations: [],
      fixtures: [],
      sourceGuidance: [],
      supportEvidence: [],
      extensions: [],
      allowUnknownPolicy: true,
    }),
  );

  await assert.rejects(
    loadCatalogueRelease(releaseRoot),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "schema-invalid" &&
      error.documentPath === "release.json",
  );
});

test("Catalogue Release rejects a mismatched content digest", async () => {
  const releaseRoot = await mkdtemp(join(tmpdir(), "catalogue-release-"));
  await writeFile(
    join(releaseRoot, "release.json"),
    JSON.stringify({
      $schema: releaseSchema,
      schemaVersion: "1.0.0",
      catalogueVersion: "1.0.0",
      catalogueDigest: `sha256:${"0".repeat(64)}`,
      schemas: [releaseSchema],
      entries: [],
      migrations: [],
      fixtures: [],
      sourceGuidance: [],
      supportEvidence: [],
      extensions: [],
    }),
  );

  await assert.rejects(
    loadCatalogueRelease(releaseRoot),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "digest-mismatch" &&
      error.documentPath === "release.json",
  );
});

test("Catalogue Release rejects referenced paths outside its root", async () => {
  const containerRoot = await mkdtemp(join(tmpdir(), "catalogue-container-"));
  const releaseRoot = join(containerRoot, "release");
  await mkdir(releaseRoot, { recursive: true });
  await writeFile(join(containerRoot, "outside.json"), "{}\n");
  await writeFile(
    join(releaseRoot, "release.json"),
    JSON.stringify({
      $schema: releaseSchema,
      schemaVersion: "1.0.0",
      catalogueVersion: "1.0.0",
      catalogueDigest: `sha256:${"0".repeat(64)}`,
      schemas: [releaseSchema],
      entries: ["entries/a/../../../outside.json"],
      migrations: [],
      fixtures: [],
      sourceGuidance: [],
      supportEvidence: [],
      extensions: [],
    }),
  );

  await assert.rejects(
    loadCatalogueRelease(releaseRoot),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "unsafe-path",
  );
});

test("Catalogue Release loads an atomic, content-addressed entry set", async () => {
  const fixtureRoot = join(packageRoot, "fixtures/valid/foundation-release");
  assert.equal(
    await calculateCatalogueReleaseDigest(fixtureRoot),
    "sha256:17f3671c948fa9fe1bcd8be1a7ed8d7b2f491b220f18487ccac2784a7e22a824",
  );
  const release = await loadCatalogueRelease(fixtureRoot);

  assert.equal(release.entries.size, 4);
  assert.deepEqual([...release.entries.keys()].sort(), [
    "entry/capability/example-conflict",
    "entry/capability/example-tests",
    "entry/core/core",
    "entry/workload/example-service",
  ]);
  assert.equal(release.migrations.size, 1);
  assert.equal(release.fixtures.size, 3);
  assert.equal(release.sourceGuidance.size, 1);
  assert.equal(release.supportEvidence.size, 1);
  assert.equal(release.extensions.size, 1);
  assert.ok(
    release.document.schemas.includes(
      "https://schemas.ironicbuddha.dev/project-standards/v1/verification-evidence.schema.json",
    ),
  );
  assert.match(release.document.catalogueDigest, /^sha256:[a-f0-9]{64}$/);
});

test("Bootstrap Configuration resolves defaults and deterministic applicability", async () => {
  const release = await loadCatalogueRelease(
    join(packageRoot, "fixtures/valid/foundation-release"),
  );

  const resolved = await resolveBootstrapConfiguration(
    release,
    foundationConfiguration(release),
  );

  assert.deepEqual(resolved.configuration.core.choices, {
    "choice/core/package-manager": "pnpm",
  });
  assert.deepEqual(resolved.configuration.workloads[0]?.choices, {
    "choice/example-service/shape": "worker",
  });
  assert.deepEqual(
    resolved.applicableRules.map(({ layerId, ruleId }) => ({ layerId, ruleId })),
    [
      { layerId: "core", ruleId: "rule/core/exact-catalogue-pin" },
      { layerId: "service", ruleId: "rule/example-service/package-check" },
      {
        layerId: "service-tests",
        ruleId: "rule/example-tests/direct-tests",
      },
    ],
  );
  assert.deepEqual(resolved.refinements, [
    {
      layerId: "service-tests",
      ruleId: "rule/example-tests/direct-tests",
      refinesLayerId: "core",
      refinesRuleId: "rule/core/exact-catalogue-pin",
    },
  ]);
});

test("Verification Evidence schema rejects undeclared secret-bearing fields", async () => {
  const evidence = validVerificationEvidence();
  evidence.secretValue = "never-allowed";
  await assert.rejects(
    validateProjectStandardsDocument("verification-evidence", evidence),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "schema-invalid",
  );
});

test("Catalogue Release rejects broken stable-ID ownership references", async () => {
  const releaseRoot = await mutateFoundationRelease(
    "entries/core.json",
    (entry) => {
      const rules = entry.rules as Array<{ requirementIds: string[] }>;
      rules[0]!.requirementIds = ["requirement/core/missing"];
    },
  );

  await assert.rejects(
    loadCatalogueRelease(releaseRoot),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "semantic-invalid" &&
      error.message.includes("requirement/core/missing"),
  );
});

test("Bootstrap Configuration rejects declared Capability incompatibility", async () => {
  const release = await loadCatalogueRelease(
    join(packageRoot, "fixtures/valid/foundation-release"),
  );

  await assert.rejects(
    resolveBootstrapConfiguration(
      release,
      foundationConfiguration(release, {
        capabilities: [
          {
            id: "service-tests",
            kind: "example-tests",
            scope: { kind: "workload", workloadIds: ["service"] },
            choices: {},
          },
          {
            id: "conflicting-tests",
            kind: "example-conflict",
            scope: { kind: "workload", workloadIds: ["service"] },
            choices: {},
          },
        ],
      }),
    ),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "catalogue-incompatibility" &&
      error.message.includes("entry/capability/example-tests"),
  );
});

test("Bootstrap Configuration rejects an unregistered extension namespace", async () => {
  const release = await loadCatalogueRelease(
    join(packageRoot, "fixtures/valid/foundation-release"),
  );
  await assert.rejects(
    resolveBootstrapConfiguration(
      release,
      foundationConfiguration(release, {
        capabilities: [],
        extensions: { "com.example.policy": { enabled: true } },
      }),
    ),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "catalogue-incompatibility" &&
      error.message.includes("com.example.policy"),
  );
});

test("Bootstrap Configuration validates a registered extension schema", async () => {
  const release = await loadCatalogueRelease(
    join(packageRoot, "fixtures/valid/foundation-release"),
  );
  assert.equal(release.extensions.size, 1);

  await assert.rejects(
    resolveBootstrapConfiguration(
      release,
      foundationConfiguration(release, {
        capabilities: [],
        extensions: {
          "dev.ironicbuddha.foundation": { assurance: "made-up" },
        },
      }),
    ),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "schema-invalid" &&
      error.documentPath ===
        "configuration.extensions.dev.ironicbuddha.foundation",
  );

  const resolved = await resolveBootstrapConfiguration(
    release,
    foundationConfiguration(release, {
      capabilities: [],
      extensions: {
        "dev.ironicbuddha.foundation": { assurance: "reviewed" },
      },
    }),
  );
  assert.deepEqual(resolved.configuration.extensions, {
    "dev.ironicbuddha.foundation": { assurance: "reviewed" },
  });
});

test("Bootstrap Configuration rejects Policy Choice values outside the Entry", async () => {
  const release = await loadCatalogueRelease(
    join(packageRoot, "fixtures/valid/foundation-release"),
  );
  await assert.rejects(
    resolveBootstrapConfiguration(
      release,
      foundationConfiguration(release, {
        coreChoices: { "choice/core/package-manager": "yarn" },
        capabilities: [],
      }),
    ),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "choice-invalid",
  );
});

test("Bootstrap Configuration rejects escaping and undeclared nested Workload roots", async () => {
  const release = await loadCatalogueRelease(
    join(packageRoot, "fixtures/valid/foundation-release"),
  );
  await assert.rejects(
    resolveBootstrapConfiguration(
      release,
      foundationConfiguration(release, {
        workloads: [
          {
            id: "outside",
            kind: "example-service",
            root: "../outside",
            choices: {},
          },
        ],
        capabilities: [],
      }),
    ),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "catalogue-incompatibility",
  );

  await assert.rejects(
    resolveBootstrapConfiguration(
      release,
      foundationConfiguration(release, {
        workloads: [
          {
            id: "service",
            kind: "example-service",
            root: "services/api",
            choices: {},
          },
          {
            id: "nested-worker",
            kind: "example-service",
            root: "services/api/worker",
            choices: {},
          },
        ],
        capabilities: [],
      }),
    ),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "catalogue-incompatibility" &&
      error.message.includes("nested Workload roots"),
  );
});

test("Bootstrap Configuration enforces Catalogue Entry cardinality", async () => {
  const release = await loadCatalogueRelease(
    join(packageRoot, "fixtures/valid/foundation-release"),
  );
  await assert.rejects(
    resolveBootstrapConfiguration(
      release,
      foundationConfiguration(release, {
        capabilities: [
          {
            id: "first-conflict",
            kind: "example-conflict",
            scope: { kind: "workload", workloadIds: ["service"] },
            choices: {},
          },
          {
            id: "second-conflict",
            kind: "example-conflict",
            scope: { kind: "workload", workloadIds: ["service"] },
            choices: {},
          },
        ],
      }),
    ),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "catalogue-incompatibility" &&
      error.message.includes("singleton"),
  );
});

test("Catalogue Release rejects an impossible applicability comparison", async () => {
  const releaseRoot = await mutateFoundationRelease(
    "entries/example-service.json",
    (entry) => {
      const rules = entry.rules as Array<{
        applicability: { value: string };
      }>;
      rules[0]!.applicability.value = "queue";
    },
  );
  await assert.rejects(
    loadCatalogueRelease(releaseRoot),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "semantic-invalid" &&
      error.message.includes("applicability"),
  );
});

test("Bootstrap Configuration rejects a refinement whose target layer is absent", async () => {
  const releaseRoot = await mutateFoundationRelease(
    "entries/example-tests.json",
    (entry) => {
      entry.refines = [
        {
          ruleId: "rule/example-tests/direct-tests",
          refinesRuleId: "rule/example-conflict/alternate-test-gate",
          scopeRelation: "same-workload",
        },
      ];
    },
  );
  const release = await loadCatalogueRelease(releaseRoot);
  await assert.rejects(
    resolveBootstrapConfiguration(
      release,
      foundationConfiguration(release),
    ),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "catalogue-incompatibility" &&
      error.message.includes("refinement"),
  );
});

test("Catalogue Check schema requires scope, prerequisites, toolchain, and retry policy", async () => {
  const entrySource = JSON.parse(
    await readFile(
      join(
        packageRoot,
        "fixtures/valid/foundation-release/entries/core.json",
      ),
      "utf8",
    ),
  ) as Record<string, unknown>;
  for (const field of [
    "scope",
    "prerequisiteCheckIds",
    "toolchain",
    "retryPolicy",
  ]) {
    const entry = structuredClone(entrySource);
    const checks = entry.checks as Array<Record<string, unknown>>;
    delete checks[0]![field];
    await assert.rejects(
      validateProjectStandardsDocument("catalogue-entry", entry),
      (error: unknown) =>
        error instanceof CatalogueValidationError &&
        error.code === "schema-invalid",
    );
  }
});

test("Verification Evidence schema requires invocation and toolchain bindings", async () => {
  const evidence = validVerificationEvidence();
  for (const field of ["invocation", "toolchain"] as const) {
    const incompleteEvidence: Record<string, unknown> = structuredClone(evidence);
    delete incompleteEvidence[field];
    await assert.rejects(
      validateProjectStandardsDocument(
        "verification-evidence",
        incompleteEvidence,
      ),
      (error: unknown) =>
        error instanceof CatalogueValidationError &&
        error.code === "schema-invalid",
    );
  }
});

test("Catalogue Release rejects an undeclared Authority Class", async () => {
  const releaseRoot = await mutateFoundationRelease(
    "entries/example-tests.json",
    (entry) => {
      const rules = entry.rules as Array<{
        waiverPolicy: { authorityClass: string };
      }>;
      rules[0]!.waiverPolicy.authorityClass = "authority/undeclared";
    },
  );

  await assert.rejects(
    loadCatalogueRelease(releaseRoot),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "semantic-invalid" &&
      error.message.includes("authority/undeclared"),
  );
});

test("Catalogue Release rejects cyclic Catalogue Check prerequisites", async () => {
  const releaseRoot = await mutateFoundationRelease(
    "entries/core.json",
    (entry) => {
      const checks = entry.checks as Array<Record<string, unknown>>;
      checks[0]!.prerequisiteCheckIds = ["check/core/prepare"];
      checks.push({
        ...structuredClone(checks[0]),
        id: "check/core/prepare",
        prerequisiteCheckIds: ["check/core/configuration-valid"],
      });
    },
  );

  await assert.rejects(
    loadCatalogueRelease(releaseRoot),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "semantic-invalid" &&
      error.message.includes("prerequisite cycle"),
  );
});

test("Catalogue Release rejects unsupported or incomplete first-party Check invocations", async () => {
  for (const arguments_ of [
    ["validate-configuration", ".project-standards/catalogue"],
    ["resolve-configuration"],
  ]) {
    const releaseRoot = await mutateFoundationRelease(
      "entries/core.json",
      (entry) => {
        const checks = entry.checks as Array<{ arguments: string[] }>;
        checks[0]!.arguments = arguments_;
      },
    );

    await assert.rejects(
      loadCatalogueRelease(releaseRoot),
      (error: unknown) =>
        error instanceof CatalogueValidationError &&
        error.code === "semantic-invalid" &&
        error.message.includes(arguments_[0]!),
    );
  }
});

test("Catalogue Release closes governed Waiver Policy control references", async () => {
  const releaseRoot = await mutateFoundationRelease(
    "entries/example-tests.json",
    (entry) => {
      const rules = entry.rules as Array<{
        waiverPolicy: { compensatingControlRequirementIds: string[] };
      }>;
      rules[0]!.waiverPolicy.compensatingControlRequirementIds = [
        "requirement/example-tests/missing-control",
      ];
    },
  );

  await assert.rejects(
    loadCatalogueRelease(releaseRoot),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "semantic-invalid" &&
      error.message.includes("missing-control"),
  );
});

test("governed Waiver Policy requires closed renewal conditions", async () => {
  const entry = JSON.parse(
    await readFile(
      join(
        packageRoot,
        "fixtures/valid/foundation-release/entries/example-tests.json",
      ),
      "utf8",
    ),
  ) as Record<string, unknown>;
  const rules = entry.rules as Array<{
    waiverPolicy: Record<string, unknown>;
  }>;
  delete rules[0]!.waiverPolicy.renewalConditions;

  await assert.rejects(
    validateProjectStandardsDocument("catalogue-entry", entry),
    (error: unknown) =>
      error instanceof CatalogueValidationError &&
      error.code === "schema-invalid",
  );
});

test("catalogue CLI independently validates a content-addressed release", async () => {
  const { stdout, stderr } = await execFileAsync(
    process.execPath,
    [
      join(packageRoot, "dist/src/cli.js"),
      "validate-release",
      join(packageRoot, "fixtures/valid/foundation-release"),
    ],
  );

  assert.equal(stderr, "");
  assert.deepEqual(JSON.parse(stdout), {
    schemaVersion: "1.0.0",
    status: "valid",
    catalogueVersion: "1.0.0",
    catalogueDigest:
      "sha256:17f3671c948fa9fe1bcd8be1a7ed8d7b2f491b220f18487ccac2784a7e22a824",
    entryIds: [
      "entry/capability/example-conflict",
      "entry/capability/example-tests",
      "entry/core/core",
      "entry/workload/example-service",
    ],
  });
});

test("Catalogue Release configuration fixtures are executable", async () => {
  const release = await loadCatalogueRelease(
    join(packageRoot, "fixtures/valid/foundation-release"),
  );
  const materialize = (fixtureId: string): unknown => {
    const fixture = release.fixtures.get(fixtureId);
    assert.ok(fixture);
    return JSON.parse(
      JSON.stringify(fixture.document).replaceAll(
        "__CATALOGUE_DIGEST__",
        release.document.catalogueDigest,
      ),
    ) as unknown;
  };

  await resolveBootstrapConfiguration(
    release,
    materialize("fixture/configuration/valid-foundation"),
  );

  for (const [fixtureId, expectedCode] of [
    ["fixture/configuration/invalid-exact-pin", "exact-pin-mismatch"],
    [
      "fixture/configuration/invalid-capability-composition",
      "catalogue-incompatibility",
    ],
  ] as const) {
    await assert.rejects(
      resolveBootstrapConfiguration(release, materialize(fixtureId)),
      (error: unknown) =>
        error instanceof CatalogueValidationError &&
        error.code === expectedCode,
    );
  }
});
