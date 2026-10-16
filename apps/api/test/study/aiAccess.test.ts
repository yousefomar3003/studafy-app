/**
 * The AI gate (ADR-0043): every AI route refuses an account that may not use
 * the AI study tools before it does any work, with a problem the app can
 * act on, and what reaches the provider carries no known name.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { createJsonLogger } from "@studafy/observability";
import type { StudyAssistant } from "@studafy/infrastructure";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import type { StudyRepository } from "../../src/study/repository";
import { createStudyRoutes } from "../../src/study/routes";
import { createSelectionRoutes } from "../../src/study/selectionRoutes";
import { createStudyNotebookRoutes } from "../../src/study/studyNotebookRoutes";
import { createNotebookRoutes } from "../../src/study/notebookRoutes";
import { createStudyAssistantRoutes } from "../../src/study-assistant/routes";
import { createAiConsentRoutes } from "../../src/study/aiConsentRoutes";
import type {
  AiAccess,
  AiAccessRepository,
  AiConsentOperation,
} from "../../src/study/aiAccess";
import { fakeAiAccess } from "../support/aiAccess";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";

const SUBJECT = "00000000-0000-4000-8000-000000000001";
const ID = "00000000-0000-4000-8000-0000000000aa";
const SCHOOL = "00000000-0000-4000-8000-0000000000bb";
const logger = createJsonLogger("api", "test", "error");
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

const usage: string[] = [];
const repository: StudyRepository = {
  usage: async (_c, operation) => {
    usage.push(operation);
    return operation === "summary"
      ? {
        outcome: "ok",
        plan: "max",
        features: ["ask", "whiteboard", "notes", "quiz", "flashcards"],
        allowance: {
          period: "month",
          total: 6_000_000,
          used: 0,
          remaining: 6_000_000,
          resetsAt: "2026-11-01T00:00:00Z",
        },
        capMicroUsd: 1_600_000,
        committedMicroUsd: 0,
        access: "not_student",
      }
      : { outcome: "ok", usageId: ID };
  },
  query: async () => null,
  command: async () => ({ outcome: "invalid" }),
};

const asked: string[] = [];
const assistant = {
  ask: async (question: string) => {
    asked.push(question);
    return {
      answer: "An answer.",
      usage: { inputTokens: 10, outputTokens: 10, model: "stub" },
    };
  },
} as unknown as StudyAssistant;

function app(aiAccess: AiAccessRepository): Hono<AuthorizationEnv> {
  const app = new Hono<AuthorizationEnv>();
  app.use("*", async (c, next) => {
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
  const idempotency = { logger, repository: new FakeIdempotencyRepository() };
  const material = { call: async () => ({ outcome: "invalid" }) };
  const prices = { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 };
  app.route(
    "/",
    createStudyAssistantRoutes({
      assistant,
      aiAccess,
      repository,
      prices,
      chatMemory: {
        contextWindowTokens: 262_144,
        freeTokens: 4_000,
        paidTokens: 32_000,
      },
    }, authorization),
  );
  app.route(
    "/",
    createStudyRoutes(
      {
        aiAccess,
        repository,
        prices,
        assistant,
        lessonToolsEnabled: true,
        storage: {} as never,
      },
      authorization,
      idempotency,
    ),
  );
  app.route(
    "/",
    createNotebookRoutes(
      {
        aiAccess,
        notebooks: { call: async () => ({ outcome: "forbidden" }) },
        study: repository,
        prices,
        assistant,
        lessonToolsEnabled: true,
      },
      authorization,
      idempotency,
    ),
  );
  app.route(
    "/",
    createStudyNotebookRoutes(
      {
        aiAccess,
        notebooks: { call: async () => ({ outcome: "forbidden" }) },
        material,
        repository,
        prices,
        assistant,
        lessonToolsEnabled: true,
      },
      authorization,
      idempotency,
    ),
  );
  app.route(
    "/",
    createSelectionRoutes(
      {
        aiAccess,
        material,
        outputs: { call: async () => ({ outcome: "forbidden" }) },
        repository,
        prices,
        assistant,
        lessonToolsEnabled: true,
      },
      authorization,
      idempotency,
    ),
  );
  app.route(
    "/",
    createAiConsentRoutes({ repository: aiAccess }, authorization, idempotency),
  );
  return app;
}

/** Every route that sends anything to the AI provider. */
const AI_ROUTES: [string, Record<string, unknown>][] = [
  ["/v1/study-assistant/ask", { question: "What is a cell?" }],
  [`/v1/classrooms/${ID}/notebook/whiteboard`, { photoFileId: ID }],
  [`/v1/resources/${ID}/study-set`, { kind: "quiz" }],
  [`/v1/resources/${ID}/lesson-notes`, {}],
  ["/v1/study-sets", {
    kind: "quiz",
    references: [{ kind: "lesson", id: ID }],
  }],
  [`/v1/classrooms/${ID}/notebook/summary`, {
    references: [{ kind: "lesson", id: ID }],
  }],
  [`/v1/classrooms/${ID}/study-notebooks`, { resourceId: ID, sourceIds: [] }],
  [`/v1/study-notebooks/${ID}/regenerate`, {}],
  [`/v1/study-notebooks/${ID}/study-set`, { kind: "quiz", sectionKeys: [] }],
];

async function post(
  target: Hono<AuthorizationEnv>,
  path: string,
  body: unknown,
): Promise<Response> {
  return await target.request(path, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "idempotency-key": crypto.randomUUID(),
    },
    body: JSON.stringify(body),
  });
}

describe("the AI gate on every AI route", () => {
  const cases: [AiAccess, string][] = [
    ["not_student", "AI_STUDENTS_ONLY"],
    ["no_class", "AI_STUDENTS_ONLY"],
    ["consent_required", "AI_CONSENT_REQUIRED"],
    ["guardian_consent_required", "AI_GUARDIAN_CONSENT_REQUIRED"],
  ];
  for (const [access, code] of cases) {
    test(`${access}: every AI route answers 403 ${code}, and nothing is spent`, async () => {
      asked.length = 0;
      usage.length = 0;
      const target = app(fakeAiAccess(access));
      for (const [path, body] of AI_ROUTES) {
        const res = await post(target, path, body);
        expect(res.status, path).toBe(403);
        expect((await res.json() as { code: string }).code, path).toBe(code);
      }
      expect(asked).toEqual([]);
      expect(usage).toEqual([]);
    });
  }

  test("a consenting student in a class is let through", async () => {
    asked.length = 0;
    const res = await post(
      app(fakeAiAccess("ok")),
      "/v1/study-assistant/ask",
      { question: "What is a cell?" },
    );
    expect(res.status).toBe(200);
    expect(asked).toEqual(["What is a cell?"]);
  });

  test("an unreachable decision is a 503, never a pass", async () => {
    const res = await post(
      app({
        call: async () => {
          throw new Error("down");
        },
      }),
      "/v1/study-assistant/ask",
      { question: "What is a cell?" },
    );
    expect(res.status).toBe(503);
  });
});

describe("names out of what the helper sends", () => {
  test("the student's and others' names are replaced before the call", async () => {
    asked.length = 0;
    const calls: AiConsentOperation[] = [];
    const res = await post(
      app(fakeAiAccess("ok", [
        { name: "Sara Haddad", kind: "self" },
        { name: "Grace Hopper", kind: "teacher" },
        { name: "أحمد", kind: "classmate" },
      ], calls)),
      "/v1/study-assistant/ask",
      { question: "I am Sara Haddad; can Grace Hopper and أحمد help?" },
    );
    expect(res.status).toBe(200);
    expect(asked).toEqual([
      "I am [student]; can [teacher] and [classmate] help?",
    ]);
    expect(calls).toEqual(["status", "names"]);
  });
});

describe("the plan summary", () => {
  test("says the account's AI access, and offers nothing to a non-student", async () => {
    const res = await app(fakeAiAccess("not_student")).request(
      "/v1/me/study-plan",
    );
    expect(res.status).toBe(200);
    const body = await res.json() as { aiAccess: string; available: string[] };
    expect(body.aiAccess).toBe("not_student");
    expect(body.available).toEqual([]);
  });
});

describe("the consent routes", () => {
  function recording(): {
    repo: AiAccessRepository;
    calls: [AiConsentOperation, Record<string, unknown>][];
  } {
    const calls: [AiConsentOperation, Record<string, unknown>][] = [];
    return {
      calls,
      repo: {
        call: async (_c, operation, input) => {
          calls.push([operation, input]);
          return {
            outcome: "ok",
            access: operation.endsWith("give") ? "ok" : "consent_required",
            version: "2026-10-15",
            consent: operation.endsWith("give")
              ? {
                version: "2026-10-15",
                locale: "ar",
                givenAt: "2026-10-15T10:00:00+00:00",
                givenAs: operation === "child_give" ? "guardian" : "self",
              }
              : null,
          };
        },
      },
    };
  }

  test("a student agrees to the notice that was shown, and withdraws", async () => {
    const { repo, calls } = recording();
    const target = app(repo);
    const given = await post(target, "/v1/me/study-tools-consent", {
      given: true,
      version: "2026-10-15",
      locale: "ar",
    });
    expect(given.status).toBe(200);
    expect(await given.json()).toEqual({
      access: "ok",
      version: "2026-10-15",
      consent: {
        version: "2026-10-15",
        locale: "ar",
        givenAt: "2026-10-15T10:00:00.000Z",
        givenAs: "self",
      },
    });
    const withdrawn = await post(target, "/v1/me/study-tools-consent", {
      given: false,
    });
    expect(withdrawn.status).toBe(200);
    expect(calls.map(([op]) => op)).toEqual(["give", "withdraw"]);
    expect(calls[0]![1]).toEqual({ version: "2026-10-15", locale: "ar" });
  });

  test("agreeing without saying which notice is refused", async () => {
    const { repo, calls } = recording();
    const res = await post(app(repo), "/v1/me/study-tools-consent", {
      given: true,
    });
    expect(res.status).toBe(400);
    expect(calls).toEqual([]);
  });

  test("a parent consents for a managed child by its id", async () => {
    const { repo, calls } = recording();
    const res = await post(
      app(repo),
      `/v1/me/managed-children/${ID}/study-tools-consent`,
      { given: true, version: "2026-10-15", locale: "en" },
    );
    expect(res.status).toBe(200);
    expect(calls).toEqual([["child_give", {
      childId: ID,
      version: "2026-10-15",
      locale: "en",
    }]]);
  });

  test("the database's refusals are problems the app can act on", async () => {
    const refusing = (outcome: string): AiAccessRepository => ({
      call: async () => ({ outcome }),
    });
    const body = { given: true, version: "2026-10-15", locale: "en" };
    const cases: [string, number, string][] = [
      ["guardian_consent_required", 403, "AI_GUARDIAN_CONSENT_REQUIRED"],
      ["not_student", 403, "AI_STUDENTS_ONLY"],
      ["stale_version", 409, "INVALID_STATE"],
      ["not_found", 404, "NOT_FOUND"],
    ];
    for (const [outcome, status, code] of cases) {
      const res = await post(
        app(refusing(outcome)),
        "/v1/me/study-tools-consent",
        body,
      );
      expect(res.status, outcome).toBe(status);
      expect((await res.json() as { code: string }).code).toBe(code);
    }
  });
});
