/**
 * The personal notebook (ADR-0045): notes in no class, editing one's own
 * notes, a photo or screenshot into notes (Plus), and practice from one's
 * own notes (Max). The SQL decides whose notes are whose
 * (supabase/tests/independent_students.sql); these check what the routes do
 * around it.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { deflateSync } from "node:zlib";
import { createJsonLogger } from "@studafy/observability";
import type { StudyAssistant } from "@studafy/infrastructure";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import {
  createPersonalNotebookRoutes,
  type PersonalNotebookRepository,
} from "../../src/study/personalNotebookRoutes";
import type { AiAccess } from "../../src/study/aiAccess";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";
import { fakeAiAccess } from "../support/aiAccess";

const SUBJECT = "00000000-0000-4000-8000-000000000001";
const NOTE = "00000000-0000-4000-8000-0000000000e1";

interface Calls {
  commands: {
    operation: string;
    resourceId: string | null;
    body: Record<string, unknown>;
  }[];
  reserved: string[];
  photos: number;
  sets: string[];
}

function entry(body: Record<string, unknown>) {
  return {
    id: NOTE,
    classroomId: null,
    title: body["title"] ?? "Cells",
    body: body["body"] ?? "Cells are the unit of life.",
    source: body["source"] ?? "typed",
    createdAt: "2026-10-21T10:00:00Z",
    updatedAt: "2026-10-21T10:00:00Z",
    photo: null,
  };
}

function app(options: {
  calls: Calls;
  plan?: "free" | "plus" | "max";
  access?: AiAccess;
  practice?: Record<string, unknown>;
  lessonToolsEnabled?: boolean;
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
      // A student with no school at all: the whole point.
      context: { userId: SUBJECT, memberships: [], membershipVersion: "1" },
      aal2: false,
      mfaRequiredByPolicy: false,
    } as unknown as Actor);
    await next();
  });
  const plan = options.plan ?? "free";
  const features: Record<string, string[]> = {
    free: ["ask"],
    plus: ["ask", "whiteboard", "notes"],
    max: ["ask", "whiteboard", "notes", "quiz", "flashcards"],
  };
  const notebook: PersonalNotebookRepository = {
    query: async (_c, operation) => {
      if (operation === "listPersonal") {
        return { outcome: "ok", items: [entry({})] };
      }
      return options.practice ?? {
        outcome: "ok",
        items: [{
          id: NOTE,
          title: "Cells",
          text:
            "Cells are the basic unit of life. Every living thing is made of cells.",
        }],
      };
    },
    command: async (_c, operation, resourceId, body) => {
      options.calls.commands.push({ operation, resourceId, body });
      return {
        outcome: "ok",
        response: operation === "deleteEntry"
          ? { id: resourceId, deleted: true }
          : entry(body),
      };
    },
  };
  routes.route(
    "/",
    createPersonalNotebookRoutes(
      {
        aiAccess: fakeAiAccess(options.access ?? "ok"),
        notebook,
        repository: {
          usage: async (_c, operation, input) => {
            if (operation !== "reserve") return { outcome: "ok" };
            const feature = String(input["feature"]);
            options.calls.reserved.push(feature);
            return features[plan]!.includes(feature)
              ? { outcome: "ok", usageId: "u1" }
              : { outcome: "plan_required" };
          },
          query: async () => null,
          command: async () => ({ outcome: "invalid" }),
        },
        prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
        assistant: {
          whiteboardNotes: async () => {
            options.calls.photos++;
            return {
              answer: "# Photosynthesis\n\n## Inputs\n\n- **Light**\n- Water",
              usage: { model: "test-model", inputTokens: 1, outputTokens: 1 },
            };
          },
          studySet: async (kind: string, title: string) => {
            options.calls.sets.push(`${kind}:${title}`);
            return {
              kind: "quiz",
              questions: [{
                question: "What are living things made of?",
                options: ["Cells", "Rocks", "Water", "Air"],
                answerIndex: 0,
                explanation: "Every living thing is made of cells.",
              }],
              usage: { model: "test-model", inputTokens: 1, outputTokens: 1 },
            };
          },
        } as unknown as StudyAssistant,
        lessonToolsEnabled: options.lessonToolsEnabled ?? true,
      },
      createAuthorizationDependencies(logger),
      { repository: new FakeIdempotencyRepository(), logger },
    ),
  );
  return routes;
}

function calls(): Calls {
  return { commands: [], reserved: [], photos: 0, sets: [] };
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

/** A real 16x12 white PNG, built by hand so the test needs no image
 * library: the route decodes and redraws it. */
function screenshot(): string {
  const crcTable = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (bytes: Buffer) => {
    let c = 0xffffffff;
    for (const b of bytes) c = crcTable[(c ^ b) & 0xff]! ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const chunk = (type: string, data: Buffer) => {
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
    const sum = Buffer.alloc(4);
    sum.writeUInt32BE(crc(body));
    return Buffer.concat([length, body, sum]);
  };
  const width = 16, height = 12;
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8; // bit depth
  header[9] = 2; // RGB
  const rows = Buffer.alloc((width * 3 + 1) * height, 0xff);
  for (let y = 0; y < height; y++) rows[y * (width * 3 + 1)] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(rows)),
    chunk("IEND", Buffer.alloc(0)),
  ]).toString("base64");
}

describe("personal notebook", () => {
  test("lists notes that belong to no class", async () => {
    const response = await app({ calls: calls() }).request("/v1/me/notebook");
    expect(response.status).toBe(200);
    const body = await response.json() as { items: { classroomId: unknown }[] };
    expect(body.items[0]!.classroomId).toBeNull();
  });

  test("a typed note is free and always 'typed'", async () => {
    const seen = calls();
    const response = await post(app({ calls: seen }), "/v1/me/notebook", {
      title: "Cells",
      body: "Cells are the unit of life.",
    });
    expect(response.status).toBe(201);
    expect(seen.commands).toEqual([{
      operation: "createPersonal",
      resourceId: null,
      body: {
        title: "Cells",
        body: "Cells are the unit of life.",
        source: "typed",
      },
    }]);
    expect(seen.reserved).toEqual([]);
  });

  test("renaming sends only what changed", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen }),
      `/v1/me/notebook-entries/${NOTE}/edit`,
      { title: "Cell biology" },
    );
    expect(response.status).toBe(200);
    expect(seen.commands[0]).toEqual({
      operation: "updateEntry",
      resourceId: NOTE,
      body: { title: "Cell biology" },
    });
  });

  test("an edit with nothing in it is refused", async () => {
    const response = await post(
      app({ calls: calls() }),
      `/v1/me/notebook-entries/${NOTE}/edit`,
      {},
    );
    expect(response.status).toBe(400);
  });

  test("deletes any of one's own notes", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen }),
      `/v1/me/notebook-entries/${NOTE}/delete`,
      {},
    );
    expect(response.status).toBe(200);
    expect(seen.commands[0]!.operation).toBe("deleteEntry");
  });
});

describe("a photo or screenshot into notes", () => {
  test("is Studafy Plus: a free student is refused before the model runs", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen }),
      "/v1/me/notebook/photo-notes",
      {
        image: { mediaType: "image/png", data: screenshot() },
      },
    );
    expect(response.status).toBe(403);
    expect((await response.json() as { code: string }).code).toBe(
      "PLAN_REQUIRED",
    );
    expect(seen.photos).toBe(0);
    expect(seen.commands).toEqual([]);
  });

  test("on Plus, files structured notes titled by their heading", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen, plan: "plus" }),
      "/v1/me/notebook/photo-notes",
      { image: { mediaType: "image/png", data: screenshot() } },
    );
    expect(response.status).toBe(201);
    expect(seen.photos).toBe(1);
    expect(seen.reserved).toEqual(["whiteboard"]);
    expect(seen.commands[0]!.body).toMatchObject({
      title: "Photosynthesis",
      source: "whiteboard",
    });
    expect(String(seen.commands[0]!.body["body"])).toContain("## Inputs");
  });

  test("refuses bytes that are not the declared image type", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen, plan: "plus" }),
      "/v1/me/notebook/photo-notes",
      {
        image: {
          mediaType: "image/png",
          data: Buffer.from("%PDF-1.7 not an image at all").toString("base64"),
        },
      },
    );
    expect(response.status).toBe(415);
    expect(seen.photos).toBe(0);
  });

  test("a parent or teacher account is refused by the AI gate", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen, plan: "plus", access: "not_student" }),
      "/v1/me/notebook/photo-notes",
      { image: { mediaType: "image/png", data: screenshot() } },
    );
    expect(response.status).toBe(403);
    expect(seen.photos).toBe(0);
  });

  test("answers 'not available' while the lesson tools are off", async () => {
    const response = await post(
      app({ calls: calls(), plan: "plus", lessonToolsEnabled: false }),
      "/v1/me/notebook/photo-notes",
      { image: { mediaType: "image/png", data: screenshot() } },
    );
    expect(response.status).toBe(409);
  });
});

describe("practice from one's own notes", () => {
  test("on Max, a quiz from the chosen notes", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen, plan: "max" }),
      "/v1/me/notebook/practice",
      { kind: "quiz", entryIds: [NOTE] },
    );
    expect(response.status).toBe(201);
    const body = await response.json() as {
      kind: string;
      questions: unknown[];
    };
    expect(body.kind).toBe("quiz");
    expect(body.questions.length).toBe(1);
    expect(seen.sets).toEqual(["quiz:Cells"]);
  });

  test("the SQL's plan refusal is passed on", async () => {
    const seen = calls();
    const response = await post(
      app({
        calls: seen,
        plan: "plus",
        practice: { outcome: "plan_required" },
      }),
      "/v1/me/notebook/practice",
      { kind: "flashcards", entryIds: [NOTE] },
    );
    expect(response.status).toBe(403);
    expect(seen.sets).toEqual([]);
  });

  test("someone else's note is not found", async () => {
    const response = await post(
      app({ calls: calls(), plan: "max", practice: { outcome: "not_found" } }),
      "/v1/me/notebook/practice",
      { kind: "quiz", entryIds: [NOTE] },
    );
    expect(response.status).toBe(404);
  });
});
