import type {
  CatalogueEntryDocument,
  ResolvedBootstrapConfiguration,
  ValidatedCatalogueRelease,
  VerificationRequirement,
} from "./index.js";
import {
  canonicalJsonDigest,
  sameCanonicalJson,
} from "./canonical-json.js";

export type VerificationHorizon = "baseline" | "delivery";
export type RequirementEvaluation =
  | "satisfied"
  | "waived"
  | "failed"
  | "incomplete";
export type VerificationOutcome = "verified" | "failed" | "incomplete";

export interface VerificationScope {
  readonly kind:
    | "repository"
    | "workload"
    | "cross-workload"
    | "artifact"
    | "interface-boundary";
  readonly id: string;
}

export interface RepositoryEvidenceBinding {
  readonly identity: string;
  readonly revision: string;
  readonly stateDigest: string;
}

export interface EvidenceActor {
  readonly kind: "human" | "provider";
  readonly identity: string;
  readonly authorityClass: string;
  readonly externalDecisionReference?: string;
}

export interface WaiverActor extends EvidenceActor {
  readonly kind: "human";
  readonly actedAt: string;
}

export interface VerificationEvidenceDocument {
  readonly $schema: string;
  readonly schemaVersion: "1.0.0";
  readonly id: string;
  readonly evidenceDigest: string;
  readonly ruleId: string;
  readonly requirementId: string;
  readonly scope: VerificationScope;
  readonly repository: RepositoryEvidenceBinding;
  readonly configurationDigest: string;
  readonly catalogueVersion: string;
  readonly catalogueDigest: string;
  readonly bootstrapperVersion: string;
  readonly bootstrapperDigest: string;
  readonly schemaDigests: Readonly<Record<string, string>>;
  readonly declaredInputsDigest: string;
  readonly artifactObservations: readonly Readonly<{
    artifactId: string;
    ownerLayerId: string;
    locator: string;
    fingerprint: string;
  }>[];
  readonly verificationHorizon: VerificationHorizon;
  readonly invocation: Readonly<{
    executable: string;
    arguments: readonly string[];
    workingDirectory: string;
    declaredEnvironmentInputs: readonly string[];
  }>;
  readonly toolchain: Readonly<{
    name: string;
    version: string;
    digest?: string;
  }>;
  readonly kind:
    | "deterministic-check"
    | "attributable-review"
    | "manual-state";
  readonly result:
    | "passed"
    | "failed"
    | "error"
    | "accepted"
    | "changes-required"
    | "unable-to-conclude"
    | "verified"
    | "not-verified"
    | "attested";
  readonly attempts: number;
  readonly observedAt: string;
  readonly validUntil?: string;
  readonly actor?: EvidenceActor;
  readonly reviewedMaterialDigest?: string;
  readonly rationale?: string;
  readonly findings?: readonly string[];
  readonly dispositions?: readonly string[];
  readonly questionConclusions?: readonly Readonly<{
    questionId: string;
    conclusion: "accepted" | "changes-required" | "unable-to-conclude";
  }>[];
  readonly manualState?: Readonly<{
    target: string;
    stateDigest: string;
    assurance: "machine-readback" | "named-attestation";
  }>;
  readonly output: Readonly<{
    digest: string;
    immutableReference?: string;
  }>;
}

export interface RuleWaiverDocument {
  readonly $schema: string;
  readonly schemaVersion: "1.0.0";
  readonly id: string;
  readonly version: number;
  readonly digest: string;
  readonly layerId: string;
  readonly ruleId: string;
  readonly scope: VerificationScope;
  readonly requirementIds: readonly string[];
  readonly managedSuppressionIds: readonly string[];
  readonly reasonClass: string;
  readonly reasonEvidence: readonly string[];
  readonly risk: string;
  readonly riskReviewedAt: string;
  readonly compensatingControls: readonly Readonly<{
    requirementId: string;
    evidenceIds: readonly string[];
  }>[];
  readonly requester: WaiverActor;
  readonly approvals: readonly WaiverActor[];
  readonly remediation: string;
  readonly validity: Readonly<{
    startsAt: string;
    expiresAt: string;
    repositoryStateDigest: string;
    configurationDigest: string;
    catalogueDigest: string;
  }>;
  readonly upgradeDisposition: "revalidate" | "retire" | "replace";
  readonly status:
    | "proposed"
    | "active"
    | "expired"
    | "revoked"
    | "invalidated"
    | "superseded";
  readonly supersedes?: string;
  readonly supersedesDigest?: string;
}

export interface ProvenanceManifestDocument {
  readonly $schema: string;
  readonly schemaVersion: "1.0.0";
  readonly configurationDigest: string;
  readonly catalogueVersion: string;
  readonly catalogueDigest: string;
  readonly bootstrapperVersion: string;
  readonly bootstrapperDigest: string;
  readonly schemaDigests: Readonly<Record<string, string>>;
  readonly verifyingRunId?: string;
  readonly artifacts: readonly ManagedSuppressionDocument["artifact"][];
  readonly evidence: readonly Readonly<{
    evidenceId: string;
    digest: string;
    result: string;
    observedAt: string;
    validUntil?: string;
    immutableReference?: string;
  }>[];
  readonly activeWaivers: readonly Readonly<{
    waiverId: string;
    version: number;
    digest: string;
  }>[];
  readonly managedSuppressions: readonly Readonly<{
    suppressionId: string;
    waiverId: string;
    waiverVersion: number;
    artifactId: string;
    ownerLayerId: string;
    locator: string;
    fingerprint: string;
  }>[];
}

export interface WaiverAuthenticityBinding {
  readonly waiverId: string;
  readonly version: number;
  readonly digest: string;
  readonly source: Readonly<{
    kind: "committed-record";
    path: string;
    revision: string;
    repositoryStateDigest: string;
  }>;
}

export interface VerificationRequest {
  readonly $schema: string;
  readonly schemaVersion: "1.0.0";
  readonly horizon: VerificationHorizon;
  readonly evaluatedAt: string;
  readonly repository: RepositoryEvidenceBinding;
  readonly bootstrapper: Readonly<{ version: string; digest: string }>;
  readonly schemaDigests: Readonly<Record<string, string>>;
  readonly affectedRequirements: readonly Readonly<{
    requirementId: string;
    scope: VerificationScope;
  }>[];
  readonly requirementInputs: readonly Readonly<{
    requirementId: string;
    scope: VerificationScope;
    digest: string;
  }>[];
  readonly authorities: readonly Readonly<{
    authorityClass: string;
    identities: readonly string[];
    externalDecisionReferences: readonly string[];
  }>[];
  readonly subjects: readonly Readonly<{
    requirementId: string;
    scope: VerificationScope;
    authorIdentities: readonly string[];
    authorityClasses: readonly string[];
  }>[];
  readonly blockers: readonly Readonly<{
    kind:
      | "conflict"
      | "catalogue-incompatibility"
      | "drift"
      | "missing-authority"
      | "invariant-failed";
    id: string;
    message: string;
  }>[];
  readonly evidence: readonly VerificationEvidenceDocument[];
  readonly evidenceAuthenticity: readonly Readonly<{
    evidenceId: string;
    evidenceDigest: string;
    source:
      | Readonly<{
          kind: "local-execution";
          runId: string;
          bootstrapperDigest: string;
        }>
      | Readonly<{
          kind: "immutable-reference";
          reference: string;
        }>;
  }>[];
  readonly waivers: readonly RuleWaiverDocument[];
  readonly waiverHistory: readonly RuleWaiverDocument[];
  readonly waiverAuthenticity: readonly WaiverAuthenticityBinding[];
  readonly projectDeliveryContract: ManagedSuppressionDocument["artifact"];
  readonly manifest: ProvenanceManifestDocument;
  readonly managedSuppressions: readonly ManagedSuppressionDocument[];
}

export interface ManagedSuppressionDocument {
  readonly id: string;
  readonly waiverId: string;
  readonly waiverVersion: number;
  readonly scope: VerificationScope;
  readonly artifact: Readonly<{
    artifactId: string;
    ownerLayerId: string;
    locator: string;
    ownership: "whole-file" | "structured-fragment" | "link";
    fingerprint: string;
    verificationState: "matching" | "drifted" | "missing" | "ambiguous";
  }>;
  readonly verificationEvidenceId: string;
}

export type VerificationReason =
  | "deterministic-check-passed"
  | "deterministic-check-failed"
  | "deterministic-check-error"
  | "review-accepted"
  | "review-changes-required"
  | "review-unable-to-conclude"
  | "manual-state-verified"
  | "manual-state-not-verified"
  | "manual-state-attested"
  | "manual-state-error"
  | "delivery-gate-satisfied"
  | "delivery-gate-unsatisfied"
  | "active-waiver"
  | "evidence-missing"
  | "evidence-invalid"
  | "evidence-stale"
  | "authority-missing"
  | "independence-violated";

export interface RequirementEvaluationResult {
  readonly layerId: string;
  readonly ruleId: string;
  readonly requirementId: string;
  readonly scope: VerificationScope;
  readonly phase: "baseline" | "delivery";
  readonly kind: VerificationRequirement["kind"];
  readonly evaluation: RequirementEvaluation;
  readonly reason: VerificationReason;
  readonly evidenceId?: string;
  readonly waiver?: WaiverReference;
}

export interface WaiverReference {
  readonly waiverId: string;
  readonly waiverVersion: number;
}

export interface VerificationResult {
  readonly schemaVersion: "1.0.0";
  readonly outcome: VerificationOutcome;
  readonly horizon: VerificationHorizon;
  readonly requirements: readonly RequirementEvaluationResult[];
  readonly blockers: VerificationRequest["blockers"];
  readonly waivers: readonly Readonly<{
    waiverId: string;
    version: number;
    digest: string;
    ruleId: string;
    scope: VerificationScope;
    requirementIds: readonly string[];
    compensatingControlRequirementIds: readonly string[];
    managedSuppressionIds: readonly string[];
    risk: string;
    remediation: string;
    expiresAt: string;
  }>[];
  readonly managedSuppressions: readonly ManagedSuppressionEvaluation[];
}

export interface ManagedSuppressionEvaluation {
  readonly suppressionId: string;
  readonly evaluation: "active" | "incomplete";
  readonly reason:
    | "active-waiver"
    | "suppression-missing"
    | "suppression-unauthorized"
    | "suppression-scope-exceeded"
    | "suppression-artifact-invalid"
    | "suppression-evidence-invalid";
  readonly waiverId: string;
  readonly waiverVersion: number;
  readonly ruleId: string;
  readonly scope: VerificationScope;
  readonly artifact?: ManagedSuppressionDocument["artifact"];
}

type ApplicableRequirement = Readonly<{
  layerId: string;
  entry: CatalogueEntryDocument;
  ruleId: string;
  requirement: VerificationRequirement;
  scope: VerificationScope;
}>;

type VerificationContext = Readonly<{
  release: ValidatedCatalogueRelease;
  resolved: ResolvedBootstrapConfiguration;
  request: VerificationRequest;
  configurationDigest: string;
}>;

function contentDigest(
  value: Readonly<Record<string, unknown>>,
  digestProperty: string,
): string | undefined {
  const { [digestProperty]: _digest, ...content } = value;
  return canonicalJsonDigest(content);
}

function waiverReference(
  waiverId: string,
  waiverVersion: number,
): WaiverReference {
  return { waiverId, waiverVersion };
}

function waiverDocumentReference(
  waiver: RuleWaiverDocument,
): WaiverReference {
  return waiverReference(waiver.id, waiver.version);
}

function sameWaiverReference(
  left: WaiverReference,
  right: WaiverReference,
): boolean {
  return (
    left.waiverId === right.waiverId &&
    left.waiverVersion === right.waiverVersion
  );
}

function layerScopes(
  resolved: ResolvedBootstrapConfiguration,
  layerId: string,
): readonly VerificationScope[] {
  if (layerId === "core") {
    return [{ kind: "repository", id: "repository" }];
  }
  if (resolved.configuration.workloads.some(({ id }) => id === layerId)) {
    return [{ kind: "workload", id: layerId }];
  }
  const capability = resolved.configuration.capabilities.find(
    ({ id }) => id === layerId,
  );
  if (capability?.scope.kind === "repository") {
    return [{ kind: "repository", id: "repository" }];
  }
  if (capability?.scope.kind === "workload") {
    return capability.scope.workloadIds.map((id) => ({
      kind: "workload",
      id,
    }));
  }
  return [
    {
      kind: "cross-workload",
      id: capability?.scope.workloadIds.join("+") ?? layerId,
    },
  ];
}

function applicableRequirements(
  release: ValidatedCatalogueRelease,
  resolved: ResolvedBootstrapConfiguration,
): readonly ApplicableRequirement[] {
  return resolved.applicableRules.flatMap(({ layerId, entryId, ruleId }) => {
    const entry = release.entries.get(entryId);
    const rule = entry?.rules.find(({ id }) => id === ruleId);
    if (entry === undefined || rule === undefined) return [];
    const requirements = rule.requirementIds.flatMap((requirementId) => {
      const requirement = entry.requirements.find(
        ({ id }) => id === requirementId,
      );
      return requirement === undefined
        ? []
        : layerScopes(resolved, layerId).map((scope) => ({
              layerId,
              entry,
              ruleId,
              requirement,
              scope,
            }));
    });
    return requirements;
  });
}

function baseEvaluation(
  applicable: ApplicableRequirement,
  evaluation: RequirementEvaluation,
  reason: VerificationReason,
  evidenceId?: string,
  waiver?: WaiverReference,
): RequirementEvaluationResult {
  return {
    layerId: applicable.layerId,
    ruleId: applicable.ruleId,
    requirementId: applicable.requirement.id,
    scope: applicable.scope,
    phase: applicable.requirement.phase,
    kind: applicable.requirement.kind,
    evaluation,
    reason,
    ...(evidenceId === undefined ? {} : { evidenceId }),
    ...(waiver === undefined ? {} : { waiver }),
  };
}

function evidenceBindingReason(
  evidence: VerificationEvidenceDocument,
  applicable: ApplicableRequirement,
  context: VerificationContext,
): "evidence-invalid" | "evidence-stale" | undefined {
  const { release, resolved, request, configurationDigest } = context;
  const expectedInputs = request.requirementInputs.filter(
    (input) =>
      input.requirementId === applicable.requirement.id &&
      sameCanonicalJson(input.scope, applicable.scope),
  );
  const expectedInput = expectedInputs[0];
  if (
    expectedInputs.length !== 1 ||
    evidence.evidenceDigest !==
    contentDigest(
      evidence as unknown as Readonly<Record<string, unknown>>,
      "evidenceDigest",
    ) ||
    evidence.ruleId !== applicable.ruleId ||
    evidence.requirementId !== applicable.requirement.id ||
    evidence.kind !== applicable.requirement.kind ||
    !sameCanonicalJson(evidence.scope, applicable.scope)
  ) {
    return "evidence-invalid";
  }
  const authenticity = request.evidenceAuthenticity.filter(
    (binding) => binding.evidenceId === evidence.id,
  );
  if (
    authenticity.length !== 1 ||
    authenticity[0]!.evidenceDigest !== evidence.evidenceDigest ||
    (authenticity[0]!.source.kind === "local-execution"
      ? authenticity[0]!.source.bootstrapperDigest !==
          request.bootstrapper.digest
      : authenticity[0]!.source.reference !==
        evidence.output.immutableReference)
  ) {
    return "evidence-invalid";
  }
  const checkId =
    applicable.requirement.kind === "deterministic-check"
      ? applicable.requirement.checkId
      : applicable.requirement.manualState?.checkId;
  if (checkId !== undefined) {
    const check = applicable.entry.checks.find(({ id }) => id === checkId);
    const workloadId =
      applicable.scope.kind === "workload"
        ? applicable.scope.id
        : undefined;
    const expectedWorkingDirectory =
      check?.scope.kind === "repository"
        ? "."
        : resolved.configuration.workloads.find(({ id }) => id === workloadId)
            ?.root;
    if (
      check === undefined ||
      expectedWorkingDirectory === undefined ||
      evidence.invocation.executable !== check.executable ||
      !sameCanonicalJson(evidence.invocation.arguments, check.arguments) ||
      evidence.invocation.workingDirectory !== expectedWorkingDirectory ||
      evidence.invocation.declaredEnvironmentInputs.length !== 0 ||
      !sameCanonicalJson(evidence.toolchain, check.toolchain) ||
      evidence.attempts > check.retryPolicy.maximumAttempts
    ) {
      return "evidence-invalid";
    }
  }
  if (applicable.requirement.kind === "attributable-review") {
    const questionIds =
      applicable.requirement.questions?.map(({ id }) => id).sort() ?? [];
    const conclusions = evidence.questionConclusions ?? [];
    if (
      !sameCanonicalJson(
        conclusions.map(({ questionId }) => questionId).sort(),
        questionIds,
      ) ||
      conclusions.some(({ conclusion }) => conclusion !== evidence.result) ||
      evidence.reviewedMaterialDigest !== expectedInput?.digest
    ) {
      return "evidence-invalid";
    }
  }
  if (
    applicable.requirement.kind === "manual-state" &&
    (evidence.manualState?.target !==
      applicable.requirement.manualState?.target ||
      evidence.manualState?.assurance !==
        applicable.requirement.manualState?.assurance ||
      evidence.manualState?.stateDigest !== expectedInput?.digest ||
      (applicable.requirement.manualState?.assurance === "named-attestation"
        ? (evidence.result !== "attested" &&
            evidence.result !== "not-verified") ||
          evidence.actor?.kind !== "human"
        : evidence.result === "attested"))
  ) {
    return "evidence-invalid";
  }
  if (
    expectedInput === undefined ||
    evidence.declaredInputsDigest !== expectedInput.digest ||
    !sameCanonicalJson(evidence.repository, request.repository) ||
    evidence.configurationDigest !== configurationDigest ||
    evidence.catalogueVersion !== release.document.catalogueVersion ||
    evidence.catalogueDigest !== release.document.catalogueDigest ||
    evidence.bootstrapperVersion !== request.bootstrapper.version ||
    evidence.bootstrapperDigest !== request.bootstrapper.digest ||
    !sameCanonicalJson(evidence.schemaDigests, request.schemaDigests) ||
    !sameCanonicalJson(request.schemaDigests, release.schemaDigests) ||
    evidence.verificationHorizon !== applicable.requirement.phase
  ) {
    return "evidence-stale";
  }
  const evaluatedAt = Date.parse(request.evaluatedAt);
  const observedAt = Date.parse(evidence.observedAt);
  const validUntil =
    evidence.validUntil === undefined
      ? undefined
      : Date.parse(evidence.validUntil);
  const freshness = applicable.requirement.freshness;
  if (
    !Number.isFinite(evaluatedAt) ||
    !Number.isFinite(observedAt) ||
    observedAt > evaluatedAt ||
    (validUntil !== undefined &&
      (!Number.isFinite(validUntil) || validUntil < evaluatedAt)) ||
    (freshness.kind === "maximum-age" &&
      (evaluatedAt - observedAt > freshness.maximumAgeSeconds * 1000 ||
        (validUntil !== undefined &&
          validUntil - observedAt > freshness.maximumAgeSeconds * 1000)))
  ) {
    return "evidence-stale";
  }
  return undefined;
}

function authorityReason(
  applicable: ApplicableRequirement,
  evidence: VerificationEvidenceDocument,
  context: VerificationContext,
): "authority-missing" | "independence-violated" | undefined {
  const { release, request } = context;
  if (applicable.requirement.kind === "deterministic-check") return undefined;
  const actor = evidence.actor;
  const authorityClass = applicable.requirement.authorityClass;
  if (
    actor === undefined ||
    (applicable.requirement.kind === "attributable-review" &&
      actor.kind !== "human") ||
    authorityClass === undefined ||
    actor.authorityClass !== authorityClass ||
    !actorSatisfiesAuthority(actor, authorityClass, context)
  ) {
    return "authority-missing";
  }
  const subjects = request.subjects.filter(
    (candidate) =>
      candidate.requirementId === applicable.requirement.id &&
      sameCanonicalJson(candidate.scope, applicable.scope),
  );
  const subject = subjects[0];
  if (
    applicable.requirement.independence !== "none" &&
    (subjects.length !== 1 ||
      subject === undefined ||
      subject.authorIdentities.includes(actor.identity))
  ) {
    return "independence-violated";
  }
  if (
    applicable.requirement.independence === "separate-authority" &&
    subject?.authorityClasses.includes(actor.authorityClass)
  ) {
    return "independence-violated";
  }
  return undefined;
}

function actorSatisfiesAuthority(
  actor: EvidenceActor,
  authorityClassId: string,
  context: VerificationContext,
): boolean {
  const { release, request } = context;
  const authorities = request.authorities.filter(
    ({ authorityClass }) => authorityClass === authorityClassId,
  );
  const authority = authorities[0];
  const definition = [...release.entries.values()]
    .flatMap((entry) => entry.authorityClasses)
    .find(({ id }) => id === authorityClassId);
  if (
    authorities.length !== 1 ||
    authority === undefined ||
    definition === undefined
  ) {
    return false;
  }
  if (definition.resolution === "named-identity") {
    return authority.identities.includes(actor.identity);
  }
  return (
    definition.resolution === "verifiable-external-decision" &&
    actor.externalDecisionReference !== undefined &&
    authority.externalDecisionReferences.includes(
      actor.externalDecisionReference,
    )
  );
}

function evidenceSatisfiesRequirement(
  applicable: ApplicableRequirement,
  evidenceId: string,
  context: VerificationContext,
): boolean {
  const { request } = context;
  const evidence = request.evidence.find(({ id }) => id === evidenceId);
  if (
    evidence === undefined ||
    evidence.requirementId !== applicable.requirement.id ||
    !sameCanonicalJson(evidence.scope, applicable.scope) ||
    evidenceBindingReason(
      evidence,
      applicable,
      context,
    ) !== undefined ||
    authorityReason(applicable, evidence, context) !== undefined
  ) {
    return false;
  }
  return evidenceOutcome(applicable, evidence).evaluation === "satisfied";
}

function waiverRecordAuthentic(
  waiver: RuleWaiverDocument,
  request: VerificationRequest,
): boolean {
  const reference = waiverDocumentReference(waiver);
  const authenticity = request.waiverAuthenticity.filter((binding) =>
    sameWaiverReference(
      waiverReference(binding.waiverId, binding.version),
      reference,
    ),
  );
  const expectedPath = `.project-standards/waivers/${waiver.id.slice("waiver/".length)}.json`;
  return (
    authenticity.length === 1 &&
    authenticity[0]!.digest === waiver.digest &&
    authenticity[0]!.source.path === expectedPath &&
    authenticity[0]!.source.repositoryStateDigest ===
      request.repository.stateDigest &&
    waiver.digest ===
      contentDigest(
        waiver as unknown as Readonly<Record<string, unknown>>,
        "digest",
      )
  );
}

function authenticPredecessorRecord(
  waiver: RuleWaiverDocument,
  request: VerificationRequest,
): RuleWaiverDocument | undefined {
  if (waiver.version === 1) return undefined;
  const predecessor = waiverReference(waiver.id, waiver.version - 1);
  const authenticity = request.waiverAuthenticity.filter((binding) =>
    sameWaiverReference(
      waiverReference(binding.waiverId, binding.version),
      predecessor,
    ),
  );
  const documents = request.waiverHistory.filter(
    (candidate) =>
      candidate.id === predecessor.waiverId &&
      candidate.version === predecessor.waiverVersion,
  );
  const expectedPath = `.project-standards/waivers/${waiver.id.slice("waiver/".length)}.json`;
  return (
    authenticity.length === 1 &&
    documents.length === 1 &&
    authenticity[0]!.digest === waiver.supersedesDigest &&
    authenticity[0]!.source.path === expectedPath &&
    authenticity[0]!.source.repositoryStateDigest ===
      documents[0]!.validity.repositoryStateDigest &&
    documents[0]!.digest === authenticity[0]!.digest &&
    documents[0]!.digest ===
      contentDigest(
        documents[0] as unknown as Readonly<Record<string, unknown>>,
        "digest",
      )
      ? documents[0]
      : undefined
  );
}

function validWaiver(
  applicable: ApplicableRequirement,
  requirements: readonly ApplicableRequirement[],
  context: VerificationContext,
): RuleWaiverDocument | undefined {
  const { release, request, configurationDigest } = context;
  const rule = applicable.entry.rules.find(({ id }) => id === applicable.ruleId);
  const policy = rule?.waiverPolicy;
  if (
    policy?.kind !== "governed" ||
    typeof policy.authorityClass !== "string"
  ) {
    return undefined;
  }
  const approvalAuthority = policy.authorityClass;
  const evaluatedAt = Date.parse(request.evaluatedAt);
  return request.waivers.find((waiver) => {
    const predecessor = authenticPredecessorRecord(waiver, request);
    const startsAt = Date.parse(waiver.validity.startsAt);
    const latestPredecessorApproval = Math.max(
      ...(predecessor?.approvals.map(({ actedAt }) => Date.parse(actedAt)) ?? []),
    );
    const approvals = waiver.approvals.filter(
      (actor) => actor.authorityClass === approvalAuthority,
    );
    const approvalResolvedAndIndependent = approvals.some(
      (approval) =>
        actorSatisfiesAuthority(approval, approvalAuthority, context) &&
        Date.parse(approval.actedAt) >= startsAt &&
        Date.parse(approval.actedAt) <= evaluatedAt &&
        (waiver.version === 1 ||
          Date.parse(approval.actedAt) > latestPredecessorApproval) &&
        (policy.independence === "none" ||
          (approval.identity !== waiver.requester.identity &&
            (policy.independence !== "separate-authority" ||
              approval.authorityClass !== waiver.requester.authorityClass))),
    );
    const expiresAt = Date.parse(waiver.validity.expiresAt);
    const maximumDurationDays = policy.maximumDurationDays;
    const durationValid =
      typeof maximumDurationDays === "number" &&
      Number.isFinite(startsAt) &&
      Number.isFinite(expiresAt) &&
      expiresAt > startsAt &&
      expiresAt - startsAt <= maximumDurationDays * 24 * 60 * 60 * 1000;
    const requiredControlIds = Array.isArray(
      policy.compensatingControlRequirementIds,
    )
      ? policy.compensatingControlRequirementIds
      : [];
    const declaredControlIds = waiver.compensatingControls.map(
      ({ requirementId }) => requirementId,
    );
    const controlsValid =
      sameCanonicalJson(
        [...declaredControlIds].sort(),
        [...requiredControlIds].sort(),
      ) &&
      waiver.compensatingControls.every((control) => {
        const controlRequirement = requirements.find(
          (candidate) =>
            candidate.requirement.id === control.requirementId &&
            (candidate.scope.kind === "repository" ||
              (candidate.layerId === applicable.layerId &&
                sameCanonicalJson(candidate.scope, applicable.scope))),
        );
        return (
          controlRequirement !== undefined &&
          control.evidenceIds.some((evidenceId) => {
            const evidence = request.evidence.find(({ id }) => id === evidenceId);
            return (
              evidence !== undefined &&
              evidenceSatisfiesRequirement(
                controlRequirement,
                evidenceId,
                context,
              ) &&
              (waiver.version === 1 ||
                Date.parse(evidence.observedAt) >= startsAt)
            );
          })
        );
      });
    const lineageValid =
      waiver.version === 1
        ? waiver.supersedes === undefined && waiver.supersedesDigest === undefined
        : waiver.supersedes === `${waiver.id}@${waiver.version - 1}` &&
          waiver.supersedesDigest !== undefined &&
          waiver.supersedesDigest !== waiver.digest &&
          predecessor !== undefined;
    const predecessorEvidenceIds = new Set(
      predecessor?.compensatingControls.flatMap(({ evidenceIds }) => evidenceIds),
    );
    const renewalFresh =
      waiver.version === 1 ||
      (predecessor !== undefined &&
        startsAt > Date.parse(predecessor.riskReviewedAt) &&
        Date.parse(waiver.riskReviewedAt) >
          Date.parse(predecessor.riskReviewedAt) &&
        waiver.compensatingControls.every(({ evidenceIds }) =>
          evidenceIds.every((evidenceId) =>
            !predecessorEvidenceIds.has(evidenceId),
          ),
        ));
    const sameWaiverIdCount = request.waivers.filter(
      ({ id }) => id === waiver.id,
    ).length;
    const ruleRequirements = requirements.filter(
      (candidate) =>
        candidate.layerId === applicable.layerId &&
        candidate.ruleId === applicable.ruleId &&
        sameCanonicalJson(candidate.scope, applicable.scope),
    );
    const requirementIdsValid = waiver.requirementIds.every(
      (requirementId) =>
        ruleRequirements.some(
          (candidate) => candidate.requirement.id === requirementId,
        ),
    );
    const declaredSuppressions = applicable.entry.managedSuppressions.filter(
      ({ ruleId }) => ruleId === applicable.ruleId,
    );
    const suppressionIdsValid = waiver.managedSuppressionIds.every(
      (suppressionId) =>
        declaredSuppressions.some(({ id }) => id === suppressionId),
    );
    const suppressionProofsRemainRequired =
      declaredSuppressions
        .filter(({ id }) => waiver.managedSuppressionIds.includes(id))
        .every(
          ({ verificationRequirementId }) =>
            !waiver.requirementIds.includes(verificationRequirementId),
        );
    const authenticityValid = waiverRecordAuthentic(waiver, request);
    const manifestReferences = request.manifest.activeWaivers.filter(
      (reference) =>
        sameWaiverReference(
          waiverReference(reference.waiverId, reference.version),
          waiverDocumentReference(waiver),
        ),
    );
    const manifestReferenceValid =
      manifestReferences.length === 1 &&
      manifestReferences[0]!.digest === waiver.digest;
    const riskReviewedAt = Date.parse(waiver.riskReviewedAt);
    return (
      waiver.status === "active" &&
      lineageValid &&
      renewalFresh &&
      sameWaiverIdCount === 1 &&
      authenticityValid &&
      manifestReferenceValid &&
      waiver.layerId === applicable.layerId &&
      waiver.ruleId === applicable.ruleId &&
      waiver.requirementIds.includes(applicable.requirement.id) &&
      requirementIdsValid &&
      suppressionIdsValid &&
      suppressionProofsRemainRequired &&
      sameCanonicalJson(waiver.scope, applicable.scope) &&
      waiver.validity.repositoryStateDigest ===
        request.repository.stateDigest &&
      waiver.validity.configurationDigest === configurationDigest &&
      waiver.validity.catalogueDigest === release.document.catalogueDigest &&
      startsAt <= evaluatedAt &&
      expiresAt > evaluatedAt &&
      Number.isFinite(riskReviewedAt) &&
      riskReviewedAt >= startsAt &&
      riskReviewedAt <= evaluatedAt &&
      durationValid &&
      Array.isArray(policy.reasonClasses) &&
      policy.reasonClasses.includes(waiver.reasonClass) &&
      approvalResolvedAndIndependent &&
      controlsValid
    );
  });
}

function resolvedArtifactLocator(
  locatorTemplate: string,
  applicable: ApplicableRequirement,
  resolved: ResolvedBootstrapConfiguration,
): string | undefined {
  let locator = locatorTemplate;
  if (locator.includes("{workload.root}")) {
    if (applicable.scope.kind !== "workload") return undefined;
    const workload = resolved.configuration.workloads.find(
      ({ id }) => id === applicable.scope.id,
    );
    if (workload === undefined) return undefined;
    locator = locator.replaceAll("{workload.root}", workload.root);
  }
  return /\{[^}]+\}/u.test(locator) ? undefined : locator;
}

function evaluateManagedSuppressions(
  requirements: readonly ApplicableRequirement[],
  context: VerificationContext,
): readonly ManagedSuppressionEvaluation[] {
  const { request, resolved } = context;
  const evaluations: ManagedSuppressionEvaluation[] = [];
  const consumedSuppressionIndexes = new Set<number>();

  for (const waiver of request.waivers) {
    for (const suppressionId of waiver.managedSuppressionIds) {
      const applicable = requirements.find(
        (candidate) =>
          candidate.layerId === waiver.layerId &&
          candidate.ruleId === waiver.ruleId &&
          waiver.requirementIds.includes(candidate.requirement.id) &&
          sameCanonicalJson(candidate.scope, waiver.scope),
      );
      const declaration = applicable?.entry.managedSuppressions.find(
        ({ id }) => id === suppressionId,
      );
      const activeWaiver =
        applicable === undefined
          ? undefined
          : validWaiver(applicable, requirements, context);
      const matchingSuppressionIndexes = request.managedSuppressions.flatMap(
        (suppression, index) =>
          suppression.id === suppressionId &&
          sameWaiverReference(
            waiverReference(
              suppression.waiverId,
              suppression.waiverVersion,
            ),
            waiverDocumentReference(waiver),
          )
            ? [index]
            : [],
      );
      const suppression =
        matchingSuppressionIndexes.length === 1
          ? request.managedSuppressions[matchingSuppressionIndexes[0]!]
          : undefined;
      const base = {
        suppressionId,
        waiverId: waiver.id,
        waiverVersion: waiver.version,
        ruleId: waiver.ruleId,
        scope: waiver.scope,
      } as const;

      if (
        activeWaiver?.id !== waiver.id ||
        activeWaiver.version !== waiver.version ||
        declaration === undefined ||
        applicable === undefined
      ) {
        continue;
      }
      for (const index of matchingSuppressionIndexes) {
        consumedSuppressionIndexes.add(index);
      }
      if (suppression === undefined) {
        evaluations.push({
          ...base,
          evaluation: "incomplete",
          reason: "suppression-missing",
        });
        continue;
      }
      if (!sameCanonicalJson(suppression.scope, waiver.scope)) {
        evaluations.push({
          ...base,
          evaluation: "incomplete",
          reason: "suppression-scope-exceeded",
          artifact: suppression.artifact,
        });
        continue;
      }
      const artifact = applicable.entry.artifacts.find(
        ({ id }) => id === declaration.artifactId,
      );
      const expectedLocator =
        artifact === undefined
          ? undefined
          : resolvedArtifactLocator(artifact.locatorTemplate, applicable, resolved);
      if (
        artifact === undefined ||
        expectedLocator === undefined ||
        suppression.artifact.artifactId !== artifact.id ||
        suppression.artifact.ownerLayerId !== applicable.layerId ||
        suppression.artifact.locator !== expectedLocator ||
        suppression.artifact.ownership !== artifact.ownership ||
        suppression.artifact.verificationState !== "matching"
      ) {
        evaluations.push({
          ...base,
          evaluation: "incomplete",
          reason: "suppression-artifact-invalid",
          artifact: suppression.artifact,
        });
        continue;
      }
      const verificationRequirement = requirements.find(
        (candidate) =>
          candidate.layerId === applicable.layerId &&
          candidate.requirement.id === declaration.verificationRequirementId &&
          sameCanonicalJson(candidate.scope, applicable.scope),
      );
      const verificationEvidence = request.evidence.find(
        ({ id }) => id === suppression.verificationEvidenceId,
      );
      if (
        verificationRequirement === undefined ||
        verificationEvidence === undefined ||
        !verificationEvidence.artifactObservations.some(
          (observation) =>
            observation.artifactId === suppression.artifact.artifactId &&
            observation.ownerLayerId === suppression.artifact.ownerLayerId &&
            observation.locator === suppression.artifact.locator &&
            observation.fingerprint === suppression.artifact.fingerprint,
        ) ||
        !evidenceSatisfiesRequirement(
          verificationRequirement,
          suppression.verificationEvidenceId,
          context,
        )
      ) {
        evaluations.push({
          ...base,
          evaluation: "incomplete",
          reason: "suppression-evidence-invalid",
          artifact: suppression.artifact,
        });
        continue;
      }
      evaluations.push({
        ...base,
        evaluation: "active",
        reason: "active-waiver",
        artifact: suppression.artifact,
      });
    }
  }

  request.managedSuppressions.forEach((suppression, index) => {
    if (consumedSuppressionIndexes.has(index)) return;
    const waiver = request.waivers.find(
      ({ id, version }) =>
        sameWaiverReference(
          waiverReference(id, version),
          waiverReference(
            suppression.waiverId,
            suppression.waiverVersion,
          ),
        ),
    );
    evaluations.push({
      suppressionId: suppression.id,
      evaluation: "incomplete",
      reason: "suppression-unauthorized",
      waiverId: suppression.waiverId,
      waiverVersion: suppression.waiverVersion,
      ruleId: waiver?.ruleId ?? "unresolved",
      scope: suppression.scope,
      artifact: suppression.artifact,
    });
  });

  return evaluations;
}

type ManagedArtifactIdentity = Readonly<{
  artifactId: string;
  ownerLayerId: string;
  locator: string;
  ownership: ManagedSuppressionDocument["artifact"]["ownership"];
}>;

function expectedManagedArtifactIdentities(
  context: VerificationContext,
): readonly ManagedArtifactIdentity[] {
  const { configuration } = context.resolved;
  const selectedLayers = [
    {
      layerId: "core",
      family: "core" as const,
      kind: configuration.core.kind,
      workloadIds: [],
    },
    ...configuration.workloads.map((workload) => ({
      layerId: workload.id,
      family: "workload" as const,
      kind: workload.kind,
      workloadIds: [workload.id],
    })),
    ...configuration.capabilities.map((capability) => ({
      layerId: capability.id,
      family: "capability" as const,
      kind: capability.kind,
      workloadIds:
        capability.scope.kind === "repository"
          ? []
          : [...capability.scope.workloadIds],
    })),
  ];
  return selectedLayers.flatMap(({ layerId, family, kind, workloadIds }) => {
    const entry = [...context.release.entries.values()].find(
      (candidate) => candidate.family === family && candidate.kind === kind,
    );
    if (entry === undefined) return [];
    return entry.artifacts.flatMap((artifact) => {
      const locators = artifact.locatorTemplate.includes("{workload.root}")
        ? workloadIds.flatMap((workloadId) => {
            const workload = configuration.workloads.find(
              ({ id }) => id === workloadId,
            );
            return workload === undefined
              ? []
              : [
                  artifact.locatorTemplate.replaceAll(
                    "{workload.root}",
                    workload.root,
                  ),
                ];
          })
        : [artifact.locatorTemplate];
      return locators.map((locator) => ({
        artifactId: artifact.id,
        ownerLayerId: layerId,
        locator,
        ownership: artifact.ownership,
      }));
    });
  });
}

function manifestAgreesWithVerification(
  activeWaivers: readonly RuleWaiverDocument[],
  managedSuppressions: readonly ManagedSuppressionEvaluation[],
  context: VerificationContext,
): boolean {
  const { manifest } = context.request;
  const expectedEvidence = context.request.evidence.map((evidence) => ({
    evidenceId: evidence.id,
    digest: evidence.evidenceDigest,
    result: evidence.result,
    observedAt: evidence.observedAt,
    ...(evidence.validUntil === undefined
      ? {}
      : { validUntil: evidence.validUntil }),
    ...(evidence.output.immutableReference === undefined
      ? {}
      : { immutableReference: evidence.output.immutableReference }),
  }));
  const expectedWaivers = activeWaivers.map((waiver) => ({
    waiverId: waiver.id,
    version: waiver.version,
    digest: waiver.digest,
  }));
  const activeSuppressions = managedSuppressions.filter(
    (suppression) => suppression.evaluation === "active",
  );
  const expectedSuppressions = activeSuppressions.flatMap((suppression) =>
    suppression.artifact === undefined
      ? []
      : [
          {
            suppressionId: suppression.suppressionId,
            waiverId: suppression.waiverId,
            waiverVersion: suppression.waiverVersion,
            artifactId: suppression.artifact.artifactId,
            ownerLayerId: suppression.artifact.ownerLayerId,
            locator: suppression.artifact.locator,
            fingerprint: suppression.artifact.fingerprint,
          },
        ],
  );
  const expectedArtifactIdentities = expectedManagedArtifactIdentities(context);
  const declaredArtifactsValid =
    manifest.artifacts.length === expectedArtifactIdentities.length &&
    expectedArtifactIdentities.every(
      (expected) =>
        manifest.artifacts.filter(
          (artifact) =>
            artifact.artifactId === expected.artifactId &&
            artifact.ownerLayerId === expected.ownerLayerId &&
            artifact.locator === expected.locator &&
            artifact.ownership === expected.ownership &&
            artifact.verificationState === "matching",
        ).length === 1,
    );
  const activeSuppressionArtifactsValid = activeSuppressions.every(
    (suppression) =>
      suppression.artifact !== undefined &&
      manifest.artifacts.filter((artifact) =>
        sameCanonicalJson(artifact, suppression.artifact),
      ).length === 1,
  );
  const observedArtifacts = manifest.artifacts.filter(
    ({ artifactId }) =>
      artifactId !== "artifact/core/configuration" &&
      artifactId !== "artifact/core/project-delivery-contract",
  );
  const artifactObservations = context.request.evidence.flatMap(
    ({ artifactObservations: observations }) => observations,
  );
  const observedArtifactFingerprintsValid =
    artifactObservations.length === observedArtifacts.length &&
    observedArtifacts.every(
      (artifact) =>
        artifactObservations.filter(
          (observation) =>
            observation.artifactId === artifact.artifactId &&
            observation.ownerLayerId === artifact.ownerLayerId &&
            observation.locator === artifact.locator &&
            observation.fingerprint === artifact.fingerprint,
        ).length === 1,
    );
  const contractDeclaration = context.release.entries
    .get("entry/core/core")
    ?.artifacts.find(
      ({ id }) => id === "artifact/core/project-delivery-contract",
    );
  const projectDeliveryContractValid =
    contractDeclaration !== undefined &&
    context.request.projectDeliveryContract.artifactId ===
      contractDeclaration.id &&
    context.request.projectDeliveryContract.ownerLayerId === "core" &&
    context.request.projectDeliveryContract.locator ===
      contractDeclaration.locatorTemplate &&
    context.request.projectDeliveryContract.ownership ===
      contractDeclaration.ownership &&
    context.request.projectDeliveryContract.verificationState === "matching" &&
    manifest.artifacts.filter((artifact) =>
      sameCanonicalJson(artifact, context.request.projectDeliveryContract),
    ).length === 1;
  const configurationArtifactValid = manifest.artifacts.some(
    (artifact) =>
      artifact.artifactId === "artifact/core/configuration" &&
      artifact.ownerLayerId === "core" &&
      artifact.fingerprint === context.configurationDigest,
  );
  const sortByIdentity = <T>(
    values: readonly T[],
    identity: (value: T) => string,
  ): readonly T[] => [...values].sort((left, right) =>
    identity(left).localeCompare(identity(right)),
  );

  return (
    manifest.configurationDigest === context.configurationDigest &&
    manifest.catalogueVersion === context.release.document.catalogueVersion &&
    manifest.catalogueDigest === context.release.document.catalogueDigest &&
    manifest.bootstrapperVersion === context.request.bootstrapper.version &&
    manifest.bootstrapperDigest === context.request.bootstrapper.digest &&
    sameCanonicalJson(manifest.schemaDigests, context.request.schemaDigests) &&
    sameCanonicalJson(
      sortByIdentity(manifest.evidence, ({ evidenceId }) => evidenceId),
      sortByIdentity(expectedEvidence, ({ evidenceId }) => evidenceId),
    ) &&
    sameCanonicalJson(
      sortByIdentity(
        manifest.activeWaivers,
        ({ waiverId, version }) => `${waiverId}@${version}`,
      ),
      sortByIdentity(
        expectedWaivers,
        ({ waiverId, version }) => `${waiverId}@${version}`,
      ),
    ) &&
    sameCanonicalJson(
      sortByIdentity(
        manifest.managedSuppressions,
        ({ suppressionId, waiverId, waiverVersion }) =>
          `${suppressionId}:${waiverId}@${waiverVersion}`,
      ),
      sortByIdentity(
        expectedSuppressions,
        ({ suppressionId, waiverId, waiverVersion }) =>
          `${suppressionId}:${waiverId}@${waiverVersion}`,
      ),
    ) &&
    projectDeliveryContractValid &&
    configurationArtifactValid &&
    declaredArtifactsValid &&
    observedArtifactFingerprintsValid &&
    activeSuppressionArtifactsValid
  );
}

function evidenceOutcome(
  applicable: ApplicableRequirement,
  evidence: VerificationEvidenceDocument,
): RequirementEvaluationResult {
  if (applicable.requirement.kind === "manual-state" && evidence.result === "error") {
    return baseEvaluation(
      applicable,
      "incomplete",
      "manual-state-error",
      evidence.id,
    );
  }
  const outcomes: Readonly<
    Record<
      VerificationEvidenceDocument["result"],
      readonly [RequirementEvaluation, VerificationReason]
    >
  > = {
    passed: ["satisfied", "deterministic-check-passed"],
    failed: ["failed", "deterministic-check-failed"],
    error: ["incomplete", "deterministic-check-error"],
    accepted: ["satisfied", "review-accepted"],
    "changes-required": ["failed", "review-changes-required"],
    "unable-to-conclude": ["incomplete", "review-unable-to-conclude"],
    verified: ["satisfied", "manual-state-verified"],
    "not-verified": ["failed", "manual-state-not-verified"],
    attested: ["satisfied", "manual-state-attested"],
  };
  const [evaluation, reason] = outcomes[evidence.result];
  return baseEvaluation(applicable, evaluation, reason, evidence.id);
}

export function reduceVerificationRequirements(
  release: ValidatedCatalogueRelease,
  resolved: ResolvedBootstrapConfiguration,
  request: VerificationRequest,
): VerificationResult {
  const configurationDigest = canonicalJsonDigest(resolved.configuration);
  if (configurationDigest === undefined) {
    throw new TypeError("Resolved Bootstrap Configuration is not canonical JSON");
  }
  const context: VerificationContext = {
    release,
    resolved,
    request,
    configurationDigest,
  };
  const requirements = applicableRequirements(release, resolved);
  const affectedRequirementsValid = request.affectedRequirements.every(
    ({ requirementId, scope }) =>
      requirements.filter(
        (applicable) =>
          applicable.requirement.phase === "delivery" &&
          applicable.requirement.id === requirementId &&
          sameCanonicalJson(applicable.scope, scope),
      ).length === 1,
  );
  const evaluations = requirements.map((applicable) => {
    const waiver = validWaiver(
      applicable,
      requirements,
      context,
    );
    if (
      request.horizon === "baseline" &&
      applicable.requirement.phase === "delivery"
    ) {
      return waiver === undefined
        ? undefined
        : baseEvaluation(
            applicable,
            "waived",
            "active-waiver",
            undefined,
            waiverDocumentReference(waiver),
          );
    }
    const affectedCount = request.affectedRequirements.filter(
      ({ requirementId, scope }) =>
        requirementId === applicable.requirement.id &&
        sameCanonicalJson(scope, applicable.scope),
    ).length;
    if (
      request.horizon === "delivery" &&
      applicable.requirement.phase === "delivery"
    ) {
      if (affectedCount === 0) return undefined;
      if (affectedCount !== 1) {
        return baseEvaluation(
          applicable,
          "incomplete",
          "evidence-invalid",
        );
      }
    }
    if (waiver !== undefined) {
      return baseEvaluation(
        applicable,
        "waived",
        "active-waiver",
        undefined,
        waiverDocumentReference(waiver),
      );
    }
    const matchingEvidence = request.evidence.filter(
      (evidence) =>
        evidence.requirementId === applicable.requirement.id &&
        sameCanonicalJson(evidence.scope, applicable.scope),
    );
    if (matchingEvidence.length === 0) {
      return baseEvaluation(
        applicable,
        "incomplete",
        "evidence-missing",
      );
    }
    if (matchingEvidence.length !== 1) {
      return baseEvaluation(
        applicable,
        "incomplete",
        "evidence-invalid",
      );
    }
    const evidence = matchingEvidence[0]!;
    const bindingReason = evidenceBindingReason(
      evidence,
      applicable,
      context,
    );
    if (bindingReason !== undefined) {
      return baseEvaluation(
        applicable,
        "incomplete",
        bindingReason,
        evidence.id,
      );
    }
    const actorReason = authorityReason(
      applicable,
      evidence,
      context,
    );
    if (actorReason !== undefined) {
      return baseEvaluation(
        applicable,
        "incomplete",
        actorReason,
        evidence.id,
      );
    }
    return evidenceOutcome(applicable, evidence);
  });
  for (const [index, applicable] of requirements.entries()) {
    if (
      evaluations[index] !== undefined ||
      request.horizon !== "baseline" ||
      applicable.requirement.phase !== "delivery"
    ) {
      continue;
    }
    const gate = evaluations.find(
      (evaluation) =>
        evaluation?.layerId === applicable.layerId &&
        evaluation.requirementId ===
          applicable.requirement.baselineGateRequirementId &&
        sameCanonicalJson(evaluation.scope, applicable.scope),
    );
    evaluations[index] =
      gate?.evaluation === "satisfied"
        ? baseEvaluation(
            applicable,
            "satisfied",
            "delivery-gate-satisfied",
            gate.evidenceId,
            gate.waiver,
          )
        : gate?.evaluation === "waived"
          ? baseEvaluation(
              applicable,
              "incomplete",
              "delivery-gate-unsatisfied",
            )
        : baseEvaluation(
            applicable,
            gate?.evaluation === "failed" ? "failed" : "incomplete",
            gate?.reason ?? "evidence-missing",
            gate?.evidenceId,
            gate?.waiver,
          );
  }
  const completeEvaluations = evaluations.filter(
    (evaluation): evaluation is RequirementEvaluationResult =>
      evaluation !== undefined,
  );
  const consumedEvidenceIds = new Set(
    completeEvaluations.flatMap(({ evidenceId }) =>
      evidenceId === undefined ? [] : [evidenceId],
    ),
  );
  const evidenceIds = request.evidence.map(({ id }) => id);
  const evidenceIdsUnique = new Set(evidenceIds).size === evidenceIds.length;
  const allEvidenceConsumed = request.evidence.every(({ id }) =>
    consumedEvidenceIds.has(id),
  );
  const consumedWaiverReferences = completeEvaluations.flatMap(
    ({ waiver }) => (waiver === undefined ? [] : [waiver]),
  );
  const waiverDocumentIds = request.waivers.map(({ id }) => id);
  const waiverIdsUnique =
    new Set(waiverDocumentIds).size === waiverDocumentIds.length;
  const evaluatedAt = Date.parse(request.evaluatedAt);
  const activeWaiverReferences = request.waivers.flatMap((waiver) =>
    waiver.status === "active" &&
    Date.parse(waiver.validity.startsAt) <= evaluatedAt &&
    Date.parse(waiver.validity.expiresAt) > evaluatedAt
      ? [waiverDocumentReference(waiver)]
      : [],
  );
  const allActiveWaiversConsumed = activeWaiverReferences.every((reference) =>
    consumedWaiverReferences.some((consumed) =>
      sameWaiverReference(consumed, reference),
    ),
  );
  const managedSuppressions = evaluateManagedSuppressions(
    requirements,
    context,
  );
  const visibleActiveWaiverDocuments = request.waivers.filter((waiver) =>
    consumedWaiverReferences.some((reference) =>
      sameWaiverReference(reference, waiverDocumentReference(waiver)),
    ),
  );
  const expectedAuthenticityCount = request.waivers.reduce(
    (count, waiver) => count + (waiver.version === 1 ? 1 : 2),
    0,
  );
  const allWaiverRecordsAuthentic =
    request.waiverAuthenticity.length === expectedAuthenticityCount &&
    request.waiverHistory.length ===
      request.waivers.filter(({ version }) => version > 1).length &&
    request.waivers.every(
      (waiver) =>
        waiverRecordAuthentic(waiver, request) &&
        (waiver.version === 1 ||
          authenticPredecessorRecord(waiver, request) !== undefined),
    );
  const manifestValid = manifestAgreesWithVerification(
    visibleActiveWaiverDocuments,
    managedSuppressions,
    context,
  );

  const failedBlocker = request.blockers.some(
    ({ kind }) => kind !== "missing-authority",
  );
  const outcome: VerificationOutcome =
    completeEvaluations.some(({ evaluation }) => evaluation === "failed") ||
    failedBlocker
      ? "failed"
      : completeEvaluations.some(
            ({ evaluation }) => evaluation === "incomplete",
          ) ||
          request.blockers.length > 0 ||
          !affectedRequirementsValid ||
          !evidenceIdsUnique ||
          !allEvidenceConsumed ||
          !waiverIdsUnique ||
          !allActiveWaiversConsumed ||
          !allWaiverRecordsAuthentic ||
          !manifestValid ||
          managedSuppressions.some(
            ({ evaluation }) => evaluation === "incomplete",
          )
        ? "incomplete"
        : "verified";

  const visibleActiveWaivers = visibleActiveWaiverDocuments.map((waiver) => ({
    waiverId: waiver.id,
    version: waiver.version,
    digest: waiver.digest,
    ruleId: waiver.ruleId,
    scope: waiver.scope,
    requirementIds: waiver.requirementIds,
    compensatingControlRequirementIds: waiver.compensatingControls.map(
      ({ requirementId }) => requirementId,
    ),
    managedSuppressionIds: waiver.managedSuppressionIds,
    risk: waiver.risk,
    remediation: waiver.remediation,
    expiresAt: waiver.validity.expiresAt,
  }));

  return {
    schemaVersion: "1.0.0",
    outcome,
    horizon: request.horizon,
    requirements: completeEvaluations,
    blockers: request.blockers,
    waivers: visibleActiveWaivers,
    managedSuppressions,
  };
}
