/**
 * The request's identity travels with the call in one statement
 * (selectAsActor / selectInRequestContext): one round trip instead of four.
 * These prove it is still set before the call runs and never outlives it,
 * on a single pooled connection where a leak would show.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import { integrationSuite } from "@studafy/test-support";
import { selectAsActor } from "../../src/auth/context";
import { selectInRequestContext } from "../../src/platform/dbContext";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const SUBJECT = "5f490000-0000-4000-8000-0000000000a1";
const SCHOOL = "5f490000-0000-4000-8000-0000000000b1";

suite("single-statement request context", () => {
  let sql: Sql;

  beforeAll(() => {
    // One connection: anything left behind would be seen by the next query.
    sql = createDatabase(databaseUrl!, { max: 1 });
  });

  afterAll(async () => {
    await sql.end({ timeout: 5 });
  });

  test("the actor is set for the call and gone after it", async () => {
    const seen = await selectAsActor<string>(
      sql,
      SUBJECT,
      "current_setting('request.jwt.claim.sub', true)",
      [],
    );
    expect(seen).toBe(SUBJECT);
    const after = await sql<{ value: string | null }[]>`
      select nullif(current_setting('request.jwt.claim.sub', true), '') as value
    `;
    expect(after[0]?.value ?? null).toBeNull();
  });

  test("auth.uid() inside a function sees the actor", async () => {
    const uid = await selectAsActor<string>(
      sql,
      SUBJECT,
      "auth.uid()::text",
      [],
    );
    expect(uid).toBe(SUBJECT);
  });

  test("tenant and request id travel with the dispatcher call", async () => {
    const seen = await selectInRequestContext<string>(
      sql,
      { subject: SUBJECT, schoolId: SCHOOL, requestId: "req-single-1" },
      "current_setting('request.jwt.claim.sub', true) || '|' || " +
        "current_setting('studafy.school_id', true) || '|' || " +
        "current_setting('studafy.request_id', true) || '|' || $1",
      ["arg"],
    );
    expect(seen).toBe(`${SUBJECT}|${SCHOOL}|req-single-1|arg`);
    const after = await sql<
      { school: string | null; request: string | null }[]
    >`
      select nullif(current_setting('studafy.school_id', true), '') as school,
        nullif(current_setting('studafy.request_id', true), '') as request
    `;
    expect(after[0]).toEqual({ school: null, request: null });
  });

  test("a failing call leaves nothing behind either", async () => {
    await expect(
      selectAsActor(sql, SUBJECT, "(1/0)::text", []),
    ).rejects.toThrow();
    const after = await sql<{ value: string | null }[]>`
      select nullif(current_setting('request.jwt.claim.sub', true), '') as value
    `;
    expect(after[0]?.value ?? null).toBeNull();
  });
});
