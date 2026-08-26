import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { createReadStream, type Stats } from "node:fs";
import {
  lstat,
  readFile,
  readdir,
  readlink,
  realpath,
} from "node:fs/promises";
import { isAbsolute, join, relative, resolve } from "node:path";
import { promisify } from "node:util";
import { pipeline } from "node:stream/promises";

const execFileAsync = promisify(execFile);

export type RepositoryInspectionErrorCode =
  | "git-inspection-failed"
  | "inspection-failed"
  | "repository-drift"
  | "root-missing"
  | "root-not-directory"
  | "root-symlink";

export class RepositoryInspectionError extends Error {
  readonly code: RepositoryInspectionErrorCode;
  readonly path: string;

  constructor(
    code: RepositoryInspectionErrorCode,
    path: string,
    message: string,
    options?: ErrorOptions,
  ) {
    super(message, options);
    this.name = "RepositoryInspectionError";
    this.code = code;
    this.path = path;
  }
}

export type RepositoryHazardCode =
  | "case-collision"
  | "filesystem-boundary"
  | "external-git-directory"
  | "nested-repository"
  | "normalization-ambiguity"
  | "parent-git-repository"
  | "special-file"
  | "submodule"
  | "symbolic-link"
  | "worktree";

export type RepositoryHazard = Readonly<{
  code: RepositoryHazardCode;
  path: string;
  evidence: string;
}>;

export type RepositoryEntry =
  | Readonly<{
      path: string;
      kind: "regular-file";
      size: number;
      fingerprint: string;
    }>
  | Readonly<{
      path: string;
      kind: "symbolic-link";
      fingerprint: string;
    }>
  | Readonly<{
      path: string;
      kind: "directory";
      empty: boolean;
      fingerprint: string;
    }>
  | Readonly<{
      path: string;
      kind: "special-file";
      specialKind:
        | "fifo"
        | "socket"
        | "block-device"
        | "character-device"
        | "unknown";
      fingerprint: string;
    }>;

export type GitBoundary = Readonly<{
  kind:
    | "external-git-directory"
    | "nested-repository"
    | "submodule"
    | "worktree";
  path: string;
  gitMetadataKind: "directory" | "file" | "index";
}>;

export type GitPathState =
  | "unchanged"
  | "modified"
  | "added"
  | "deleted"
  | "renamed"
  | "copied"
  | "unmerged"
  | "untracked"
  | "type-changed";

export type GitDirtyPath = Readonly<{
  path: string;
  indexState: GitPathState;
  worktreeState: GitPathState;
  originalPath?: string;
}>;

export type RunModeRecommendationEvidence =
  | "dirty-git-state"
  | "empty-git-root"
  | "empty-initial-commit"
  | "external-git-directory-boundary"
  | "git-initialization-requires-confirmation"
  | "ignorable-content-preserved"
  | "no-substantive-content"
  | "non-empty-git-history"
  | "parent-git-repository"
  | "repository-hazards"
  | "submodule-boundary"
  | "substantive-content"
  | "tracked-content"
  | "worktree-boundary";

export interface DetectedRepositoryState {
  readonly schemaVersion: "1.0.0";
  readonly kind: "detected-repository-state";
  readonly root: Readonly<{
    selectedPath: string;
    realPath: string;
    device: string;
    inode: string;
    fingerprint: string;
  }>;
  readonly filesystem: Readonly<{
    entryCount: number;
    substantivePaths: readonly string[];
    ignorablePaths: readonly string[];
    emptyDirectoryPaths: readonly string[];
    entries: readonly RepositoryEntry[];
  }>;
  readonly git:
    | Readonly<{
        relationship: "none";
        hasCommits: false;
        headCommit: null;
        headTree: null;
        indexFingerprint: null;
        gitDirectoryFingerprint: null;
        commitCount: 0;
        headTreePathCount: 0;
        trackedPathCount: 0;
        boundaries: readonly GitBoundary[];
        dirtyPaths: readonly GitDirtyPath[];
      }>
    | Readonly<{
        relationship:
          | "external-git-directory"
          | "parent-repository"
          | "repository-root"
          | "worktree"
          | "submodule";
        root: string;
        hasCommits: boolean;
        headCommit: string | null;
        headTree: string | null;
        indexFingerprint: string;
        gitDirectoryFingerprint: string;
        commitCount: number;
        headTreePathCount: number;
        trackedPathCount: number;
        boundaries: readonly GitBoundary[];
        dirtyPaths: readonly GitDirtyPath[];
      }>;
  readonly hazards: readonly RepositoryHazard[];
  readonly recommendation: Readonly<{
    mode: "initialize" | "adopt";
    initializeEligible: boolean;
    evidence: readonly RunModeRecommendationEvidence[];
  }>;
  readonly stateFingerprint: string;
}

function digest(value: unknown): string {
  return `sha256:${createHash("sha256").update(JSON.stringify(value)).digest("hex")}`;
}

async function gitOutput(root: string, arguments_: readonly string[]): Promise<string> {
  const { stdout } = await execFileAsync("git", ["-C", root, ...arguments_], {
    encoding: "utf8",
    env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" },
  });
  return stdout;
}

async function optionalGitOutput(
  root: string,
  arguments_: readonly string[],
): Promise<string | undefined> {
  try {
    return await gitOutput(root, arguments_);
  } catch (error) {
    if (
      error instanceof Error &&
      "code" in error &&
      error.code === 1
    ) {
      return undefined;
    }
    throw error;
  }
}

function isNotGitRepositoryError(error: unknown): boolean {
  if (!(error instanceof Error) || !("stderr" in error)) return false;
  const stderr = error.stderr;
  return (
    typeof stderr === "string" &&
    (stderr.includes("not a git repository") ||
      stderr.includes("must be run in a work tree"))
  );
}

function gitPathState(status: string): GitPathState {
  const states: Readonly<Record<string, GitPathState>> = {
    " ": "unchanged",
    M: "modified",
    A: "added",
    D: "deleted",
    R: "renamed",
    C: "copied",
    U: "unmerged",
    "?": "untracked",
    T: "type-changed",
    m: "modified",
  };
  const state = states[status];
  if (state === undefined) {
    throw new Error(`Unsupported Git status code ${JSON.stringify(status)}`);
  }
  return state;
}

function parseGitStatus(output: string): GitDirtyPath[] {
  const records = output.split("\0");
  const dirtyPaths: GitDirtyPath[] = [];
  for (let index = 0; index < records.length; index += 1) {
    const record = records[index];
    if (record === undefined || record.length === 0) continue;
    const indexCode = record[0];
    const worktreeCode = record[1];
    if (indexCode === undefined || worktreeCode === undefined || record[2] !== " ") {
      throw new Error(`Malformed Git status record ${JSON.stringify(record)}`);
    }
    const path = record.slice(3);
    const hasOriginalPath = indexCode === "R" || indexCode === "C";
    const originalPath = hasOriginalPath ? records[index + 1] : undefined;
    if (hasOriginalPath) index += 1;
    dirtyPaths.push({
      path,
      indexState: gitPathState(indexCode),
      worktreeState: gitPathState(worktreeCode),
      ...(originalPath === undefined ? {} : { originalPath }),
    });
  }
  dirtyPaths.sort(comparePath);
  return dirtyPaths;
}

type GitIndexEntry = Readonly<{
  mode: string;
  objectId: string;
  stage: number;
  path: string;
}>;

function parseGitIndex(output: string): GitIndexEntry[] {
  return output
    .split("\0")
    .filter(Boolean)
    .map((record) => {
      const match = /^(\d{6}) ([a-f0-9]+) ([0-3])\t([\s\S]+)$/.exec(record);
      if (match === null) {
        throw new Error(`Malformed Git index record ${JSON.stringify(record)}`);
      }
      const [, mode, objectId, stage, path] = match;
      if (
        mode === undefined ||
        objectId === undefined ||
        stage === undefined ||
        path === undefined
      ) {
        throw new Error(`Incomplete Git index record ${JSON.stringify(record)}`);
      }
      return { mode, objectId, stage: Number.parseInt(stage, 10), path };
    });
}

function rebaseGitPaths(
  paths: readonly GitDirtyPath[],
  gitRoot: string,
  selectedRoot: string,
): GitDirtyPath[] {
  return paths.map((dirtyPath) => ({
    ...dirtyPath,
    path: rebaseGitPath(dirtyPath.path, gitRoot, selectedRoot),
    ...(dirtyPath.originalPath === undefined
      ? {}
      : {
          originalPath: rebaseGitPath(
            dirtyPath.originalPath,
            gitRoot,
            selectedRoot,
          ),
        }),
  }));
}

function rebaseGitPath(path: string, gitRoot: string, selectedRoot: string): string {
  const prefix = relative(gitRoot, selectedRoot);
  if (prefix.length === 0) return path;
  const prefixWithSeparator = `${prefix}/`;
  return path.startsWith(prefixWithSeparator)
    ? path.slice(prefixWithSeparator.length)
    : path;
}

function collisionHazards(paths: readonly string[]): RepositoryHazard[] {
  const uniquePaths = [...new Set(paths)];
  const normalizationGroups = new Map<string, string[]>();
  const caseGroups = new Map<string, string[]>();
  for (const path of uniquePaths) {
    const normalized = path.normalize("NFC");
    normalizationGroups.set(normalized, [
      ...(normalizationGroups.get(normalized) ?? []),
      path,
    ]);
    const caseKey = normalized.toLocaleLowerCase("en-US");
    caseGroups.set(caseKey, [...(caseGroups.get(caseKey) ?? []), path]);
  }

  const hazards: RepositoryHazard[] = [];
  for (const pathsInGroup of normalizationGroups.values()) {
    if (new Set(pathsInGroup).size < 2) continue;
    hazards.push({
      code: "normalization-ambiguity",
      path: [...pathsInGroup].sort().join(" | "),
      evidence: "Paths normalize to the same Unicode NFC form",
    });
  }
  for (const pathsInGroup of caseGroups.values()) {
    const normalizedPaths = new Set(
      pathsInGroup.map((path) => path.normalize("NFC")),
    );
    if (normalizedPaths.size < 2) continue;
    hazards.push({
      code: "case-collision",
      path: [...pathsInGroup].sort().join(" | "),
      evidence: "Paths differ only by case after Unicode normalization",
    });
  }
  return hazards;
}

function assertStableMetadata(
  before: Stats,
  after: Stats,
  path: string,
  includeSize = false,
): void {
  if (
    before.dev !== after.dev ||
    before.ino !== after.ino ||
    before.mode !== after.mode ||
    before.mtimeMs !== after.mtimeMs ||
    (includeSize && before.size !== after.size)
  ) {
    throw new RepositoryInspectionError(
      "repository-drift",
      path,
      `Repository state drifted while inspecting ${path}`,
    );
  }
}

async function inspectRegularFile(
  root: string,
  path: string,
): Promise<RepositoryEntry> {
  const absolutePath = join(root, path);
  const before = await lstat(absolutePath);
  if (!before.isFile()) {
    throw new RepositoryInspectionError(
      "repository-drift",
      path,
      `Repository state drifted while inspecting ${path}`,
    );
  }
  const hash = createHash("sha256");
  await pipeline(createReadStream(absolutePath), hash);
  const after = await lstat(absolutePath);
  assertStableMetadata(before, after, path, true);
  return {
    path,
    kind: "regular-file",
    size: after.size,
    fingerprint: `sha256:${hash.digest("hex")}`,
  };
}

async function inspectSymbolicLink(
  root: string,
  path: string,
): Promise<RepositoryEntry> {
  const absolutePath = join(root, path);
  const before = await lstat(absolutePath);
  if (!before.isSymbolicLink()) {
    throw new RepositoryInspectionError(
      "repository-drift",
      path,
      `Repository state drifted while inspecting ${path}`,
    );
  }
  const target = await readlink(absolutePath);
  const after = await lstat(absolutePath);
  assertStableMetadata(before, after, path);
  return {
    path,
    kind: "symbolic-link",
    fingerprint: `sha256:${createHash("sha256").update(target).digest("hex")}`,
  };
}

type FilesystemScan = {
  entries: RepositoryEntry[];
  substantivePaths: string[];
  ignorablePaths: string[];
  emptyDirectoryPaths: string[];
  hazards: RepositoryHazard[];
  gitBoundaries: GitBoundary[];
};

function comparePath(
  left: Readonly<{ path: string }>,
  right: Readonly<{ path: string }>,
): number {
  return left.path < right.path ? -1 : left.path > right.path ? 1 : 0;
}

async function gitMetadataBoundary(
  directory: string,
): Promise<
  | Readonly<{
      kind: GitBoundary["kind"];
      metadataKind: GitBoundary["gitMetadataKind"];
    }>
  | undefined
> {
  try {
    const metadata = await lstat(join(directory, ".git"));
    if (metadata.isDirectory()) {
      return { kind: "nested-repository", metadataKind: "directory" };
    }
    if (metadata.isFile()) {
      const contents = await readFile(join(directory, ".git"), "utf8");
      const match = /^gitdir: (.+)$/m.exec(contents);
      if (match?.[1] === undefined) {
        return { kind: "external-git-directory", metadataKind: "file" };
      }
      try {
        const superprojectRoot = (
          await gitOutput(directory, [
            "rev-parse",
            "--show-superproject-working-tree",
          ])
        ).trim();
        if (superprojectRoot.length > 0) {
          return { kind: "submodule", metadataKind: "file" };
        }
        const gitDirectory = await realpath(
          (await gitOutput(directory, ["rev-parse", "--absolute-git-dir"])).trim(),
        );
        const commonDirectoryOutput = (
          await gitOutput(directory, ["rev-parse", "--git-common-dir"])
        ).trim();
        const commonDirectory = await realpath(
          isAbsolute(commonDirectoryOutput)
            ? commonDirectoryOutput
            : resolve(directory, commonDirectoryOutput),
        );
        if (gitDirectory !== commonDirectory) {
          return { kind: "worktree", metadataKind: "file" };
        }
      } catch {
        return { kind: "external-git-directory", metadataKind: "file" };
      }
      return { kind: "external-git-directory", metadataKind: "file" };
    }
    return undefined;
  } catch (error) {
    if (
      error instanceof Error &&
      "code" in error &&
      error.code === "ENOENT"
    ) {
      return undefined;
    }
    throw error;
  }
}

function isIgnorableInitializationPath(path: string): boolean {
  const parts = path.split("/");
  const name = parts.at(-1) ?? path;
  if (
    name === ".gitkeep" ||
    name === ".keep" ||
    name === ".DS_Store" ||
    name === "Thumbs.db" ||
    name === "desktop.ini"
  ) {
    return true;
  }
  return [".idea", ".vscode", ".zed"].includes(parts[0] ?? "");
}

function recommendRunMode(
  scan: FilesystemScan,
  git: DetectedRepositoryState["git"],
  selectedTrackedPaths: readonly string[],
): DetectedRepositoryState["recommendation"] {
  const substantiveDirtyPaths = git.dirtyPaths.filter(
    ({ path }) => !isIgnorableInitializationPath(path),
  );
  const substantiveTrackedPaths = selectedTrackedPaths.filter(
    (path) => !isIgnorableInitializationPath(path),
  );
  const eligibleGitHistory =
    git.relationship === "none" ||
    git.commitCount === 0 ||
    (git.commitCount === 1 && git.headTreePathCount === 0);
  const eligibleGitRelationship =
    git.relationship === "none" || git.relationship === "repository-root";
  const initializeEligible =
    scan.substantivePaths.length === 0 &&
    substantiveDirtyPaths.length === 0 &&
    substantiveTrackedPaths.length === 0 &&
    eligibleGitHistory &&
    eligibleGitRelationship &&
    scan.hazards.length === 0;

  if (initializeEligible) {
    const evidence: RunModeRecommendationEvidence[] = [
      git.relationship === "none"
        ? "git-initialization-requires-confirmation"
        : git.hasCommits
          ? "empty-initial-commit"
          : "empty-git-root",
    ];
    if (scan.ignorablePaths.length > 0) {
      evidence.push("ignorable-content-preserved");
    }
    evidence.push("no-substantive-content");
    return {
      mode: "initialize",
      initializeEligible: true,
      evidence,
    };
  }

  let evidence: RunModeRecommendationEvidence;
  if (git.relationship === "parent-repository") {
    evidence = "parent-git-repository";
  } else if (git.relationship === "external-git-directory") {
    evidence = "external-git-directory-boundary";
  } else if (
    git.relationship === "worktree" ||
    git.relationship === "submodule"
  ) {
    evidence = `${git.relationship}-boundary`;
  } else {
    const evidenceSet: RunModeRecommendationEvidence[] = [];
    if (scan.substantivePaths.length > 0) {
      evidenceSet.push("substantive-content");
    }
    if (substantiveDirtyPaths.length > 0) {
      evidenceSet.push("dirty-git-state");
    }
    if (substantiveTrackedPaths.length > 0) {
      evidenceSet.push("tracked-content");
    }
    if (!eligibleGitHistory) {
      evidenceSet.push("non-empty-git-history");
    }
    if (scan.hazards.length > 0) {
      evidenceSet.push("repository-hazards");
    }
    evidence = evidenceSet[0] ?? "repository-hazards";
    return {
      mode: "adopt",
      initializeEligible: false,
      evidence: evidenceSet.length > 0 ? evidenceSet : [evidence],
    };
  }
  return {
    mode: "adopt",
    initializeEligible: false,
    evidence: [evidence],
  };
}

async function scanFilesystem(
  root: string,
  directory: string,
  rootDevice: number,
  scan: FilesystemScan,
): Promise<void> {
  const directoryBefore = await lstat(directory);
  const directoryEntries = await readdir(directory, { withFileTypes: true });
  directoryEntries.sort((left, right) =>
    left.name < right.name ? -1 : left.name > right.name ? 1 : 0,
  );

  for (const entry of directoryEntries) {
    if (directory === root && entry.name === ".git") continue;
    const absolutePath = join(directory, entry.name);
    const repositoryPath = relative(root, absolutePath);
    const metadata = await lstat(absolutePath);

    if (metadata.isSymbolicLink()) {
      const inspected = await inspectSymbolicLink(root, repositoryPath);
      scan.entries.push(inspected);
      scan.substantivePaths.push(repositoryPath);
      scan.hazards.push({
        code: "symbolic-link",
        path: repositoryPath,
        evidence: "Symlink target was fingerprinted but not followed",
      });
      continue;
    }

    if (metadata.isDirectory()) {
      const directoryFingerprint = digest({
        kind: "directory",
        path: repositoryPath,
        device: String(metadata.dev),
        inode: String(metadata.ino),
        mode: metadata.mode,
      });
      if (metadata.dev !== rootDevice) {
        scan.entries.push({
          path: repositoryPath,
          kind: "directory",
          empty: false,
          fingerprint: directoryFingerprint,
        });
        scan.substantivePaths.push(repositoryPath);
        scan.hazards.push({
          code: "filesystem-boundary",
          path: repositoryPath,
          evidence: "Directory is on a different filesystem and was not traversed",
        });
        continue;
      }

      const gitBoundary = await gitMetadataBoundary(absolutePath);
      if (gitBoundary !== undefined) {
        scan.entries.push({
          path: repositoryPath,
          kind: "directory",
          empty: false,
          fingerprint: directoryFingerprint,
        });
        scan.substantivePaths.push(repositoryPath);
        scan.gitBoundaries.push({
          kind: gitBoundary.kind,
          path: repositoryPath,
          gitMetadataKind: gitBoundary.metadataKind,
        });
        scan.hazards.push({
          code: gitBoundary.kind,
          path: repositoryPath,
          evidence:
            gitBoundary.kind === "worktree"
              ? "Git worktree metadata defines a separate ownership boundary"
              : gitBoundary.kind === "submodule"
                ? "Git submodule metadata defines a separate ownership boundary"
                : gitBoundary.kind === "external-git-directory"
                  ? "External Git metadata defines a separate ownership boundary"
                : "Nested Git metadata defines a separate ownership boundary",
        });
        continue;
      }

      const entryCountBefore = scan.entries.length;
      await scanFilesystem(root, absolutePath, rootDevice, scan);
      const empty = scan.entries.length === entryCountBefore;
      scan.entries.push({
        path: repositoryPath,
        kind: "directory",
        empty,
        fingerprint: directoryFingerprint,
      });
      if (empty) scan.emptyDirectoryPaths.push(repositoryPath);
      continue;
    }

    if (metadata.isFile()) {
      scan.entries.push(await inspectRegularFile(root, repositoryPath));
      if (isIgnorableInitializationPath(repositoryPath)) {
        scan.ignorablePaths.push(repositoryPath);
      } else {
        scan.substantivePaths.push(repositoryPath);
      }
      continue;
    }

    scan.substantivePaths.push(repositoryPath);
    const specialKind = metadata.isFIFO()
      ? "fifo"
      : metadata.isSocket()
        ? "socket"
        : metadata.isBlockDevice()
          ? "block-device"
          : metadata.isCharacterDevice()
            ? "character-device"
            : "unknown";
    scan.entries.push({
      path: repositoryPath,
      kind: "special-file",
      specialKind,
      fingerprint: digest({
        kind: specialKind,
        device: String(metadata.dev),
        inode: String(metadata.ino),
        mode: metadata.mode,
        rdev: String(metadata.rdev),
        size: metadata.size,
      }),
    });
    scan.hazards.push({
      code: "special-file",
      path: repositoryPath,
      evidence: "Special filesystem object was fingerprinted but not opened",
    });
  }
  const directoryAfter = await lstat(directory);
  assertStableMetadata(
    directoryBefore,
    directoryAfter,
    relative(root, directory) || ".",
  );
}

async function inspectRepositoryRootUnchecked(
  selectedRoot: string,
): Promise<DetectedRepositoryState> {
  const selectedPath = isAbsolute(selectedRoot)
    ? resolve(selectedRoot)
    : resolve(process.cwd(), selectedRoot);
  let rootMetadata: Awaited<ReturnType<typeof lstat>>;
  try {
    rootMetadata = await lstat(selectedPath);
  } catch (error) {
    if (
      error instanceof Error &&
      "code" in error &&
      error.code === "ENOENT"
    ) {
      throw new RepositoryInspectionError(
        "root-missing",
        selectedPath,
        `Selected repository root does not exist: ${selectedPath}`,
        { cause: error },
      );
    }
    throw new RepositoryInspectionError(
      "inspection-failed",
      selectedPath,
      `Cannot inspect selected repository root: ${selectedPath}`,
      { cause: error },
    );
  }
  if (rootMetadata.isSymbolicLink()) {
    throw new RepositoryInspectionError(
      "root-symlink",
      selectedPath,
      `Selected repository root is a symlink and will not be followed: ${selectedPath}`,
    );
  }
  if (!rootMetadata.isDirectory()) {
    throw new RepositoryInspectionError(
      "root-not-directory",
      selectedPath,
      `Selected repository root is not a directory: ${selectedPath}`,
    );
  }
  const resolvedRoot = await realpath(selectedPath);

  const scan: FilesystemScan = {
    entries: [],
    substantivePaths: [],
    ignorablePaths: [],
    emptyDirectoryPaths: [],
    hazards: [],
    gitBoundaries: [],
  };
  await scanFilesystem(selectedPath, selectedPath, rootMetadata.dev, scan);
  scan.entries.sort(comparePath);
  scan.substantivePaths.sort();
  scan.ignorablePaths.sort();
  scan.emptyDirectoryPaths.sort();
  scan.hazards.sort(comparePath);
  scan.gitBoundaries.sort(comparePath);

  let git: DetectedRepositoryState["git"];
  let selectedTrackedPaths: string[] = [];
  const selectedRootGitMetadata = await gitMetadataBoundary(selectedPath);
  try {
    const gitRoot = (
      await gitOutput(selectedPath, ["rev-parse", "--show-toplevel"])
    ).trim();
    const resolvedGitRoot = await realpath(gitRoot);
    const headCommit = (
      await optionalGitOutput(selectedPath, [
        "rev-parse",
        "--verify",
        "--quiet",
        "HEAD",
      ])
    )?.trim() ?? null;
    const hasCommits = headCommit !== null;
    const commitCount = hasCommits
      ? Number.parseInt(
          (await gitOutput(selectedPath, ["rev-list", "--count", "HEAD"])).trim(),
          10,
        )
      : 0;
    const headTree = hasCommits
      ? (
          await gitOutput(selectedPath, ["rev-parse", "--verify", "HEAD^{tree}"])
        ).trim()
      : null;
    const gitDirectory = (
      await gitOutput(selectedPath, ["rev-parse", "--absolute-git-dir"])
    ).trim();
    const gitDirectoryFingerprint = digest(await realpath(gitDirectory));
    const trackedPaths = (
      await gitOutput(selectedPath, ["ls-files", "-z", "--", "."])
    )
      .split("\0")
      .filter(Boolean);
    selectedTrackedPaths = trackedPaths.map((path) =>
      rebaseGitPath(path, resolvedGitRoot, resolvedRoot),
    );
    const indexOutput = await gitOutput(selectedPath, [
      "ls-files",
      "--stage",
      "-z",
      "--",
      ".",
    ]);
    const indexFingerprint = `sha256:${createHash("sha256")
      .update(indexOutput)
      .digest("hex")}`;
    const indexEntries = parseGitIndex(indexOutput).map((entry) => ({
      ...entry,
      path: rebaseGitPath(entry.path, resolvedGitRoot, resolvedRoot),
    }));
    for (const entry of indexEntries) {
      if (entry.mode !== "160000") continue;
      if (
        !scan.gitBoundaries.some(
          ({ kind, path }) => kind === "submodule" && path === entry.path,
        )
      ) {
        scan.gitBoundaries.push({
          kind: "submodule",
          path: entry.path,
          gitMetadataKind: "index",
        });
      }
      if (
        !scan.hazards.some(
          ({ code, path }) => code === "submodule" && path === entry.path,
        )
      ) {
        scan.hazards.push({
          code: "submodule",
          path: entry.path,
          evidence: "Git index entry defines a submodule ownership boundary",
        });
      }
    }
    scan.gitBoundaries.sort(comparePath);
    scan.hazards.sort(comparePath);
    const headTreePathCount = hasCommits
      ? (await gitOutput(selectedPath, ["ls-tree", "-r", "--name-only", "-z", "HEAD", "--", "."]))
          .split("\0")
          .filter(Boolean).length
      : 0;
    const dirtyPaths = rebaseGitPaths(
      parseGitStatus(
        await gitOutput(selectedPath, [
          "status",
          "--porcelain=v1",
          "-z",
          "--untracked-files=all",
          "--",
          ".",
        ]),
      ),
      resolvedGitRoot,
      resolvedRoot,
    );
    const selectedGitBoundary =
      resolvedGitRoot === resolvedRoot ? selectedRootGitMetadata : undefined;
    const relationship =
      resolvedGitRoot !== resolvedRoot
        ? "parent-repository"
        : selectedGitBoundary?.kind === "worktree"
          ? "worktree"
        : selectedGitBoundary?.kind === "submodule"
            ? "submodule"
            : selectedGitBoundary?.kind === "external-git-directory"
              ? "external-git-directory"
            : "repository-root";
    git = {
      relationship,
      root: resolvedGitRoot,
      hasCommits,
      headCommit,
      headTree,
      indexFingerprint,
      gitDirectoryFingerprint,
      commitCount,
      headTreePathCount,
      trackedPathCount: trackedPaths.length,
      boundaries: scan.gitBoundaries,
      dirtyPaths,
    };
    if (resolvedGitRoot !== resolvedRoot) {
      scan.hazards.push({
        code: "parent-git-repository",
        path: ".",
        evidence: `Selected root was not redirected to parent Git root ${resolvedGitRoot}`,
      });
      scan.hazards.sort(comparePath);
    } else if (
      relationship === "worktree" ||
      relationship === "submodule" ||
      relationship === "external-git-directory"
    ) {
      scan.hazards.push({
        code: relationship,
        path: ".",
        evidence:
          relationship === "worktree"
            ? "Selected root uses external Git worktree metadata"
            : relationship === "submodule"
              ? "Selected root is a Git submodule ownership boundary"
              : "Selected root uses an external Git administrative directory",
      });
      scan.hazards.sort(comparePath);
    }
  } catch (error) {
    if (isNotGitRepositoryError(error) && selectedRootGitMetadata === undefined) {
      git = {
        relationship: "none",
        hasCommits: false,
        headCommit: null,
        headTree: null,
        indexFingerprint: null,
        gitDirectoryFingerprint: null,
        commitCount: 0,
        headTreePathCount: 0,
        trackedPathCount: 0,
        boundaries: scan.gitBoundaries,
        dirtyPaths: [],
      };
    } else {
      throw new RepositoryInspectionError(
        "git-inspection-failed",
        ".git",
        `Git state could not be inspected for selected root ${selectedPath}`,
        { cause: error },
      );
    }
  }
  scan.hazards.push(
    ...collisionHazards([
      ...scan.entries.map(({ path }) => path),
      ...selectedTrackedPaths,
    ]),
  );
  scan.hazards.sort(comparePath);
  const rootIdentity = {
    selectedPath,
    realPath: resolvedRoot,
    device: String(rootMetadata.dev),
    inode: String(rootMetadata.ino),
  };
  const root = { ...rootIdentity, fingerprint: digest(rootIdentity) };
  const detectedWithoutFingerprint = {
    schemaVersion: "1.0.0" as const,
    kind: "detected-repository-state" as const,
    root,
    filesystem: {
      entryCount: scan.entries.length,
      substantivePaths: scan.substantivePaths,
      ignorablePaths: scan.ignorablePaths,
      emptyDirectoryPaths: scan.emptyDirectoryPaths,
      entries: scan.entries,
    },
    git,
    hazards: scan.hazards,
    recommendation: recommendRunMode(scan, git, selectedTrackedPaths),
  };
  return {
    ...detectedWithoutFingerprint,
    stateFingerprint: digest(detectedWithoutFingerprint),
  };
}

export async function inspectRepositoryRoot(
  selectedRoot: string,
): Promise<DetectedRepositoryState> {
  const selectedPath = isAbsolute(selectedRoot)
    ? resolve(selectedRoot)
    : resolve(process.cwd(), selectedRoot);
  try {
    return await inspectRepositoryRootUnchecked(selectedRoot);
  } catch (error) {
    if (error instanceof RepositoryInspectionError) throw error;
    throw new RepositoryInspectionError(
      "inspection-failed",
      selectedPath,
      `Repository inspection failed for selected root ${selectedPath}`,
      { cause: error },
    );
  }
}
