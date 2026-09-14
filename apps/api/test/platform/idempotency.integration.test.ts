import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;
const USER = "4a400000-0000-4000-8000-000000000001";
const OTHER_USER = "4a400000-0000-4000-8000-000000000002";
const SCHOOL = "4a400000-0000-4000-8000-000000000003";

let sql: Sql;
let repository: PostgresIdempotencyRepository;

async function seed() {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values
      (${USER}::uuid, 'api040.a@synthetic.studafy.test', 'synthetic', 'authenticated', 'authenticated', now(), now(), now(),
       '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-040 A"}'::jsonb),
      (${OTHER_USER}::uuid, 'api040.b@synthetic.studafy.test', 'synthetic', 'authenticated', 'authenticated', now(), now(), now(),
       '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-040 B"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'API-040 School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status='active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status)
    values (${SCHOOL}::uuid, ${USER}::uuid, 'teacher', true, 'active')
    on conflict (school_id, user_id, role) do update set active=true, status='active'
  `;
}

async function cleanup() {
  await sql`delete from public.idempotency_records where actor_id in (${USER}::uuid, ${OTHER_USER}::uuid)`;
  await sql`delete from public.memberships where user_id in (${USER}::uuid, ${OTHER_USER}::uuid)`;
  await sql`delete from public.schools where id=${SCHOOL}::uuid`;
  await sql`delete from auth.users where id in (${USER}::uuid, ${OTHER_USER}::uuid)`;
}

function input(key: string, requestHash = "a".repeat(64)) {
  return {
    schoolId: SCHOOL,
    scope: "v1.api040_integration",
    key,
    requestHash,
    retentionSeconds: 86_400,
    leaseSeconds: 15,
  };
}

suite("PostgreSQL idempotency repository", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!, { max: 5 });
    await cleanup();
    await seed();
    repository = new PostgresIdempotencyRepository(sql);
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("concurrent reservations serialize to one winner", async () => {
    const [a, b] = await Promise.all([
      repository.reserve(USER, input("concurrent-key-00001")),
      repository.reserve(USER, input("concurrent-key-00001")),
    ]);
    expect([a.outcome, b.outcome].sort()).toEqual(["inProgress", "reserved"]);
  });

  test("completion replays exact status/body and mismatches conflict", async () => {
    const reserved = await repository.reserve(
      USER,
      input("complete-key-000001"),
    );
    expect(reserved.outcome).toBe("reserved");
    if (reserved.outcome !== "reserved") return;
    expect(
      await repository.complete(USER, reserved.id, reserved.generation, 202, {
        accepted: true,
      }),
    ).toBe(true);
    expect(await repository.reserve(USER, input("complete-key-000001")))
      .toEqual({
        outcome: "replay",
        responseStatus: 202,
        responseBody: { accepted: true },
      });
    expect(
      (await repository.reserve(
        USER,
        input("complete-key-000001", "b".repeat(64)),
      )).outcome,
    )
      .toBe("mismatch");
  });

  test("actor derivation and membership checks prevent cross-scope takeover", async () => {
    expect(
      (await repository.reserve(OTHER_USER, input("tenant-key-0000001")))
        .outcome,
    ).toBe("denied");
    expect(
      (await repository.reserve(USER, input("tenant-key-0000001"))).outcome,
    ).toBe("reserved");
  });

  test("an expired lease increments generation and rejects stale completion", async () => {
    const first = await repository.reserve(USER, input("lease-key-00000001"));
    expect(first.outcome).toBe("reserved");
    if (first.outcome !== "reserved") return;
    await sql`update public.idempotency_records set lease_expires_at=now()-interval '1 second' where id=${first.id}::uuid`;
    const second = await repository.reserve(USER, input("lease-key-00000001"));
    expect(second.outcome).toBe("reserved");
    if (second.outcome !== "reserved") return;
    expect(second.generation).toBe(first.generation + 1);
    expect(await repository.complete(USER, first.id, first.generation, 200, {}))
      .toBe(false);
    expect(
      await repository.complete(USER, second.id, second.generation, 200, {
        current: true,
      }),
    ).toBe(true);
  });
});
