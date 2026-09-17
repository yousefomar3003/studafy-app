/**
 * OPS-060 cache catalogue.
 *
 * The catalogued set of revocation-safe caches. Every entry declares its
 * key shape, TTL, invalidation event, failure mode, and status before any
 * implementation points Redis at it; the invariant test asserts TTLs stay
 * inside the revocation budget for authorization-adjacent entries and that
 * namespaces never collide with the limiter or the BullMQ queue keys.
 *
 * Rule 1: `authz_authorize` - the per-request permission decision - is never
 * cached. The catalogue caches derived *context*, not authorization.
 * Rule 2: an entry is only "active" when its invalidation story is proven;
 * everything else is declared for its owning phase, not invented for a read
 * path that has no hot query.
 * Rule 3: Redis down means the documented failure mode, never a stale
 * authorization artifact and never a queue eviction.
 */

export interface CacheCatalogueEntry {
  /** Stable id; also the key segment under the cache namespace. */
  id: string;
  description: string;
  /**
   * TTL in seconds. Authorization-adjacent entries clamp to the configured
   * revocation budget when one is set (min(30, budget)); a zero budget does
   * NOT disable them because the key embeds every mutating dimension, so a
   * revocation changes the key instantly (ADR-0022).
   */
  ttlSeconds: (budgetSeconds: number) => number;
  /** Bounded stale-while-revalidate window in seconds; unset = none. */
  staleSeconds?: number;
  /** What happens when Redis cannot serve: never a stale authorization. */
  failure: "fallback_to_loader" | "fail_closed_to_db";
  /** The event whose mutation changes the key (version-keyed). */
  invalidation: string;
  status: "active" | "declared";
}

export const CACHE_CATALOGUE: Record<
  | "authContext"
  | "userSummary"
  | "classroomSummary"
  | "timetableWindow"
  | "publishedFeedPage"
  | "billingCatalog"
  | "entitlementRead"
  | "negativeNotFound",
  CacheCatalogueEntry
> = {
  authContext: {
    id: "authctx",
    description:
      "DB-loaded session context (memberships, profile state, revocation watermark) behind every authenticated request.",
    ttlSeconds: (budget) => budget > 0 ? Math.min(30, budget) : 30,
    failure: "fallback_to_loader",
    invalidation:
      "Version key embeds membershipVersion + revocation watermark + profile state; every AuthContextRepository mutation bumps the account's generation.",
    status: "active",
  },
  userSummary: {
    id: "user-summary",
    description:
      "Safe display summary for the signed-in user (name, locale, school label).",
    ttlSeconds: () => 300,
    failure: "fallback_to_loader",
    invalidation: "account.profile.write",
    status: "declared",
  },
  classroomSummary: {
    id: "classroom-summary",
    description: "Roster/staff counts and labels for classroom headers.",
    ttlSeconds: () => 300,
    failure: "fallback_to_loader",
    invalidation: "classroom/school-admin write commands",
    status: "declared",
  },
  timetableWindow: {
    id: "timetable",
    description: "Published timetable for a time window.",
    ttlSeconds: () => 300,
    failure: "fallback_to_loader",
    invalidation: "schedule replace/publish commands",
    status: "declared",
  },
  publishedFeedPage: {
    id: "feed-page",
    description: "A published content feed page for an anonymous render.",
    ttlSeconds: () => 120,
    staleSeconds: 60,
    failure: "fallback_to_loader",
    invalidation: "publish/withdraw commands",
    status: "declared",
  },
  billingCatalog: {
    id: "billing-catalog",
    description: "Store product catalog snapshot (public, versioned).",
    ttlSeconds: () => 3600,
    failure: "fallback_to_loader",
    invalidation: "catalog publish",
    status: "declared",
  },
  entitlementRead: {
    id: "entitlement",
    description:
      "Entitlement check result; authorization-adjacent, clamped to the revocation budget.",
    ttlSeconds: (budget) => budget > 0 ? Math.min(30, budget) : 30,
    failure: "fail_closed_to_db",
    invalidation: "entitlement grant/revoke",
    status: "declared",
  },
  negativeNotFound: {
    id: "negative-404",
    description: "Short-lived negative cache for repeated not-found probes.",
    ttlSeconds: () => 5,
    failure: "fallback_to_loader",
    invalidation: "resource creation",
    status: "declared",
  },
};

/** Key namespaces. The BullMQ prefix must never overlap the other two. */
export function redisKeyPrefixes(environment: string): {
  rateLimit: string;
  cache: string;
  queue: string;
} {
  return {
    rateLimit: `studafy:{${environment}}:rl`,
    cache: `studafy:{${environment}}:cache`,
    queue: `studafy-${environment}`,
  };
}

/**
 * The committed staleness bound for authorization-adjacent caches. Entries
 * whose ttlSeconds consults the revocation budget clamp to this value;
 * asserted in the catalogue test.
 */
export const AUTH_CACHE_MAX_TTL_SECONDS = 30;

export function authContextTtlMs(budgetSeconds: number): number {
  return CACHE_CATALOGUE.authContext.ttlSeconds(budgetSeconds) * 1000;
}
