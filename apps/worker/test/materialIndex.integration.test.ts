import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import type { PrivateFileStorage } from "@studafy/infrastructure";
import { integrationSuite, removeFixtures } from "@studafy/test-support";
import {
  createMaterialIndexProcessor,
  postgresMaterialQueue,
  startMaterialIndex,
} from "../src/processors/materialIndex";

// Material reading through Postgres (launch plan 7.1): a link added to a
// lesson becomes a document by trigger, the worker claims it, reads it and
// stores passages, all through the real SQL functions. The reading itself
// (PDF, Word, PowerPoint, pictures) is materialIndex.test.ts; who may read
// the passages is supabase/tests/grounded_material.sql.

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const SCHOOL = "7d000000-0000-4000-8000-0000000000f1";
const TEACHER = "7d000000-0000-4000-8000-0000000000a1";
const RESOURCE = "7d000000-0000-4000-8000-0000000000e1";
const VERSION = "7d000000-0000-4000-8000-0000000000e2";
const LINK = "7d000000-0000-4000-8000-0000000000e3";
const URL = "https://materials.synthetic.studafy.test/photosynthesis";

let sql: Sql;

const noStorage = {
  openObject: () => Promise.reject(new Error("no storage in this test")),
} as unknown as PrivateFileStorage;

async function cleanup() {
  await sql`
    delete from private.ai_material_chunks c using private.ai_material_docs d
    where c.doc_id = d.id and d.school_id = ${SCHOOL}`;
  await removeFixtures(sql, { schoolIds: [SCHOOL], userIds: [TEACHER] });
}

suite("material reading through Postgres", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await sql`
      insert into auth.users (id, email, aud, role)
      values (${TEACHER}, 'material.teacher@synthetic.studafy.test', 'authenticated', 'authenticated')
      on conflict (id) do nothing`;
    await sql`
      insert into public.profiles (id, display_name, status) values (${TEACHER}, 'Material Teacher', 'active')
      on conflict (id) do update set status = 'active'`;
    await sql`
      insert into public.schools (id, name, timezone, locale, status)
      values (${SCHOOL}, 'Material School', 'Asia/Amman', 'en', 'active')`;
    await sql`
      insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by)
      values (${RESOURCE}, ${SCHOOL}, 'Photosynthesis', 'lesson', 'published', 1, ${TEACHER})`;
    await sql`
      insert into public.resource_versions (id, school_id, resource_id, version, body, created_by)
      values (${VERSION}, ${SCHOOL}, ${RESOURCE}, 1, 'Lesson text', ${TEACHER})`;
    await sql`
      insert into public.content_links (id, school_id, title, url, role, resource_version_id, created_by)
      values (${LINK}, ${SCHOOL}, 'Reading', ${URL}, 'material', ${VERSION}, ${TEACHER})`;
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("a lesson link is claimed, read and stored as passages", async () => {
    const [doc] = await sql<{ id: string; state: string }[]>`
      select id::text, state from private.ai_material_docs where content_link_id = ${LINK}`;
    expect(doc?.state).toBe("pending");

    const fetched: string[] = [];
    const processor = createMaterialIndexProcessor({
      queue: postgresMaterialQueue(sql),
      storage: noStorage,
      assistant: null,
      limits: {
        ocrPagesPerFile: 60,
        textPagesPerFile: 500,
        charsPerDocument: 600_000,
        linkMaxBytes: 3_000_000,
      },
      prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
      logger: { info() {}, warn() {}, error() {}, debug() {} } as never,
      fetchLink: (url) => {
        fetched.push(url);
        return Promise.resolve({
          ok: true,
          url,
          contentType: "text/html; charset=utf-8",
          bytes: new TextEncoder().encode(
            "<html><body><h1>Photosynthesis</h1><p>Plants use light, water and carbon dioxide to make glucose. Chlorophyll in the leaves absorbs the light.</p></body></html>",
          ),
          truncated: false,
        });
      },
    });

    // Other documents may be waiting in a shared database; read until ours is.
    let state = "pending";
    for (let i = 0; i < 20 && state === "pending"; i++) {
      if (await processor.runOnce() === 0) break;
      const [row] = await sql<{ state: string }[]>`
        select state from private.ai_material_docs where id = ${doc!.id}::uuid`;
      state = row?.state ?? state;
    }
    expect(fetched).toContain(URL);
    expect(state).toBe("ready");
    const chunks = await sql<{ body: string }[]>`
      select body from private.ai_material_chunks where doc_id = ${
      doc!.id
    }::uuid order by ordinal`;
    expect(chunks.length).toBeGreaterThan(0);
    expect(chunks.map((c) => c.body).join(" ")).toContain("Chlorophyll");
  });

  test("the same link on another lesson within a week reuses what was read", async () => {
    const otherVersion = "7d000000-0000-4000-8000-0000000000e4";
    await sql`
      insert into public.resource_versions (id, school_id, resource_id, version, body, created_by)
      values (${otherVersion}, ${SCHOOL}, ${RESOURCE}, 2, 'Lesson text v2', ${TEACHER})`;
    const [link] = await sql<{ id: string }[]>`
      insert into public.content_links (school_id, title, url, role, resource_version_id, created_by)
      values (${SCHOOL}, 'Reading again', ${URL}, 'material', ${otherVersion}, ${TEACHER})
      returning id::text`;
    const [doc] = await sql<{ state: string; chunks: number }[]>`
      select d.state, (select count(*)::int from private.ai_material_chunks c where c.doc_id = d.id) as chunks
      from private.ai_material_docs d where d.content_link_id = ${
      link!.id
    }::uuid`;
    expect(doc?.state).toBe("ready");
    expect(doc?.chunks).toBeGreaterThan(0);
  });

  test("the polling loop drains, then stops cleanly", async () => {
    const runtime = startMaterialIndex({
      queue: postgresMaterialQueue(sql),
      storage: noStorage,
      assistant: null,
      limits: {
        ocrPagesPerFile: 60,
        textPagesPerFile: 500,
        charsPerDocument: 600_000,
        linkMaxBytes: 3_000_000,
      },
      prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
      logger: { info() {}, warn() {}, error() {}, debug() {} } as never,
      fetchLink: () =>
        Promise.resolve({ ok: false, reason: "unreachable" } as never),
    }, 20);
    await Bun.sleep(100);
    await runtime.close();
    expect(typeof (await runtime.runOnce())).toBe("number");
  });
});
