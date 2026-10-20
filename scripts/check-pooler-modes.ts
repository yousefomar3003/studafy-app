/**
 * The worker stall of 2026-10-20, measured: postgres.js pipelining through
 * Supabase's transaction pooler against its session pooler, and
 * DATABASE_POOLER_MODE=session's rewrite of a 6543 URL (packages/config,
 * databasePooler.ts).
 *
 * Runs against a THROWAWAY local Supabase stack with Supavisor on, never the
 * owner's local stack (54321/54322) and never a hosted database: every URL
 * must be given explicitly and point at this machine, and the owner's ports
 * are refused. CI cannot run it (its stack excludes Supavisor); the numbers
 * go in the PR.
 *
 *   POOLER_TRANSACTION_URL  Supavisor transaction port (container 6543)
 *   POOLER_SESSION_URL      Supavisor session port (container 5432)
 *   POOLER_DIRECT_URL       optional, the same stack's Postgres, to count
 *                           stranded server sessions and end them
 *
 *   bun --no-env-file scripts/check-pooler-modes.ts
 *
 * (a) transaction mode, prepare off, default pipelining, 2 connections:
 *     40 concurrent statements, three rounds; hung statements are counted.
 * (b) session mode, postgres.js defaults, 2 connections: the same 40, then
 *     1,000 in batches of 40, then 100 transactions (set_config + reads)
 *     mixed with 200 plain statements, all at once.
 * (c) databaseClientConfig (what createDatabase uses) given a
 *     *.pooler.supabase.com:6543 URL and poolerMode "session": the socket
 *     is redirected to this machine by the port the client asks for (5432
 *     to the session port, 6543 to the transaction port), so the rewrite is
 *     what decides which pooler the load reaches. It then runs (b).
 *
 * Exits 1 when (b) or (c) fail. (a) only reports.
 */
import net from "node:net";
import postgres, { type Sql } from "postgres";
import { databaseClientConfig } from "../packages/database/src/index";

const LOOPBACK = new Set(["127.0.0.1", "localhost", "::1", "[::1]"]);
const OWNER_PORTS = new Set([54321, 54322, 54323, 54324, 54329]);
const STATEMENT_TIMEOUT_MS = 10_000;

function requireLocal(name: string, optional = false): URL | undefined {
  const value = process.env[name];
  if (!value) {
    if (optional) return undefined;
    throw new Error(`${name} is required (a throwaway stack's URL)`);
  }
  const url = new URL(value);
  const port = Number(url.port || 5432);
  if (!LOOPBACK.has(url.hostname)) {
    throw new Error(`${name} must point at this machine, not ${url.hostname}`);
  }
  if (OWNER_PORTS.has(port)) {
    throw new Error(`${name} is on ${port}: that is the owner's local stack`);
  }
  return url;
}

type Outcome = "ok" | "hung" | "error";

async function settle(
  promise: Promise<unknown>,
  check: (value: unknown) => boolean,
): Promise<Outcome> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<Outcome>((resolve) => {
    timer = setTimeout(() => resolve("hung"), STATEMENT_TIMEOUT_MS);
  });
  try {
    return await Promise.race([
      promise.then((value) => (check(value) ? "ok" : "error"), () => "error"),
      timeout,
    ]) as Outcome;
  } finally {
    clearTimeout(timer);
  }
}

interface Tally {
  ok: number;
  hung: number;
  error: number;
}

function tally(outcomes: Outcome[]): Tally {
  return {
    ok: outcomes.filter((o) => o === "ok").length,
    hung: outcomes.filter((o) => o === "hung").length,
    error: outcomes.filter((o) => o === "error").length,
  };
}

/**
 * [count] concurrent short statements, alternating between statements with
 * no parameters (as the pollers' fixed queries; these are the ones that
 * strand in transaction mode) and statements with one, which must return
 * their own number.
 */
function burst(sql: Sql, count: number, offset = 0): Promise<Outcome>[] {
  return Array.from({ length: count }, (_, index) => {
    const n = offset + index;
    if (n % 2 === 0) {
      return settle(
        sql`select 1 as one, pg_sleep(0.002)`,
        (rows) => (rows as { one: number }[])[0]?.one === 1,
      );
    }
    return settle(
      sql`select ${n}::int as n, pg_sleep(${0.002 * (n % 4)}::float8)`,
      (rows) => (rows as { n: number }[])[0]?.n === n,
    );
  });
}

/** A transaction that sets a local setting and reads it back twice. */
function transaction(sql: Sql, n: number): Promise<Outcome> {
  const token = `t${n}`;
  return settle(
    sql.begin(async (tx) => {
      await tx`select set_config('studafy.pooler_check', ${token}, true)`;
      const [first] = await tx<{ value: string }[]>`
        select current_setting('studafy.pooler_check') as value`;
      await tx`select pg_sleep(${0.002 * (n % 3)}::float8)`;
      const [second] = await tx<{ value: string }[]>`
        select current_setting('studafy.pooler_check') as value`;
      return [first?.value, second?.value];
    }),
    (values) =>
      Array.isArray(values) && values[0] === token && values[1] === token,
  );
}

async function sessionLoad(sql: Sql): Promise<Record<string, Tally>> {
  const results: Record<string, Tally> = {};
  results.burst40 = tally(await Promise.all(burst(sql, 40)));
  const batched: Outcome[] = [];
  for (let batch = 0; batch < 25; batch++) {
    batched.push(...await Promise.all(burst(sql, 40, batch * 40)));
  }
  results.batched1000 = tally(batched);
  const mixed = [
    ...Array.from({ length: 100 }, (_, n) => transaction(sql, n)),
    ...burst(sql, 200, 10_000),
  ];
  const settled = await Promise.all(mixed);
  results.transactions100 = tally(settled.slice(0, 100));
  results.mixedPlain200 = tally(settled.slice(100));
  // A local setting must not outlive its transaction on the connection.
  const leaked = await settle(
    sql`select current_setting('studafy.pooler_check', true) as value`,
    (rows) => {
      const value = (rows as { value: string | null }[])[0]?.value;
      return value === null || value === "";
    },
  );
  results.settingNotLeaked = tally([leaked]);
  return results;
}

function passed(results: Record<string, Tally>): boolean {
  return Object.values(results).every((t) => t.hung === 0 && t.error === 0);
}

async function strandedSessions(direct: Sql | undefined) {
  if (!direct) return null;
  const rows = await direct<
    { state: string; wait_event: string | null; count: number }[]
  >`
    select state, wait_event, count(*)::int as count
    from pg_stat_activity
    where backend_type = 'client backend'
      and pid <> pg_backend_pid()
      and usename = 'postgres'
      and application_name = 'Supavisor'
    group by state, wait_event
    order by state, wait_event`;
  return rows.map((r) => ({ ...r }));
}

async function endStranded(direct: Sql | undefined): Promise<number> {
  if (!direct) return 0;
  const rows = await direct<{ pid: number }[]>`
    select pg_terminate_backend(pid) as ended, pid
    from pg_stat_activity
    where backend_type = 'client backend'
      and pid <> pg_backend_pid()
      and application_name = 'Supavisor'
      and state in ('active', 'idle in transaction')
      and wait_event = 'ClientRead'`;
  return rows.length;
}

/**
 * A postgres.js socket factory that connects by the port the client asks
 * for, never resolving the URL's host, and records each port.
 */
function redirect(routes: Map<number, URL>, asked: number[]): never {
  return ((options: { port: number[] }) =>
    new Promise<net.Socket>((resolve, reject) => {
      const port = options.port[0]!;
      asked.push(port);
      const route = routes.get(port);
      if (!route) return reject(new Error(`no route for port ${port}`));
      const socket = net.connect(
        Number(route.port),
        route.hostname,
        () => resolve(socket),
      );
      socket.once("error", reject);
    })) as never;
}

const transactionUrl = requireLocal("POOLER_TRANSACTION_URL")!;
const sessionUrl = requireLocal("POOLER_SESSION_URL")!;
const directUrl = requireLocal("POOLER_DIRECT_URL", true);
const direct = directUrl
  ? postgres(directUrl.toString(), { max: 1, ssl: false })
  : undefined;

const report: Record<string, unknown> = {};

// (a) The stall: transaction mode with the transaction-pooler client
// settings createDatabase used before (prepare off, pipelining on).
const rounds: Tally[] = [];
for (let round = 0; round < 3; round++) {
  const sql = postgres(transactionUrl.toString(), {
    max: 2,
    prepare: false,
    ssl: false,
    connect_timeout: 5,
  });
  rounds.push(tally(await Promise.all(burst(sql, 40))));
  report[`a_round${round + 1}_server`] = await strandedSessions(direct);
  report[`a_round${round + 1}_ended_stranded`] = await endStranded(direct);
  await sql.end({ timeout: 1 }).catch(() => undefined);
}
report.a_transaction_mode_40_concurrent_on_2_connections = rounds;

// (b) Session mode, postgres.js defaults (prepare on, pipelining on).
{
  const sql = postgres(sessionUrl.toString(), {
    max: 2,
    ssl: false,
    connect_timeout: 5,
  });
  report.b_session_mode = await sessionLoad(sql);
  report.b_server_after = await strandedSessions(direct);
  await sql.end({ timeout: 5 });
}

// (c) The rewrite decides the pooler: a 6543 Supabase-style URL with the
// throwaway stack's credentials, through databaseClientConfig.
{
  const fakeHost = "aws-0-local-check-1.pooler.supabase.com";
  const pooled = new URL(transactionUrl.toString());
  pooled.hostname = fakeHost;
  pooled.port = "6543";
  pooled.searchParams.set("sslmode", "disable");
  const config = databaseClientConfig(pooled.toString(), {
    max: 2,
    poolerMode: "session",
  });
  const asked: number[] = [];
  const routes = new Map<number, URL>([
    [5432, sessionUrl],
    [6543, transactionUrl],
  ]);
  const sql = postgres(config.url, {
    ...config.options,
    // Never resolves the fake host: connects by the port the client asks for.
    socket: redirect(routes, asked),
  });
  const parsed = sql.options as unknown as {
    prepare: boolean;
    max_pipeline: number;
  };
  report.c_target = config.target;
  report.c_client = {
    prepare: parsed.prepare,
    max_pipeline: parsed.max_pipeline,
  };
  const results = await sessionLoad(sql);
  report.c_rewritten_session = results;
  report.c_ports_asked = [...new Set(asked)];
  report.c_connections_opened = asked.length;
  await sql.end({ timeout: 5 });

  // Control: the same URL and redirect without the rewrite reaches the
  // transaction pooler, and strands statements again.
  const control = databaseClientConfig(pooled.toString(), { max: 2 });
  const controlAsked: number[] = [];
  const controlSql = postgres(control.url, {
    ...control.options,
    socket: redirect(routes, controlAsked),
  });
  report.c_control_transaction_mode = {
    target: control.target,
    burst40: tally(await Promise.all(burst(controlSql, 40))),
    ports_asked: [...new Set(controlAsked)],
  };
  report.c_control_ended_stranded = await endStranded(direct);
  await controlSql.end({ timeout: 1 }).catch(() => undefined);
}

await direct?.end({ timeout: 5 });

const b = report.b_session_mode as Record<string, Tally>;
const c = report.c_rewritten_session as Record<string, Tally>;
const cTarget = report.c_target as { port: number; rewritten: boolean };
const cPorts = report.c_ports_asked as number[];
const ok = passed(b) && passed(c) && cTarget.port === 5432 &&
  cTarget.rewritten && cPorts.length === 1 && cPorts[0] === 5432;

console.log(JSON.stringify(report, null, 2));
console.log(ok ? "PASS: (b) and (c)" : "FAIL: (b) or (c)");
process.exit(ok ? 0 : 1);
