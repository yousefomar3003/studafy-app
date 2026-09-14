import postgres, { type Sql } from "postgres";

export type { Sql };
export type { Database } from "./database.types.generated.ts";

export interface DatabaseOptions {
  /** Maximum pooled connections. */
  max?: number;
  /** Seconds of idle before a pooled connection is closed. */
  idleTimeout?: number;
  /** Seconds to wait for a connection before failing. */
  connectTimeout?: number;
}

/**
 * Creates a Postgres client for read-only connectivity smoke. No domain data
 * access exists yet; Phase 2+ adds query modules behind repositories.
 */
export function createDatabase(
  url: string,
  options: DatabaseOptions = {},
): Sql {
  // postgres.js takes both timeouts in seconds. They were previously
  // multiplied by 1000, which made the idle timeout roughly eight hours and
  // the connect timeout roughly 83 minutes: pooled connections were never
  // recycled and an unreachable host hung instead of failing fast.
  return postgres(url, {
    max: options.max ?? 5,
    idle_timeout: options.idleTimeout ?? 30,
    connect_timeout: options.connectTimeout ?? 5,
  });
}

/** Read-only health probe. Throws when the database is unreachable. */
export async function checkDatabase(sql: Sql): Promise<void> {
  await sql`select 1`;
}

/** Closes the pool, waiting up to `timeout` seconds for in-flight queries. */
export async function closeDatabase(sql: Sql, timeout = 5): Promise<void> {
  await sql.end({ timeout });
}
