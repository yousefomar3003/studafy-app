import type { Sql } from "@studafy/database";
import { withVerifiedActor } from "../auth/context";
import type { Permission } from "./catalogue";

export interface ResourceAuthorizationDecision {
  allowed: boolean;
  schoolId: string | null;
  reason: "allowed" | "denied" | "unknown_action" | "invalid_resource";
}

interface RawDecision {
  allowed?: boolean;
  school_id?: string | null;
  reason?: ResourceAuthorizationDecision["reason"];
}

export interface ResourceAuthorizationRepository {
  authorize(
    subject: string,
    permission: Permission,
    resourceId: string,
  ): Promise<ResourceAuthorizationDecision>;
}

/** Calls the narrow AUTH-031 SECURITY DEFINER decision surface. */
export class PostgresAuthorizationRepository
  implements ResourceAuthorizationRepository {
  readonly #sql: Sql;

  constructor(sql: Sql) {
    this.#sql = sql;
  }

  async authorize(
    subject: string,
    permission: Permission,
    resourceId: string,
  ): Promise<ResourceAuthorizationDecision> {
    return await withVerifiedActor(this.#sql, subject, async (tx) => {
      const rows = await tx<{ decision: RawDecision | null }[]>`
        select private.authz_authorize(
          ${permission}, ${resourceId}::uuid
        ) as decision
      `;
      const raw = rows[0]?.decision;
      if (!raw) return denied("invalid_resource");
      return {
        allowed: raw.allowed === true,
        schoolId: raw.school_id ?? null,
        reason: raw.reason ?? "denied",
      };
    });
  }
}

function denied(
  reason: ResourceAuthorizationDecision["reason"],
): ResourceAuthorizationDecision {
  return { allowed: false, schoolId: null, reason };
}
