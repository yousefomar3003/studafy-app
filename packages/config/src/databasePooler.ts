/**
 * Which Supabase pooler mode the API and worker connect through
 * (DATABASE_POOLER_MODE, the worker stall of 2026-10-20).
 *
 * Supabase's pooler (Supavisor) listens on two ports of the same host with
 * the same user (`role.projectref`) and password: 6543 is transaction mode,
 * 5432 session mode. postgres.js pipelines statements when every pooled
 * connection is busy, and through transaction mode a pipelined statement can
 * be stranded half-sent: the server session waits in `ClientRead` inside an
 * open transaction forever, and the client connection is lost. Session mode
 * gives each client connection its own server connection, so pipelining is
 * safe there.
 *
 * The hosted DATABASE_URLs are Fly secrets that cannot be read back, so the
 * mode is switched here rather than by writing new URLs:
 *
 * - `transaction` (default): connect to DATABASE_URL exactly as written. A
 *   URL on 6543 gets the transaction-pooler client settings
 *   (`prepare: false`, packages/database).
 * - `session`: a Supabase transaction-pooler URL (host
 *   `*.pooler.supabase.com`, port 6543) is moved to port 5432 on the same
 *   host. Any other URL that is not on 6543 (a direct `db.*.supabase.co`
 *   connection, the session pooler itself, a local stack) is used as is: it
 *   is already a session connection. A URL on 6543 that is not a Supabase
 *   pooler host (the dedicated PgBouncer, a self-hosted pooler) is refused,
 *   because session mode was asked for and cannot be given.
 */

export const DATABASE_POOLER_MODES = ["transaction", "session"] as const;
export type DatabasePoolerMode = (typeof DATABASE_POOLER_MODES)[number];

/** Supabase's pooler ports: one host, two modes. */
export const TRANSACTION_POOLER_PORT = 6543;
export const SESSION_POOLER_PORT = 5432;
const DEFAULT_POSTGRES_PORT = 5432;

/** Supavisor's shared pooler hosts, e.g. aws-1-eu-central-1.pooler.supabase.com. */
export function isSupabasePoolerHost(hostname: string): boolean {
  return hostname.toLowerCase().endsWith(".pooler.supabase.com");
}

/** Where a client actually connects, after DATABASE_POOLER_MODE. */
export interface DatabaseConnectionTarget {
  /** The URL to connect to. Carries credentials: never log it. */
  url: string;
  /** The effective port. */
  port: number;
  mode: DatabasePoolerMode;
  /** True when the port was moved from 6543 to 5432. */
  rewritten: boolean;
  /** True when the effective connection is a transaction pooler (port 6543). */
  transactionPooler: boolean;
}

export class DatabasePoolerModeError extends Error {
  override readonly name = "DatabasePoolerModeError";
}

function portOf(parsed: URL): number {
  return parsed.port ? Number(parsed.port) : DEFAULT_POSTGRES_PORT;
}

/**
 * Why [url] cannot be used in [mode], or undefined when it can. Only
 * `session` with a 6543 URL that is not a Supabase pooler host is refused.
 */
export function databasePoolerProblem(
  url: string,
  mode: DatabasePoolerMode,
): string | undefined {
  if (mode !== "session") return undefined;
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return undefined;
  }
  if (
    portOf(parsed) === TRANSACTION_POOLER_PORT &&
    !isSupabasePoolerHost(parsed.hostname)
  ) {
    return "session mode moves only a Supabase pooler URL (*.pooler.supabase.com) from port 6543 to 5432; this URL is on 6543 at another host, so it would stay on a transaction pooler. Use a session-mode URL, or DATABASE_POOLER_MODE=transaction.";
  }
  return undefined;
}

/**
 * The connection [url] makes in [mode]. Throws DatabasePoolerModeError for
 * the combination `databasePoolerProblem` reports; config validation refuses
 * it first, so a process never reaches that.
 */
export function resolveDatabaseConnection(
  url: string,
  mode: DatabasePoolerMode = "transaction",
): DatabaseConnectionTarget {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    // Not a URL postgres.js and this agree on; leave it to the client.
    return {
      url,
      port: DEFAULT_POSTGRES_PORT,
      mode,
      rewritten: false,
      transactionPooler: false,
    };
  }
  const problem = databasePoolerProblem(url, mode);
  if (problem) throw new DatabasePoolerModeError(problem);
  const port = portOf(parsed);
  if (
    mode === "session" && port === TRANSACTION_POOLER_PORT &&
    isSupabasePoolerHost(parsed.hostname)
  ) {
    parsed.port = String(SESSION_POOLER_PORT);
    return {
      url: parsed.toString(),
      port: SESSION_POOLER_PORT,
      mode,
      rewritten: true,
      transactionPooler: false,
    };
  }
  return {
    url,
    port,
    mode,
    rewritten: false,
    transactionPooler: port === TRANSACTION_POOLER_PORT,
  };
}

/**
 * The log-safe part of the target: mode and effective port, never the URL
 * or its credentials.
 */
export function describeDatabaseConnection(
  url: string | undefined,
  mode: DatabasePoolerMode,
): Record<string, unknown> | null {
  if (!url) return null;
  try {
    const target = resolveDatabaseConnection(url, mode);
    return {
      pooler_mode: target.mode,
      port: target.port,
      rewritten_from_transaction_pooler: target.rewritten,
      transaction_pooler: target.transactionPooler,
    };
  } catch {
    return { pooler_mode: mode, port: null, refused: true };
  }
}
