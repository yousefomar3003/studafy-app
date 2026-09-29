import type { Sql } from "@studafy/database";
import { type RequestDbContext, withRequestContext } from "./dbContext";

/** What a SQL dispatcher answered for a command. */
export interface CatalogueCommandResult {
  outcome:
    | "ok"
    | "not_found"
    | "forbidden"
    | "version_conflict"
    | "invalid_state"
    | "window_closed"
    | "invalid";
  response?: unknown;
}

/**
 * The port a catalogue-driven module's repository implements: one query and
 * one command entry point, each forwarding an operation to the module's SQL
 * dispatcher.
 */
export interface CatalogueRepository {
  query(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
  ): Promise<unknown>;
  command(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult>;
}

/** A pair of SQL dispatchers that one or more modules forward to. */
export interface SqlDispatcher {
  query: "private.api041_query" | "private.api042_query";
  command: "private.api041_command" | "private.api042_command";
  /**
   * Whether the actor's real AAL2 status is added to each command's input.
   * The generic route sends only {body, params, responseStatus}; modules
   * whose SQL requires a second factor (support access, moderation access,
   * legal holds) need to know whether one was presented.
   */
  forwardAal2?: boolean;
}

/** Terms, classes, lessons, assignments, assessments, grades, attendance. */
export const ACADEMIC: SqlDispatcher = {
  query: "private.api041_query",
  command: "private.api041_command",
};

/** Accounts, family, messaging, meetings, notifications, school admin. */
export const SCHOOL_OPERATIONS: SqlDispatcher = {
  query: "private.api042_query",
  command: "private.api042_command",
};

/** School operations whose commands are gated on a second factor. */
export const SCHOOL_OPERATIONS_WITH_AAL2: SqlDispatcher = {
  ...SCHOOL_OPERATIONS,
  forwardAal2: true,
};

/**
 * The repository every catalogue module uses: each operation goes, inside
 * the request's identity and school, to the module's SQL dispatcher. The
 * function names come from the fixed set above, never from input.
 */
export class PostgresDispatchRepository implements CatalogueRepository {
  constructor(
    readonly sql: Sql,
    private readonly dispatcher: SqlDispatcher,
  ) {}

  async query(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
  ): Promise<unknown> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx.unsafe<{ result: unknown }[]>(
        `select ${this.dispatcher.query}($1, $2::uuid, $3::jsonb) as result`,
        [operation, resourceId, tx.json((input ?? null) as never)],
      );
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
    const payload = this.dispatcher.forwardAal2
      ? { ...(input as Record<string, unknown>), aal2: context.aal2 }
      : input;
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx.unsafe<{ result: CatalogueCommandResult }[]>(
        `select ${this.dispatcher.command}($1, $2::uuid, $3::jsonb, $4::uuid, $5)
           as result`,
        [
          operation,
          resourceId,
          tx.json((payload ?? null) as never),
          reservation.id,
          reservation.generation,
        ],
      );
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}
