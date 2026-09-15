import type { Sql } from "@studafy/database";
import { withRequestContext } from "../auth/context";
import { sha256Hex } from "../auth/middleware";
import type {
  CatalogueCommandResult,
  CatalogueRepository,
  RequestDbContext,
} from "../platform/catalogueRoutes";

export type InvitationsRepository = CatalogueRepository;

/** 43 base64url characters is 32 bytes of entropy - same shape as AUTH-030's opaqueGrant. */
function opaqueToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

/**
 * The invitation token is generated and hashed here, in TypeScript, the
 * same way AUTH-030 handles recent-auth grants - the SQL dispatcher never
 * sees or produces a raw token, only its SHA-256 hash. issueInvitation's
 * response is the one place the raw token is ever exposed; acceptInvitation
 * only ever sends a hash to look up.
 */
export class PostgresInvitationsRepository implements CatalogueRepository {
  constructor(readonly sql: Sql) {}

  async query(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
  ): Promise<unknown> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: unknown }[]>`
        select private.api042_query(
          ${operation}, ${resourceId}::uuid, ${tx.json(input as never)}
        ) as result
      `;
      return rows[0]?.result ?? null;
    });
  }

  async command(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult> {
    const typed = input as { body?: Record<string, unknown> };
    let body = typed.body ?? {};

    if (operation === "issueInvitation") {
      const token = opaqueToken();
      const tokenHash = await sha256Hex(token);
      body = { ...body, tokenHash };
      const result = await this.execute(
        context,
        operation,
        resourceId,
        { ...typed, body },
        reservation,
      );
      if (result.outcome !== "ok") return result;
      return {
        outcome: "ok",
        response: { ...(result.response as Record<string, unknown>), token },
      };
    }

    if (operation === "acceptInvitation") {
      const token = body["token"];
      if (typeof token !== "string") return { outcome: "invalid" };
      const tokenHash = await sha256Hex(token);
      return await this.execute(
        context,
        operation,
        resourceId,
        { ...typed, body: { tokenHash } },
        reservation,
      );
    }

    return await this.execute(context, operation, resourceId, input, reservation);
  }

  private async execute(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: CatalogueCommandResult }[]>`
        select private.api042_command(
          ${operation}, ${resourceId}::uuid, ${tx.json(input as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}
