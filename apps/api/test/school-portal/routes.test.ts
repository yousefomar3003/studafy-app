/**
 * Studafy School Portal routes (docs/planning/school-portal.md). The SQL
 * decides who may see what (supabase/tests/school_portal.sql); these check
 * what the routes do around it: the server switch, refusals and their
 * codes, request shapes, and that a response is held to its contract.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { SCHOOL_AGREEMENT_VERSION } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import {
  createSchoolPortalRoutes,
  type SchoolPortalRepository,
} from "../../src/school-portal/routes";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";

const SUBJECT = "00000000-0000-4000-8000-000000000001";
const ORG = "00000000-0000-4000-8000-0000000000a1";
const CLASS = "00000000-0000-4000-8000-0000000000b1";
const LINK = "00000000-0000-4000-8000-0000000000c1";
const STUDENT = "00000000-0000-4000-8000-0000000000d1";
const TEACHER = "00000000-0000-4000-8000-0000000000e1";

interface Calls {
  queries: {
    operation: string;
    resourceId: string | null;
    orgId: string | null;
  }[];
  commands: {
    operation: string;
    resourceId: string | null;
    body: Record<string, unknown>;
  }[];
}

function app(options: {
  calls: Calls;
  enabled?: boolean;
  delivery?: boolean;
  download?: Record<string, unknown>;
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
      // A portal administrator belongs to no school.
      context: { userId: SUBJECT, memberships: [], membershipVersion: "1" },
      aal2: false,
      mfaRequiredByPolicy: false,
    } as unknown as Actor);
    await next();
  });
  const queries: Record<string, Record<string, unknown>> = {
    classes: {
      outcome: "ok",
      classes: [{
        id: CLASS,
        name: "Grade 7 Science",
        grade: "7",
        section: "A",
        status: "active",
        timezone: "Asia/Amman",
        teachers: [{ id: TEACHER, name: "Ms Haddad", role: "lead_teacher" }],
        students: 24,
      }],
    },
    roster: {
      outcome: "ok",
      students: [{
        studentId: STUDENT,
        name: "Omar K.",
        studafyId: "SJ-0A1B2C3D4E",
        email: "omar@example.test",
        joinedOn: "2026-09-01",
        parents: [{
          name: "Lina K.",
          email: "lina@example.test",
          relationship: "parent",
        }],
      }],
    },
    myLinks: { outcome: "ok", links: [] },
    ...options.query,
  };
  const commands: Record<string, Record<string, unknown>> = {
    createOrg: {
      outcome: "ok",
      status: 201,
      response: { id: ORG, status: "active" },
    },
    requestLink: {
      outcome: "ok",
      status: 201,
      response: {
        linkId: LINK,
        teacher: {
          id: TEACHER,
          name: "Ms Haddad",
          email: "haddad@example.test",
        },
        status: "pending",
      },
    },
    decideLink: {
      outcome: "ok",
      response: { linkId: LINK, status: "linked", replaced: null },
    },
    ...options.command,
  };
  const repository: SchoolPortalRepository = {
    query: async (_c, operation, resourceId, orgId) => {
      options.calls.queries.push({ operation, resourceId, orgId });
      return queries[operation] ?? { outcome: "not_found" };
    },
    command: async (_c, operation, resourceId, body) => {
      options.calls.commands.push({ operation, resourceId, body });
      return (commands[operation] ?? { outcome: "invalid" }) as never;
    },
    fileDownload: async (_c, orgId, fileId, internal) => {
      options.calls.commands.push({
        operation: "fileDownload",
        resourceId: fileId,
        body: { orgId, ...internal },
      });
      return (options.download ?? {
        outcome: "ok",
        response: {
          downloadUrl: internal.downloadUrl,
          expiresAt: internal.expiresAt,
          displayName: "trip-letter.pdf",
          mediaType: "application/pdf",
        },
      }) as never;
    },
  };
  routes.route(
    "/",
    createSchoolPortalRoutes(
      {
        repository,
        enabled: options.enabled ?? true,
        delivery: options.delivery === false ? null : {
          signingKey: "portal-delivery-test-signing-key-0123456789abcdef",
          publicBaseUrl: "https://api.studafy.test",
        },
      },
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

async function code(response: Response): Promise<string> {
  return ((await response.json()) as { code: string }).code;
}

describe("the server switch", () => {
  test("off, every portal and school-link route is 404 and nothing reaches SQL", async () => {
    const seen = calls();
    const routes = app({ calls: seen, enabled: false });
    for (
      const path of [
        "/v1/school-portal/orgs",
        `/v1/school-portal/orgs/${ORG}/classes`,
        `/v1/school-portal/orgs/${ORG}/classes/${CLASS}/roster`,
        "/v1/me/school-links",
      ]
    ) {
      const response = await routes.request(path);
      expect(response.status).toBe(404);
    }
    const created = await post(routes, "/v1/school-portal/orgs", {
      name: "Cedar Grove",
      country: "Jordan",
      city: "Amman",
      kind: "private",
      jobTitle: "Principal",
      adult: true,
      agreementVersion: SCHOOL_AGREEMENT_VERSION,
    });
    expect(created.status).toBe(404);
    expect(seen.queries).toEqual([]);
    expect(seen.commands).toEqual([]);
  });
});

describe("reads", () => {
  test("a class read passes the school and the class, and keeps to the contract", async () => {
    const seen = calls();
    const response = await app({ calls: seen }).request(
      `/v1/school-portal/orgs/${ORG}/classes/${CLASS}/roster`,
    );
    expect(response.status).toBe(200);
    const body = await response.json() as { students: { email: string }[] };
    expect(body.students[0]?.email).toBe("omar@example.test");
    expect(seen.queries).toEqual([{
      operation: "roster",
      resourceId: CLASS,
      orgId: ORG,
    }]);
  });

  test("a class the school may not see is a plain 404", async () => {
    const response = await app({
      calls: calls(),
      query: { roster: { outcome: "not_found" } },
    }).request(`/v1/school-portal/orgs/${ORG}/classes/${CLASS}/roster`);
    expect(response.status).toBe(404);
    expect(await code(response)).toBe("NOT_FOUND");
  });

  test("a response that breaks its contract is never passed on", async () => {
    const response = await app({
      calls: calls(),
      query: { classes: { outcome: "ok", classes: [{ id: "not-a-uuid" }] } },
    }).request(`/v1/school-portal/orgs/${ORG}/classes`);
    expect(response.status).toBe(500);
  });

  test("ids in the path must be ids", async () => {
    const response = await app({ calls: calls() }).request(
      "/v1/school-portal/orgs/not-an-id/classes",
    );
    expect(response.status).toBe(400);
  });
});

describe("commands", () => {
  test("creating a school answers 201 and never sends the challenge token to SQL", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen }),
      "/v1/school-portal/orgs",
      {
        name: "Cedar Grove School",
        country: "Jordan",
        city: "Amman",
        kind: "private",
        jobTitle: "Principal",
        adult: true,
        agreementVersion: SCHOOL_AGREEMENT_VERSION,
        captchaToken: "token",
      },
    );
    expect(response.status).toBe(201);
    expect(seen.commands[0]?.operation).toBe("createOrg");
    expect(seen.commands[0]?.body["captchaToken"]).toBeUndefined();
  });

  test("a school is created only by someone accepting the current School Agreement", async () => {
    const seen = calls();
    const routes = app({ calls: seen });
    const school = {
      name: "Cedar Grove School",
      country: "Jordan",
      city: "Amman",
      kind: "private",
      jobTitle: "Principal",
      adult: true,
    };
    for (const agreement of [{}, { agreementVersion: "2026-01-01" }]) {
      const response = await post(routes, "/v1/school-portal/orgs", {
        ...school,
        ...agreement,
      });
      expect(response.status).toBe(400);
    }
    const invite = await post(
      routes,
      `/v1/school-portal/invites/${ORG}/accept`,
      { adult: true },
    );
    expect(invite.status).toBe(400);
    expect(seen.commands).toEqual([]);
  });

  test("a teacher is asked by a ten-digit Studafy ID only", async () => {
    const seen = calls();
    const routes = app({ calls: seen });
    const bad = await post(
      routes,
      `/v1/school-portal/orgs/${ORG}/link-requests`,
      {
        studafyId: "SJ-123",
      },
    );
    expect(bad.status).toBe(400);
    const good = await post(
      routes,
      `/v1/school-portal/orgs/${ORG}/link-requests`,
      {
        studafyId: "4821937560",
      },
    );
    expect(good.status).toBe(201);
    expect(seen.commands).toEqual([{
      operation: "requestLink",
      resourceId: ORG,
      body: { studafyId: "4821937560" },
    }]);
  });

  test("each refusal keeps its own code", async () => {
    const cases: [Record<string, unknown>, number, string][] = [
      [{ outcome: "teacher_not_found" }, 404, "TEACHER_NOT_FOUND"],
      [{ outcome: "rate_limited" }, 429, "RATE_LIMITED"],
      [
        { outcome: "conflict", reason: "already_requested" },
        409,
        "SCHOOL_LINK_EXISTS",
      ],
      [
        { outcome: "conflict", reason: "recently_declined" },
        409,
        "SCHOOL_LINK_RECENTLY_DECLINED",
      ],
      [
        { outcome: "conflict", reason: "teacher_busy" },
        409,
        "TEACHER_REQUESTS_FULL",
      ],
    ];
    for (const [result, status, expected] of cases) {
      const response = await post(
        app({ calls: calls(), command: { requestLink: result } }),
        `/v1/school-portal/orgs/${ORG}/link-requests`,
        { studafyId: "4821937560" },
      );
      expect(response.status).toBe(status);
      expect(await code(response)).toBe(expected);
    }
  });

  test("accepting while linked elsewhere asks the teacher to agree first", async () => {
    const response = await post(
      app({
        calls: calls(),
        command: {
          decideLink: {
            outcome: "conflict",
            reason: "linked_elsewhere",
            current: { linkId: LINK, orgName: "Oak Hill" },
          },
        },
      }),
      `/v1/me/school-links/${LINK}/decision`,
      { decision: "accept" },
    );
    expect(response.status).toBe(409);
    expect(await code(response)).toBe("LINKED_ELSEWHERE");
  });

  test("a group's refusals keep their own codes", async () => {
    const cases: [Record<string, unknown>, string][] = [
      [{ outcome: "conflict", reason: "already_in_group" }, "ALREADY_IN_GROUP"],
      [{ outcome: "conflict", reason: "group_full" }, "SCHOOL_GROUP_FULL"],
    ];
    for (const [result, expected] of cases) {
      const response = await post(
        app({ calls: calls(), command: { addGroupClass: result } }),
        `/v1/school-portal/orgs/${ORG}/groups/${LINK}/classes`,
        { classroomId: CLASS },
      );
      expect(response.status).toBe(409);
      expect(await code(response)).toBe(expected);
    }
  });

  test("a teacher answers for a class in a group: approve, decline or remove", async () => {
    const recorded = calls();
    const ok = await post(
      app({
        calls: recorded,
        command: {
          decideGroupClass: {
            outcome: "ok",
            response: { id: LINK, status: "approved" },
          },
        },
      }),
      `/v1/me/school-group-classes/${LINK}/decision`,
      { decision: "approve" },
    );
    expect(ok.status).toBe(200);
    expect(recorded.commands).toEqual([{
      operation: "decideGroupClass",
      resourceId: LINK,
      body: { decision: "approve" },
    }]);
    const other = await post(
      app({ calls: calls() }),
      `/v1/me/school-group-classes/${LINK}/decision`,
      { decision: "accept" },
    );
    expect(other.status).toBe(400);
  });

  test("a decision is accept or decline, nothing else", async () => {
    const response = await post(
      app({ calls: calls() }),
      `/v1/me/school-links/${LINK}/decision`,
      { decision: "maybe" },
    );
    expect(response.status).toBe(400);
  });

  test("an outcome the routes do not know is a server error, not a guess", async () => {
    const response = await post(
      app({ calls: calls(), command: { decideLink: { outcome: "surprise" } } }),
      `/v1/me/school-links/${LINK}/decision`,
      { decision: "decline" },
    );
    expect(response.status).toBe(500);
  });
});

describe("opening a file", () => {
  const FILE = "00000000-0000-4000-8000-0000000000f1";
  const path = `/v1/school-portal/orgs/${ORG}/files/${FILE}/download-intent`;

  test("answers a single-use link on the delivery route, never the bytes", async () => {
    const seen = calls();
    const response = await post(app({ calls: seen }), path, {});
    expect(response.status).toBe(200);
    const body = await response.json() as { downloadUrl: string };
    const url = new URL(body.downloadUrl);
    expect(url.origin).toBe("https://api.studafy.test");
    expect(url.pathname).toBe(`/delivery/v1/files/${FILE}/content`);
    expect(url.searchParams.get("token")).toBeTruthy();
    const sent = seen.commands[0]!;
    expect(sent.operation).toBe("fileDownload");
    expect(sent.body["orgId"]).toBe(ORG);
    // The database keeps a hash of the link's secret, never the secret.
    expect(String(sent.body["nonceHash"])).toMatch(/^[0-9a-f]{64}$/);
    expect(String(sent.body["downloadUrl"])).not.toContain(
      String(sent.body["nonceHash"]),
    );
  });

  test("a file the school may not open is a plain 404", async () => {
    const response = await post(
      app({ calls: calls(), download: { outcome: "not_found" } }),
      path,
      {},
    );
    expect(response.status).toBe(404);
  });

  test("a file still being scanned says so", async () => {
    const response = await post(
      app({ calls: calls(), download: { outcome: "file_not_clean" } }),
      path,
      {},
    );
    expect(response.status).toBe(409);
    expect(await code(response)).toBe("FILE_NOT_CLEAN");
  });

  test("without delivery configured, nothing is asked of the database", async () => {
    const seen = calls();
    const response = await post(
      app({ calls: seen, delivery: false }),
      path,
      {},
    );
    expect(response.status).toBe(409);
    expect(await code(response)).toBe("FILE_DELIVERY_DISABLED");
    expect(seen.commands).toEqual([]);
  });
});
