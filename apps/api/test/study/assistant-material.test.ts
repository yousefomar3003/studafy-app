/**
 * The study helper reading class material and photos. The SQL decides what
 * a student may read (supabase/tests/assistant_material.sql); these check the
 * route's gates around it.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { createJsonLogger } from "@studafy/observability";
import type { StudyReference } from "@studafy/infrastructure";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { createStudyAssistantRoutes } from "../../src/study-assistant/routes";
import type { NotebookRepository } from "../../src/study/notebookRoutes";

const SUBJECT = "00000000-0000-4000-8000-000000000001";
const LESSON = "00000000-0000-4000-8000-0000000000d1";
const PHOTO = "00000000-0000-4000-8000-0000000000f1";

function app(options: {
  plan?: string;
  lessonToolsEnabled?: boolean;
  notebooks?: NotebookRepository;
  heard?: StudyReference[][];
}) {
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
      context: { userId: SUBJECT, memberships: [] },
      aal2: false,
      mfaRequiredByPolicy: false,
    } as unknown as Actor);
    await next();
  });
  routes.route(
    "/",
    createStudyAssistantRoutes(
      {
        assistant: {
          ask: async (_q, _h, extras) => {
            options.heard?.push(extras?.references ?? []);
            return { answer: "ok" };
          },
        },
        repository: {
          usage: async (_c, operation) =>
            operation === "reserve" ? { outcome: "ok", usageId: "u1" } : {
              outcome: "ok",
              plan: options.plan ?? "free",
              askPerDay: 10,
              askToday: 1,
            },
          query: async () => null,
          command: async () => ({ outcome: "invalid" }),
        },
        prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
        chatMemory: {
          contextWindowTokens: 262_144,
          freeTokens: 4_000,
          paidTokens: 32_000,
        },
        notebooks: options.notebooks ?? {
          call: async (_c, operation) =>
            operation === "references"
              ? {
                outcome: "ok",
                items: [{ title: "Cells", text: "The unit of life." }],
              }
              : { outcome: "ok", object: { rootClean: false } },
        },
        storage: {
          openObject: async () => ({ bytes: new Uint8Array() }),
        } as never,
        lessonToolsEnabled: options.lessonToolsEnabled ?? true,
      },
      createAuthorizationDependencies(createJsonLogger("api", "test", "error")),
    ),
  );
  return routes;
}

function ask(routes: Hono<AuthorizationEnv>, extra: Record<string, unknown>) {
  return routes.request("/v1/study-assistant/ask", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ question: "Explain this", ...extra }),
  });
}

const lessonRef = { references: [{ kind: "lesson", id: LESSON }] };

describe("the helper reading class material", () => {
  test("reads what the student may see, and answers from it", async () => {
    const heard: StudyReference[][] = [];
    const res = await ask(app({ heard }), lessonRef);
    expect(res.status).toBe(200);
    expect(heard[0]).toEqual([{ title: "Cells", text: "The unit of life." }]);
  });

  test("is off while lesson material may not go to the provider", async () => {
    const res = await ask(app({ lessonToolsEnabled: false }), lessonRef);
    expect(res.status).toBe(409);
  });
});

describe("the helper reading photos", () => {
  test("needs Studafy Plus", async () => {
    const res = await ask(app({ plan: "free" }), {
      attachmentFileIds: [PHOTO],
    });
    expect(res.status).toBe(403);
  });

  test("waits for the scan before anything is sent", async () => {
    const res = await ask(app({ plan: "plus" }), {
      attachmentFileIds: [PHOTO],
    });
    expect(res.status).toBe(409);
    expect((await res.json() as { code: string }).code).toBe("PHOTO_NOT_READY");
  });

  test("never sends a photo that is not the student's own", async () => {
    const res = await ask(
      app({
        plan: "plus",
        notebooks: { call: async () => ({ outcome: "not_found" }) },
      }),
      { attachmentFileIds: [PHOTO] },
    );
    expect(res.status).toBe(404);
  });
});
