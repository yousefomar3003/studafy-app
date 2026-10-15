import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import type { NotebookContent } from "@studafy/domain";
import {
  type StudyAssistant,
  StudyAssistantError,
} from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { integrationSuite, removeFixtures } from "@studafy/test-support";
import {
  createNotebookGenerationProcessor,
  type NotebookJob,
  postgresNotebookQueue,
  startNotebookGeneration,
} from "../src/processors/notebookGeneration";

// Study notebooks written off the notebook queue (2026-10-16), through the
// real SQL: a notebook the API creates is queued by trigger, claimed with a
// lease, written as its owner and charged once - through busy providers,
// stopped workers, replaced generations and lost access. The provider is a
// stand-in; nothing real is called. Who may call what is
// supabase/tests/study_notebooks.sql.

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const P = "f0b30000-0000-4000-8000-0000000000";
const SCHOOL = `${P}01`;
const TERM = `${P}02`;
const CLASSROOM = `${P}03`;
const TEACHER = `${P}11`;
const STUDENT = `${P}12`;
const STUDENT_ROW = `${P}21`;
const LESSON = `${P}31`;
const LESSON_V1 = `${P}32`;
const OTHER_LESSON = `${P}33`;

const PRICES = { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 };
const USAGE = { inputTokens: 900, outputTokens: 700, model: "stub" };

const CONTENT: NotebookContent = {
  overview: "Plants turn light into food.",
  objectives: [],
  keyTerms: [],
  sections: [{
    key: "s-leaf",
    heading: "Leaves",
    paragraphs: ["Chloroplasts in leaves capture light."],
    points: [],
    cites: [],
    extra: false,
  }],
  examples: [],
  facts: [],
  mistakes: [],
  summary: [],
};

type Behaviour = "ok" | "busy" | "empty";
let behaviours: Behaviour[] = [];
let calls = 0;
const assistant = {
  notebook: async (_title: string, passages: { text: string }[]) => {
    calls++;
    expect(passages.map((p) => p.text).join(" ")).toContain("chloroplasts");
    const next = behaviours.shift() ?? "ok";
    if (next === "busy") throw new StudyAssistantError("unavailable", 503);
    if (next === "empty") {
      throw new StudyAssistantError("empty", undefined, USAGE, true);
    }
    return { content: CONTENT, usage: USAGE };
  },
} as unknown as Pick<StudyAssistant, "notebook">;

const events: { event: string; fields: Record<string, unknown> }[] = [];
const logger = createJsonLogger("worker", "notebook-it", "debug", (line) => {
  const parsed = JSON.parse(line) as Record<string, unknown>;
  events.push({ event: String(parsed["event"]), fields: parsed });
});

let sql: Sql;

async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [TEACHER, STUDENT],
  });
}

async function user(id: string, name: string): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${`nbqueue.${id.slice(-2)}@synthetic.studafy.test`},
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(),
      now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, ${JSON.stringify({ full_name: name })}::jsonb
    ) on conflict (id) do nothing`;
}

async function seed(): Promise<void> {
  await user(TEACHER, "Queue Teacher");
  await user(STUDENT, "Queue Student");
  await sql`insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'Queue School', 'Asia/Riyadh', 'active')`;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT}::uuid, 'student', true, 'active', 1)`;
  await sql`insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}::uuid, ${SCHOOL}::uuid, 'Queue Term', current_date - 10, current_date + 90, true, 'active')`;
  await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Biology', '8', 'A', ${TEACHER}::uuid, 'active', 1)`;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL}::uuid, ${CLASSROOM}::uuid, m.id, m.user_id, 'lead_teacher'
    from public.memberships m where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid`;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
    values (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT}::uuid, 'STU-NQ-1', 'Queue Student', false, ${TEACHER}::uuid)`;
  await sql`
    insert into public.enrollments (classroom_id, student_id, school_id, status, active)
    values (${CLASSROOM}::uuid, ${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, 'active', true)`;
  await sql`insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by)
    values (${LESSON}::uuid, ${SCHOOL}::uuid, 'Photosynthesis', 'lesson_note', 'published', 1, ${TEACHER}::uuid),
      (${OTHER_LESSON}::uuid, ${SCHOOL}::uuid, 'Other', 'lesson_note', 'published', 1, ${TEACHER}::uuid)`;
  await sql`insert into public.resource_versions (id, school_id, resource_id, version, body, created_by)
    values (${LESSON_V1}::uuid, ${SCHOOL}::uuid, ${LESSON}::uuid, 1,
      'Photosynthesis turns light into chemical energy in the chloroplasts. Chlorophyll absorbs the light.',
      ${TEACHER}::uuid)`;
  await sql`insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state, published_at, created_by)
    values (${SCHOOL}::uuid, ${LESSON_V1}::uuid, ${CLASSROOM}::uuid, 'both', 'published', now(), ${TEACHER}::uuid)`;
  await sql`insert into private.study_plan_grants (user_id, plan, reason, ends_at)
    values (${STUDENT}::uuid, 'plus', 'integration test', now() + interval '1 day')`;
}

/** What the API does: the notebook call, as the student. */
async function asStudent(
  operation: string,
  input: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  return await sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claim.sub', ${STUDENT}, true)`;
    const [row] = await tx<{ result: Record<string, unknown> }[]>`
      select private.api055_study_notebooks(${operation}, ${
      tx.json(input as never)
    }) as result`;
    return row!.result;
  }) as Record<string, unknown>;
}

async function createNotebook(): Promise<string> {
  const started = await asStudent("create", {
    classroomId: CLASSROOM,
    resourceId: LESSON,
    sourceIds: [],
  });
  expect(started["outcome"]).toBe("ok");
  return String(started["notebookId"]);
}

async function notebook(id: string) {
  const [row] = await sql<
    { status: string; failure: string | null; generation: number }[]
  >`select status, failure, generation from public.study_notebooks where id = ${id}::uuid`;
  return row!;
}

interface JobRow {
  generation: number;
  state: string;
  attempts: number;
  last_error: string | null;
  due_in: number;
}

async function jobs(id: string): Promise<JobRow[]> {
  const rows = await sql<JobRow[]>`
    select generation, state, attempts, last_error,
      extract(epoch from next_attempt_at - now())::float8 as due_in
    from private.study_notebook_jobs where notebook_id = ${id}::uuid
    order by generation`;
  return [...rows];
}

async function charged(): Promise<number> {
  const [row] = await sql<{ total: string }[]>`
    select coalesce(sum(coalesce(input_tokens, 0) + coalesce(output_tokens, 0)), 0)::text as total
    from private.ai_usage where user_id = ${STUDENT}::uuid and status = 'settled'
      and not replay`;
  return Number(row!.total);
}

/** Due now: skips the backoff a retry waits. */
async function due(id: string): Promise<void> {
  await sql`update private.study_notebook_jobs set next_attempt_at = now()
    where notebook_id = ${id}::uuid and state = 'pending'`;
}

const processor = () =>
  createNotebookGenerationProcessor({
    queue: postgresNotebookQueue(sql),
    assistant,
    prices: PRICES,
    logger,
    concurrency: 2,
    workerId: "notebook-it",
  });

suite("study notebooks written off the queue", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("a queued notebook is written by the worker and charged once", async () => {
    const id = await createNotebook();
    expect(await jobs(id)).toMatchObject([{ generation: 1, state: "pending" }]);
    const before = await charged();
    expect(await processor().runOnce()).toBe(1);
    expect(await notebook(id)).toMatchObject({ status: "ready" });
    expect(await jobs(id)).toEqual([]);
    expect(await charged()).toBe(before + 1_600);
    expect(await processor().runOnce()).toBe(0);
  });

  test("a busy provider is tried again with backoff, then written, charged once", async () => {
    const id = await createNotebook();
    const before = await charged();
    behaviours = ["busy"];
    expect(await processor().runOnce()).toBe(1);
    const [waiting] = await jobs(id);
    expect(waiting).toMatchObject({
      state: "pending",
      attempts: 1,
      last_error: "provider_unavailable",
    });
    expect(waiting!.due_in).toBeGreaterThan(15);
    expect(await notebook(id)).toMatchObject({ status: "creating" });
    // Not due yet.
    expect(await processor().runOnce()).toBe(0);
    await due(id);
    expect(await processor().runOnce()).toBe(1);
    expect(await notebook(id)).toMatchObject({ status: "ready" });
    // The busy attempt's hold was released; only the write is charged.
    expect(await charged()).toBe(before + 1_600);
  });

  test("three failed attempts make a dead letter, and the notebook shows failed", async () => {
    const id = await createNotebook();
    const before = await charged();
    behaviours = ["busy", "busy", "busy"];
    for (let attempt = 1; attempt <= 3; attempt++) {
      await due(id);
      expect(await processor().runOnce()).toBe(1);
    }
    expect(await jobs(id)).toMatchObject([{
      state: "dead",
      attempts: 3,
      last_error: "provider_unavailable",
    }]);
    expect(await notebook(id)).toMatchObject({
      status: "failed",
      failure: "provider_unavailable",
    });
    expect(await charged()).toBe(before);
    const backlog = await postgresNotebookQueue(sql).backlog();
    expect(Number(backlog["deadLetters"])).toBeGreaterThanOrEqual(1);
    expect(events.some((e) => e.event === "study_notebook_dead_letter")).toBe(
      true,
    );
    // The student's retry is a new generation, queued afresh.
    expect((await asStudent("regenerate", { id }))["outcome"]).toBe("ok");
    expect(await processor().runOnce()).toBe(1);
    expect(await notebook(id)).toMatchObject({ status: "ready" });
  });

  test("an unusable reply fails at once and is charged, once", async () => {
    const id = await createNotebook();
    const before = await charged();
    behaviours = ["empty"];
    expect(await processor().runOnce()).toBe(1);
    expect(await notebook(id)).toMatchObject({
      status: "failed",
      failure: "unusable_reply",
    });
    expect(await jobs(id)).toEqual([]);
    expect(await charged()).toBe(before + 1_600);
  });

  test("a worker that stopped mid-write: the next attempt writes it, charged once", async () => {
    const id = await createNotebook();
    const before = await charged();
    const queue = postgresNotebookQueue(sql);
    const [stopped] = await queue.claim("stopped-worker", 1) as NotebookJob[];
    expect(stopped!.start.notebookId).toBe(id);
    expect(stopped!.ownerId).toBe(STUDENT);
    // It held the allowance, then its machine stopped.
    const held = await queue.usage("stopped-worker", stopped!, "reserve", {
      feature: "notes",
      estimateMicroUsd: 2_000,
      estimateTokens: 6_000,
    });
    expect(held["outcome"]).toBe("ok");
    // Nobody else takes it while the lease holds.
    expect(await processor().runOnce()).toBe(0);
    await sql`update private.study_notebook_jobs set lease_until = now() - interval '1 second'
      where notebook_id = ${id}::uuid`;
    expect(await processor().runOnce()).toBe(1);
    expect(await notebook(id)).toMatchObject({ status: "ready" });
    expect(await charged()).toBe(before + 1_600);
    // The stopped attempt's hold released, never charged; the write settled.
    const [left] = await sql<{ status: string }[]>`
      select status from private.ai_usage where id = ${
      String(held["usageId"])
    }::uuid`;
    expect(left!.status).toBe("released");
    const [written] = await sql<{ status: string }[]>`
      select status from private.ai_usage
      where user_id = ${STUDENT}::uuid and request_key = ${`notebook:${id}:1`}`;
    expect(written!.status).toBe("settled");
    // The stopped worker, back, can no longer act on it.
    expect(
      (await queue.material("stopped-worker", stopped!, "lessons", {
        resourceIds: [LESSON],
      }))["outcome"],
    ).toBe("lease_lost");
    expect(
      (await queue.finish("stopped-worker", stopped!, {
        outcome: "failed",
        reason: "provider_unavailable",
      }))["outcome"],
    ).toBe("lease_lost");
    expect(await notebook(id)).toMatchObject({ status: "ready" });
  });

  test("a job reaches only its own lesson and its own charge", async () => {
    const id = await createNotebook();
    const queue = postgresNotebookQueue(sql);
    const [job] = await queue.claim("scoped-worker", 1) as NotebookJob[];
    expect(
      (await queue.material("scoped-worker", job!, "lessons", {
        resourceIds: [OTHER_LESSON],
      }))["outcome"],
    ).toBe("invalid");
    expect(
      (await queue.material("scoped-worker", job!, "status", {
        resourceIds: [LESSON],
      }))["outcome"],
    ).toBe("invalid");
    expect(
      (await queue.usage("scoped-worker", job!, "reserve", {
        feature: "quiz",
        estimateMicroUsd: 10,
        estimateTokens: 10,
      }))["outcome"],
    ).toBe("invalid");
    const [other] = await sql<{ id: string }[]>`
      insert into private.ai_usage (user_id, feature, plan, month, reserved_micro_usd,
        reserved_tokens, request_key)
      values (${STUDENT}::uuid, 'ask', 'plus', date_trunc('month', now())::date, 10, 10,
        'someone-elses-request')
      returning id::text`;
    expect(
      (await queue.usage("scoped-worker", job!, "settle", {
        usageId: other!.id,
        costMicroUsd: 0,
      }))["outcome"],
    ).toBe("not_found");
    await sql`delete from private.ai_usage where id = ${other!.id}::uuid`;
    await queue.finish("scoped-worker", job!, {
      outcome: "failed",
      reason: "provider_unavailable",
    });
    expect(await notebook(id)).toMatchObject({ status: "failed" });
  });

  test("a replaced generation is dropped, and a lesson the student lost fails", async () => {
    const id = await createNotebook();
    // A newer request replaced the queued one before the worker came.
    await sql`update public.study_notebooks set status = 'failed' where id = ${id}::uuid`;
    expect((await asStudent("regenerate", { id }))["outcome"]).toBe("ok");
    expect((await jobs(id)).map((j) => j.generation)).toEqual([1, 2]);
    const before = calls;
    expect(await processor().runOnce()).toBe(1);
    expect(calls).toBe(before + 1);
    expect(await notebook(id)).toMatchObject({
      status: "ready",
      generation: 2,
    });
    expect(await jobs(id)).toEqual([]);

    const lost = await createNotebook();
    await sql`update public.enrollments set status = 'withdrawn', active = false
      where student_id = ${STUDENT_ROW}::uuid`;
    try {
      const seen = calls;
      expect(await processor().runOnce()).toBe(1);
      // Read as the student, the lesson is gone: no model call, no charge.
      expect(calls).toBe(seen);
      expect(await notebook(lost)).toMatchObject({
        status: "failed",
        failure: "lesson_unavailable",
      });
      expect(await jobs(lost)).toEqual([]);
    } finally {
      await sql`update public.enrollments set status = 'active', active = true
        where student_id = ${STUDENT_ROW}::uuid`;
    }
  });

  test("a notebook that waited too long is a dead letter, timed out", async () => {
    const id = await createNotebook();
    await sql`update public.study_notebooks
      set generation_started_at = now() - interval '10 minutes' where id = ${id}::uuid`;
    expect(await processor().runOnce()).toBe(0);
    expect(await jobs(id)).toMatchObject([{
      state: "dead",
      last_error: "timed_out",
    }]);
    expect(await notebook(id)).toMatchObject({
      status: "failed",
      failure: "timed_out",
    });
  });

  test("the running processor polls, writes, logs its backlog and closes", async () => {
    const id = await createNotebook();
    const running = startNotebookGeneration(
      {
        queue: postgresNotebookQueue(sql),
        assistant,
        prices: PRICES,
        logger,
        concurrency: 2,
      },
      50,
      { backlogLogIntervalMs: 0 },
    );
    try {
      for (let i = 0; i < 100; i++) {
        if ((await notebook(id)).status !== "creating") break;
        await Bun.sleep(50);
      }
      expect(await notebook(id)).toMatchObject({ status: "ready" });
      expect(events.some((e) => e.event === "notebook_backlog")).toBe(true);
    } finally {
      await running.close();
    }
  });
});
