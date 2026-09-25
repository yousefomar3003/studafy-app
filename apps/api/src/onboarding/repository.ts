import type { Sql } from "@studafy/database";
import { withRequestContext } from "../auth/context";
import type {
  CatalogueCommandResult,
  CatalogueRepository,
  RequestDbContext,
} from "../platform/catalogueRoutes";

export type OnboardingRepository = CatalogueRepository;

/**
 * Self-serve teacher sign-up.
 *
 * The one command here is the only path to a first membership that does not
 * start from a platform operator, so everything it may do is decided in
 * `private.api045_command` rather than here: one workspace per account, the
 * teacher role rather than school_admin, and the first term created with it.
 * This class does no more than carry the call across.
 */
export class PostgresOnboardingRepository implements CatalogueRepository {
  constructor(readonly sql: Sql) {}

  // No query surface: nothing about a workspace is readable before it exists,
  // and afterwards it is ordinary school data behind the usual permissions.
  async query(): Promise<unknown> {
    return null;
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
        select private.api045_command(
          ${operation}, ${resourceId}::uuid, ${tx.json(input as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}
