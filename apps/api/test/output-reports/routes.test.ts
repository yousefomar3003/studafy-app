/**
 * Reporting an AI answer (DL-076). The SQL decides who may file and stores
 * the report (supabase/tests/ai_output_reports.sql); these check what the
 * route does around it: the request shape, that the caller and nothing in
 * the body is the reporter, the refusals, and that the response is held to
 * its contract and never carries the output.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import {
  createOutputReportRoutes,
  type OutputReportRepository,
} from "../../src/output-reports/routes";
import type { RequestDbContext } from "../../src/platform/dbContext";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";

const SUBJECT = "00000000-0000-4000-8000-000000000001";
const REPORT = "00000000-0000-4000-8000-0000000000a1";

interface Filed {
  context: RequestDbContext;
  body: Record<string, unknown>;
}

function app(
  options: {
    filed?: Filed[];
    result?: Record<string, unknown>;
    collector?: LogCollector;
  } = {},
) {
  const logger = createJsonLogger(
    "api",
    "test",
    options.collector ? "debug" : "error",
    options.collector?.sink,
  );
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
      // No school at all: a student with no class reports too.
      context: { userId: SUBJECT, memberships: [], membershipVersion: "1" },
      aal2: false,
      mfaRequiredByPolicy: false,
    } as unknown as Actor);
    await next();
  });
  const reports: OutputReportRepository = {
    file: async (context, body) => {
      options.filed?.push({ context, body });
      return (options.result ?? {
        outcome: "ok",
        response: { id: REPORT, createdAt: "2026-11-03T10:00:00.000Z" },
      }) as never;
    },
  };
  routes.route(
    "/",
    createOutputReportRoutes(
      { reports },
      createAuthorizationDependencies(logger),
      { repository: new FakeIdempotencyRepository(), logger },
    ),
  );
  return routes;
}

function post(
  routes: Hono<AuthorizationEnv>,
  body: unknown,
  key: string | null = crypto.randomUUID(),
) {
  return routes.request("/v1/me/output-reports", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(key ? { "idempotency-key": key } : {}),
    },
    body: JSON.stringify(body),
  });
}

const valid = {
  feature: "tutor",
  reason: "offensive",
  details: "  It was rude.  ",
  excerpt: "The AI answer as shown.",
};

describe("reporting an AI answer", () => {
  test("files it as the caller, with no school, and answers 201", async () => {
    const filed: Filed[] = [];
    const collector = new LogCollector();
    const response = await post(app({ filed, collector }), valid);
    expect(response.status).toBe(201);
    expect(await response.json()).toEqual({
      id: REPORT,
      createdAt: "2026-11-03T10:00:00.000Z",
    });
    expect(filed).toHaveLength(1);
    expect(filed[0]!.context.subject).toBe(SUBJECT);
    expect(filed[0]!.context.schoolId).toBeNull();
    expect(filed[0]!.body).toEqual({
      feature: "tutor",
      reason: "offensive",
      details: "It was rude.",
      excerpt: "The AI answer as shown.",
    });
    // The log says a report was filed, never what it says.
    const log = collector.lines.join("\n");
    expect(log).toContain("output_report_filed");
    expect(log).not.toContain("The AI answer as shown.");
    expect(log).not.toContain("It was rude.");
  });

  test("details are optional", async () => {
    const filed: Filed[] = [];
    const { details: _details, ...withoutDetails } = valid;
    const response = await post(app({ filed }), withoutDetails);
    expect(response.status).toBe(201);
    expect(filed[0]!.body["details"]).toBeNull();
  });

  test("every feature and reason the app offers is accepted", async () => {
    for (
      const feature of [
        "tutor",
        "notes",
        "notebook",
        "quiz",
        "flashcards",
        "summary",
      ]
    ) {
      for (const reason of ["offensive", "harmful", "wrong", "other"]) {
        const response = await post(app(), { ...valid, feature, reason });
        expect({ feature, reason, status: response.status }).toEqual({
          feature,
          reason,
          status: 201,
        });
      }
    }
  });

  test("a malformed request reaches nothing", async () => {
    for (
      const body of [
        { ...valid, feature: "chat" },
        { ...valid, reason: "rude" },
        { ...valid, excerpt: "   " },
        { ...valid, excerpt: "x".repeat(4001) },
        { ...valid, details: "d".repeat(1001) },
        // The reporter is the caller; it cannot be named.
        { ...valid, reporterId: SUBJECT },
        { ...valid, schoolId: SUBJECT },
      ]
    ) {
      const filed: Filed[] = [];
      const response = await post(app({ filed }), body);
      expect(response.status).toBe(400);
      expect(filed).toEqual([]);
    }
  });

  test("an idempotency key is required", async () => {
    const filed: Filed[] = [];
    const response = await post(app({ filed }), valid, null);
    expect(response.status).toBe(400);
    expect(filed).toEqual([]);
  });

  test("the database's refusals become problems", async () => {
    const forbidden = await post(
      app({ result: { outcome: "forbidden" } }),
      valid,
    );
    expect(forbidden.status).toBe(403);
    const invalid = await post(app({ result: { outcome: "invalid" } }), valid);
    expect(invalid.status).toBe(400);
  });

  test("a response outside the contract is not passed on", async () => {
    const response = await post(
      app({
        result: {
          outcome: "ok",
          response: { id: REPORT, createdAt: "now", excerpt: "leak" },
        },
      }),
      valid,
    );
    expect(response.status).toBe(500);
    expect(await response.text()).not.toContain("leak");
  });
});
