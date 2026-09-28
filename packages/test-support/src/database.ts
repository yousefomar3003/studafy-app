import type { Sql } from "@studafy/database";

/**
 * Database fixtures for integration suites.
 *
 * Every suite seeds its own schools and accounts and must leave the database
 * as it found it, including a developer's local one. Hand-written cleanups
 * listed tables in delete order and lifted each append-only trigger by name;
 * they drifted as tables were added, and one suite left its school behind on
 * every run. This removes a fixture by what the schema says references it, so
 * a new table is covered the day it is added.
 */

const databaseUrl = process.env["DATABASE_URL"];

/** `describe` when a database is configured, `describe.skip` otherwise. */
export function integrationSuite<D>(describe: D & { skip: D }): D {
  return databaseUrl ? describe : describe.skip;
}

export interface FixtureIds {
  /** Schools the suite created; everything carrying their id goes too. */
  schoolIds?: readonly string[];
  /** Accounts the suite created; everything that references them goes too. */
  userIds?: readonly string[];
  /**
   * Requests whose records outlive their account by design (a failed
   * sign-in has no account to hang from): their rows go too.
   */
  requestIds?: readonly string[];
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Tables are only ever read from these schemas. */
const SCHEMAS = ["public", "private"];

/**
 * Deletes a fixture: every row in a tenant table carrying one of its schools,
 * every row that references one of its accounts or students, then the
 * schools, profiles and auth users themselves.
 *
 * Runs in one transaction with `session_replication_role = replica`, which
 * suspends triggers and foreign-key checks for that transaction only: the
 * append-only guards (audit events, grade history, submission attempts) are
 * exactly what a teardown has to get past, and ordering no longer matters
 * because nothing is left pointing at a deleted row.
 */
export async function removeFixtures(
  sql: Sql,
  fixtures: FixtureIds,
): Promise<void> {
  const schools = [...(fixtures.schoolIds ?? [])];
  const users = [...(fixtures.userIds ?? [])];
  const requests = [...(fixtures.requestIds ?? [])];
  if (schools.length === 0 && users.length === 0 && requests.length === 0) {
    return;
  }

  await sql.begin(async (tx) => {
    await tx`set local session_replication_role = replica`;

    const students = (await tx<{ id: string }[]>`
      select id::text from public.students
      where school_id = any(${schools}::uuid[])
    `).map((row) => row.id);

    // Tenant tables: anything with a school_id column.
    const tenantTables = await tx<{ schema: string; table: string }[]>`
      select n.nspname as schema, c.relname as table
      from pg_attribute a
      join pg_class c on c.oid = a.attrelid
      join pg_namespace n on n.oid = c.relnamespace
      where a.attname = 'school_id' and not a.attisdropped
        and c.relkind in ('r', 'p') and n.nspname = any(${SCHEMAS})
    `;
    // The ids of everything deleted, so audit events about them go too:
    // a background job records some with no school and no actor.
    const deleted: string[] = [];
    const remember = (rows: { id: string | null }[]) => {
      for (const row of rows) {
        if (row.id && UUID.test(row.id)) deleted.push(row.id);
      }
    };
    for (const { schema, table } of tenantTables) {
      remember(
        await tx.unsafe(
          `delete from "${schema}"."${table}" t where school_id = any($1::uuid[])
           returning to_jsonb(t)->>'id' as id`,
          [schools],
        ) as { id: string | null }[],
      );
    }

    // Anything referencing one of the accounts or students by foreign key.
    const references = await tx<
      { schema: string; table: string; column: string; target: string }[]
    >`
      select n.nspname as schema, c.relname as table, a.attname as column,
        k.confrelid::regclass::text as target
      from pg_constraint k
      join pg_class c on c.oid = k.conrelid
      join pg_namespace n on n.oid = c.relnamespace
      join pg_attribute a on a.attrelid = k.conrelid and a.attnum = k.conkey[1]
      where k.contype = 'f' and array_length(k.conkey, 1) = 1
        and n.nspname = any(${SCHEMAS})
        and k.confrelid in (
          'auth.users'::regclass, 'public.profiles'::regclass,
          'public.students'::regclass
        )
      union
      -- Account columns kept without a foreign key on purpose, so history
      -- outlives the account (security events): a fixture's still go.
      select n.nspname, c.relname, a.attname, 'auth.users'
      from pg_attribute a
      join pg_class c on c.oid = a.attrelid
      join pg_namespace n on n.oid = c.relnamespace
      where a.attname in ('user_id', 'actor_id') and not a.attisdropped
        and a.atttypid = 'uuid'::regtype and c.relkind in ('r', 'p')
        and n.nspname = any(${SCHEMAS})
    `;
    for (const { schema, table, column, target } of references) {
      const ids = target === "public.students" ? students : users;
      if (ids.length === 0) continue;
      remember(
        await tx.unsafe(
          `delete from "${schema}"."${table}" t where "${column}" = any($1::uuid[])
           returning to_jsonb(t)->>'id' as id`,
          [ids],
        ) as { id: string | null }[],
      );
    }

    if (deleted.length > 0) {
      await tx`delete from public.audit_events where entity_id = any(${deleted}::uuid[])`;
    }
    if (requests.length > 0) {
      await tx`delete from public.audit_events where request_id = any(${requests})`;
      await tx`delete from public.auth_security_events where request_id = any(${requests}::uuid[])`;
    }

    await tx`delete from public.schools where id = any(${schools}::uuid[])`;
    await tx`delete from public.profiles where id = any(${users}::uuid[])`;
    await tx`delete from auth.identities where user_id = any(${users}::uuid[])`;
    await tx`delete from auth.users where id = any(${users}::uuid[])`;
  });
}
