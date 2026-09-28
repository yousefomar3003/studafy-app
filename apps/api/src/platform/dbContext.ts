import type { Context } from "hono";
import type { Sql } from "@studafy/database";
import type { AuthorizationEnv } from "../authorization/middleware";

/**
 * Who a database call runs as, and for which school.
 *
 * Every repository takes one of these and installs it with
 * [withRequestContext], so the SQL functions see the same identity the API
 * authorised.
 */
export interface RequestDbContext {
  subject: string;
  /**
   * Null only for self-scoped permissions (e.g. platform-operator school
   * provisioning) that have no resolved tenant to check. Every
   * resource/tenant-scoped permission always resolves a school here.
   */
  schoolId: string | null;
  requestId: string;
  /**
   * Whether this session actually presented a second factor (AAL2), not
   * just whether MFA is enrolled. Most modules ignore this; support-access
   * requires it unconditionally, matching docs/planning/instructions.md section 7's
   * "MFA, ticket/reason, ... full audit" requirement.
   */
  aal2: boolean;
}

/** API-041 transaction boundary. Tenant and request correlation are installed
 * with SET LOCAL beside the verified subject so pooled connections cannot
 * retain authority from a previous request. */
export async function withRequestContext<T>(
  sql: Sql,
  context: Pick<RequestDbContext, "subject" | "schoolId" | "requestId">,
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
 * The context for a route whose school is the caller's own membership.
 *
 * Catalogue routes and billing use this: their SQL re-checks the school, and
 * a caller with no membership (a verified guardian) runs with no school.
 */
export function membershipDbContext(
  c: Context<AuthorizationEnv>,
): RequestDbContext {
  return {
    subject: c.get("actor").token.subject,
    schoolId: c.get("authorization").tenant?.schoolId ?? null,
    requestId: c.get("requestId"),
    aal2: c.get("actor").aal2,
  };
}

/**
 * The context for a route whose school is the one the permission check
 * resolved from the resource, falling back to that when the caller holds no
 * membership there.
 *
 * Files and study use this: a guardian has no membership, so the school a
 * decision resolved through their link to a child is the one handed to SQL,
 * which re-authorizes against it.
 */
export function resolvedSchoolDbContext(
  c: Context<AuthorizationEnv>,
): RequestDbContext {
  return {
    subject: c.get("actor").token.subject,
    schoolId: c.get("authorization").tenant?.schoolId ??
      c.get("authorization").decisionSchoolId ?? null,
    requestId: c.get("requestId"),
    aal2: c.get("actor").aal2,
  };
}
