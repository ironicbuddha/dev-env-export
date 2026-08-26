import { createHash } from "node:crypto";
import { readFile, realpath } from "node:fs/promises";
import { basename, dirname, isAbsolute, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  Ajv2020,
  type AnySchema,
  type ErrorObject,
} from "ajv/dist/2020.js";
import formatsPlugin, { type FormatsPlugin } from "ajv-formats";
import canonicalizeModule from "canonicalize";

export {
  inspectRepositoryRoot,
  type DetectedRepositoryState,
  type GitBoundary,
  type GitDirtyPath,
  type GitPathState,
  type RepositoryEntry,
  type RepositoryHazard,
  type RepositoryHazardCode,
  RepositoryInspectionError,
  type RepositoryInspectionErrorCode,
  type RunModeRecommendationEvidence,
} from "./repository-inspection.js";

export type CatalogueValidationErrorCode =
  | "catalogue-incompatibility"
  | "choice-invalid"
  | "document-missing"
  | "digest-mismatch"
  | "exact-pin-mismatch"
  | "json-invalid"
  | "semantic-invalid"
  | "schema-invalid"
  | "unsafe-path";

export class CatalogueValidationError extends Error {
  readonly code: CatalogueValidationErrorCode;
  readonly documentPath: string;
  readonly details: readonly ErrorObject[];

  constructor(
    code: CatalogueValidationErrorCode,
    documentPath: string,
    message: string,
    details: readonly ErrorObject[] = [],
  ) {
    super(message);
    this.name = "CatalogueValidationError";
    this.code = code;
    this.documentPath = documentPath;
    this.details = details;
  }
}

export interface CatalogueReleaseDocument {
  readonly $schema: string;
  readonly schemaVersion: "1.0.0";
  readonly catalogueVersion: string;
  readonly catalogueDigest: string;
  readonly schemas: readonly string[];
  readonly entries: readonly string[];
  readonly migrations: readonly string[];
  readonly fixtures: readonly string[];
  readonly sourceGuidance: readonly string[];
  readonly supportEvidence: readonly string[];
  readonly extensions: readonly string[];
}

export interface ValidatedCatalogueRelease {
  readonly root: string;
  readonly document: CatalogueReleaseDocument;
  readonly entries: ReadonlyMap<string, CatalogueEntryDocument>;
  readonly migrations: ReadonlyMap<string, IdentifiedDocument>;
  readonly fixtures: ReadonlyMap<string, IdentifiedDocument>;
  readonly sourceGuidance: ReadonlyMap<string, IdentifiedDocument>;
  readonly supportEvidence: ReadonlyMap<string, IdentifiedDocument>;
  readonly extensions: ReadonlyMap<string, IdentifiedDocument>;
}

export type IdentifiedDocument = Readonly<{
  id: string;
  [key: string]: unknown;
}>;

export interface CatalogueEntryDocument {
  readonly $schema: string;
  readonly schemaVersion: "1.0.0";
  readonly id: string;
  readonly family: "core" | "workload" | "capability";
  readonly kind: string;
  readonly version: string;
  readonly scopeKinds: readonly (
    | "repository"
    | "workload"
    | "cross-workload"
  )[];
  readonly cardinality: "singleton" | "multiple";
  readonly authorityClasses: readonly AuthorityClassDefinition[];
  readonly choices: readonly ChoiceDefinition[];
  readonly rules: readonly CatalogueRule[];
  readonly artifacts: readonly CatalogueArtifact[];
  readonly checks: readonly CatalogueCheck[];
  readonly requirements: readonly VerificationRequirement[];
  readonly requires: readonly EntryRelationship[];
  readonly refines: readonly RuleRelationship[];
  readonly incompatibleWith: readonly EntryRelationship[];
  readonly nestedRootContracts: readonly NestedRootContract[];
  readonly sourceGuidanceIds: readonly string[];
  readonly supportEvidenceIds: readonly string[];
  readonly fixtureIds: readonly string[];
  readonly migrationIds: readonly string[];
  readonly extensions: Readonly<Record<string, unknown>>;
}

export type JsonScalar = string | boolean | number;

export interface AuthorityClassDefinition {
  readonly id: string;
  readonly description: string;
  readonly resolution: "named-identity" | "verifiable-external-decision";
}

export interface ChoiceDefinition {
  readonly id: string;
  readonly valueType: "string" | "boolean" | "integer";
  readonly required: boolean;
  readonly allowedValues: readonly JsonScalar[];
  readonly default?: JsonScalar;
}

export type ApplicabilityCondition =
  | Readonly<{ kind: "always" }>
  | Readonly<{ kind: "choice-equals"; choiceId: string; value: JsonScalar }>
  | Readonly<{ kind: "entry-selected"; entryId: string }>
  | Readonly<{
      kind: "scope-kind-is";
      scopeKind: "repository" | "workload" | "cross-workload";
    }>
  | Readonly<{
      kind: "all" | "any";
      conditions: readonly ApplicabilityCondition[];
    }>
  | Readonly<{ kind: "not"; condition: ApplicabilityCondition }>;

export interface CatalogueRule {
  readonly id: string;
  readonly statement: string;
  readonly applicability: ApplicabilityCondition;
  readonly requirementIds: readonly string[];
  readonly waiverPolicy: Readonly<Record<string, unknown>>;
}

export interface CatalogueArtifact {
  readonly id: string;
  readonly locatorTemplate: string;
  readonly ownership: "whole-file" | "structured-fragment" | "link";
  readonly compositionContract?: string;
}

export interface CatalogueCheck {
  readonly id: string;
  readonly executable: string;
  readonly arguments: readonly string[];
  readonly scope: Readonly<{ kind: "repository" | "owning-layer" }>;
  readonly prerequisiteCheckIds: readonly string[];
  readonly toolchain: Readonly<{
    name: string;
    version: string;
    digest?: string;
  }>;
  readonly timeoutMs: number;
  readonly network: "forbidden" | "allowed";
  readonly secrets: "forbidden" | "references-only";
  readonly retryPolicy: Readonly<{
    maximumAttempts: number;
    retryableResults: readonly "error"[];
  }>;
  readonly passCriteria: "exit-zero";
}

export interface VerificationRequirement {
  readonly id: string;
  readonly ruleId: string;
  readonly phase: "baseline" | "delivery";
  readonly kind:
    | "deterministic-check"
    | "attributable-review"
    | "manual-state";
  readonly checkId?: string;
  readonly authorityClass?: string;
  readonly independence: "none" | "not-author" | "separate-authority";
}

export interface EntryRelationship {
  readonly entryId: string;
  readonly scopeRelation: "repository" | "same-workload";
}

export interface RuleRelationship {
  readonly ruleId: string;
  readonly refinesRuleId: string;
  readonly scopeRelation: "repository" | "same-workload";
}

export interface NestedRootContract {
  readonly nestedEntryId: string;
  readonly compositionContract: string;
}

export interface BootstrapConfiguration {
  readonly $schema: string;
  readonly schemaVersion: "1.0.0";
  readonly catalogueVersion: string;
  readonly catalogueDigest: string;
  readonly core: Readonly<{
    kind: string;
    choices: Readonly<Record<string, JsonScalar>>;
  }>;
  readonly workloads: readonly Readonly<{
    id: string;
    kind: string;
    root: string;
    choices: Readonly<Record<string, JsonScalar>>;
  }>[];
  readonly capabilities: readonly Readonly<{
    id: string;
    kind: string;
    scope:
      | Readonly<{ kind: "repository" }>
      | Readonly<{
          kind: "workload" | "cross-workload";
          workloadIds: readonly string[];
        }>;
    choices: Readonly<Record<string, JsonScalar>>;
  }>[];
  readonly extensions: Readonly<Record<string, unknown>>;
}

export interface ResolvedBootstrapConfiguration {
  readonly configuration: BootstrapConfiguration;
  readonly applicableRules: readonly Readonly<{
    layerId: string;
    entryId: string;
    ruleId: string;
  }>[];
  readonly refinements: readonly Readonly<{
    layerId: string;
    ruleId: string;
    refinesLayerId: string;
    refinesRuleId: string;
  }>[];
}

export type ProjectStandardsDocumentKind =
  | "catalogue-entry"
  | "catalogue-release"
  | "configuration"
  | "detected-repository-state"
  | "extension-registration"
  | "fixture"
  | "manifest"
  | "migration"
  | "rule-waiver"
  | "source-guidance"
  | "support-evidence"
  | "verification-evidence";

const moduleDirectory = dirname(fileURLToPath(import.meta.url));
const schemaDirectory = join(moduleDirectory, "../../schemas/v1");
const addFormats = formatsPlugin as unknown as FormatsPlugin;
const canonicalize = canonicalizeModule as unknown as (
  value: unknown,
) => string | undefined;
const firstPartyCheckArgumentCounts = new Map([
  ["validate-release", 2],
  ["calculate-digest", 2],
  ["resolve-configuration", 3],
]);

function createSchemaValidator(): Ajv2020 {
  const validator = new Ajv2020({ allErrors: true, strict: true });
  addFormats(validator);
  return validator;
}

type ReferencedDocument = Readonly<{
  path: string;
  value: unknown;
}>;

async function readJson(documentPath: string, displayPath: string): Promise<unknown> {
  let source: string;
  try {
    source = await readFile(documentPath, "utf8");
  } catch (error) {
    throw new CatalogueValidationError(
      "document-missing",
      displayPath,
      `Cannot read ${displayPath}: ${String(error)}`,
    );
  }

  try {
    return JSON.parse(source) as unknown;
  } catch (error) {
    throw new CatalogueValidationError(
      "json-invalid",
      displayPath,
      `Cannot parse ${displayPath}: ${String(error)}`,
    );
  }
}

export async function validateProjectStandardsDocument(
  documentKind: ProjectStandardsDocumentKind,
  document: unknown,
): Promise<void> {
  const schemaFile = `${documentKind}.schema.json`;
  const schema = await readJson(join(schemaDirectory, schemaFile), schemaFile);
  const ajv = createSchemaValidator();
  const validate = ajv.compile(schema as AnySchema);
  if (!validate(document)) {
    throw new CatalogueValidationError(
      "schema-invalid",
      documentKind,
      `${documentKind} does not match its closed schema`,
      validate.errors ?? [],
    );
  }
}

function releaseReferences(
  release: CatalogueReleaseDocument,
): readonly string[] {
  return [
    ...release.entries,
    ...release.migrations,
    ...release.fixtures,
    ...release.sourceGuidance,
    ...release.supportEvidence,
    ...release.extensions,
  ].sort();
}

async function loadTrustedSchemas(
  schemaIds: readonly string[],
): Promise<readonly ReferencedDocument[]> {
  return Promise.all(
    [...schemaIds].sort().map(async (schemaId) => {
      const schemaFile = basename(new URL(schemaId).pathname);
      const value = await readJson(
        join(schemaDirectory, schemaFile),
        `schemas/v1/${schemaFile}`,
      );
      if (
        typeof value !== "object" ||
        value === null ||
        !("$id" in value) ||
        value.$id !== schemaId
      ) {
        throw new CatalogueValidationError(
          "semantic-invalid",
          `schemas/v1/${schemaFile}`,
          `Schema ${schemaId} does not match its immutable $id`,
        );
      }
      return { path: `schemas/v1/${schemaFile}`, value };
    }),
  );
}

async function loadReferencedDocuments(
  releaseRoot: string,
  release: CatalogueReleaseDocument,
): Promise<readonly ReferencedDocument[]> {
  return Promise.all(
    releaseReferences(release).map(async (path) => {
      const absoluteRoot = resolve(releaseRoot);
      const candidatePath = resolve(absoluteRoot, path);
      const lexicalRelativePath = relative(absoluteRoot, candidatePath);
      if (
        lexicalRelativePath.startsWith(`..${process.platform === "win32" ? "\\" : "/"}`) ||
        lexicalRelativePath === ".." ||
        isAbsolute(lexicalRelativePath)
      ) {
        throw new CatalogueValidationError(
          "unsafe-path",
          path,
          `Catalogue document path escapes the release root: ${path}`,
        );
      }

      let realRoot: string;
      let realCandidate: string;
      try {
        [realRoot, realCandidate] = await Promise.all([
          realpath(absoluteRoot),
          realpath(candidatePath),
        ]);
      } catch (error) {
        throw new CatalogueValidationError(
          "document-missing",
          path,
          `Cannot resolve ${path}: ${String(error)}`,
        );
      }
      const physicalRelativePath = relative(realRoot, realCandidate);
      if (
        physicalRelativePath.startsWith(
          `..${process.platform === "win32" ? "\\" : "/"}`,
        ) ||
        physicalRelativePath === ".." ||
        isAbsolute(physicalRelativePath)
      ) {
        throw new CatalogueValidationError(
          "unsafe-path",
          path,
          `Catalogue document resolves outside the release root: ${path}`,
        );
      }

      return {
        path,
        value: await readJson(realCandidate, path),
      };
    }),
  );
}

function catalogueDigest(
  release: CatalogueReleaseDocument,
  documents: readonly ReferencedDocument[],
): string {
  const { catalogueDigest: _declaredDigest, ...releaseIdentity } = release;
  const canonicalPayload = canonicalize({
    documents,
    release: releaseIdentity,
  });
  if (canonicalPayload === undefined) {
    throw new TypeError("Catalogue Release contains non-JSON content");
  }

  return `sha256:${createHash("sha256").update(canonicalPayload).digest("hex")}`;
}

function semanticError(documentPath: string, message: string): never {
  throw new CatalogueValidationError(
    "semantic-invalid",
    documentPath,
    message,
  );
}

function assertUniqueIds(
  entry: CatalogueEntryDocument,
  values: readonly Readonly<{ id: string }>[] ,
  category: string,
  globalIds: Set<string>,
): void {
  const localIds = new Set<string>();
  for (const value of values) {
    if (localIds.has(value.id) || globalIds.has(value.id)) {
      semanticError(entry.id, `Duplicate ${category} ID ${value.id}`);
    }
    localIds.add(value.id);
    globalIds.add(value.id);
    if (!value.id.startsWith(`${category}/${entry.kind}/`)) {
      semanticError(
        entry.id,
        `${category} ID ${value.id} is not owned by Catalogue Entry ${entry.id}`,
      );
    }
  }
}

function validateConditionReferences(
  entry: CatalogueEntryDocument,
  condition: ApplicabilityCondition,
  choices: ReadonlyMap<string, ChoiceDefinition>,
  entryIds: ReadonlySet<string>,
): void {
  switch (condition.kind) {
    case "always":
    case "scope-kind-is":
      return;
    case "choice-equals":
      const choice = choices.get(condition.choiceId);
      if (choice === undefined) {
        semanticError(
          entry.id,
          `Applicability references Policy Choice ${condition.choiceId} outside its owning Entry`,
        );
      }
      if (
        !scalarMatchesType(condition.value, choice.valueType) ||
        !choice.allowedValues.includes(condition.value)
      ) {
        semanticError(
          entry.id,
          `Policy Choice applicability for ${condition.choiceId} compares an invalid value`,
        );
      }
      return;
    case "entry-selected":
      if (!entryIds.has(condition.entryId)) {
        semanticError(
          entry.id,
          `Applicability references missing Catalogue Entry ${condition.entryId}`,
        );
      }
      return;
    case "all":
    case "any":
      for (const nested of condition.conditions) {
        validateConditionReferences(entry, nested, choices, entryIds);
      }
      return;
    case "not":
      validateConditionReferences(
        entry,
        condition.condition,
        choices,
        entryIds,
      );
  }
}

function assertReferencesExist(
  entry: CatalogueEntryDocument,
  ids: readonly string[],
  available: ReadonlyMap<string, unknown>,
  category: string,
): void {
  for (const id of ids) {
    if (!available.has(id)) {
      semanticError(entry.id, `${category} reference ${id} does not exist`);
    }
  }
}

function validateCheckPrerequisites(entry: CatalogueEntryDocument): void {
  const checks = new Map(entry.checks.map((check) => [check.id, check]));
  const active = new Set<string>();
  const complete = new Set<string>();

  const visit = (checkId: string): void => {
    if (complete.has(checkId)) return;
    if (active.has(checkId)) {
      semanticError(
        entry.id,
        `Catalogue Check prerequisite cycle includes ${checkId}`,
      );
    }
    active.add(checkId);
    const check = checks.get(checkId)!;
    for (const prerequisiteCheckId of check.prerequisiteCheckIds) {
      if (!checks.has(prerequisiteCheckId)) {
        semanticError(
          entry.id,
          `Catalogue Check ${check.id} has invalid prerequisite ${prerequisiteCheckId}`,
        );
      }
      visit(prerequisiteCheckId);
    }
    active.delete(checkId);
    complete.add(checkId);
  };

  for (const checkId of checks.keys()) visit(checkId);
}

function validateCatalogueSemantics(
  release: CatalogueReleaseDocument,
  entries: ReadonlyMap<string, CatalogueEntryDocument>,
  migrations: ReadonlyMap<string, IdentifiedDocument>,
  fixtures: ReadonlyMap<string, IdentifiedDocument>,
  sourceGuidance: ReadonlyMap<string, IdentifiedDocument>,
  supportEvidence: ReadonlyMap<string, IdentifiedDocument>,
  extensions: ReadonlyMap<string, IdentifiedDocument>,
): void {
  const requiredSchemaIds = [
    "catalogue-entry",
    "catalogue-release",
    "configuration",
    "extension-registration",
    "fixture",
    "manifest",
    "migration",
    "rule-waiver",
    "source-guidance",
    "support-evidence",
    "verification-evidence",
  ].map(
    (name) =>
      `https://schemas.ironicbuddha.dev/project-standards/v1/${name}.schema.json`,
  );
  for (const schemaId of requiredSchemaIds) {
    if (!release.schemas.includes(schemaId)) {
      semanticError("release.json", `Catalogue Release omits schema ${schemaId}`);
    }
  }

  const entryIds = new Set(entries.keys());
  const ruleIds = new Set<string>();
  const artifactIds = new Set<string>();
  const checkIds = new Set<string>();
  const requirementIds = new Set<string>();
  const choiceIds = new Set<string>();
  const authorityClassIds = new Set<string>();
  const familyKinds = new Set<string>();
  const artifactTargets = new Map<string, CatalogueArtifact[]>();

  const coreEntries = [...entries.values()].filter(
    (entry) => entry.family === "core",
  );
  if (coreEntries.length !== 1) {
    semanticError(
      "release.json",
      `Catalogue Release must contain exactly one Core Baseline Entry; found ${coreEntries.length}`,
    );
  }

  for (const entry of entries.values()) {
    for (const authorityClass of entry.authorityClasses) {
      if (authorityClassIds.has(authorityClass.id)) {
        semanticError(
          entry.id,
          `Duplicate Authority Class ID ${authorityClass.id}`,
        );
      }
      authorityClassIds.add(authorityClass.id);
    }
  }

  for (const entry of entries.values()) {
    const expectedEntryId = `entry/${entry.family}/${entry.kind}`;
    if (entry.id !== expectedEntryId) {
      semanticError(
        entry.id,
        `Catalogue Entry ID ${entry.id} must be ${expectedEntryId}`,
      );
    }
    const familyKind = `${entry.family}/${entry.kind}`;
    if (familyKinds.has(familyKind)) {
      semanticError(entry.id, `Duplicate Catalogue Entry kind ${familyKind}`);
    }
    familyKinds.add(familyKind);

    assertUniqueIds(entry, entry.choices, "choice", choiceIds);
    assertUniqueIds(entry, entry.rules, "rule", ruleIds);
    assertUniqueIds(entry, entry.artifacts, "artifact", artifactIds);
    assertUniqueIds(entry, entry.checks, "check", checkIds);
    assertUniqueIds(
      entry,
      entry.requirements,
      "requirement",
      requirementIds,
    );

    const entryChoices = new Map(
      entry.choices.map((choice) => [choice.id, choice]),
    );
    const entryRequirementIds = new Set(
      entry.requirements.map((requirement) => requirement.id),
    );
    const entryCheckIds = new Set(entry.checks.map((check) => check.id));
    for (const choice of entry.choices) {
      if (
        choice.default !== undefined &&
        (!scalarMatchesType(choice.default, choice.valueType) ||
          !choice.allowedValues.includes(choice.default))
      ) {
        semanticError(
          entry.id,
          `Policy Choice ${choice.id} has an invalid default`,
        );
      }
    }
    for (const rule of entry.rules) {
      for (const requirementId of rule.requirementIds) {
        if (!entryRequirementIds.has(requirementId)) {
          semanticError(
            entry.id,
            `Catalogue Rule ${rule.id} references missing Verification Requirement ${requirementId}`,
          );
        }
      }
      validateConditionReferences(
        entry,
        rule.applicability,
        entryChoices,
        entryIds,
      );
    }
    for (const requirement of entry.requirements) {
      const owningRule = entry.rules.find(
        (rule) => rule.id === requirement.ruleId,
      );
      if (
        owningRule === undefined ||
        !owningRule.requirementIds.includes(requirement.id)
      ) {
        semanticError(
          entry.id,
          `Verification Requirement ${requirement.id} is not owned by Catalogue Rule ${requirement.ruleId}`,
        );
      }
      if (
        requirement.kind === "deterministic-check" &&
        (requirement.checkId === undefined ||
          !entryCheckIds.has(requirement.checkId))
      ) {
        semanticError(
          entry.id,
          `Verification Requirement ${requirement.id} references missing Catalogue Check ${String(requirement.checkId)}`,
        );
      }
      if (
        requirement.kind !== "deterministic-check" &&
        requirement.authorityClass === undefined
      ) {
        semanticError(
          entry.id,
          `Verification Requirement ${requirement.id} is missing an Authority Class`,
        );
      }
      if (
        requirement.authorityClass !== undefined &&
        !authorityClassIds.has(requirement.authorityClass)
      ) {
        semanticError(
          entry.id,
          `Verification Requirement ${requirement.id} references undeclared Authority Class ${requirement.authorityClass}`,
        );
      }
    }
    for (const rule of entry.rules) {
      const waiverAuthority = rule.waiverPolicy.authorityClass;
      if (
        typeof waiverAuthority === "string" &&
        !authorityClassIds.has(waiverAuthority)
      ) {
        semanticError(
          entry.id,
          `Waiver Policy for ${rule.id} references undeclared Authority Class ${waiverAuthority}`,
        );
      }
    }
    for (const check of entry.checks) {
      const command = check.arguments[0] ?? "";
      const expectedArgumentCount = firstPartyCheckArgumentCounts.get(command);
      if (
        check.executable === "project-standards-catalogue" &&
        (expectedArgumentCount === undefined ||
          check.arguments.length !== expectedArgumentCount)
      ) {
        semanticError(
          entry.id,
          `Catalogue Check ${check.id} has unsupported or incomplete project-standards-catalogue invocation ${command}`,
        );
      }
    }
    validateCheckPrerequisites(entry);
    for (const relationship of [
      ...entry.requires,
      ...entry.incompatibleWith,
    ]) {
      if (!entryIds.has(relationship.entryId)) {
        semanticError(
          entry.id,
          `Composition references missing Catalogue Entry ${relationship.entryId}`,
        );
      }
    }
    for (const nestedRootContract of entry.nestedRootContracts) {
      const nestedEntry = entries.get(nestedRootContract.nestedEntryId);
      if (
        entry.family !== "workload" ||
        nestedEntry?.family !== "workload"
      ) {
        semanticError(
          entry.id,
          `Nested-root contract must connect Workload Entries and references ${nestedRootContract.nestedEntryId}`,
        );
      }
    }
    for (const artifact of entry.artifacts) {
      const owners = artifactTargets.get(artifact.locatorTemplate) ?? [];
      owners.push(artifact);
      artifactTargets.set(artifact.locatorTemplate, owners);
    }
    assertReferencesExist(
      entry,
      entry.sourceGuidanceIds,
      sourceGuidance,
      "Source Guidance",
    );
    assertReferencesExist(
      entry,
      entry.supportEvidenceIds,
      supportEvidence,
      "support evidence",
    );
    assertReferencesExist(entry, entry.fixtureIds, fixtures, "fixture");
    assertReferencesExist(entry, entry.migrationIds, migrations, "migration");
  }

  for (const entry of entries.values()) {
    const ownedRuleIds = new Set(entry.rules.map((rule) => rule.id));
    for (const rule of entry.rules) {
      const controls = rule.waiverPolicy.compensatingControlRequirementIds;
      if (Array.isArray(controls)) {
        for (const requirementId of controls) {
          if (
            typeof requirementId !== "string" ||
            !requirementIds.has(requirementId)
          ) {
            semanticError(
              entry.id,
              `Waiver Policy for ${rule.id} references missing compensating-control requirement ${String(requirementId)}`,
            );
          }
        }
      }
    }
    for (const refinement of entry.refines) {
      if (!ownedRuleIds.has(refinement.ruleId)) {
        semanticError(
          entry.id,
          `Refinement source Catalogue Rule ${refinement.ruleId} is not owned by ${entry.id}`,
        );
      }
      if (!ruleIds.has(refinement.refinesRuleId)) {
        semanticError(
          entry.id,
          `Refinement references missing Catalogue Rule ${refinement.refinesRuleId}`,
        );
      }
      if (refinement.ruleId === refinement.refinesRuleId) {
        semanticError(entry.id, `Catalogue Rule ${refinement.ruleId} cannot refine itself`);
      }
    }
  }
  for (const [target, owners] of artifactTargets) {
    if (owners.length < 2) continue;
    const contracts = new Set(
      owners.map((artifact) => artifact.compositionContract),
    );
    if (contracts.size !== 1 || contracts.has(undefined)) {
      semanticError(
        "release.json",
        `Managed Artifact target ${target} has multiple owners without one explicit composition contract`,
      );
    }
  }

  const migrationEdges = new Set<string>();
  for (const migration of migrations.values()) {
    const from = migration.fromSchemaVersion;
    const to = migration.toSchemaVersion;
    const documentKind = migration.documentKind;
    if (from === to) {
      semanticError(migration.id, "Schema migration cannot target its source version");
    }
    const edge = `${String(documentKind)}:${String(from)}->${String(to)}`;
    if (migrationEdges.has(edge)) {
      semanticError(migration.id, `Duplicate schema migration edge ${edge}`);
    }
    migrationEdges.add(edge);
  }

  for (const evidence of supportEvidence.values()) {
    const evidenceEntryIds = evidence.entryIds;
    const evidenceGuidanceIds = evidence.sourceGuidanceIds;
    if (!Array.isArray(evidenceEntryIds) || !Array.isArray(evidenceGuidanceIds)) {
      semanticError(evidence.id, "Support evidence has invalid reference sets");
    }
    for (const entryId of evidenceEntryIds) {
      if (typeof entryId !== "string" || !entries.has(entryId)) {
        semanticError(
          evidence.id,
          `Support evidence references missing Catalogue Entry ${String(entryId)}`,
        );
      }
    }
    for (const guidanceId of evidenceGuidanceIds) {
      if (typeof guidanceId !== "string" || !sourceGuidance.has(guidanceId)) {
        semanticError(
          evidence.id,
          `Support evidence references missing Source Guidance ${String(guidanceId)}`,
        );
      }
    }
  }

  const namespaces = new Set<string>();
  const extensionRegistrations = new Map<string, IdentifiedDocument>();
  for (const extension of extensions.values()) {
    const namespace = extension.namespace;
    if (typeof namespace !== "string" || namespaces.has(namespace)) {
      semanticError(extension.id, `Duplicate or invalid extension namespace ${String(namespace)}`);
    }
    try {
      createSchemaValidator().compile(extension.schema as AnySchema);
    } catch (error) {
      semanticError(
        extension.id,
        `Extension namespace ${namespace} has an invalid schema: ${String(error)}`,
      );
    }
    namespaces.add(namespace);
    extensionRegistrations.set(namespace, extension);
  }
  for (const entry of entries.values()) {
    for (const [namespace, value] of Object.entries(entry.extensions)) {
      const registration = extensionRegistrations.get(namespace);
      if (
        registration === undefined ||
        !Array.isArray(registration.targets) ||
        !registration.targets.includes("catalogue-entry")
      ) {
        semanticError(
          entry.id,
          `Catalogue Entry uses unregistered extension namespace ${namespace}`,
        );
      }
      const validateExtension = createSchemaValidator().compile(
        registration.schema as AnySchema,
      );
      if (!validateExtension(value)) {
        semanticError(
          entry.id,
          `Catalogue Entry extension ${namespace} does not match its registered schema`,
        );
      }
    }
  }
}

export async function calculateCatalogueReleaseDigest(
  releaseRoot: string,
): Promise<string> {
  const releaseDocument = await readJson(
    join(releaseRoot, "release.json"),
    "release.json",
  );
  await validateProjectStandardsDocument(
    "catalogue-release",
    releaseDocument,
  );
  const typedRelease = releaseDocument as CatalogueReleaseDocument;
  const [schemaDocuments, referencedDocuments] = await Promise.all([
    loadTrustedSchemas(typedRelease.schemas),
    loadReferencedDocuments(releaseRoot, typedRelease),
  ]);
  return catalogueDigest(
    typedRelease,
    [...schemaDocuments, ...referencedDocuments].sort((left, right) =>
      left.path.localeCompare(right.path),
    ),
  );
}

export async function loadCatalogueRelease(
  releaseRoot: string,
): Promise<ValidatedCatalogueRelease> {
  const releaseSchema = await readJson(
    join(schemaDirectory, "catalogue-release.schema.json"),
    "schemas/v1/catalogue-release.schema.json",
  );
  const releaseDocument = await readJson(
    join(releaseRoot, "release.json"),
    "release.json",
  );

  const ajv = createSchemaValidator();
  const validate = ajv.compile<CatalogueReleaseDocument>(
    releaseSchema as AnySchema,
  );

  if (!validate(releaseDocument)) {
    throw new CatalogueValidationError(
      "schema-invalid",
      "release.json",
      "release.json does not match the closed Catalogue Release schema",
      validate.errors ?? [],
    );
  }

  const typedRelease = releaseDocument as CatalogueReleaseDocument;
  const schemaDocuments = await loadTrustedSchemas(typedRelease.schemas);
  const referencedDocuments = await loadReferencedDocuments(
    releaseRoot,
    typedRelease,
  );
  const actualDigest = catalogueDigest(
    typedRelease,
    [...schemaDocuments, ...referencedDocuments].sort((left, right) =>
      left.path.localeCompare(right.path),
    ),
  );
  if (actualDigest !== typedRelease.catalogueDigest) {
    throw new CatalogueValidationError(
      "digest-mismatch",
      "release.json",
      `Catalogue Release digest mismatch: declared ${typedRelease.catalogueDigest}, calculated ${actualDigest}`,
    );
  }

  const entrySchema = await readJson(
    join(schemaDirectory, "catalogue-entry.schema.json"),
    "schemas/v1/catalogue-entry.schema.json",
  );
  const validateEntry = ajv.compile<CatalogueEntryDocument>(
    entrySchema as AnySchema,
  );
  const documentsByPath = new Map(
    referencedDocuments.map(({ path, value }) => [path, value]),
  );
  const entries = new Map<string, CatalogueEntryDocument>();

  for (const entryPath of typedRelease.entries) {
    const entryDocument = documentsByPath.get(entryPath);
    if (!validateEntry(entryDocument)) {
      throw new CatalogueValidationError(
        "schema-invalid",
        entryPath,
        `${entryPath} does not match the closed Catalogue Entry schema`,
        validateEntry.errors ?? [],
      );
    }

    const typedEntry = entryDocument as CatalogueEntryDocument;
    if (entries.has(typedEntry.id)) {
      throw new CatalogueValidationError(
        "schema-invalid",
        entryPath,
        `Duplicate Catalogue Entry ID ${typedEntry.id}`,
      );
    }
    entries.set(typedEntry.id, typedEntry);
  }

  const loadCollection = async (
    paths: readonly string[],
    documentKind: ProjectStandardsDocumentKind,
  ): Promise<ReadonlyMap<string, IdentifiedDocument>> => {
    const documents = new Map<string, IdentifiedDocument>();
    for (const path of paths) {
      const document = documentsByPath.get(path);
      await validateProjectStandardsDocument(documentKind, document);
      const typedDocument = document as IdentifiedDocument;
      if (documents.has(typedDocument.id)) {
        throw new CatalogueValidationError(
          "semantic-invalid",
          path,
          `Duplicate ${documentKind} ID ${typedDocument.id}`,
        );
      }
      documents.set(typedDocument.id, typedDocument);
    }
    return documents;
  };
  const migrations = await loadCollection(
    typedRelease.migrations,
    "migration",
  );
  const fixtures = await loadCollection(typedRelease.fixtures, "fixture");
  const sourceGuidance = await loadCollection(
    typedRelease.sourceGuidance,
    "source-guidance",
  );
  const supportEvidence = await loadCollection(
    typedRelease.supportEvidence,
    "support-evidence",
  );
  const extensions = await loadCollection(
    typedRelease.extensions,
    "extension-registration",
  );
  validateCatalogueSemantics(
    typedRelease,
    entries,
    migrations,
    fixtures,
    sourceGuidance,
    supportEvidence,
    extensions,
  );

  return {
    root: releaseRoot,
    document: typedRelease,
    entries,
    migrations,
    fixtures,
    sourceGuidance,
    supportEvidence,
    extensions,
  };
}

interface SelectedLayer {
  readonly layerId: string;
  readonly entry: CatalogueEntryDocument;
  readonly choices: Readonly<Record<string, JsonScalar>>;
  readonly scopeKind: "repository" | "workload" | "cross-workload";
  readonly workloadIds: readonly string[];
}

function findEntry(
  release: ValidatedCatalogueRelease,
  family: CatalogueEntryDocument["family"],
  kind: string,
): CatalogueEntryDocument {
  const matches = [...release.entries.values()].filter(
    (entry) => entry.family === family && entry.kind === kind,
  );
  if (matches.length !== 1) {
    throw new CatalogueValidationError(
      "semantic-invalid",
      "configuration",
      `Expected exactly one ${family} Catalogue Entry for kind ${kind}; found ${matches.length}`,
    );
  }
  return matches[0] as CatalogueEntryDocument;
}

function scalarMatchesType(
  value: JsonScalar,
  valueType: ChoiceDefinition["valueType"],
): boolean {
  if (valueType === "integer") {
    return typeof value === "number" && Number.isInteger(value);
  }
  return typeof value === valueType;
}

function resolveChoices(
  entry: CatalogueEntryDocument,
  supplied: Readonly<Record<string, JsonScalar>>,
  layerId: string,
): Readonly<Record<string, JsonScalar>> {
  const definitions = new Map(entry.choices.map((choice) => [choice.id, choice]));
  for (const choiceId of Object.keys(supplied)) {
    if (!definitions.has(choiceId)) {
      throw new CatalogueValidationError(
        "choice-invalid",
        "configuration",
        `Layer ${layerId} supplies unknown Policy Choice ${choiceId}`,
      );
    }
  }

  const resolved: Record<string, JsonScalar> = {};
  for (const choice of entry.choices) {
    const suppliedValue = supplied[choice.id];
    const value = suppliedValue ?? choice.default;
    if (value === undefined) {
      if (choice.required) {
        throw new CatalogueValidationError(
          "choice-invalid",
          "configuration",
          `Layer ${layerId} is missing required Policy Choice ${choice.id}`,
        );
      }
      continue;
    }
    if (
      !scalarMatchesType(value, choice.valueType) ||
      !choice.allowedValues.includes(value)
    ) {
      throw new CatalogueValidationError(
        "choice-invalid",
        "configuration",
        `Layer ${layerId} has invalid value for Policy Choice ${choice.id}`,
      );
    }
    resolved[choice.id] = value;
  }
  return resolved;
}

function conditionMatches(
  condition: ApplicabilityCondition,
  layer: SelectedLayer,
  selectedEntryIds: ReadonlySet<string>,
): boolean {
  switch (condition.kind) {
    case "always":
      return true;
    case "choice-equals":
      return layer.choices[condition.choiceId] === condition.value;
    case "entry-selected":
      return selectedEntryIds.has(condition.entryId);
    case "scope-kind-is":
      return layer.scopeKind === condition.scopeKind;
    case "all":
      return condition.conditions.every((item) =>
        conditionMatches(item, layer, selectedEntryIds),
      );
    case "any":
      return condition.conditions.some((item) =>
        conditionMatches(item, layer, selectedEntryIds),
      );
    case "not":
      return !conditionMatches(condition.condition, layer, selectedEntryIds);
  }
}

function relationshipMatches(
  source: SelectedLayer,
  target: SelectedLayer,
  scopeRelation: EntryRelationship["scopeRelation"],
): boolean {
  if (scopeRelation === "repository") {
    return true;
  }
  return (
    source.workloadIds.length > 0 &&
    source.workloadIds.every((workloadId) =>
      target.workloadIds.includes(workloadId),
    )
  );
}

function validateComposition(layers: readonly SelectedLayer[]): void {
  for (const layer of layers) {
    for (const requirement of layer.entry.requires) {
      const satisfied = layers.some(
        (candidate) =>
          candidate.entry.id === requirement.entryId &&
          relationshipMatches(layer, candidate, requirement.scopeRelation),
      );
      if (!satisfied) {
        throw new CatalogueValidationError(
          "catalogue-incompatibility",
          "configuration",
          `Layer ${layer.layerId} requires ${requirement.entryId} with ${requirement.scopeRelation} scope`,
        );
      }
    }

    for (const incompatibility of layer.entry.incompatibleWith) {
      const conflicts = layers.some(
        (candidate) =>
          candidate.entry.id === incompatibility.entryId &&
          relationshipMatches(
            layer,
            candidate,
            incompatibility.scopeRelation,
          ),
      );
      if (conflicts) {
        throw new CatalogueValidationError(
          "catalogue-incompatibility",
          "configuration",
          `Layer ${layer.layerId} is incompatible with ${incompatibility.entryId} at ${incompatibility.scopeRelation} scope`,
        );
      }
    }
  }
}

export async function resolveBootstrapConfiguration(
  release: ValidatedCatalogueRelease,
  configuration: unknown,
): Promise<ResolvedBootstrapConfiguration> {
  const configurationSchema = await readJson(
    join(schemaDirectory, "configuration.schema.json"),
    "schemas/v1/configuration.schema.json",
  );
  const ajv = createSchemaValidator();
  const validate = ajv.compile<BootstrapConfiguration>(
    configurationSchema as AnySchema,
  );
  if (!validate(configuration)) {
    throw new CatalogueValidationError(
      "schema-invalid",
      "configuration",
      "Configuration does not match the closed Bootstrap Configuration schema",
      validate.errors ?? [],
    );
  }

  const typedConfiguration = configuration as BootstrapConfiguration;
  if (
    typedConfiguration.catalogueVersion !==
      release.document.catalogueVersion ||
    typedConfiguration.catalogueDigest !== release.document.catalogueDigest
  ) {
    throw new CatalogueValidationError(
      "exact-pin-mismatch",
      "configuration",
      "Configuration does not pin the exact loaded Catalogue Release version and digest",
    );
  }

  const extensionRegistrations = new Map<string, IdentifiedDocument>();
  for (const registration of release.extensions.values()) {
    if (
      typeof registration.namespace === "string" &&
      Array.isArray(registration.targets) &&
      registration.targets.includes("configuration")
    ) {
      extensionRegistrations.set(registration.namespace, registration);
    }
  }
  for (const [namespace, value] of Object.entries(
    typedConfiguration.extensions,
  )) {
    const registration = extensionRegistrations.get(namespace);
    if (registration === undefined) {
      throw new CatalogueValidationError(
        "catalogue-incompatibility",
        "configuration",
        `Configuration uses unregistered extension namespace ${namespace}`,
      );
    }
    const extensionValidator = ajv.compile(registration.schema as AnySchema);
    if (!extensionValidator(value)) {
      throw new CatalogueValidationError(
        "schema-invalid",
        `configuration.extensions.${namespace}`,
        `Configuration extension ${namespace} does not match its registered schema`,
        extensionValidator.errors ?? [],
      );
    }
  }

  const coreEntry = findEntry(
    release,
    "core",
    typedConfiguration.core.kind,
  );
  const resolvedCoreChoices = resolveChoices(
    coreEntry,
    typedConfiguration.core.choices,
    "core",
  );

  const workloadIds = new Set<string>();
  const workloadRoots = new Set<string>();
  const resolvedWorkloads = typedConfiguration.workloads.map((workload) => {
    const rootSegments = workload.root.split("/");
    if (
      (workload.root !== "." &&
        rootSegments.some((segment) => segment === "." || segment === "..")) ||
      workload.root.startsWith("/") ||
      workload.root.includes("\\")
    ) {
      throw new CatalogueValidationError(
        "catalogue-incompatibility",
        "configuration",
        `Workload ${workload.id} root must be repository-relative: ${workload.root}`,
      );
    }
    if (workloadIds.has(workload.id) || workloadRoots.has(workload.root)) {
      throw new CatalogueValidationError(
        "catalogue-incompatibility",
        "configuration",
        `Workload IDs and roots must be unique; duplicate ${workload.id} or ${workload.root}`,
      );
    }
    workloadIds.add(workload.id);
    workloadRoots.add(workload.root);
    const entry = findEntry(release, "workload", workload.kind);
    return {
      ...workload,
      choices: resolveChoices(entry, workload.choices, workload.id),
      entry,
    };
  });
  for (const parent of resolvedWorkloads) {
    for (const nested of resolvedWorkloads) {
      if (parent.id === nested.id) continue;
      const isNested =
        (parent.root === "." && nested.root !== ".") ||
        nested.root.startsWith(`${parent.root}/`);
      if (!isNested) continue;
      const declared = parent.entry.nestedRootContracts.some(
        (contract) => contract.nestedEntryId === nested.entry.id,
      );
      if (!declared) {
        throw new CatalogueValidationError(
          "catalogue-incompatibility",
          "configuration",
          `Workloads ${parent.id} and ${nested.id} have nested Workload roots without a catalogue-declared ownership contract`,
        );
      }
    }
  }

  const layerIds = new Set<string>(workloadIds);
  const resolvedCapabilities = typedConfiguration.capabilities.map(
    (capability) => {
      if (layerIds.has(capability.id)) {
        throw new CatalogueValidationError(
          "catalogue-incompatibility",
          "configuration",
          `Layer instance ID ${capability.id} is duplicated`,
        );
      }
      layerIds.add(capability.id);
      const entry = findEntry(release, "capability", capability.kind);
      if (!entry.scopeKinds.includes(capability.scope.kind)) {
        throw new CatalogueValidationError(
          "catalogue-incompatibility",
          "configuration",
          `Capability ${capability.id} does not support ${capability.scope.kind} scope`,
        );
      }
      if ("workloadIds" in capability.scope) {
        for (const workloadId of capability.scope.workloadIds) {
          if (!workloadIds.has(workloadId)) {
            throw new CatalogueValidationError(
              "catalogue-incompatibility",
              "configuration",
              `Capability ${capability.id} references unknown Workload ${workloadId}`,
            );
          }
        }
      }
      return {
        ...capability,
        choices: resolveChoices(entry, capability.choices, capability.id),
        entry,
      };
    },
  );

  const layers: readonly SelectedLayer[] = [
    {
      layerId: "core",
      entry: coreEntry,
      choices: resolvedCoreChoices,
      scopeKind: "repository",
      workloadIds: [],
    },
    ...resolvedWorkloads.map((workload) => ({
      layerId: workload.id,
      entry: workload.entry,
      choices: workload.choices,
      scopeKind: "workload" as const,
      workloadIds: [workload.id],
    })),
    ...resolvedCapabilities.map((capability) => ({
      layerId: capability.id,
      entry: capability.entry,
      choices: capability.choices,
      scopeKind: capability.scope.kind,
      workloadIds:
        "workloadIds" in capability.scope
          ? capability.scope.workloadIds
          : ([] as const),
    })),
  ];
  const selectedEntryCounts = new Map<string, number>();
  for (const layer of layers) {
    selectedEntryCounts.set(
      layer.entry.id,
      (selectedEntryCounts.get(layer.entry.id) ?? 0) + 1,
    );
  }
  for (const layer of layers) {
    if (
      layer.entry.cardinality === "singleton" &&
      (selectedEntryCounts.get(layer.entry.id) ?? 0) > 1
    ) {
      throw new CatalogueValidationError(
        "catalogue-incompatibility",
        "configuration",
        `Catalogue Entry ${layer.entry.id} is singleton but was selected more than once`,
      );
    }
  }
  validateComposition(layers);

  const selectedEntryIds = new Set(layers.map((layer) => layer.entry.id));
  const applicableRules = layers.flatMap((layer) =>
    layer.entry.rules
      .filter((rule) =>
        conditionMatches(rule.applicability, layer, selectedEntryIds),
      )
      .map((rule) => ({
        layerId: layer.layerId,
        entryId: layer.entry.id,
        ruleId: rule.id,
      })),
  );
  const refinements = layers.flatMap((layer) =>
    layer.entry.refines.flatMap((refinement) => {
      const sourceIsApplicable = applicableRules.some(
        (rule) =>
          rule.layerId === layer.layerId &&
          rule.ruleId === refinement.ruleId,
      );
      if (!sourceIsApplicable) return [];

      const targets = layers.filter(
        (candidate) =>
          candidate.entry.rules.some(
            (rule) => rule.id === refinement.refinesRuleId,
          ) &&
          relationshipMatches(layer, candidate, refinement.scopeRelation) &&
          applicableRules.some(
            (rule) =>
              rule.layerId === candidate.layerId &&
              rule.ruleId === refinement.refinesRuleId,
          ),
      );
      if (targets.length === 0) {
        throw new CatalogueValidationError(
          "catalogue-incompatibility",
          "configuration",
          `Catalogue refinement ${refinement.ruleId} -> ${refinement.refinesRuleId} has no applicable target layer`,
        );
      }
      return targets.map((target) => ({
        layerId: layer.layerId,
        ruleId: refinement.ruleId,
        refinesLayerId: target.layerId,
        refinesRuleId: refinement.refinesRuleId,
      }));
    }),
  );

  return {
    configuration: {
      ...typedConfiguration,
      core: { ...typedConfiguration.core, choices: resolvedCoreChoices },
      workloads: resolvedWorkloads.map(({ entry: _entry, ...workload }) =>
        workload,
      ),
      capabilities: resolvedCapabilities.map(
        ({ entry: _entry, ...capability }) => capability,
      ),
    },
    applicableRules,
    refinements,
  };
}
