/**
 * AUTH-030 session context repository.
 *
 * The API's whole database surface is the `private.auth_*` functions granted
 * to `studafy_api_runtime`; this module is the only caller. Each call runs
 * inside a transaction that sets `request.jwt.claim.sub` from the *verified*
 * token, so the functions resolve `auth.uid()` to the subject the signature
 * proved and to nobody else.
 *
 * Roles and tenants are read from here, never from the token, which is what
 * makes "never trust role metadata from the client" true rather than
 * aspirational.
 */
import type { Sql } from "@studafy/database";
import type { VerifiedToken } from "./verify";

export type AuthRole =
  | "school_admin"
  | "teacher"
  | "parent"
  | "guardian"
  | "student";

export interface ContextMembership {
  id: string;
  school_id: string;
  school_name: string;
  school_timezone: string;
  role: AuthRole;
  active: boolean;
  active_term_id: string | null;
}

export interface SessionContext {
  userId: string;
  displayName: string;
  locale: "en" | "ar";
  profileStatus: string;
  profileDeletedAt: string | null;
  revokedBefore: string | null;
  deletionState: string | null;
  memberships: ContextMembership[];
  membershipVersion: string;
  mfaEnrolled: boolean;
}

interface RawContext {
  user_id: string;
  display_name: string;
  locale: "en" | "ar";
  profile_status: string;
  profile_deleted_at: string | null;
  revoked_before: string | null;
  deletion_state: string | null;
  memberships: ContextMembership[];
  membership_version: string;
  mfa_enrolled: boolean;
}

/**
 * Runs `work` with the verified subject installed as the request identity.
 *
 * `set_local` scopes the claim to the transaction, so a pooled connection
 * cannot leak one request's identity into the next — the failure mode that
 * would turn a connection pool into a cross-tenant data leak.
 */
export async function withVerifiedActor<T>(
  sql: Sql,
  subject: string,
  work: (tx: Sql) => Promise<T>,
): Promise<T> {
  return await sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claim.sub', ${subject}, true)`;
    return await work(tx as unknown as Sql);
  }) as T;
}

/** API-041 transaction boundary. Tenant and request correlation are installed
 * with SET LOCAL beside the verified subject so pooled connections cannot
 * retain authority from a previous request. */
export async function withRequestContext<T>(
  sql: Sql,
  context: { subject: string; schoolId: string | null; requestId: string },
  work: (tx: Sql) => Promise<T>,
): Promise<T> {
  return await sql.begin(async (tx) => {
    await tx`select
      set_config('request.jwt.claim.sub', ${context.subject}, true),
      set_config('studafy.school_id', ${context.schoolId}, true),
      set_config('studafy.request_id', ${context.requestId}, true)`;
    return await work(tx as unknown as Sql);
  }) as T;
}

/**
 * Normalizes a `timestamptz` to an ISO string.
 *
 * postgres.js decodes scalar timestamps into `Date`, while the same value
 * inside a jsonb result arrives as a string. Contracts declare strings, so
 * the two paths are converged here rather than leaving callers to guess.
 */
function isoOrNull(value: Date | string | null | undefined): string | null {
  if (value === null || value === undefined) return null;
  return value instanceof Date ? value.toISOString() : value;
}

/**
 * OPS-060 cache port for the session context. The implementation
 * (platform/cache/authContextCache.ts) keys on HMAC(subject) plus an
 * account generation and must never store an authorization decision.
 */
export interface AuthContextCache {
  load(
    subject: string,
    loader: () => Promise<SessionContext | null>,
  ): Promise<SessionContext | null>;
  invalidate(subject: string): Promise<void>;
}

export class AuthContextRepository {
  readonly #sql: Sql;
  readonly #cache: AuthContextCache | null;

  constructor(sql: Sql, cache?: AuthContextCache) {
    this.#sql = sql;
    this.#cache = cache ?? null;
  }

  /**
   * OPS-060: when a cache is wired, the DB load runs behind a version-keyed
   * Redis entry whose key embeds the account generation; a cache failure
   * falls back to the loader (the catalogue's documented failure mode), so
   * Redis problems can only cost latency, never correctness.
   */
  async load(subject: string): Promise<SessionContext | null> {
    const loader = () =>
      withVerifiedActor(this.#sql, subject, async (tx) => {
        const rows = await tx<{ context: RawContext | null }[]>`
          select private.auth_context() as context
        `;
        const raw = rows[0]?.context ?? null;
        if (!raw) return null;
        return {
          userId: raw.user_id,
          displayName: raw.display_name,
          locale: raw.locale,
          profileStatus: raw.profile_status,
          profileDeletedAt: raw.profile_deleted_at,
          revokedBefore: raw.revoked_before,
          deletionState: raw.deletion_state,
          memberships: raw.memberships ?? [],
          membershipVersion: raw.membership_version,
          mfaEnrolled: raw.mfa_enrolled,
        };
      });
    if (!this.#cache) return await loader();
    try {
      return await this.#cache.load(subject, loader);
    } catch {
      return await loader();
    }
  }

  /**
   * Bumps the account's cache generation after a mutation changes session
   * state, so the next load keys a fresh entry immediately. Best effort:
   * a failed bump is bounded by the cache TTL.
   */
  async #invalidate(subject: string | null | undefined): Promise<void> {
    if (!this.#cache || !subject) return;
    try {
      await this.#cache.invalidate(subject);
    } catch {
      // Bounded by the cache TTL; recorded context freshness recovers.
    }
  }

  async listDevices(subject: string): Promise<
    {
      id: string;
      platform: "ios" | "android" | "other";
      app_version: string | null;
      display_label: string | null;
      first_seen_at: string;
      last_seen_at: string;
      revoked_at: string | null;
    }[]
  > {
    return await withVerifiedActor(this.#sql, subject, async (tx) => {
      const rows = await tx<{ devices: unknown }[]>`
        select private.auth_list_devices() as devices
      `;
      return (rows[0]?.devices ?? []) as never;
    });
  }

  async touchDevice(
    subject: string,
    device: {
      deviceHash: string;
      platform: string;
      appVersion: string | null;
      label: string | null;
    },
  ): Promise<{ id: string; revoked: boolean } | null> {
    const result = await withVerifiedActor(this.#sql, subject, async (tx) => {
      const rows = await tx<
        { device: { id: string; revoked: boolean } | null }[]
      >`
        select private.auth_touch_device(
          ${device.deviceHash}, ${device.platform},
          ${device.appVersion}, ${device.label}
        ) as device
      `;
      return rows[0]?.device ?? null;
    });
    if (result?.revoked) await this.#invalidate(subject);
    return result;
  }

  async revokeDevice(subject: string, deviceId: string): Promise<boolean> {
    const revoked = await withVerifiedActor(this.#sql, subject, async (tx) => {
      const rows = await tx<{ revoked: boolean }[]>`
        select private.auth_revoke_device(${deviceId}::uuid) as revoked
      `;
      return rows[0]?.revoked ?? false;
    });
    if (revoked) await this.#invalidate(subject);
    return revoked;
  }

  async signOutAll(subject: string): Promise<string | null> {
    const watermark = await withVerifiedActor(
      this.#sql,
      subject,
      async (tx) => {
        const rows = await tx<{ watermark: Date | string | null }[]>`
        select private.auth_sign_out_all() as watermark
      `;
        return isoOrNull(rows[0]?.watermark);
      },
    );
    await this.#invalidate(subject);
    return watermark;
  }

  async issueReauthGrant(
    subject: string,
    grant: {
      purpose: string;
      grantHash: string;
      sessionId: string;
      assuranceLevel: string;
      ttlSeconds: number;
    },
  ): Promise<string | null> {
    return await withVerifiedActor(this.#sql, subject, async (tx) => {
      const rows = await tx<{ expires_at: Date | string | null }[]>`
        select private.auth_issue_reauth_grant(
          ${grant.purpose}, ${grant.grantHash}, ${grant.sessionId}::uuid,
          ${grant.assuranceLevel}, ${grant.ttlSeconds}
        ) as expires_at
      `;
      return isoOrNull(rows[0]?.expires_at);
    });
  }

  async consumeReauthGrant(
    subject: string,
    grant: {
      purpose: string;
      grantHash: string;
      sessionId: string;
      requestId: string;
    },
  ): Promise<boolean> {
    return await withVerifiedActor(this.#sql, subject, async (tx) => {
      const rows = await tx<{ consumed: boolean }[]>`
        select private.auth_consume_reauth_grant(
          ${grant.purpose}, ${grant.grantHash}, ${grant.sessionId}::uuid,
          ${grant.requestId}::uuid
        ) as consumed
      `;
      return rows[0]?.consumed ?? false;
    });
  }

  async linkIdentity(
    subject: string,
    provider: string,
    providerSubject: string,
    makePrimary: boolean,
  ): Promise<string> {
    const outcome = await withVerifiedActor(this.#sql, subject, async (tx) => {
      const rows = await tx<{ outcome: string }[]>`
        select private.auth_link_identity(
          ${provider}, ${providerSubject}, ${makePrimary}
        ) as outcome
      `;
      return rows[0]?.outcome ?? "collision";
    });
    if (outcome !== "collision") await this.#invalidate(subject);
    return outcome;
  }

  async unlinkIdentity(
    subject: string,
    provider: string,
    providerSubject: string,
  ): Promise<string> {
    const outcome = await withVerifiedActor(this.#sql, subject, async (tx) => {
      const rows = await tx<{ outcome: string }[]>`
        select private.auth_unlink_identity(${provider}, ${providerSubject})
          as outcome
      `;
      return rows[0]?.outcome ?? "not_linked";
    });
    if (outcome === "unlinked") await this.#invalidate(subject);
    return outcome;
  }

  async deletionImpact(
    subject: string,
  ): Promise<Record<string, unknown> | null> {
    return await withVerifiedActor(this.#sql, subject, async (tx) => {
      const rows = await tx<{ impact: Record<string, unknown> | null }[]>`
        select private.auth_deletion_impact() as impact
      `;
      return rows[0]?.impact ?? null;
    });
  }

  async requestDeletion(
    subject: string,
    reasonCode: string,
    impact: unknown,
    graceDays: number,
  ): Promise<
    | { id: string; state: string; execute_after: string; created: boolean }
    | null
  > {
    const result = await withVerifiedActor(this.#sql, subject, async (tx) => {
      const rows = await tx<{ result: never }[]>`
        select private.auth_request_deletion(
          ${reasonCode}, ${JSON.stringify(impact ?? {})}::jsonb, ${graceDays}
        ) as result
      `;
      return rows[0]?.result ?? null;
    });
    if (result) await this.#invalidate(subject);
    return result;
  }

  async cancelDeletion(subject: string): Promise<boolean> {
    const cancelled = await withVerifiedActor(
      this.#sql,
      subject,
      async (tx) => {
        const rows = await tx<{ result: { cancelled: boolean } | null }[]>`
        select private.auth_cancel_deletion() as result
      `;
        return rows[0]?.result?.cancelled ?? false;
      },
    );
    if (cancelled) await this.#invalidate(subject);
    return cancelled;
  }

  /**
   * Security events are written on their own connection rather than inside
   * the caller's transaction: a denied request usually has no transaction to
   * join, and an audit write must not be rolled back by the failure it
   * records.
   */
  async recordEvent(event: {
    subject: string | null;
    eventType: string;
    outcome: "allowed" | "denied";
    reasonCode: string;
    accountIdentifier?: string | null;
    schoolId?: string | null;
    method?: string | null;
    assuranceLevel?: string | null;
    ip?: string | null;
    deviceHash?: string | null;
    userAgentFamily?: string | null;
    requestId?: string | null;
  }): Promise<void> {
    const write = async (tx: Sql) => {
      await tx`
        select private.auth_record_security_event(
          ${event.eventType}, ${event.outcome}, ${event.reasonCode},
          ${event.accountIdentifier ?? null},
          ${event.schoolId ?? null}::uuid,
          ${event.method ?? null}, ${event.assuranceLevel ?? null},
          ${event.ip ?? null}, ${event.deviceHash ?? null},
          ${event.userAgentFamily ?? null},
          ${event.requestId ?? null}::uuid
        )
      `;
    };
    if (event.subject) {
      await withVerifiedActor(this.#sql, event.subject, write);
      return;
    }
    await write(this.#sql);
  }
}

/**
 * Decides whether a verified token still corresponds to a usable session.
 *
 * The signature and expiry only prove the token was issued; these checks are
 * what make revocation take effect before the token would have expired on its
 * own.
 */
export function evaluateSession(
  token: VerifiedToken,
  context: SessionContext | null,
  revocationBudgetSeconds: number,
):
  | { allowed: true; context: SessionContext }
  | {
    allowed: false;
    reason:
      | "no_profile"
      | "profile_suspended"
      | "profile_deleted"
      | "session_revoked";
  } {
  if (!context) return { allowed: false, reason: "no_profile" };
  if (context.profileDeletedAt !== null) {
    return { allowed: false, reason: "profile_deleted" };
  }
  if (context.profileStatus !== "active") {
    return { allowed: false, reason: "profile_suspended" };
  }
  if (context.revokedBefore) {
    const watermark = Date.parse(context.revokedBefore) / 1000;
    // A token issued before the watermark belongs to a session the user (or
    // an operator) has already signed out, even though it has not expired.
    if (token.issuedAt < watermark - revocationBudgetSeconds) {
      return { allowed: false, reason: "session_revoked" };
    }
  }
  return { allowed: true, context };
}
