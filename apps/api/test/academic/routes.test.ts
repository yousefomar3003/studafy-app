/**
 * API-041 academic route behaviour with the platform middlewares mounted.
 *
 * These tests drive the real route catalogue, real Zod validation, the real
 * authorization middleware and the real idempotency middleware, with only the
 * domain repository faked. The SQL domain semantics are proven separately by
 * supabase/tests/api041_academic.sql and academic.integration.test.ts.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { filterHash, signCursor } from "../../src/platform/cursor";
import type {
  IdempotencyRepository,
  Reservation,
} from "../../src/platform/idempotency";
import type {
  AcademicCommandResult,
  AcademicRepository,
  RequestDbContext,
} from "../../src/academic/repository";
import { createAcademicRoutes } from "../../src/academic/routes";
import { baseContext } from "../auth/fake-repository";
import type {
  ResourceAuthorizationDecision,
  ResourceAuthorizationRepository,
} from "../../src/authorization/repository";
import type { Permission } from "../../src/authorization/catalogue";

const SCHOOL = "bbbbbbbb-0000-4000-8000-000000000001";
const TERM = "cccccccc-0000-4000-8000-000000000001";
const CLASSROOM = "dddddddd-0000-4000-8000-000000000001";
const ASSIGNMENT = "eeeeeeee-0000-4000-8000-000000000001";
const POSITION = "abcd0000-0000-4000-8000-000000000010";
const CURSOR_KEY = "api041-test-cursor-signing-key-0001";

function classroomItem() {
  return {
    id: CLASSROOM,
    schoolId: SCHOOL,
    termId: TERM,
    name: "Biology",
    grade: "10",
    section: "A",
    room: null,
    status: "active" as const,
    version: 1,
    studentCount: 12,
    weeklySessions: 2,
    termName: "Term 1",
  };
}

function assignmentResponse() {
  return {
    id: ASSIGNMENT,
    classroomId: CLASSROOM,
    title: "Atomic models",
    instructions: null,
    dueAt: "2026-09-20T10:00:00Z",
    closesAt: null,
    state: "published" as const,
    version: 2,
    submissionId: null,
    submittedAt: null,
  };
}

const assignmentBody = {
  classroomId: CLASSROOM,
  title: "Atomic models",
  instructions: "Draw and label the parts.",
  dueAt: "2026-09-20T10:00:00Z",
  closesAt: null,
};

class FakeAcademicRepository implements AcademicRepository {
  readonly queries: {
    operation: string;
    resourceId: string | null;
    input: unknown;
  }[] = [];
  readonly commands: {
    operation: string;
    resourceId: string | null;
    input: unknown;
    reservation: { id: string; generation: number };
  }[] = [];
  readonly queryResults = new Map<string, unknown>();
  readonly commandResults = new Map<string, AcademicCommandResult>();

  /** Mirrors the SQL boundary, where the domain mutation and the idempotency
   * completion commit in one transaction. */
  constructor(private readonly idempotency?: InMemoryIdempotency) {}

  async query(
    _context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
  ): Promise<unknown> {
    this.queries.push({ operation, resourceId, input });
    return this.queryResults.get(operation) ?? null;
  }

  async command(
    _context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
    reservation: { id: string; generation: number },
  ): Promise<AcademicCommandResult> {
    this.commands.push({ operation, resourceId, input, reservation });
    const result = this.commandResults.get(operation) ??
      { outcome: "ok", response: assignmentResponse() };
    const status =
      typeof (input as { responseStatus?: number })?.responseStatus === "number"
        ? (input as { responseStatus: number }).responseStatus
        : 200;
    if (result.outcome === "ok") {
      await this.idempotency?.complete(
        actorSubject,
        reservation.id,
        reservation.generation,
        status,
        result.response,
      );
    }
    return result;
  }
}

class InMemoryIdempotency implements IdempotencyRepository {
  readonly entries = new Map<
    string,
    {
      id: string;
      generation: number;
      hash: string;
      status: number;
      body: unknown;
    }
  >();

  async reserve(
    _subject: string,
    input: Parameters<IdempotencyRepository["reserve"]>[1],
  ): Promise<Reservation> {
    const existing = this.entries.get(input.key);
    if (!existing) {
      const id = crypto.randomUUID();
      this.entries.set(input.key, {
        id,
        generation: 1,
        hash: input.requestHash,
        status: -1,
        body: null,
      });
      return { outcome: "reserved", id, generation: 1 };
    }
    if (existing.hash !== input.requestHash) return { outcome: "mismatch" };
    if (existing.status === -1) return { outcome: "inProgress" };
    return {
      outcome: "replay",
      responseStatus: existing.status,
      responseBody: existing.body,
    };
  }

  async complete(
    _subject: string,
    id: string,
    _generation: number,
    status: number,
    body: unknown,
  ): Promise<boolean> {
    const entry = [...this.entries.values()].find((candidate) =>
      candidate.id === id
    );
    if (!entry || entry.status !== -1) return false;
    entry.status = status;
    entry.body = body;
    return true;
  }

  async fail(): Promise<boolean> {
    return true;
  }
}

const actorSubject = baseContext().userId;

class FakeAuthorizationRepository implements ResourceAuthorizationRepository {
  decision: ResourceAuthorizationDecision = {
    allowed: true,
    schoolId: SCHOOL,
    reason: "allowed",
  };
  calls: { subject: string; permission: Permission; resourceId: string }[] = [];

  authorize(subject: string, permission: Permission, resourceId: string) {
    this.calls.push({ subject, permission, resourceId });
    return Promise.resolve(this.decision);
  }
}

class RecordingIdempotencyRepository implements IdempotencyRepository {
  readonly reservations = 0;

  async reserve(
    _subject: string,
    input: Parameters<IdempotencyRepository["reserve"]>[1],
  ): Promise<Reservation> {
    throw new Error(
      `unexpected reservation for ${input.scope}; authorization must deny first`,
    );
  }

  async complete(): Promise<boolean> {
    return false;
  }

  async fail(): Promise<boolean> {
    return false;
  }
}

function actor(): Actor {
  return {
    token: {
      subject: baseContext().userId,
      sessionId: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
      issuedAt: 1,
      expiresAt: 4_000_000_000,
      assuranceLevel: "aal1",
      authMethods: [],
      // Hostile claims are retained to prove they are never an input.
      claims: {
        school_id: "99999999-0000-4000-8000-000000000009",
        role: "school_admin",
      },
    },
    context: baseContext(),
    aal2: false,
    mfaRequiredByPolicy: false,
  };
}

interface Harness {
  request: (
    path: string,
    init?: RequestInit & { key?: string },
  ) => Promise<Response>;
  repository: FakeAcademicRepository;
  authorization: FakeAuthorizationRepository;
}

function harness(
  options: {
    repository?: FakeAcademicRepository;
    authorization?: FakeAuthorizationRepository;
    idempotency?: IdempotencyRepository;
    enabledSlices?: Parameters<typeof createAcademicRoutes>[0]["enabledSlices"];
  } = {},
): Harness {
  const collector = new LogCollector();
  const logger = createJsonLogger(
    "api",
    "api041-test",
    "debug" as LogLevel,
    collector.sink,
  );
  const idempotency = options.idempotency ?? new InMemoryIdempotency();
  const repository = options.repository ?? new FakeAcademicRepository(
    idempotency instanceof InMemoryIdempotency ? idempotency : undefined,
  );
  const authorization = options.authorization ??
    new FakeAuthorizationRepository();
  const app = new Hono<AuthorizationEnv>();
  app.use("*", async (c, next) => {
    c.set("requestId", crypto.randomUUID());
    c.set("actor", actor());
    await next();
  });
  app.route(
    "/",
    createAcademicRoutes(
      {
        repository,
        cursorSigningKey: CURSOR_KEY,
        ...(options.enabledSlices
          ? { enabledSlices: options.enabledSlices }
          : {}),
      },
      createAuthorizationDependencies(logger, authorization),
      { logger, repository: idempotency },
    ),
  );
  return {
    repository,
    authorization,
    request: async (path, init = {}) => {
      const headers = new Headers(init.headers);
      if (init.body) headers.set("content-type", "application/json");
      if (init.method === "POST" && !headers.has("idempotency-key")) {
        headers.set(
          "idempotency-key",
          init.key ?? "api041-route-test-key-0001",
        );
      }
      return await app.request(path, { ...init, headers });
    },
  };
}

describe("API-041 cursor paging", () => {
  test("issues a signed cursor and pages by position on the next request", async () => {
    const repository = new FakeAcademicRepository();
    repository.queryResults.set("listClassrooms", {
      items: [classroomItem()],
      nextPosition: POSITION,
    });
    const h = harness({ repository });
    const first = await h.request(`/v1/classrooms?schoolId=${SCHOOL}`);
    expect(first.status).toBe(200);
    const page = await first.json() as {
      items: unknown[];
      nextCursor: string | null;
    };
    expect(page.items).toHaveLength(1);
    expect(typeof page.nextCursor).toBe("string");
    expect(repository.queries[0]?.input).toEqual({
      schoolId: SCHOOL,
      pageSize: 50,
      position: null,
    });

    repository.queryResults.set("listClassrooms", {
      items: [classroomItem()],
      nextPosition: null,
    });
    const second = await h.request(
      `/v1/classrooms?schoolId=${SCHOOL}&cursor=${
        encodeURIComponent(page.nextCursor!)
      }`,
    );
    expect(second.status).toBe(200);
    expect((await second.json() as { nextCursor: string | null }).nextCursor)
      .toBeNull();
    expect(repository.queries[1]?.input).toEqual({
      schoolId: SCHOOL,
      pageSize: 50,
      position: POSITION,
    });
  });

  test("rejects garbage and tampered cursor signatures", async () => {
    const h = harness();
    const garbage = await h.request(
      `/v1/classrooms?schoolId=${SCHOOL}&cursor=${"x".repeat(40)}`,
    );
    expect(garbage.status).toBe(400);
    expect(((await garbage.json()) as { code: string }).code).toBe(
      "CURSOR_INVALID",
    );

    const signed = await signCursor(CURSOR_KEY, {
      version: 1,
      filterVersion: 1,
      operation: "listClassrooms",
      schoolId: SCHOOL,
      filterHash: await filterHash({ schoolId: SCHOOL, pageSize: 50 }),
      position: POSITION,
    });
    const [body, signature] = signed.split(".");
    const tampered = `${body}.${signature!.slice(0, -2)}xy`;
    const response = await h.request(
      `/v1/classrooms?schoolId=${SCHOOL}&cursor=${
        encodeURIComponent(tampered)
      }`,
    );
    expect(response.status).toBe(400);
    expect(((await response.json()) as { code: string }).code).toBe(
      "CURSOR_INVALID",
    );
    expect(h.repository.queries).toHaveLength(0);
  });

  test("rejects a validly signed cursor from another school, operation or filter", async () => {
    const h = harness();
    const digest = await filterHash({ schoolId: SCHOOL, pageSize: 50 });
    const foreignSchool = await h.request(
      `/v1/classrooms?schoolId=${SCHOOL}&cursor=${
        encodeURIComponent(
          await signCursor(CURSOR_KEY, {
            version: 1,
            filterVersion: 1,
            operation: "listClassrooms",
            schoolId: "99999999-0000-4000-8000-000000000009",
            filterHash: digest,
            position: POSITION,
          }),
        )
      }`,
    );
    expect(foreignSchool.status).toBe(400);

    const foreignOperation = await h.request(
      `/v1/classrooms?schoolId=${SCHOOL}&cursor=${
        encodeURIComponent(
          await signCursor(CURSOR_KEY, {
            version: 1,
            filterVersion: 1,
            operation: "listTerms",
            schoolId: SCHOOL,
            filterHash: digest,
            position: POSITION,
          }),
        )
      }`,
    );
    expect(foreignOperation.status).toBe(400);

    const changedFilters = await h.request(
      `/v1/classrooms?schoolId=${SCHOOL}&pageSize=100&cursor=${
        encodeURIComponent(
          await signCursor(CURSOR_KEY, {
            version: 1,
            filterVersion: 1,
            operation: "listClassrooms",
            schoolId: SCHOOL,
            filterHash: digest,
            position: POSITION,
          }),
        )
      }`,
    );
    expect(changedFilters.status).toBe(400);
    expect(h.repository.queries).toHaveLength(0);
  });
});

describe("API-041 route controls", () => {
  test("unknown query fields are rejected before authorization", async () => {
    const h = harness();
    const response = await h.request(`/v1/classrooms?schoolId=${SCHOOL}&foo=1`);
    expect(response.status).toBe(400);
    expect(((await response.json()) as { code: string }).code).toBe(
      "INVALID_REQUEST",
    );
    expect(h.authorization.calls).toHaveLength(0);
  });

  test("path parameters that are not UUIDs are rejected", async () => {
    const h = harness();
    const response = await h.request("/v1/classrooms/not-a-uuid");
    expect(response.status).toBe(400);
    expect(((await response.json()) as { code: string }).code).toBe(
      "INVALID_REQUEST",
    );
  });

  test("a disabled slice answers 503 before any repository work", async () => {
    const h = harness({ enabledSlices: { assignments: false } });
    const list = await h.request(`/v1/assignments?schoolId=${SCHOOL}`);
    expect(list.status).toBe(503);
    expect(((await list.json()) as { code: string }).code).toBe(
      "SERVICE_UNAVAILABLE",
    );
    const command = await h.request(
      `/v1/assignments/${ASSIGNMENT}/publish`,
      { method: "POST", body: JSON.stringify({ expectedVersion: 1 }) },
    );
    expect(command.status).toBe(503);
    expect(h.repository.queries).toHaveLength(0);
    expect(h.repository.commands).toHaveLength(0);
  });

  test("assessment rollout is independent from the grades slice", async () => {
    const h = harness({
      enabledSlices: { assessments: false, grades: true },
    });
    const response = await h.request(`/v1/assessments?schoolId=${SCHOOL}`);
    expect(response.status).toBe(503);
    expect(h.repository.queries).toHaveLength(0);
  });

  test("commands require a well-formed idempotency key", async () => {
    const h = harness();
    const missing = await h.request("/v1/assignments", {
      method: "POST",
      body: JSON.stringify(assignmentBody),
      key: "",
    });
    expect(missing.status).toBe(400);
    expect(((await missing.json()) as { code: string }).code).toBe(
      "IDEMPOTENCY_KEY_REQUIRED",
    );
    const malformed = await h.request("/v1/assignments", {
      method: "POST",
      body: JSON.stringify(assignmentBody),
      key: "short",
    });
    expect(malformed.status).toBe(400);
    expect(h.repository.commands).toHaveLength(0);
  });

  test("authorization denial happens before any idempotency reservation", async () => {
    const authorization = new FakeAuthorizationRepository();
    authorization.decision = {
      allowed: false,
      schoolId: SCHOOL,
      reason: "denied",
    };
    const h = harness({
      authorization,
      idempotency: new RecordingIdempotencyRepository(),
    });
    const response = await h.request("/v1/assignments", {
      method: "POST",
      body: JSON.stringify(assignmentBody),
    });
    // Resource denials are concealed as absence so UUID substitution cannot
    // become an existence oracle.
    expect(response.status).toBe(404);
    expect(h.repository.commands).toHaveLength(0);
  });
});

describe("API-041 command handling", () => {
  test("creates through a slash-verb command route and returns the contract body", async () => {
    const h = harness();
    const response = await h.request("/v1/assignments", {
      method: "POST",
      body: JSON.stringify(assignmentBody),
    });
    expect(response.status).toBe(201);
    expect(await response.json()).toEqual(assignmentResponse());
    expect(h.repository.commands).toHaveLength(1);
    expect(h.repository.commands[0]?.operation).toBe("createAssignment");
    expect(h.repository.commands[0]?.resourceId).toBe(CLASSROOM);
    expect(h.repository.commands[0]?.reservation.generation).toBe(1);
  });

  test("replays the stored response without re-running the command", async () => {
    const h = harness();
    const first = await h.request("/v1/assignments", {
      method: "POST",
      body: JSON.stringify(assignmentBody),
      key: "api041-replay-key-000001",
    });
    expect(first.status).toBe(201);
    const replay = await h.request("/v1/assignments", {
      method: "POST",
      body: JSON.stringify(assignmentBody),
      key: "api041-replay-key-000001",
    });
    expect(replay.status).toBe(201);
    expect(replay.headers.get("idempotency-replayed")).toBe("true");
    expect(await replay.json()).toEqual(assignmentResponse());
    expect(h.repository.commands).toHaveLength(1);
  });

  test("conflicts when a key is reused with a different body", async () => {
    const h = harness();
    const first = await h.request("/v1/assignments", {
      method: "POST",
      body: JSON.stringify(assignmentBody),
      key: "api041-mismatch-key-00001",
    });
    expect(first.status).toBe(201);
    const mismatch = await h.request("/v1/assignments", {
      method: "POST",
      body: JSON.stringify({ ...assignmentBody, title: "Different work" }),
      key: "api041-mismatch-key-00001",
    });
    expect(mismatch.status).toBe(409);
    expect(((await mismatch.json()) as { code: string }).code).toBe(
      "IDEMPOTENCY_KEY_REUSED",
    );
    expect(h.repository.commands).toHaveLength(1);
  });

  test("maps domain outcomes to safe problem codes", async () => {
    for (
      const [outcome, status, code] of [
        ["version_conflict", 409, "VERSION_CONFLICT"],
        ["invalid_state", 409, "INVALID_STATE"],
        ["window_closed", 409, "WINDOW_CLOSED"],
        ["not_found", 404, "NOT_FOUND"],
        ["forbidden", 403, "FORBIDDEN"],
      ] as const
    ) {
      const repository = new FakeAcademicRepository();
      repository.commandResults.set("publishAssignment", { outcome });
      const h = harness({ repository });
      const response = await h.request(
        `/v1/assignments/${ASSIGNMENT}/publish`,
        { method: "POST", body: JSON.stringify({ expectedVersion: 1 }) },
      );
      expect(response.status).toBe(status);
      const body = await response.json() as Record<string, unknown>;
      expect(body["code"]).toBe(code);
      // Problems never carry stacks, SQL or repository detail.
      expect(JSON.stringify(body)).not.toContain("stack");
      expect(JSON.stringify(body)).not.toContain("error:");
    }
  });

  test("fails closed when the repository violates the response contract", async () => {
    const repository = new FakeAcademicRepository();
    repository.commandResults.set("createAssignment", {
      outcome: "ok",
      response: { id: ASSIGNMENT },
    });
    const h = harness({ repository });
    const response = await h.request("/v1/assignments", {
      method: "POST",
      body: JSON.stringify(assignmentBody),
    });
    expect(response.status).toBe(500);
    const body = await response.json() as Record<string, unknown>;
    expect(body["code"]).toBe("INTERNAL_ERROR");
    expect(Object.keys(body)).not.toContain("issues");
  });
});
