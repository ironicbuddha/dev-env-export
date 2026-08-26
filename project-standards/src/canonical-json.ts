import { createHash } from "node:crypto";

import canonicalizeModule from "canonicalize";

const canonicalize = canonicalizeModule as unknown as (
  value: unknown,
) => string | undefined;

export function canonicalJson(value: unknown): string | undefined {
  return canonicalize(value);
}

export function canonicalJsonDigest(value: unknown): string | undefined {
  const canonical = canonicalJson(value);
  return canonical === undefined
    ? undefined
    : `sha256:${createHash("sha256").update(canonical).digest("hex")}`;
}

export function sameCanonicalJson(left: unknown, right: unknown): boolean {
  return canonicalJson(left) === canonicalJson(right);
}
