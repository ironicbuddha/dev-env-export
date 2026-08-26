import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import {
  lstat,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  readlink,
  realpath,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, relative } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import {
  inspectRepositoryRoot,
  RepositoryInspectionError,
  validateProjectStandardsDocument,
} from "../src/index.js";

const execFileAsync = promisify(execFile);
const packageRoot = join(dirname(fileURLToPath(import.meta.url)), "../..");

async function runGit(root: string, ...arguments_: string[]): Promise<void> {
  await execFileAsync("git", ["-C", root, ...arguments_], {
    env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" },
  });
}

async function gitOutput(root: string, ...arguments_: string[]): Promise<string> {
  const { stdout } = await execFileAsync("git", ["-C", root, ...arguments_], {
    encoding: "utf8",
    env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" },
  });
  return stdout.trim();
}

async function treeFingerprint(root: string): Promise<string> {
  const records: string[] = [];

  async function visit(directory: string): Promise<void> {
    const entries = await readdir(directory, { withFileTypes: true });
    entries.sort((left, right) => left.name.localeCompare(right.name, "en"));
    for (const entry of entries) {
      const absolutePath = join(directory, entry.name);
      const repositoryPath = relative(root, absolutePath);
      const metadata = await lstat(absolutePath);
      if (entry.isDirectory()) {
        records.push(`directory\0${repositoryPath}\0${metadata.mode}`);
        await visit(absolutePath);
      } else if (entry.isSymbolicLink()) {
        records.push(
          `symlink\0${repositoryPath}\0${metadata.mode}\0${await readlink(absolutePath)}`,
        );
      } else {
        const digest = createHash("sha256")
          .update(await readFile(absolutePath))
          .digest("hex");
        records.push(
          `file\0${repositoryPath}\0${metadata.mode}\0${metadata.size}\0${digest}`,
        );
      }
    }
  }

  await visit(root);
  return createHash("sha256").update(records.join("\n")).digest("hex");
}

test("inspect recommends initialization for an exact Git root with an empty initial commit without changing it", async () => {
  const root = await mkdtemp(join(tmpdir(), "project-standards-inspect-empty-"));
  await runGit(root, "init", "--quiet");
  await runGit(
    root,
    "-c",
    "user.name=Project Standards Test",
    "-c",
    "user.email=project-standards@example.test",
    "commit",
    "--quiet",
    "--allow-empty",
    "-m",
    "empty initial commit",
  );
  const before = await treeFingerprint(root);

  const detected = await inspectRepositoryRoot(root);

  assert.equal(detected.kind, "detected-repository-state");
  assert.equal(detected.root.selectedPath, root);
  assert.equal(detected.root.realPath, await realpath(root));
  assert.equal(detected.git.relationship, "repository-root");
  assert.equal(detected.git.hasCommits, true);
  assert.equal(detected.git.trackedPathCount, 0);
  assert.deepEqual(detected.hazards, []);
  assert.deepEqual(detected.recommendation, {
    mode: "initialize",
    initializeEligible: true,
    evidence: ["empty-initial-commit", "no-substantive-content"],
  });
  assert.match(detected.root.fingerprint, /^sha256:[a-f0-9]{64}$/);
  assert.match(detected.stateFingerprint, /^sha256:[a-f0-9]{64}$/);
  await validateProjectStandardsDocument("detected-repository-state", detected);
  await assert.rejects(
    validateProjectStandardsDocument("detected-repository-state", {
      ...detected,
      selectedMode: "initialize",
    }),
    (error: unknown) =>
      error instanceof Error &&
      "code" in error &&
      error.code === "schema-invalid",
  );
  assert.equal(await treeFingerprint(root), before);
});

test("inspect recommends adoption for substantive user content without exposing or changing it", async () => {
  const root = await mkdtemp(join(tmpdir(), "project-standards-inspect-adopt-"));
  const userContent = "private user-authored content\n";
  await writeFile(join(root, "README.md"), userContent);
  const before = await treeFingerprint(root);

  const detected = await inspectRepositoryRoot(root);

  assert.equal(detected.git.relationship, "none");
  assert.equal(detected.filesystem.entryCount, 1);
  assert.deepEqual(detected.filesystem.substantivePaths, ["README.md"]);
  assert.deepEqual(detected.filesystem.entries, [
    {
      path: "README.md",
      kind: "regular-file",
      size: Buffer.byteLength(userContent),
      fingerprint: `sha256:${createHash("sha256").update(userContent).digest("hex")}`,
    },
  ]);
  assert.deepEqual(detected.recommendation, {
    mode: "adopt",
    initializeEligible: false,
    evidence: ["substantive-content"],
  });
  assert.doesNotMatch(JSON.stringify(detected), /private user-authored content/);
  assert.equal(await treeFingerprint(root), before);

  await writeFile(join(root, "README.md"), "changed user content\n");
  const changed = await inspectRepositoryRoot(root);
  assert.notEqual(changed.stateFingerprint, detected.stateFingerprint);
});

test("inspect fingerprints a symlink without following or changing its external target", async () => {
  const root = await mkdtemp(join(tmpdir(), "project-standards-inspect-link-"));
  const outside = await mkdtemp(
    join(tmpdir(), "project-standards-inspect-outside-"),
  );
  const outsideFile = join(outside, "private.txt");
  await writeFile(outsideFile, "external secret content\n");
  await symlink(outsideFile, join(root, "outside-link"));
  const outsideBefore = await treeFingerprint(outside);

  const detected = await inspectRepositoryRoot(root);

  assert.deepEqual(detected.filesystem.entries, [
    {
      path: "outside-link",
      kind: "symbolic-link",
      target: outsideFile,
      fingerprint: `sha256:${createHash("sha256").update(outsideFile).digest("hex")}`,
    },
  ]);
  assert.deepEqual(detected.hazards, [
    {
      code: "symbolic-link",
      path: "outside-link",
      evidence: "Symlink target was fingerprinted but not followed",
    },
  ]);
  assert.equal(detected.recommendation.mode, "adopt");
  assert.equal(detected.recommendation.initializeEligible, false);
  assert.doesNotMatch(JSON.stringify(detected), /external secret content/);
  assert.equal(await treeFingerprint(outside), outsideBefore);
});

test("inspect reports a nested Git repository as a separate ownership boundary", async () => {
  const root = await mkdtemp(join(tmpdir(), "project-standards-inspect-nested-"));
  const nested = join(root, "packages", "nested");
  await mkdir(nested, { recursive: true });
  await runGit(nested, "init", "--quiet");
  const before = await treeFingerprint(root);

  const detected = await inspectRepositoryRoot(root);

  assert.equal(detected.git.relationship, "none");
  assert.deepEqual(detected.git.boundaries, [
    {
      kind: "nested-repository",
      path: "packages/nested",
      gitMetadataKind: "directory",
    },
  ]);
  assert.deepEqual(
    detected.hazards.filter(({ code }) => code === "nested-repository"),
    [
      {
        code: "nested-repository",
        path: "packages/nested",
        evidence: "Nested Git metadata defines a separate ownership boundary",
      },
    ],
  );
  assert.equal(detected.recommendation.mode, "adopt");
  assert.equal(await treeFingerprint(root), before);
});

test("inspect keeps a selected subdirectory exact instead of redirecting to its parent Git root", async () => {
  const outer = await mkdtemp(join(tmpdir(), "project-standards-inspect-parent-"));
  await runGit(outer, "init", "--quiet");
  const selectedRoot = join(outer, "services", "api");
  await mkdir(selectedRoot, { recursive: true });
  await writeFile(join(selectedRoot, "package.json"), "{}\n");
  const before = await treeFingerprint(outer);

  const detected = await inspectRepositoryRoot(selectedRoot);

  assert.equal(detected.root.selectedPath, selectedRoot);
  assert.deepEqual(detected.git, {
    relationship: "parent-repository",
    root: await realpath(outer),
    hasCommits: false,
    commitCount: 0,
    headTreePathCount: 0,
    trackedPathCount: 0,
    boundaries: [],
    dirtyPaths: [
      {
        path: "package.json",
        indexState: "untracked",
        worktreeState: "untracked",
      },
    ],
  });
  assert.deepEqual(
    detected.hazards.filter(({ code }) => code === "parent-git-repository"),
    [
      {
        code: "parent-git-repository",
        path: ".",
        evidence: `Selected root was not redirected to parent Git root ${await realpath(outer)}`,
      },
    ],
  );
  assert.equal(detected.recommendation.mode, "adopt");
  assert.equal(await treeFingerprint(outer), before);
});

test("inspect reports exact dirty Git paths as evidence without reading their contents", async () => {
  const root = await mkdtemp(join(tmpdir(), "project-standards-inspect-dirty-"));
  await runGit(root, "init", "--quiet");
  await writeFile(join(root, "tracked.txt"), "committed value\n");
  await runGit(root, "add", "tracked.txt");
  await runGit(
    root,
    "-c",
    "user.name=Project Standards Test",
    "-c",
    "user.email=project-standards@example.test",
    "commit",
    "--quiet",
    "-m",
    "tracked fixture",
  );
  await writeFile(join(root, "tracked.txt"), "private modified value\n");
  await writeFile(join(root, "untracked.txt"), "private untracked value\n");
  const before = await treeFingerprint(root);

  const detected = await inspectRepositoryRoot(root);

  assert.deepEqual(detected.git.dirtyPaths, [
    {
      path: "tracked.txt",
      indexState: "unchanged",
      worktreeState: "modified",
    },
    {
      path: "untracked.txt",
      indexState: "untracked",
      worktreeState: "untracked",
    },
  ]);
  assert.doesNotMatch(JSON.stringify(detected), /private (modified|untracked) value/);
  assert.equal(await treeFingerprint(root), before);
});

test("inspect preserves conventional placeholders and ignorable OS or editor metadata while recommending initialization", async () => {
  const root = await mkdtemp(
    join(tmpdir(), "project-standards-inspect-metadata-"),
  );
  await runGit(root, "init", "--quiet");
  await mkdir(join(root, "docs", "empty"), { recursive: true });
  await mkdir(join(root, ".vscode"), { recursive: true });
  await writeFile(join(root, ".gitkeep"), "");
  await writeFile(join(root, ".DS_Store"), "opaque metadata");
  await writeFile(
    join(root, ".vscode", "settings.json"),
    '{"editor.formatOnSave":true}\n',
  );
  const before = await treeFingerprint(root);

  const detected = await inspectRepositoryRoot(root);

  assert.deepEqual(detected.filesystem.substantivePaths, []);
  assert.deepEqual(detected.filesystem.ignorablePaths, [
    ".DS_Store",
    ".gitkeep",
    ".vscode/settings.json",
  ]);
  assert.deepEqual(detected.filesystem.emptyDirectoryPaths, ["docs/empty"]);
  assert.deepEqual(detected.recommendation, {
    mode: "initialize",
    initializeEligible: true,
    evidence: [
      "empty-git-root",
      "ignorable-content-preserved",
      "no-substantive-content",
    ],
  });
  assert.equal(await treeFingerprint(root), before);
});

test("inspect reports a special file without opening it", async () => {
  const root = await mkdtemp(join(tmpdir(), "project-standards-inspect-fifo-"));
  await execFileAsync("mkfifo", [join(root, "events.pipe")]);

  const detected = await inspectRepositoryRoot(root);

  const specialFile = detected.filesystem.entries.find(
    ({ path }) => path === "events.pipe",
  );
  assert.equal(specialFile?.kind, "special-file");
  if (specialFile?.kind !== "special-file") assert.fail("special file missing");
  assert.equal(specialFile.specialKind, "fifo");
  assert.match(specialFile.fingerprint, /^sha256:[a-f0-9]{64}$/);
  assert.deepEqual(detected.hazards, [
    {
      code: "special-file",
      path: "events.pipe",
      evidence: "Special filesystem object was fingerprinted but not opened",
    },
  ]);
  assert.equal(detected.recommendation.mode, "adopt");
});

test("inspect rejects initialization when Git paths collide by case or Unicode normalization", async () => {
  const root = await mkdtemp(
    join(tmpdir(), "project-standards-inspect-collisions-"),
  );
  await runGit(root, "init", "--quiet");
  await runGit(root, "config", "core.precomposeunicode", "false");
  const blobSource = join(root, "blob-source");
  await writeFile(blobSource, "collision fixture\n");
  const blob = await gitOutput(root, "hash-object", "-w", "blob-source");
  await runGit(root, "clean", "-f", "--", "blob-source");
  for (const path of [
    "README.md",
    "readme.md",
    "caf\u00e9.md",
    "cafe\u0301.md",
  ]) {
    await runGit(root, "update-index", "--add", "--cacheinfo", `100644,${blob},${path}`);
  }
  const before = await treeFingerprint(root);

  const detected = await inspectRepositoryRoot(root);

  assert.deepEqual(
    detected.hazards.filter(({ code }) =>
      ["case-collision", "normalization-ambiguity"].includes(code),
    ),
    [
      {
        code: "case-collision",
        path: "README.md | readme.md",
        evidence: "Paths differ only by case after Unicode normalization",
      },
      {
        code: "normalization-ambiguity",
        path: "cafe\u0301.md | caf\u00e9.md",
        evidence: "Paths normalize to the same Unicode NFC form",
      },
    ],
  );
  assert.equal(detected.git.trackedPathCount, 4);
  assert.equal(detected.recommendation.mode, "adopt");
  assert.equal(detected.recommendation.initializeEligible, false);
  assert.equal(await treeFingerprint(root), before);
});

test("inspect distinguishes selected Git worktree and submodule roots as separate boundaries", async () => {
  const container = await mkdtemp(
    join(tmpdir(), "project-standards-inspect-git-boundaries-"),
  );
  const source = join(container, "source");
  await mkdir(source);
  await runGit(source, "init", "--quiet");
  await writeFile(join(source, "tracked.txt"), "source\n");
  await runGit(source, "add", "tracked.txt");
  await runGit(
    source,
    "-c",
    "user.name=Project Standards Test",
    "-c",
    "user.email=project-standards@example.test",
    "commit",
    "--quiet",
    "-m",
    "source fixture",
  );

  const worktree = join(container, "worktree");
  await runGit(source, "worktree", "add", "--quiet", "-b", "fixture-worktree", worktree);
  const worktreeBefore = await treeFingerprint(worktree);
  const detectedWorktree = await inspectRepositoryRoot(worktree);
  assert.equal(detectedWorktree.git.relationship, "worktree");
  assert.deepEqual(
    detectedWorktree.hazards.filter(({ code }) => code === "worktree"),
    [
      {
        code: "worktree",
        path: ".",
        evidence: "Selected root uses external Git worktree metadata",
      },
    ],
  );
  assert.equal(await treeFingerprint(worktree), worktreeBefore);

  const outer = join(container, "outer");
  await mkdir(outer);
  await runGit(outer, "init", "--quiet");
  await runGit(
    outer,
    "-c",
    "protocol.file.allow=always",
    "submodule",
    "add",
    "--quiet",
    source,
    "vendor/source",
  );
  const submodule = join(outer, "vendor", "source");
  const submoduleBefore = await treeFingerprint(submodule);
  const detectedSubmodule = await inspectRepositoryRoot(submodule);
  assert.equal(detectedSubmodule.git.relationship, "submodule");
  assert.deepEqual(
    detectedSubmodule.hazards.filter(({ code }) => code === "submodule"),
    [
      {
        code: "submodule",
        path: ".",
        evidence: "Selected root is a Git submodule ownership boundary",
      },
    ],
  );
  assert.equal(await treeFingerprint(submodule), submoduleBefore);
});

test("inspect fails closed for a missing root or a symlink-selected root", async () => {
  const container = await mkdtemp(
    join(tmpdir(), "project-standards-inspect-invalid-root-"),
  );
  const missing = join(container, "missing");
  await assert.rejects(
    inspectRepositoryRoot(missing),
    (error: unknown) =>
      error instanceof RepositoryInspectionError &&
      error.code === "root-missing" &&
      error.path === missing,
  );

  const realRoot = join(container, "real-root");
  await mkdir(realRoot);
  const linkedRoot = join(container, "linked-root");
  await symlink(realRoot, linkedRoot);
  await assert.rejects(
    inspectRepositoryRoot(linkedRoot),
    (error: unknown) =>
      error instanceof RepositoryInspectionError &&
      error.code === "root-symlink" &&
      error.path === linkedRoot,
  );
});

test("inspect fails closed when selected-root Git metadata cannot be inspected", async () => {
  const root = await mkdtemp(
    join(tmpdir(), "project-standards-inspect-broken-git-"),
  );
  await writeFile(join(root, ".git"), "gitdir: /definitely/missing/git-metadata\n");

  await assert.rejects(
    inspectRepositoryRoot(root),
    (error: unknown) =>
      error instanceof RepositoryInspectionError &&
      error.code === "git-inspection-failed" &&
      error.path === ".git",
  );
});

test("CLI inspect exposes the same read-only state and typed failure outcomes", async () => {
  const root = await mkdtemp(join(tmpdir(), "project-standards-inspect-cli-"));
  await writeFile(join(root, "user-file.txt"), "user-owned\n");
  const before = await treeFingerprint(root);
  const cliPath = join(packageRoot, "dist", "src", "cli.js");

  const { stdout } = await execFileAsync(process.execPath, [
    cliPath,
    "inspect",
    root,
  ]);
  const output = JSON.parse(stdout) as Record<string, unknown>;
  assert.equal(output.schemaVersion, "1.0.0");
  assert.equal(output.status, "inspected");
  assert.equal(
    (output.detectedRepositoryState as { recommendation: { mode: string } })
      .recommendation.mode,
    "adopt",
  );
  assert.doesNotMatch(JSON.stringify(output), /verified/i);
  assert.equal(await treeFingerprint(root), before);

  const missing = join(root, "missing");
  await assert.rejects(
    execFileAsync(process.execPath, [cliPath, "inspect", missing]),
    (error: unknown) => {
      if (!(error instanceof Error) || !("stderr" in error) || !("code" in error)) {
        return false;
      }
      const failure = JSON.parse(String(error.stderr)) as Record<string, unknown>;
      return (
        error.code === 2 &&
        failure.status === "invalid" &&
        failure.code === "root-missing" &&
        !JSON.stringify(failure).toLowerCase().includes("verified")
      );
    },
  );
});

test("inspect does not recommend initialization for an empty-looking root with substantive history or dirty deletion", async () => {
  async function committedFileRoot(prefix: string): Promise<string> {
    const root = await mkdtemp(join(tmpdir(), prefix));
    await runGit(root, "init", "--quiet");
    await writeFile(join(root, "tracked.txt"), "substantive history\n");
    await runGit(root, "add", "tracked.txt");
    await runGit(
      root,
      "-c",
      "user.name=Project Standards Test",
      "-c",
      "user.email=project-standards@example.test",
      "commit",
      "--quiet",
      "-m",
      "substantive commit",
    );
    return root;
  }

  const historicalRoot = await committedFileRoot(
    "project-standards-inspect-history-",
  );
  await runGit(historicalRoot, "rm", "--quiet", "tracked.txt");
  await runGit(
    historicalRoot,
    "-c",
    "user.name=Project Standards Test",
    "-c",
    "user.email=project-standards@example.test",
    "commit",
    "--quiet",
    "-m",
    "empty current tree",
  );
  const historical = await inspectRepositoryRoot(historicalRoot);
  assert.equal(historical.git.commitCount, 2);
  assert.equal(historical.git.headTreePathCount, 0);
  assert.deepEqual(historical.recommendation, {
    mode: "adopt",
    initializeEligible: false,
    evidence: ["non-empty-git-history"],
  });

  const dirtyRoot = await committedFileRoot(
    "project-standards-inspect-deletion-",
  );
  await runGit(dirtyRoot, "rm", "--quiet", "tracked.txt");
  const dirty = await inspectRepositoryRoot(dirtyRoot);
  assert.equal(dirty.git.trackedPathCount, 0);
  assert.deepEqual(dirty.git.dirtyPaths, [
    {
      path: "tracked.txt",
      indexState: "deleted",
      worktreeState: "unchanged",
    },
  ]);
  assert.deepEqual(dirty.recommendation, {
    mode: "adopt",
    initializeEligible: false,
    evidence: ["dirty-git-state"],
  });
});
