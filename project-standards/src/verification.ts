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
  readonly ruleId: string;
  readonly scope: VerificationScope;
  readonly requirementIds: readonly string[];
  readonly reasonClass: string;
  readonly reasonEvidence: readonly string[];
  readonly risk: string;
  readonly compensatingControls: readonly Readonly<{
    requirementId: string;
    evidenceIds: readonly string[];
  }>[];
  readonly requester: EvidenceActor;
  readonly approvals: readonly EvidenceActor[];
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
  readonly waiverId?: string;
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
    requirementId: string;
    scope: VerificationScope;
    expiresAt: string;
  }>[];
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
  waiverId?: string,
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
    ...(waiverId === undefined ? {} : { waiverId }),
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
    const approval = waiver.approvals.find(
      (actor) => actor.authorityClass === approvalAuthority,
    );
    const approvalResolved =
      approval !== undefined &&
      actorSatisfiesAuthority(
        approval,
        approvalAuthority,
        context,
      );
    const independent =
      policy.independence === "none" ||
      (approval !== undefined &&
        approval.identity !== waiver.requester.identity &&
        (policy.independence !== "separate-authority" ||
          approval.authorityClass !== waiver.requester.authorityClass));
    const startsAt = Date.parse(waiver.validity.startsAt);
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
          control.evidenceIds.some((evidenceId) =>
            evidenceSatisfiesRequirement(
              controlRequirement,
              evidenceId,
              context,
            ),
          )
        );
      });
    return (
      waiver.status === "active" &&
      waiver.version === 1 &&
      waiver.supersedes === undefined &&
      waiver.ruleId === applicable.ruleId &&
      waiver.requirementIds.includes(applicable.requirement.id) &&
      sameCanonicalJson(waiver.scope, applicable.scope) &&
      waiver.validity.repositoryStateDigest ===
        request.repository.stateDigest &&
      waiver.validity.configurationDigest === configurationDigest &&
      waiver.validity.catalogueDigest === release.document.catalogueDigest &&
      startsAt <= evaluatedAt &&
      expiresAt > evaluatedAt &&
      durationValid &&
      Array.isArray(policy.reasonClasses) &&
      policy.reasonClasses.includes(waiver.reasonClass) &&
      approvalResolved &&
      independent &&
      controlsValid &&
      waiver.digest ===
        contentDigest(
          waiver as unknown as Readonly<Record<string, unknown>>,
          "digest",
        )
    );
  });
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
            `${waiver.id}@${waiver.version}`,
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
        `${waiver.id}@${waiver.version}`,
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
            gate.waiverId,
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
            gate?.waiverId,
          );
  }
  const completeEvaluations = evaluations.filter(
    (evaluation): evaluation is RequirementEvaluationResult =>
      evaluation !== undefined,
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
          !affectedRequirementsValid
        ? "incomplete"
        : "verified";

  return {
    schemaVersion: "1.0.0",
    outcome,
    horizon: request.horizon,
    requirements: completeEvaluations,
    blockers: request.blockers,
    waivers: request.waivers.flatMap((waiver) =>
      completeEvaluations.flatMap((evaluation) =>
        evaluation.waiverId === `${waiver.id}@${waiver.version}`
          ? [
              {
                waiverId: waiver.id,
                version: waiver.version,
                requirementId: evaluation.requirementId,
                scope: evaluation.scope,
                expiresAt: waiver.validity.expiresAt,
              },
            ]
          : [],
      ),
    ),
  };
}
