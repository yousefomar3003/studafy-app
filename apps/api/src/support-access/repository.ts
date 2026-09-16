import type { Sql } from "@studafy/database";
import { withRequestContext } from "../auth/context";
import type {
  CatalogueCommandResult,
  CatalogueRepository,
  RequestDbContext,
} from "../platform/catalogueRoutes";

export type SupportAccessRepository = CatalogueRepository;

/**
 * The only module that needs the actor's real AAL2 status inside the SQL
 * dispatcher: instructions.md section 7 requires MFA for support access
 * unconditionally, not by role policy like requireAal2() elsewhere. context
 * carries it (RequestDbContext.aal2); this repository is what actually
 * forwards it into the command input, since the generic dispatcher only
 * sends {body, params, responseStatus}.
 */
export class PostgresSupportAccessRepository implements CatalogueRepository {
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
    const withAal2 = { ...(input as Record<string, unknown>), aal2: context.aal2 };
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
