/**
 * The same whiteboard photo is not sent to the AI twice: while the note made
 * from it exists, that note is the answer (202609290005).
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { createJsonLogger } from "@studafy/observability";
import type { StudyAssistant } from "@studafy/infrastructure";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import type { NotebookRepository } from "../../src/study/notebookRoutes";
import { createStudyRoutes } from "../../src/study/routes";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";

const SUBJECT = "00000000-0000-4000-8000-000000000001";
const CLASS = "00000000-0000-4000-8000-0000000000c1";
const PHOTO = "00000000-0000-4000-8000-0000000000f1";
const SCHOOL = "00000000-0000-4000-8000-0000000000a1";

const existing = {
  id: "00000000-0000-4000-8000-0000000000e1",
  classroomId: CLASS,
  title: "Photosynthesis",
  body: "# Photosynthesis\n\n- Light to sugar",
  source: "whiteboard",
  createdAt: "2026-09-29T10:00:00Z",
  photo: null,
};

function app(notebooks: NotebookRepository, calls: string[]) {
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
  routes.route(
    "/",
    createStudyRoutes(
      {
        repository: {
          usage: async (_c, operation) => {
            calls.push(`usage:${operation}`);
            return { outcome: "ok", usageId: "u1" };
          },
          query: async (_c, operation) => {
            calls.push(`query:${operation}`);
            return null;
          },
          command: async () => ({ outcome: "invalid" }),
        },
        prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
        assistant: {
          whiteboardNotes: async () => {
            calls.push("ai");
            return { answer: "new notes" };
          },
        } as unknown as StudyAssistant,
        lessonToolsEnabled: true,
        storage: {} as never,
        notebooks,
      },
      {
        ...createAuthorizationDependencies(logger),
        repository: {
          authorize: async () => ({
            allowed: true,
            schoolId: SCHOOL,
            reason: "allowed" as const,
          }),
        },
      },
      { repository: new FakeIdempotencyRepository(), logger },
    ),
  );
  return routes;
}

const send = (routes: Hono<AuthorizationEnv>) =>
  routes.request(`/v1/classrooms/${CLASS}/notebook/whiteboard`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "idempotency-key": crypto.randomUUID(),
    },
    body: JSON.stringify({ photoFileId: PHOTO }),
  });

describe("a whiteboard photo sent again", () => {
  test("returns the note already made, with no AI call or charge", async () => {
    const calls: string[] = [];
    const res = await send(app({
      call: async (_c, operation, resourceId) => {
        calls.push(`notebooks:${operation}:${resourceId}`);
        return { outcome: "ok", entry: existing };
      },
    }, calls));
    expect(res.status).toBe(201);
    expect(await res.json()).toMatchObject({
      id: existing.id,
      source: "whiteboard",
    });
    expect(calls).toEqual([`notebooks:whiteboardEntry:${PHOTO}`]);
  });

  test("without a live note, the photo goes on to be read", async () => {
    const calls: string[] = [];
    await send(app({
      call: async () => ({ outcome: "ok", entry: null }),
    }, calls));
    // Past the reuse check: the photo is looked up for reading.
    expect(calls).toContain("query:getNotebookPhoto");
  });
});
