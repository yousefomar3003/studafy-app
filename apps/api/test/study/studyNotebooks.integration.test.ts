/**
 * Study notebooks over real SQL: made from a lesson in the background,
 * charged once, kept with the student's own notes through every update, and
 * practised from without paying twice for the same quiz.
 *
 * The provider is a stand-in; the routes, permissions, idempotency, plan
 * lookup and AI ledger are the real thing.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { testAssurance } from "../support/assurance";
import type { LogLevel } from "@studafy/contracts";
import { createDatabase, type Sql } from "@studafy/database";
import type { NotebookContent } from "@studafy/domain";
import { createJsonLogger } from "@studafy/observability";
import {
  type StudyAssistant,
  StudyAssistantError,
} from "@studafy/infrastructure";
import { AuthContextRepository } from "../../src/auth/context";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";
import { PostgresStudyRepository } from "../../src/study/repository";
import { PostgresMaterialRepository } from "../../src/study/material";
import {
  createStudyNotebookRoutes,
  PostgresStudyNotebookRepository,
} from "../../src/study/studyNotebookRoutes";
import { integrationSuite, removeFixtures } from "@studafy/test-support";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const P = "f0b20000-0000-4000-8000-0000000000";
const SCHOOL = `${P}01`;
const TERM = `${P}02`;
const CLASSROOM = `${P}03`;
const TEACHER = `${P}11`;
const STUDENT = `${P}12`;
const OUTSIDER = `${P}14`;
const STUDENT_ROW = `${P}21`;
const OUTSIDER_ROW = `${P}23`;
const LESSON = `${P}31`;
const LESSON_V1 = `${P}32`;

const PRICES = { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 };

let sql: Sql;
let app: Hono<AuthorizationEnv>;
const calls: string[] = [];
let pending: Promise<void>[] = [];
let failNext = false;

const CONTENT: NotebookContent = {
  overview: "Plants turn light into food.",
  objectives: ["Explain where photosynthesis happens"],
  keyTerms: [{ term: "Chlorophyll", definition: "Green pigment", cite: null }],
  sections: [{
    key: "s-leaf",
    heading: "Leaves",
    paragraphs: ["Chloroplasts in leaves capture light."],
    points: [],
    cites: [{ name: "Photosynthesis", page: null, slide: null }],
    extra: false,
  }],
  examples: [],
  facts: [],
  mistakes: [],
  summary: ["Light becomes chemical energy."],
};

const assistant = {
  notebook: async (_title: string, passages: { text: string }[]) => {
    calls.push("notebook");
    if (failNext) {
      failNext = false;
      throw new StudyAssistantError("unavailable", 503);
    }
    expect(passages.map((p) => p.text).join(" ")).toContain("chloroplasts");
    return {
      content: CONTENT,
      usage: { inputTokens: 900, outputTokens: 700, model: "stub" },
    };
  },
  studySet: async (
    kind: "quiz" | "flashcards",
    _title: string,
    text: string,
  ) => {
    calls.push(`${kind}:${text.includes("Leaves") ? "leaves" : "other"}`);
    const usage = { inputTokens: 300, outputTokens: 500, model: "stub" };
    return kind === "quiz"
      ? {
        kind,
        usage,
        questions: [{
          question: "Where is light captured?",
          options: ["Chloroplasts", "Roots", "Nucleus", "Stem"],
          answerIndex: 0,
          explanation: "In the chloroplasts.",
        }],
      }
      : { kind, usage, cards: [{ front: "Chlorophyll", back: "Pigment" }] };
  },
} as unknown as StudyAssistant;

async function user(id: string, name: string): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${`notebook.${id.slice(-2)}@synthetic.studafy.test`},
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(),
      now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, ${JSON.stringify({ full_name: name })}::jsonb
    ) on conflict (id) do nothing`;
}

async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [TEACHER, STUDENT, OUTSIDER],
  });
}

async function seed(): Promise<void> {
  await user(TEACHER, "Notebook Teacher");
  await user(STUDENT, "Notebook Student");
  await user(OUTSIDER, "Notebook Outsider");
  await sql`insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'Notebook School', 'Asia/Riyadh', 'active')`;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT}::uuid, 'student', true, 'active', 1),
      (${SCHOOL}::uuid, ${OUTSIDER}::uuid, 'student', true, 'active', 1)`;
  await sql`insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}::uuid, ${SCHOOL}::uuid, 'Notebook Term', current_date - 10, current_date + 90, true, 'active')`;
  await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Biology', '8', 'A', ${TEACHER}::uuid, 'active', 1)`;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL}::uuid, ${CLASSROOM}::uuid, m.id, m.user_id, 'lead_teacher'
    from public.memberships m where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid`;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT}::uuid, 'STU-NB-1', 'Notebook Student', false, ${TEACHER}::uuid),
      (${OUTSIDER_ROW}::uuid, ${SCHOOL}::uuid, ${OUTSIDER}::uuid, 'STU-NB-3', 'Notebook Outsider', false, ${TEACHER}::uuid)`;
  await sql`
    insert into public.enrollments (classroom_id, student_id, school_id, status, active) values
      (${CLASSROOM}::uuid, ${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, 'active', true)`;
  await sql`insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by)
    values (${LESSON}::uuid, ${SCHOOL}::uuid, 'Photosynthesis', 'lesson_note', 'published', 1, ${TEACHER}::uuid)`;
  await sql`insert into public.resource_versions (id, school_id, resource_id, version, body, created_by)
    values (${LESSON_V1}::uuid, ${SCHOOL}::uuid, ${LESSON}::uuid, 1,
      'Photosynthesis turns light into chemical energy in the chloroplasts. Chlorophyll absorbs the light.',
      ${TEACHER}::uuid)`;
  await sql`insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state, published_at, created_by)
    values (${SCHOOL}::uuid, ${LESSON_V1}::uuid, ${CLASSROOM}::uuid, 'both', 'published', now(), ${TEACHER}::uuid)`;
}

async function grant(userId: string, plan: "plus" | "max"): Promise<void> {
  await sql`delete from private.study_plan_grants where user_id = ${userId}::uuid`;
  await sql`insert into private.study_plan_grants (user_id, plan, reason, ends_at)
    values (${userId}::uuid, ${plan}, 'integration test', now() + interval '1 day')`;
}

async function request(
  path: string,
  subject: string,
  init: { method?: "GET" | "POST"; body?: unknown; key?: string } = {},
): Promise<Response> {
  const headers = new Headers({ "x-test-subject": subject });
  if (init.body !== undefined) headers.set("content-type", "application/json");
  if ((init.method ?? "GET") === "POST") {
    headers.set("idempotency-key", init.key ?? crypto.randomUUID());
  }
  return await app.request(path, {
    method: init.method ?? "GET",
    headers,
    ...(init.body !== undefined ? { body: JSON.stringify(init.body) } : {}),
  });
}

/** Waits for the notebooks being written in the background. */
async function settle(): Promise<void> {
  const work = pending;
  pending = [];
  await Promise.all(work);
}

async function tokens(userId: string): Promise<number> {
  const rows = await sql<{ total: string }[]>`
    select coalesce(sum(coalesce(input_tokens, 0) + coalesce(output_tokens, 0)), 0)::text as total
    from private.ai_usage where user_id = ${userId}::uuid and status = 'settled'`;
  return Number(rows[0]!.total);
}

interface Notebook {
  summary: {
    id: string;
    status: string;
    failure: string | null;
    contentVersion: number;
    updateAvailable: boolean;
  };
  content: NotebookContent | null;
  personal: { notes: { text: string }[] };
  personalVersion: number;
  sets: { kind: string; outdated: boolean }[];
}

suite("Study notebooks over real SQL", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    const contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "notebook-it",
      "debug" as LogLevel,
      () => undefined,
    );
    const authorization = createAuthorizationDependencies(
      logger,
      new PostgresAuthorizationRepository(sql),
    );
    const idempotency = {
      logger,
      repository: new PostgresIdempotencyRepository(sql),
    };
    app = new Hono<AuthorizationEnv>();
    app.use("*", async (c, next) => {
      const subject = c.req.header("x-test-subject")!;
      const context = await contexts.load(subject);
      if (!context) return c.text("unauthenticated", 401);
      const actor: Actor = {
        token: {
          subject,
          sessionId: null,
          issuedAt: 1,
          expiresAt: 4_000_000_000,
          assuranceLevel: testAssurance(c),
          authMethods: [],
          claims: {},
        },
        context,
        aal2: false,
        mfaRequiredByPolicy: false,
      };
      c.set("requestId", crypto.randomUUID());
      c.set("actor", actor);
      await next();
    });
    app.route(
      "/",
      createStudyNotebookRoutes(
        {
          notebooks: new PostgresStudyNotebookRepository(sql),
          material: new PostgresMaterialRepository(sql),
          repository: new PostgresStudyRepository(sql),
          prices: PRICES,
          assistant,
          lessonToolsEnabled: true,
          background: (work) => pending.push(work),
        },
        authorization,
        idempotency,
      ),
    );
  });

  afterAll(async () => {
    if (!sql) return;
    await settle();
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  const create = (subject: string, key?: string) =>
    request(`/v1/classrooms/${CLASSROOM}/study-notebooks`, subject, {
      method: "POST",
      body: { resourceId: LESSON, sourceIds: [] },
      ...(key ? { key } : {}),
    });
  const open = async (id: string, subject = STUDENT) =>
    await request(`/v1/study-notebooks/${id}`, subject);

  let notebookId = "";

  test("a notebook needs Studafy Plus", async () => {
    const res = await create(STUDENT);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { code: string }).code).toBe("PLAN_REQUIRED");
    expect(calls).toHaveLength(0);
  });

  test("on Plus, a lesson becomes a notebook, written in the background", async () => {
    await grant(STUDENT, "plus");
    const key = crypto.randomUUID();
    const res = await create(STUDENT, key);
    expect(res.status).toBe(201);
    const summary = await res.json() as { id: string; status: string };
    expect(summary.status).toBe("creating");
    notebookId = summary.id;
    await settle();

    const notebook = await (await open(notebookId)).json() as Notebook;
    expect(notebook.summary.status).toBe("ready");
    expect(notebook.summary.contentVersion).toBe(1);
    expect(notebook.summary.updateAvailable).toBe(false);
    expect(notebook.content?.sections[0]?.heading).toBe("Leaves");
    expect(await tokens(STUDENT)).toBe(1_600);

    // The same request again: the same notebook, written and charged once.
    const again = await create(STUDENT, key);
    const againBody = await again.json() as { id: string };
    expect(againBody.id).toBe(notebookId);
    await settle();
    expect(calls.filter((c) => c === "notebook")).toHaveLength(1);
    expect(await tokens(STUDENT)).toBe(1_600);
  });

  test("it is listed in the class, and nobody else can open it", async () => {
    const list = await request(
      `/v1/classrooms/${CLASSROOM}/study-notebooks`,
      STUDENT,
    );
    expect(list.status).toBe(200);
    const items = ((await list.json()) as { items: { id: string }[] }).items;
    expect(items.map((i) => i.id)).toEqual([notebookId]);
    expect((await open(notebookId, OUTSIDER)).status).toBe(404);
    expect((await open(notebookId, TEACHER)).status).toBe(404);
  });

  test("the student's notes are saved, and a stale save does not overwrite them", async () => {
    const personal = {
      notes: [{ id: "n1", sectionKey: "s-leaf", text: "Ask about stomata" }],
      sections: [{ id: "o1", title: "My summary", body: "Leaves eat light." }],
      bookmarks: ["s-leaf"],
      highlights: [{ sectionKey: "s-leaf", index: 0, color: "yellow" }],
    };
    const saved = await request(
      `/v1/study-notebooks/${notebookId}/personal`,
      STUDENT,
      { method: "POST", body: { expectedVersion: 1, personal } },
    );
    expect(saved.status).toBe(200);
    expect(((await saved.json()) as Notebook).personalVersion).toBe(2);

    const stale = await request(
      `/v1/study-notebooks/${notebookId}/personal`,
      STUDENT,
      {
        method: "POST",
        body: {
          expectedVersion: 1,
          personal: { notes: [], sections: [], bookmarks: [], highlights: [] },
        },
      },
    );
    expect(stale.status).toBe(409);
    expect(((await stale.json()) as { code: string }).code).toBe(
      "VERSION_CONFLICT",
    );
  });

  test("the cover can be changed", async () => {
    const res = await request(
      `/v1/study-notebooks/${notebookId}/settings`,
      STUDENT,
      {
        method: "POST",
        body: {
          title: "My leaves",
          subtitle: "Unit 3",
          color: "teal",
          icon: "science",
          pageStyle: "grid",
          headings: [{ key: "s-leaf", title: "All about leaves" }],
        },
      },
    );
    expect(res.status).toBe(200);
    expect(((await res.json()) as { title: string }).title).toBe("My leaves");
  });

  test("a failed update keeps the last notebook and the student's notes, and costs nothing", async () => {
    const before = await tokens(STUDENT);
    failNext = true;
    const res = await request(
      `/v1/study-notebooks/${notebookId}/regenerate`,
      STUDENT,
      { method: "POST", body: {} },
    );
    expect(res.status).toBe(200);
    await settle();
    const notebook = await (await open(notebookId)).json() as Notebook;
    expect(notebook.summary.status).toBe("failed");
    expect(notebook.summary.failure).toBe("provider_unavailable");
    expect(notebook.content?.overview).toBe(CONTENT.overview);
    expect(notebook.personal.notes[0]?.text).toBe("Ask about stomata");
    expect(await tokens(STUDENT)).toBe(before);

    // Trying again works, and still keeps the notes.
    await request(`/v1/study-notebooks/${notebookId}/regenerate`, STUDENT, {
      method: "POST",
      body: {},
    });
    await settle();
    const retried = await (await open(notebookId)).json() as Notebook;
    expect(retried.summary.status).toBe("ready");
    expect(retried.summary.contentVersion).toBe(2);
    expect(retried.personal.notes[0]?.text).toBe("Ask about stomata");
  });

  test("quizzes from a notebook are on Max, made once per version and section", async () => {
    const path = `/v1/study-notebooks/${notebookId}/study-set`;
    const body = { kind: "quiz", sectionKeys: ["s-leaf"] };
    const plus = await request(path, STUDENT, { method: "POST", body });
    expect(plus.status).toBe(403);

    await grant(STUDENT, "max");
    const first = await request(path, STUDENT, { method: "POST", body });
    expect(first.status).toBe(201);
    const set = await first.json() as {
      id: string;
      questions: unknown[] | null;
      sectionKeys: string[];
    };
    expect(set.questions).toHaveLength(1);
    expect(set.sectionKeys).toEqual(["s-leaf"]);
    expect(calls).toContain("quiz:leaves");

    const used = await tokens(STUDENT);
    const before = calls.length;
    const again = await request(path, STUDENT, { method: "POST", body });
    expect(((await again.json()) as { id: string }).id).toBe(set.id);
    expect(calls.length).toBe(before);
    expect(await tokens(STUDENT)).toBe(used);
  });

  test("updating the notebook marks its quizzes outdated", async () => {
    await request(`/v1/study-notebooks/${notebookId}/regenerate`, STUDENT, {
      method: "POST",
      body: {},
    });
    await settle();
    const notebook = await (await open(notebookId)).json() as Notebook;
    expect(notebook.sets[0]?.outdated).toBe(true);
  });

  test("the student can delete it", async () => {
    const res = await request(
      `/v1/study-notebooks/${notebookId}/delete`,
      STUDENT,
      { method: "POST", body: {} },
    );
    expect(res.status).toBe(200);
    expect((await open(notebookId)).status).toBe(404);
  });
});
