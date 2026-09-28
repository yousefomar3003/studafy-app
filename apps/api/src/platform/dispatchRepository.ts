import type { RequestDbContext } from "./dbContext";

/**
 * The port a catalogue-driven module's repository implements: one query and
 * one command entry point, each forwarding an operation to the module's SQL
 * dispatcher.
 */
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
