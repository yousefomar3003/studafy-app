import type { Sql } from "@studafy/database";
import { withRequestContext } from "../platform/dbContext";
import type {
  CatalogueCommandResult,
  CatalogueRepository,
} from "../platform/dispatchRepository";
import type { RequestDbContext } from "../platform/dbContext";

export type SchoolAdminRepository = CatalogueRepository;

/**
 * S1 school-admin module is command-only: every operation in its catalogue
 * slice is a POST. `query` exists to satisfy CatalogueRepository and is
 * never reached by createCatalogueRoutes, since no GET route selects it.
 */
export class PostgresSchoolAdminRepository implements CatalogueRepository {
  constructor(readonly sql: Sql) {}

  query(): Promise<unknown> {
    throw new Error("school-admin module has no query operations");
  }

  async command(
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
