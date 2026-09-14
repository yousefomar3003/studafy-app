import { describe, expect, test } from "bun:test";
import { VersionedTenantContextCache } from "../../src/authorization/cache";
import { baseContext } from "../auth/fake-repository";

const SCHOOL = "bbbbbbbb-0000-4000-8000-000000000001";

describe("versioned tenant context cache", () => {
  test("reuses only the same database membership version", () => {
    const cache = new VersionedTenantContextCache();
    const v1 = baseContext({ membershipVersion: "membership-v1" });
    const first = cache.resolve(v1, SCHOOL);
    const second = cache.resolve(v1, SCHOOL);

    expect(first).toBe(second);
    expect(first?.schoolId).toBe(SCHOOL);
    expect(first?.roles).toEqual(["teacher"]);

    const v2 = baseContext({ membershipVersion: "membership-v2" });
    const third = cache.resolve(v2, SCHOOL);
    expect(third).not.toBe(first);
    expect(third?.membershipVersion).toBe("membership-v2");
    expect(cache.size).toBe(1);
  });

  test("a revoked membership cannot reuse the cached grant", () => {
    const cache = new VersionedTenantContextCache();
    expect(cache.resolve(baseContext(), SCHOOL)).not.toBeNull();

    const revoked = baseContext({
      memberships: [],
      membershipVersion: "membership-after-revoke",
    });
    expect(cache.resolve(revoked, SCHOOL)).toBeNull();
    expect(cache.size).toBe(0);
  });

  test("expiry and explicit invalidation are bounded", () => {
    let now = 100;
    const cache = new VersionedTenantContextCache({
      ttlMs: 10,
      now: () => now,
    });
    const context = baseContext();
    const first = cache.resolve(context, SCHOOL);
    now = 111;
    const afterExpiry = cache.resolve(context, SCHOOL);
    expect(afterExpiry).not.toBe(first);

    cache.invalidate(context.userId);
    expect(cache.size).toBe(0);
  });
});
