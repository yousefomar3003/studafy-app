/**
 * The study helper answering from class material and photos (ADR-0037).
 * What a student may read is decided in SQL
 * (supabase/tests/grounded_material.sql); these check what the route sends
 * to the model, what it charges, and what it returns.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { createJsonLogger } from "@studafy/observability";
import type { AskExtras } from "@studafy/infrastructure";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { createStudyAssistantRoutes } from "../../src/study-assistant/routes";
import type { NotebookRepository } from "../../src/study/notebookRoutes";
import type { MaterialRepository } from "../../src/study/material";

const SUBJECT = "00000000-0000-4000-8000-000000000001";
const LESSON = "00000000-0000-4000-8000-0000000000d1";
const PDF = "00000000-0000-4000-8000-0000000000e1";
const LINK = "00000000-0000-4000-8000-0000000000e2";
const PHOTO = "00000000-0000-4000-8000-0000000000f1";

const allowance = {
  period: "week",
  total: 40_000,
  used: 3_200,
  remaining: 36_800,
  resetsAt: "2026-10-12T00:00:00.000Z",
};

interface Seen {
  extras: AskExtras[];
  questions: string[];
  reserves: Record<string, unknown>[];
  retrieves: Record<string, unknown>[];
}

function app(options: {
  plan?: string;
  lessonToolsEnabled?: boolean;
  notebooks?: NotebookRepository;
  material?: MaterialRepository;
  reserveOutcome?: string;
  answer?: string;
  seen?: Seen;
}) {
  const seen = options.seen ??
    { extras: [], questions: [], reserves: [], retrieves: [] };
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
  const material: MaterialRepository = options.material ?? {
    call: async (_c, operation, input) => {
      if (operation === "lessons") {
        return {
          outcome: "ok",
          lessons: [{
            resourceId: LESSON,
            title: "Photosynthesis",
            body: "Plants make food from light.",
            grade: "7",
            sources: [
              {
                id: PDF,
                kind: "file",
                name: "Leaf.pdf",
                state: "ready",
                reason: null,
              },
              {
                id: LINK,
                kind: "link",
                name: "Video",
                state: "unsupported",
                reason: "link_video",
              },
            ],
          }],
        };
      }
      seen.retrieves.push(input);
      return {
        outcome: "ok",
        passages: [{
          sourceKind: "file",
          name: "Leaf.pdf",
          page: 3,
          slide: null,
          heading: "Stomata",
          text: "Stomata let carbon dioxide into the leaf.",
        }],
      };
    },
  };
  routes.route(
    "/",
    createStudyAssistantRoutes(
      {
        assistant: {
          ask: async (question, _h, extras) => {
            seen.questions.push(question);
            seen.extras.push(extras ?? {});
            return {
              answer: options.answer ??
                "Stomata let gas in [S2]. Light helps [S1].",
              usage: {
                inputTokens: 2_000,
                outputTokens: 300,
                model: "Qwen/Qwen3.5-9B",
              },
            };
          },
        },
        repository: {
          usage: async (_c, operation, input) => {
            if (operation === "reserve") {
              seen.reserves.push(input);
              return options.reserveOutcome
                ? { outcome: options.reserveOutcome, allowance }
                : { outcome: "ok", usageId: "u1" };
            }
            if (operation === "settle") return { outcome: "ok", allowance };
            return { outcome: "ok", plan: options.plan ?? "free", allowance };
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
        material,
        notebooks: options.notebooks ?? {
          call: async (_c, operation) =>
            operation === "references"
              ? {
                outcome: "ok",
                items: [{ title: "My notes", text: "Chlorophyll is green." }],
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
  return { routes, seen };
}

function ask(routes: Hono<AuthorizationEnv>, extra: Record<string, unknown>) {
  return routes.request("/v1/study-assistant/ask", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      question: "How does the leaf take in gas?",
      ...extra,
    }),
  });
}

const lessonRef = { references: [{ kind: "lesson", id: LESSON }] };

describe("answering from a lesson", () => {
  test("sends the lesson and its best passages, and cites them", async () => {
    const { routes, seen } = app({});
    const res = await ask(routes, { ...lessonRef, language: "ar" });
    expect(res.status).toBe(200);
    const body = await res.json() as Record<string, unknown>;
    const extras = seen.extras[0]!;
    expect(extras.passages?.map((p) => [p.sourceKind, p.name, p.page ?? null]))
      .toEqual([["lesson", "Photosynthesis", null], ["file", "Leaf.pdf", 3]]);
    expect(extras.learner).toEqual({ grade: "7", language: "ar" });
    // [S2] is the PDF's page 3, cited first, so it is [1].
    expect(body["answer"]).toBe("Stomata let gas in [1]. Light helps [2].");
    expect(body["citations"]).toEqual([
      {
        n: 1,
        sourceKind: "file",
        name: "Leaf.pdf",
        lessonTitle: "Photosynthesis",
        page: 3,
        slide: null,
      },
      {
        n: 2,
        sourceKind: "lesson",
        name: "Photosynthesis",
        lessonTitle: null,
        page: null,
        slide: null,
      },
    ]);
    expect(body["allowance"]).toEqual(allowance);
  });

  test("tells the model, and the student, what could not be read", async () => {
    const { routes, seen } = app({});
    const body = await (await ask(routes, lessonRef)).json() as Record<
      string,
      unknown
    >;
    expect(seen.extras[0]!.unreadable).toEqual([
      { name: "Video", reason: "it is a video", code: "link_video" } as never,
    ]);
    expect(body["unreadable"]).toEqual([{
      name: "Video",
      reason: "link_video",
    }]);
  });

  test("one file chosen on its own: only it is searched, not the lesson text", async () => {
    const { routes, seen } = app({});
    await ask(routes, {
      references: [{ kind: "file", id: PDF, lessonId: LESSON }],
    });
    expect(seen.retrieves[0]!["sourceIds"]).toEqual([PDF]);
    expect(seen.extras[0]!.passages?.some((p) => p.sourceKind === "lesson"))
      .toBe(false);
  });

  test("a named page is looked up; a summary reads across everything", async () => {
    const { routes, seen } = app({});
    await ask(routes, { ...lessonRef, question: "Explain page 3" });
    expect(seen.retrieves[0]).toMatchObject({ pages: [3], mode: "search" });
    await ask(routes, { ...lessonRef, question: "Summarise this lesson" });
    expect(seen.retrieves[1]).toMatchObject({ mode: "coverage" });
  });

  test("a follow-up keeps the topic of the question before it", async () => {
    const { routes, seen } = app({});
    await ask(routes, {
      ...lessonRef,
      question: "Explain more simply",
      history: [
        { role: "student", text: "What do stomata do?" },
        { role: "assistant", text: "They let gas in." },
      ],
    });
    expect(String(seen.retrieves[0]!["query"])).toContain("stomata");
  });

  test("labels the model made up are dropped, never shown as sources", async () => {
    const { routes } = app({ answer: "Plants are green [S7]." });
    const body = await (await ask(routes, lessonRef)).json() as Record<
      string,
      unknown
    >;
    expect(body["answer"]).toBe("Plants are green .");
    expect(body["citations"]).toEqual([]);
  });

  test("is off while lesson material may not go to the provider", async () => {
    const res = await ask(app({ lessonToolsEnabled: false }).routes, lessonRef);
    expect(res.status).toBe(409);
  });
});

describe("tokens", () => {
  test("a question is held at its size before the model is asked", async () => {
    const { routes, seen } = app({});
    await ask(routes, {
      ...lessonRef,
      requestId: "11111111-1111-4111-8111-111111111111",
    });
    const reserve = seen.reserves[0]!;
    expect(reserve["feature"]).toBe("ask");
    // Instructions, material, question and the longer answer bound.
    expect(Number(reserve["estimateTokens"])).toBeGreaterThan(700 + 1_400);
    expect(reserve["requestKey"]).toBe(
      "ask:11111111-1111-4111-8111-111111111111",
    );
  });

  test("an allowance too small for the question costs nothing and says so", async () => {
    const { routes, seen } = app({ reserveOutcome: "allowance_exhausted" });
    const res = await ask(routes, lessonRef);
    expect(res.status).toBe(429);
    expect((await res.json() as { code: string }).code).toBe(
      "AI_ALLOWANCE_USED",
    );
    expect(seen.questions).toEqual([]);
  });

  test("the same request still running is not answered twice", async () => {
    const res = await ask(
      app({ reserveOutcome: "in_progress" }).routes,
      lessonRef,
    );
    expect(res.status).toBe(409);
    expect((await res.json() as { code: string }).code).toBe(
      "AI_REQUEST_IN_PROGRESS",
    );
  });
});

describe("the helper reading photos", () => {
  test("needs Studafy Plus", async () => {
    const res = await ask(app({ plan: "free" }).routes, {
      attachmentFileIds: [PHOTO],
    });
    expect(res.status).toBe(403);
  });

  test("waits for the scan before anything is sent", async () => {
    const res = await ask(app({ plan: "plus" }).routes, {
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
      }).routes,
      { attachmentFileIds: [PHOTO] },
    );
    expect(res.status).toBe(404);
  });
});
