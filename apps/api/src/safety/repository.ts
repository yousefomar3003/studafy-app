import type { Sql } from "@studafy/database";
import { withRequestContext } from "../auth/context";
import type {
  CatalogueCommandResult,
  CatalogueRepository,
  RequestDbContext,
} from "../platform/catalogueRoutes";

export type SafetyRepository = CatalogueRepository;

/**
 * SAFE-043's moderation-access and legal-hold commands are MFA-gated like the
 * support-access ones (instructions.md section 7: platform-operator actions
 * carry MFA and a ticket reference). The generic dispatcher only sends
 * {body, params, responseStatus} and does not know the actor's real AAL2
 * status; this repository is the one place that forwards it, exactly like
 * support-access/repository.ts.
 */
export class PostgresSafetyRepository implements CatalogueRepository {
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
    const withAal2 = {
      ...(input as Record<string, unknown>),
      aal2: context.aal2,
    };
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: CatalogueCommandResult }[]>`
        select private.api042_command(
          ${operation}, ${resourceId}::uuid, ${tx.json(withAal2 as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}
