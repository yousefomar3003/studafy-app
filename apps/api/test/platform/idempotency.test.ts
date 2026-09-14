import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { idempotency, requestHash } from "../../src/platform/idempotency";
import { requestContext } from "../../src/platform/middleware";
import { FakeIdempotencyRepository } from "./fake-idempotency";

const SUBJECT = "aaaaaaaa-0000-4000-8000-000000000001";
const SCHOOL = "bbbbbbbb-0000-4000-8000-000000000001";

function harness(
  options: {
    repository?: FakeIdempotencyRepository;
    mode?: "required" | "forbidden";
  } = {},
) {
  const repository = options.repository ?? new FakeIdempotencyRepository();
  const collector = new LogCollector();
  const logger = createJsonLogger(
    "api",
    "test",
    "debug" as LogLevel,
    collector.sink,
  );
  const app = new Hono<AuthorizationEnv>();
  app.use("*", requestContext() as never);
  app.use("*", async (c, next) => {
    c.set("validatedBody", await c.req.json());
    c.set("actor", {
      token: { subject: SUBJECT },
      context: { userId: SUBJECT },
    } as never);
    c.set("authorization", {
      permission: "account.session.revoke",
      resourceId: SUBJECT,
      tenant: null,
    });
    await next();
  });
  let executions = 0;
  let status = 200;
  let gate: Promise<void> | undefined;
  app.post(
    "/command",
    idempotency({ repository, logger }, "signOut", options.mode ?? "required"),
    async (c) => {
      executions += 1;
      await gate;
      return c.json({ execution: executions }, status as 200 | 500);
    },
  );
  return {
    app,
    repository,
    executions: () => executions,
    failNext: () => {
      status = 500;
    },
    succeedNext: () => {
      status = 200;
    },
    block: () => {
      let release!: () => void;
      gate = new Promise<void>((resolve) => {
        release = resolve;
      });
      return () => {
        gate = undefined;
        release();
      };
    },
  };
}

function request(
  app: Hono<AuthorizationEnv>,
  key: string | null,
  body = { scope: "all" },
) {
  const headers = new Headers({ "content-type": "application/json" });
  if (key) headers.set("idempotency-key", key);
  return app.request("/command", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

describe("durable idempotency middleware contract", () => {
  test("requires a bounded caller key and forbids it on one-time verification", async () => {
    const required = harness();
    expect((await request(required.app, null)).status).toBe(400);
    expect((await request(required.app, "short")).status).toBe(400);

    const forbidden = harness({ mode: "forbidden" });
    const rejected = await request(forbidden.app, "0123456789abcdef");
    expect(rejected.status).toBe(400);
    expect((await rejected.json() as { code: string }).code).toBe(
      "IDEMPOTENCY_KEY_NOT_ALLOWED",
    );
  });

  test("executes once and replays the exact completed response", async () => {
    const h = harness();
    const key = "replay-key-00000001";
    const first = await request(h.app, key);
    const replay = await request(h.app, key);
    expect(first.status).toBe(200);
    expect(replay.status).toBe(200);
    expect(await replay.json()).toEqual(await first.json());
    expect(replay.headers.get("idempotency-replayed")).toBe("true");
    expect(h.executions()).toBe(1);
  });

  test("rejects a key reused with a different canonical request", async () => {
    const h = harness();
    const key = "mismatch-key-000001";
    expect((await request(h.app, key, { scope: "all" })).status).toBe(200);
    const mismatch = await request(h.app, key, { scope: "current" });
    expect(mismatch.status).toBe(409);
    expect((await mismatch.json() as { code: string }).code).toBe(
      "IDEMPOTENCY_KEY_REUSED",
    );
  });

  test("serializes a live reservation and supplies Retry-After", async () => {
    const h = harness();
    const release = h.block();
    const first = request(h.app, "concurrent-key-00001");
    await Promise.resolve();
    const second = await request(h.app, "concurrent-key-00001");
    expect(second.status).toBe(409);
    expect(second.headers.get("retry-after")).toBe("1");
    expect((await second.json() as { code: string }).code).toBe(
      "IDEMPOTENCY_IN_PROGRESS",
    );
    release();
    expect((await first).status).toBe(200);
    expect(h.executions()).toBe(1);
  });

  test("failed responses release the key for a retry", async () => {
    const h = harness();
    h.failNext();
    expect((await request(h.app, "failure-key-0000001")).status).toBe(500);
    h.succeedNext();
    expect((await request(h.app, "failure-key-0000001")).status).toBe(200);
    expect(h.executions()).toBe(2);
  });

  test("an uncertain completion keeps the lease and prevents an immediate duplicate", async () => {
    const repository = new FakeIdempotencyRepository();
    repository.complete = async () => {
      throw new Error("database unavailable");
    };
    const h = harness({ repository });
    const key = "uncertain-key-000001";
    const first = await request(h.app, key);
    expect(first.status).toBe(503);
    const second = await request(h.app, key);
    expect(second.status).toBe(409);
    expect(h.executions()).toBe(1);
  });

  test("hashing is stable across object key order", async () => {
    expect(await requestHash("POST", "signOut", { a: 1, b: { y: 2, x: 3 } }))
      .toBe(await requestHash("POST", "signOut", { b: { x: 3, y: 2 }, a: 1 }));
  });

  test("repository scope isolates actors, tenants, and operations", async () => {
    const repository = new FakeIdempotencyRepository();
    const common = {
      schoolId: SCHOOL,
      scope: "v1.signOut",
      key: "isolation-key-000001",
      requestHash: "a".repeat(64),
      retentionSeconds: 86_400,
      leaseSeconds: 15,
    };
    expect((await repository.reserve(SUBJECT, common)).outcome).toBe(
      "reserved",
    );
    expect(
      (await repository.reserve("aaaaaaaa-0000-4000-8000-000000000002", common))
        .outcome,
    ).toBe("reserved");
    expect(
      (await repository.reserve(SUBJECT, {
        ...common,
        schoolId: "bbbbbbbb-0000-4000-8000-000000000002",
      })).outcome,
    ).toBe("reserved");
    expect(
      (await repository.reserve(SUBJECT, {
        ...common,
        scope: "v1.challengeReauth",
      })).outcome,
    ).toBe("reserved");
  });
});
