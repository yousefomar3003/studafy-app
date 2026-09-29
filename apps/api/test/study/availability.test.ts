/**
 * The plan summary says which AI features this server can actually run, so
 * the app can explain a switched-off feature instead of offering one whose
 * every use fails. It must agree with the checks the AI routes make.
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
import { costMicroUsd, holdFor } from "../../src/study/metering";
import { createStudyAssistantRoutes } from "../../src/study-assistant/routes";

const SUBJECT = "00000000-0000-4000-8000-000000000001";

const repository: StudyRepository = {
  usage: async () => ({
    outcome: "ok",
    plan: "max",
    features: ["ask", "whiteboard", "quiz", "flashcards"],
    capMicroUsd: 1_600_000,
    committedMicroUsd: 0,
    askToday: 0,
    askPerDay: 60,
    resetsAt: "2026-10-01T00:00:00Z",
  }),
  query: async () => null,
  command: async () => ({ outcome: "invalid" }),
};

async function available(
  options: { assistant: boolean; lessonTools: boolean; storage: boolean },
): Promise<unknown> {
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
      context: { userId: SUBJECT, memberships: [] },
      aal2: false,
      mfaRequiredByPolicy: false,
    } as unknown as Actor);
    await next();
  });
  app.route(
    "/",
    createStudyRoutes(
      {
        repository,
        prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
        assistant: options.assistant ? {} as StudyAssistant : null,
        lessonToolsEnabled: options.lessonTools,
        storage: options.storage ? {} as never : null,
      },
      createAuthorizationDependencies(createJsonLogger("api", "test", "error")),
      {} as never,
    ),
  );
  const res = await app.request("/v1/me/study-plan");
  expect(res.status).toBe(200);
  return (await res.json() as { available: unknown }).available;
}

describe("what the plan summary says is available", () => {
  test("no AI provider: nothing, whatever the plan includes", async () => {
    expect(
      await available({ assistant: false, lessonTools: true, storage: true }),
    ).toEqual([]);
  });

  test("a provider without the lesson-tools switch: only the question box", async () => {
    expect(
      await available({ assistant: true, lessonTools: false, storage: true }),
    ).toEqual(["ask"]);
  });

  test("lesson tools on but no photo storage: no whiteboard notes", async () => {
    expect(
      await available({ assistant: true, lessonTools: true, storage: false }),
    ).toEqual(["ask", "quiz", "flashcards"]);
  });

  test("everything configured: everything", async () => {
    expect(
      await available({ assistant: true, lessonTools: true, storage: true }),
    ).toEqual(["ask", "whiteboard", "quiz", "flashcards"]);
  });
});

describe("the hold for a question", () => {
  const prices = { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 };

  test("grows with the chat sent along, so the cap can never be passed", () => {
    const alone = holdFor(prices, "ask");
    const withChat = holdFor(prices, "ask", 8 * 2_000);
    // 16,000 characters at two a token is 8,000 more input tokens.
    expect(withChat - alone).toBe(costMicroUsd(prices, 8_000, 0));
  });
});

describe("chat memory by plan", () => {
  const budgets = {
    contextWindowTokens: 262_144,
    freeTokens: 10,
    paidTokens: 1_000,
  };

  async function askWith(plan: string, turns: number) {
    const heard: { text: string }[][] = [];
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
        context: { userId: SUBJECT, memberships: [] },
        aal2: false,
        mfaRequiredByPolicy: false,
      } as unknown as Actor);
      await next();
    });
    app.route(
      "/",
      createStudyAssistantRoutes(
        {
          assistant: {
            ask: async (_question, history = []) => {
              heard.push(history);
              return { answer: "ok" };
            },
          },
          repository: {
            usage: async (_context, operation) =>
              operation === "reserve"
                ? { outcome: "ok", usageId: "u1" }
                : { outcome: "ok", plan, askPerDay: 10, askToday: 1 },
            query: async () => null,
            command: async () => ({ outcome: "invalid" }),
          },
          prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
          chatMemory: budgets,
        },
        createAuthorizationDependencies(
          createJsonLogger("api", "test", "error"),
        ),
      ),
    );
    const history = Array.from({ length: turns }, (_, i) => ({
      role: i % 2 === 0 ? "student" : "assistant",
      text: `turn ${String(i).padStart(2, "0")}`, // 7 characters each
    }));
    const res = await app.request("/v1/study-assistant/ask", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ question: "And then?", history }),
    });
    expect(res.status).toBe(200);
    return heard[0]!;
  }

  test("a free chat is remembered up to the free budget, newest first", async () => {
    // Ten tokens is twenty characters: the last two seven-character turns.
    const heard = await askWith("free", 20);
    expect(heard.map((t) => t.text)).toEqual(["turn 18", "turn 19"]);
  });

  test("a paid chat is remembered much further back", async () => {
    expect(await askWith("max", 20)).toHaveLength(20);
  });
});
