import postgres, { type Options, type Sql } from "postgres";
import {
  type DatabasePoolerMode,
  resolveDatabaseConnection,
} from "@studafy/config";

export type { Sql };
export type { Database } from "./database.types.generated.ts";
export type { DatabasePoolerMode };

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
  /**
   * DATABASE_POOLER_MODE. `session` moves a Supabase transaction-pooler URL
   * (`*.pooler.supabase.com:6543`) to the session pooler on port 5432 of
   * the same host, same credentials (packages/config, databasePooler.ts).
   * Default `transaction`: the URL as written.
   */
  poolerMode?: DatabasePoolerMode;
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
 * be off. Session mode (5432) and direct connections keep them. Pass the
 * effective URL (`databaseClientConfig`), not DATABASE_URL as written: in
 * session mode a 6543 URL is moved to 5432.
 */
export function usesTransactionPooler(url: string): boolean {
  try {
    return new URL(url).port === "6543";
  } catch {
    return false;
  }
}

/**
 * Client settings for the transaction pooler, for anything still on 6543
 * (DATABASE_POOLER_MODE=transaction).
 *
 * - `prepare: false`: see `usesTransactionPooler`.
 *
 * Not `max_pipeline: 0` (#127, reverted in #128): postgres.js then never
 * reserves a connection for `sql.begin`, and every transaction fails with
 * UNSAFE_TRANSACTION. Pipelining through the transaction pooler can still
 * strand a statement (the worker stall of 2026-10-20), which is why the
 * deployed apps run in session mode, where postgres.js keeps its defaults.
 * The worker's pollers still report a stuck run as `poll_stalled`.
 */
const TRANSACTION_POOLER_OPTIONS = {
  prepare: false,
} as const;

/** What `createDatabase` hands postgres.js: the effective URL and options. */
export interface DatabaseClientConfig {
  /** Carries credentials: never log it. */
  url: string;
  options: Options<Record<string, never>>;
  /** Log-safe: the mode, the effective port, whether it was rewritten. */
  target: {
    poolerMode: DatabasePoolerMode;
    port: number;
    rewritten: boolean;
    transactionPooler: boolean;
  };
}

/**
 * The connection `createDatabase` makes for [url], without opening it.
 * Throws for `session` with a 6543 URL that is not a Supabase pooler host;
 * config validation refuses that combination first.
 */
export function databaseClientConfig(
  url: string,
  options: DatabaseOptions = {},
): DatabaseClientConfig {
  const target = resolveDatabaseConnection(
    url,
    options.poolerMode ?? "transaction",
  );
  // postgres.js takes both timeouts in seconds. They were previously
  // multiplied by 1000, which made the idle timeout roughly eight hours and
  // the connect timeout roughly 83 minutes: pooled connections were never
  // recycled and an unreachable host hung instead of failing fast.
  const ssl = databaseTls(target.url, options.caCert);
  return {
    url: target.url,
    options: {
      ...(ssl === undefined ? {} : { ssl }),
      max: options.max ?? 5,
      idle_timeout: options.idleTimeout ?? 30,
      connect_timeout: options.connectTimeout ?? 5,
      ...(usesTransactionPooler(target.url) ? TRANSACTION_POOLER_OPTIONS : {}),
    },
    target: {
      poolerMode: target.mode,
      port: target.port,
      rewritten: target.rewritten,
      transactionPooler: usesTransactionPooler(target.url),
    },
  };
}

/** Creates the Postgres client for [url] (`databaseClientConfig`). */
export function createDatabase(
  url: string,
  options: DatabaseOptions = {},
): Sql {
  const config = databaseClientConfig(url, options);
  return postgres(config.url, config.options);
}

/** Read-only health probe. Throws when the database is unreachable. */
export async function checkDatabase(sql: Sql): Promise<void> {
  await sql`select 1`;
}

/** Closes the pool, waiting up to `timeout` seconds for in-flight queries. */
export async function closeDatabase(sql: Sql, timeout = 5): Promise<void> {
  await sql.end({ timeout });
}
