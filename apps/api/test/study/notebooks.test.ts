/**
 * Notebooks by class, and study notes made from a lesson. The SQL decides
 * who may see what (supabase/tests/archive_classes.sql); these check what
 * the routes do around it.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { createJsonLogger } from "@studafy/observability";
import type { StudyAssistant } from "@studafy/infrastructure";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import {
  createNotebookRoutes,
  type NotebookRepository,
} from "../../src/study/notebookRoutes";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";
import { fakeAiAccess } from "../support/aiAccess";

const SUBJECT = "00000000-0000-4000-8000-000000000001";
const CLASS = "00000000-0000-4000-8000-0000000000c1";
const LESSON = "00000000-0000-4000-8000-0000000000d1";
const SCHOOL = "00000000-0000-4000-8000-0000000000a1";

function app(options: {
  notebooks: NotebookRepository;
  lessonToolsEnabled?: boolean;
  saved?: Record<string, unknown>[];
  asked?: string[];
}) {
  const logger = createJsonLogger("api", "test", "error");
  const routes = new Hono<AuthorizationEnv>();
  routes.use("*", async (c, next) => {
    c.set("requestId", crypto.randomUUID());
    c.set("actor", {
      token: {
        subject: SUBJECT,
        sessionId: null,
        issuedAt: 1,
        expiresAt: 4_000_000_000,
        assuranceLevel: "aal1",
        authMethods: [],
        claims: {},
      },
      context: {
        userId: SUBJECT,
        memberships: [{
          id: "00000000-0000-4000-8000-0000000000b1",
          school_id: SCHOOL,
          school_name: "School",
          school_timezone: "UTC",
          role: "student",
          active: true,
          active_term_id: null,
        }],
        membershipVersion: "1",
      },
      aal2: false,
      mfaRequiredByPolicy: false,
    } as unknown as Actor);
    await next();
  });
  const authorization = {
    ...createAuthorizationDependencies(logger),
    repository: {
      authorize: async () => ({
        allowed: true,
        schoolId: SCHOOL,
        reason: "allowed" as const,
      }),
    },
  };
  routes.route(
    "/",
    createNotebookRoutes(
      {
        aiAccess: fakeAiAccess(),
        notebooks: options.notebooks,
        study: {
          usage: async (_c, operation) =>
            operation === "reserve"
              ? { outcome: "ok", usageId: "u1" }
              : { outcome: "ok" },
          query: async () => null,
          command: async (_c, _op, classroomId, body) => {
            options.saved?.push({ classroomId, ...body });
            return {
              outcome: "ok",
              response: {
                id: "00000000-0000-4000-8000-0000000000e1",
                classroomId,
                title: body["title"],
                body: body["body"],
                source: body["source"],
                createdAt: "2026-09-29T10:00:00Z",
                photo: null,
              },
            };
          },
        },
        prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
        assistant: {
          lessonNotes: async (title: string) => {
            options.asked?.push(title);
            return {
              answer: "# Cells\n\n- Unit of life",
              usage: { model: "test-model", inputTokens: 1, outputTokens: 1 },
            };
          },
        } as unknown as StudyAssistant,
        lessonToolsEnabled: options.lessonToolsEnabled ?? true,
      },
      authorization,
      { repository: new FakeIdempotencyRepository(), logger },
    ),
  );
  return routes;
}

const lesson = {
  outcome: "ok",
  lesson: {
    classroomId: CLASS,
    title: "Cells",
    body:
      "Cells are the basic unit of life. Every living thing is made of cells.",
  },
};

function makeNotes(routes: Hono<AuthorizationEnv>) {
  return routes.request(`/v1/resources/${LESSON}/lesson-notes`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "idempotency-key": crypto.randomUUID(),
    },
    body: "{}",
  });
}

describe("study notes from a lesson", () => {
  test("are saved to the class's notebook, marked as from a lesson", async () => {
    const saved: Record<string, unknown>[] = [];
    const res = await makeNotes(
      app({ notebooks: { call: async () => lesson }, saved }),
    );
    expect(res.status).toBe(201);
    expect(saved[0]).toMatchObject({
      classroomId: CLASS,
      title: "Cells",
      source: "lesson",
    });
  });

  test("made once per lesson version, then reused without the AI", async () => {
    const asked: string[] = [];
    const cached: unknown[][] = [];
    const saved: Record<string, unknown>[] = [];
    const versioned = {
      ...lesson,
      lesson: {
        ...lesson.lesson,
        versionId: "00000000-0000-4000-8000-0000000000f1",
      },
    };
    // First time: made by the AI, and kept for this version of the lesson.
    let res = await makeNotes(app({
      notebooks: {
        call: async () => versioned,
        cacheLessonNotes: async (...args) => {
          cached.push(args.slice(1));
          return true;
        },
      },
      asked,
    }));
    expect(res.status).toBe(201);
    expect(asked).toEqual(["Cells"]);
    expect(cached).toEqual([[
      LESSON,
      "00000000-0000-4000-8000-0000000000f1",
      "# Cells\n\n- Unit of life",
      "test-model",
    ]]);

    // Next time: the kept notes, no AI call, still filed in the notebook.
    res = await makeNotes(app({
      notebooks: {
        call: async () => ({ ...versioned, cachedNotes: "# Cells (kept)" }),
      },
      asked,
      saved,
    }));
    expect(res.status).toBe(201);
    expect(asked).toEqual(["Cells"]);
    expect(saved[0]).toMatchObject({
      body: "# Cells (kept)",
      source: "lesson",
    });
  });

  test("need Studafy Plus", async () => {
    const res = await makeNotes(
      app({ notebooks: { call: async () => ({ outcome: "plan_required" }) } }),
    );
    expect(res.status).toBe(403);
    expect((await res.json() as { code: string }).code).toBe("PLAN_REQUIRED");
  });

  test("are off while lesson material may not go to the provider", async () => {
    const res = await makeNotes(
      app({
        notebooks: { call: async () => lesson },
        lessonToolsEnabled: false,
      }),
    );
    expect(res.status).toBe(409);
  });
});

describe("every notebook a student has", () => {
  test("includes deleted classes, marked", async () => {
    const res = await app({
      notebooks: {
        call: async () => ({
          outcome: "ok",
          classes: [{
            classroomId: CLASS,
            name: "Biology",
            archived: true,
            entries: [],
          }],
        }),
      },
    }).request("/v1/me/notebooks");
    expect(res.status).toBe(200);
    const body = await res.json() as { classes: { archived: boolean }[] };
    expect(body.classes[0]!.archived).toBe(true);
  });
});
