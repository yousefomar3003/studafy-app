import type { SessionContext } from "../auth/context";

export interface TenantContext {
  userId: string;
  schoolId: string;
  membershipIds: readonly string[];
  roles: readonly string[];
  membershipVersion: string;
  schoolName: string;
  schoolTimezone: string;
  activeTermId: string | null;
}

interface CacheEntry {
  value: TenantContext;
  expiresAt: number;
}

/**
 * Short-lived membership context cache keyed by the database version.
 *
 * A caller must present the freshly loaded SessionContext on every lookup.
 * Consequently, a membership update changes the key before a cached value can
 * be reused. Resource/relationship decisions are intentionally never cached.
 */
export class VersionedTenantContextCache {
  readonly #entries = new Map<string, CacheEntry>();
  readonly #ttlMs: number;
  readonly #maxEntries: number;
  readonly #now: () => number;

  constructor(options: {
    ttlMs?: number;
    maxEntries?: number;
    now?: () => number;
  } = {}) {
    this.#ttlMs = options.ttlMs ?? 15_000;
    this.#maxEntries = options.maxEntries ?? 1_000;
    this.#now = options.now ?? Date.now;
  }

  resolve(context: SessionContext, schoolId: string): TenantContext | null {
    const key = this.#key(context.userId, schoolId, context.membershipVersion);
    const cached = this.#entries.get(key);
    const now = this.#now();
    if (cached && cached.expiresAt > now) return cached.value;
    if (cached) this.#entries.delete(key);

    const memberships = context.memberships.filter((membership) =>
      membership.active && membership.school_id === schoolId
    );
    if (memberships.length === 0) {
      // Remove every older version for this user/school. This bounds the
      // revocation race even when an invalidation event is delayed.
      this.invalidate(context.userId, schoolId);
      return null;
    }

    const first = memberships[0]!;
    const value: TenantContext = Object.freeze({
      userId: context.userId,
      schoolId,
      membershipIds: Object.freeze(memberships.map((item) => item.id)),
      roles: Object.freeze([...new Set(memberships.map((item) => item.role))]),
      membershipVersion: context.membershipVersion,
      schoolName: first.school_name,
      schoolTimezone: first.school_timezone,
      activeTermId: first.active_term_id,
    });

    // Only the current version remains reusable for this user/school.
    this.invalidate(context.userId, schoolId);
    this.#entries.set(key, { value, expiresAt: now + this.#ttlMs });
    this.#evictOverflow();
    return value;
  }

  invalidate(userId: string, schoolId?: string): void {
    const prefix = schoolId ? `${userId}:${schoolId}:` : `${userId}:`;
    for (const key of this.#entries.keys()) {
      if (key.startsWith(prefix)) this.#entries.delete(key);
    }
  }

  get size(): number {
    return this.#entries.size;
  }

  #key(userId: string, schoolId: string, version: string): string {
    return `${userId}:${schoolId}:${version}`;
  }

  #evictOverflow(): void {
    while (this.#entries.size > this.#maxEntries) {
      const oldest = this.#entries.keys().next().value as string | undefined;
      if (!oldest) return;
      this.#entries.delete(oldest);
    }
  }
}
