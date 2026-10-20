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
  /**
   * PEM of the CA that signs the server's certificate (for Supabase, its
   * root CA). With it the certificate and host name are verified; without
   * it a remote connection is still encrypted, but not authenticated.
   */
  caCert?: string;
}

const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1", "::1", "[::1]"]);

/**
 * The TLS setting for [url] (security audit 2026-10-08).
 *
 * postgres.js connects in plaintext unless told otherwise, and the deployed
 * API and worker reach the Supabase pooler over the internet - password,
 * children's records and all. A connection that leaves this machine is now
 * encrypted by default. An explicit `sslmode` in the URL still wins (the
 * production config refuses `disable`), and a loopback host (the local
 * stack, CI) stays plaintext.
 */
export function databaseTls(
  url: string,
  caCert?: string,
): false | "require" | { ca: string; rejectUnauthorized: true } | undefined {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return undefined;
  }
  if (parsed.searchParams.has("sslmode") || parsed.searchParams.has("ssl")) {
    return undefined;
  }
  if (LOCAL_HOSTS.has(parsed.hostname)) return false;
  return caCert ? { ca: caCert, rejectUnauthorized: true } : "require";
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
 * Client settings for the transaction pooler (worker stall, 2026-10-20).
 *
 * - `prepare: false`: see `usesTransactionPooler`.
 * - `max_pipeline: 0`: one statement in flight per connection. When every
 *   pooled connection is busy, postgres.js otherwise writes the next
 *   statements onto a busy connection without waiting (pipelining). The
 *   pooler hands its server connection back as soon as the first statement
 *   finishes, while the next one has already reached that server, half
 *   sent: a parameterised statement goes as Parse/Describe/Flush and waits
 *   for the reply before sending Bind/Execute/Sync. The reply never comes
 *   back, so the query never settles, the server session stays `active` on
 *   ClientRead, and the client connection is lost for good. The worker lost
 *   its five connections that way and every poller stopped (the test copy
 *   was silent for 80 minutes), and the same request against the test
 *   pooler hung 34 of 40 statements. With nothing pipelined, each pooler
 *   transaction is one whole statement.
 */
const TRANSACTION_POOLER_OPTIONS = {
  prepare: false,
  max_pipeline: 0,
} as const;

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
  const ssl = databaseTls(url, options.caCert);
  return postgres(url, {
    ...(ssl === undefined ? {} : { ssl }),
    max: options.max ?? 5,
    idle_timeout: options.idleTimeout ?? 30,
    connect_timeout: options.connectTimeout ?? 5,
    ...(usesTransactionPooler(url) ? TRANSACTION_POOLER_OPTIONS : {}),
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
