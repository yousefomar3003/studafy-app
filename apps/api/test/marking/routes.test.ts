/**
 * AI-suggested marks against the teacher's reference (ADR-0046). The SQL
 * decides who teaches what and who may opt out
 * (supabase/tests/marking_suggestions.sql); these check what the routes do
 * around it: the server switch, the plan refusal, the request shapes, and
 * that a response is held to its contract.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { createJsonLogger } from "@studafy/observability";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import {
  createMarkingRoutes,
  type MarkingRepository,
} from "../../src/marking/routes";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";

const SUBJECT = "00000000-0000-4000-8000-000000000001";
const ASSESSMENT = "00000000-0000-4000-8000-0000000000a1";
const QUESTION = "00000000-0000-4000-8000-0000000000b1";
const SUGGESTION = "00000000-0000-4000-8000-0000000000c1";
const STUDENT = "00000000-0000-4000-8000-0000000000d1";
const RUN = "00000000-0000-4000-8000-0000000000e1";

interface Calls {
  queries: { operation: string; resourceId: string | null }[];
  commands: {
    operation: string;
    resourceId: string | null;
    body: Record<string, unknown>;
  }[];
}

const settings = { strictness: "balanced", referenceVersion: 2 };
const reference = {
  questionId: QUESTION,
  position: 1,
  kind: "essay",
  prompt: "Explain photosynthesis.",
  maximumScore: 5,
  options: [],
  correctOptionIds: null,
  correctChoice: null,
  acceptedAnswers: null,
  preferredAnswer: "Light, water and carbon dioxide make glucose and oxygen.",
  markingGuidance: null,
  keyPoints: [{ text: "Names light as the energy source", marks: 1 }],
  acceptedMethods: null,
  partialCredit: null,
};
const suggestion = {
  id: SUGGESTION,
  studentId: STUDENT,
  attemptId: RUN,
  questionId: QUESTION,
  submissionAttemptId: null,
  status: "ready",
  maximumScore: 5,
  suggestedScore: 3,
  met: ["Names light as the energy source"],
  missed: ["Does not name oxygen"],
  rationale: "Two of the three key points.",
  feedback: "Good start: say what the plant gives off.",
  conflict: null,
  reviewReason: null,
  reason: null,
  referenceVersion: 1,
  strictness: "balanced",
  stale: true,
  createdAt: "2026-10-25T10:00:00Z",
  updatedAt: "2026-10-25T10:00:05Z",
};

function app(options: {
  calls: Calls;
  available?: boolean;
  query?: Record<string, Record<string, unknown>>;
  command?: Record<string, Record<string, unknown>>;
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
      context: { userId: SUBJECT, memberships: [], membershipVersion: "1" },
      aal2: false,
      mfaRequiredByPolicy: false,
    } as unknown as Actor);
    await next();
  });
  const queries: Record<string, Record<string, unknown>> = {
    plan: {
      outcome: "ok",
      active: true,
      teacher: true,
      allowance: {
        total: 4_000_000,
        used: 1200,
        resetsAt: "2026-11-01T00:00:00Z",
      },
    },
    references: {
      outcome: "ok",
      delivery: "online",
      settings,
      references: [reference],
    },
    suggestions: { outcome: "ok", settings, items: [suggestion] },
    preference: { outcome: "ok", optedOut: false },
    ...options.query,
  };
  const commands: Record<string, Record<string, unknown>> = {
    setReferences: {
      outcome: "ok",
      response: {
        settings,
        references: [reference],
        changed: true,
        staleSuggestions: 1,
      },
    },
    requestSuggestions: {
      outcome: "ok",
      response: {
        runId: RUN,
        referenceVersion: 2,
        strictness: "balanced",
        queued: 3,
        optedOut: 1,
        replaced: 0,
      },
    },
    dismissSuggestion: {
      outcome: "ok",
      response: { id: SUGGESTION, status: "dismissed" },
    },
    setPreference: { outcome: "ok", response: { optedOut: true } },
    ...options.command,
  };
  const marking: MarkingRepository = {
    query: async (_c, operation, resourceId) => {
      options.calls.queries.push({ operation, resourceId });
      return queries[operation]!;
    },
    command: async (_c, operation, resourceId, body) => {
      options.calls.commands.push({ operation, resourceId, body });
      return commands[operation] as never;
    },
  };
  routes.route(
    "/",
    createMarkingRoutes(
      { marking, available: options.available ?? true },
      createAuthorizationDependencies(logger),
      { repository: new FakeIdempotencyRepository(), logger },
    ),
  );
  return routes;
}

function calls(): Calls {
  return { queries: [], commands: [] };
}

function post(routes: Hono<AuthorizationEnv>, path: string, body: unknown) {
  return routes.request(path, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "idempotency-key": crypto.randomUUID(),
    },
    body: JSON.stringify(body),
  });
}

describe("Studafy AI Marking plan", () => {
  test("says whether suggestions can be made on this server", async () => {
    for (const available of [true, false]) {
      const response = await app({ calls: calls(), available }).request(
        "/v1/me/marking-plan",
      );
      expect(response.status).toBe(200);
      const body = await response.json() as Record<string, unknown>;
      expect(body["available"]).toBe(available);
      expect(body["active"]).toBe(true);
    }
  });
});

describe("marking references", () => {
  test("are read for the assessment named in the path", async () => {
    const seen = calls();
    const response = await app({ calls: seen }).request(
      `/v1/assessments/${ASSESSMENT}/marking-references`,
    );
    expect(response.status).toBe(200);
    expect(seen.queries).toEqual([{
      operation: "references",
      resourceId: ASSESSMENT,
    }]);
    const body = await response.json() as { references: unknown[] };
    expect(body.references).toHaveLength(1);
  });

  test("an assessment the caller does not teach is not found", async () => {
    const response = await app({
      calls: calls(),
      query: { references: { outcome: "not_found" } },
    }).request(`/v1/assessments/${ASSESSMENT}/marking-references`);
    expect(response.status).toBe(404);
  });

  test("are written with the strictness, and say how many suggestions are stale", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen, available: false }),
      `/v1/assessments/${ASSESSMENT}/marking-references`,
      {
        strictness: "strict",
        references: [{
          questionId: QUESTION,
          keyPoints: [{ text: "Names oxygen", marks: 1 }],
          partialCredit: "One mark per key point.",
        }],
      },
    );
    // References can be written with the server switch off.
    expect(response.status).toBe(200);
    expect(seen.commands[0]!.operation).toBe("setReferences");
    expect(seen.commands[0]!.body["strictness"]).toBe("strict");
    const body = await response.json() as Record<string, unknown>;
    expect(body["staleSuggestions"]).toBe(1);
  });

  test("an unknown strictness or too many key points never reach the SQL", async () => {
    const seen = calls();
    const routes = app({ calls: seen });
    const path = `/v1/assessments/${ASSESSMENT}/marking-references`;
    expect((await post(routes, path, { strictness: "harsh" })).status).toBe(
      400,
    );
    const points = Array.from({ length: 21 }, (_, i) => ({ text: `P${i}` }));
    expect(
      (await post(routes, path, {
        references: [{ questionId: QUESTION, keyPoints: points }],
      })).status,
    ).toBe(400);
    expect(seen.commands).toEqual([]);
  });
});

describe("marking suggestions", () => {
  test("are listed with the stale flag", async () => {
    const response = await app({ calls: calls() }).request(
      `/v1/assessments/${ASSESSMENT}/marking-suggestions`,
    );
    expect(response.status).toBe(200);
    const body = await response.json() as {
      items: { stale: boolean; suggestedScore: number }[];
    };
    expect(body.items[0]).toMatchObject({ stale: true, suggestedScore: 3 });
  });

  test("are asked for only while the server can make them", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen, available: false }),
      `/v1/assessments/${ASSESSMENT}/marking-suggestions`,
      {},
    );
    expect(response.status).toBe(409);
    expect((await response.json() as { code: string }).code).toBe(
      "AI_FEATURE_DISABLED",
    );
    expect(seen.commands).toEqual([]);
  });

  test("asking queues a run and reports opted-out students", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen }),
      `/v1/assessments/${ASSESSMENT}/marking-suggestions`,
      { scope: "all", studentIds: [STUDENT] },
    );
    expect(response.status).toBe(201);
    expect(seen.commands[0]).toEqual({
      operation: "requestSuggestions",
      resourceId: ASSESSMENT,
      body: { scope: "all", studentIds: [STUDENT] },
    });
    const body = await response.json() as Record<string, unknown>;
    expect(body).toMatchObject({ queued: 3, optedOut: 1 });
  });

  test("without the plan the teacher is told so", async () => {
    const response = await post(
      app({
        calls: calls(),
        command: { requestSuggestions: { outcome: "plan_required" } },
      }),
      `/v1/assessments/${ASSESSMENT}/marking-suggestions`,
      {},
    );
    expect(response.status).toBe(403);
    expect((await response.json() as { code: string }).code).toBe(
      "PLAN_REQUIRED",
    );
  });

  test("a suggestion can be dismissed", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen }),
      `/v1/marking-suggestions/${SUGGESTION}/dismiss`,
      {},
    );
    expect(response.status).toBe(200);
    expect(seen.commands[0]!.resourceId).toBe(SUGGESTION);
  });

  test("a reply the contract does not allow is never passed on", async () => {
    const response = await app({
      calls: calls(),
      query: {
        suggestions: {
          outcome: "ok",
          settings,
          items: [{ ...suggestion, suggestedScore: -1 }],
        },
      },
    }).request(`/v1/assessments/${ASSESSMENT}/marking-suggestions`);
    expect(response.status).toBe(500);
  });
});

describe("a student's choice", () => {
  test("is read and written as their own", async () => {
    const seen = calls();
    const routes = app({ calls: seen });
    const read = await routes.request("/v1/me/marking-preference");
    expect(await read.json()).toEqual({ optedOut: false });
    const write = await post(routes, "/v1/me/marking-preference", {
      optedOut: true,
    });
    expect(write.status).toBe(200);
    expect(seen.commands[0]).toEqual({
      operation: "setPreference",
      resourceId: null,
      body: { optedOut: true },
    });
  });

  test("a teacher or parent is refused by the SQL", async () => {
    const response = await post(
      app({
        calls: calls(),
        command: { setPreference: { outcome: "forbidden" } },
      }),
      "/v1/me/marking-preference",
      { optedOut: true },
    );
    expect(response.status).toBe(403);
  });
});
