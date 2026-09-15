import type { Sql } from "@studafy/database";
import { withRequestContext } from "../auth/context";
import type {
  CatalogueCommandResult,
  CatalogueRepository,
  RequestDbContext,
} from "../platform/catalogueRoutes";

export interface AcademicPageResult {
  items: unknown[];
  nextPosition: string | null;
}

export type AcademicCommandResult = CatalogueCommandResult;
export type AcademicRepository = CatalogueRepository;
export type { RequestDbContext };

export class PostgresAcademicRepository implements AcademicRepository {
  constructor(readonly sql: Sql) {}

  async query(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
  ): Promise<unknown> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: unknown }[]>`
        select private.api041_query(
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
  ): Promise<AcademicCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: AcademicCommandResult }[]>`
        select private.api041_command(
          ${operation}, ${resourceId}::uuid, ${tx.json(input as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}
