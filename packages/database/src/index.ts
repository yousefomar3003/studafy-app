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
 * Whether [url] goes through Supabase's transaction pooler (port 6543).
 * There a connection is shared between transactions, so a statement
 * prepared on one may be gone on the next: named prepared statements must
 * be off. Session mode (5432) and direct connections keep them.
 */
export function usesTransactionPooler(url: string): boolean {
  try {
    return new URL(url).port === "6543";
  } catch {
    return false;
  }
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
    ...(usesTransactionPooler(url) ? { prepare: false } : {}),
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
