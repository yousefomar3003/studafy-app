import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { createFileRoutes } from "../../src/files/routes";
import type { FileRepository } from "../../src/files/repository";
import type { PrivateFileStorage } from "@studafy/infrastructure";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";
import { baseContext } from "../auth/fake-repository";

const SCHOOL = "bbbbbbbb-0000-4000-8000-000000000001";
const UPLOAD = "cccccccc-0000-4000-8000-000000000001";
const KEY = "file050-route-key-0001";
const SHA = "a".repeat(64);

function actor(): Actor {
  return {
    token: {
      subject: baseContext().userId,
      sessionId: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
      issuedAt: 1,
      expiresAt: 4_000_000_000,
      assuranceLevel: "aal1",
      authMethods: [],
      claims: {},
    },
    context: baseContext(),
    aal2: false,
    mfaRequiredByPolicy: false,
  };
}

function validBody() {
  return {
    schoolId: SCHOOL,
    purpose: "profile_image",
    displayName: "avatar.png",
    expectedSizeBytes: 8,
    declaredMediaType: "image/png",
    sha256: SHA,
  };
}

function harness(options: { enabled?: boolean; allowed?: boolean } = {}) {
  const events: string[] = [];
  const idem = new FakeIdempotencyRepository();
  const session = {
    id: UPLOAD,
    purpose: "profile_image",
    displayName: "avatar.png",
    declaredMediaType: "image/png",
    expectedSizeBytes: 8,
    state: "initiated",
    expiresAt: "2026-09-17T12:00:00Z",
    createdAt: "2026-09-17T10:00:00Z",
    completedAt: null,
    fileId: null,
    failureCode: null,
  };
  const repository: FileRepository = {
    async prepareIntent() {
      events.push("prepare");
      return { outcome: "ok" };
    },
    async issueIntent(_context, _body, internal, reservation) {
      events.push("issue");
      const response = {
        session,
        uploadUrl: (internal as { uploadUrl: string }).uploadUrl,
        method: "PUT",
        requiredHeaders: {
          "content-type": "image/png",
          "cache-control": "max-age=3600",
          "x-upsert": "false",
        },
        expiresAt: session.expiresAt,
      };
      await idem.complete(
        actor().token.subject,
        reservation.id,
        reservation.generation,
        201,
        response,
      );
      return { outcome: "ok", response };
    },
    query: async () => ({ outcome: "not_found" }),
    prepareCompletion: async () => ({ outcome: "not_found" }),
    complete: async () => ({ outcome: "invalid" }),
    publish: async () => ({ outcome: "invalid" }),
    createDownloadGrant: async () => ({ outcome: "invalid" }),
    consumeDownloadGrant: async () => ({ outcome: "grant_invalid" }),
  };
  const storage: PrivateFileStorage = {
    async createUploadCapability(uploadId) {
      events.push("sign");
      return {
        bucket: "private-school-files",
        objectKey: `quarantine/v1/${uploadId}/abcdefghijklmnopqrstuv`,
        nonceHash: "b".repeat(64),
        uploadUrl: "https://storage.invalid/signed-upload",
        expiresAt: session.expiresAt,
      };
    },
    inspect: async () => ({ exists: false }),
    delete: async () => undefined,
    openObject: async () => {
      throw new Error("not used");
    },
    replaceObject: async () => undefined,
  };
  const logger = createJsonLogger(
    "api",
    "file050-test",
    "debug" as LogLevel,
    new LogCollector().sink,
  );
  const app = new Hono<AuthorizationEnv>();
  app.use("*", async (c, next) => {
    c.set("requestId", "dddddddd-0000-4000-8000-000000000001");
    c.set("actor", actor());
    await next();
  });
  app.route(
    "/",
    createFileRoutes(
      { repository, storage, newIntentsEnabled: options.enabled ?? true },
      createAuthorizationDependencies(logger, {
        authorize: async () => ({
          allowed: options.allowed ?? true,
          schoolId: (options.allowed ?? true) ? SCHOOL : null,
          reason: (options.allowed ?? true) ? "allowed" : "denied",
        }),
      }),
      { logger, repository: idem },
    ),
  );
  return {
    events,
    request: (body: unknown, key = KEY) =>
      app.request("/v1/uploads", {
        method: "POST",
        headers: { "content-type": "application/json", "idempotency-key": key },
        body: JSON.stringify(body),
      }),
  };
}

describe("FILE-050 upload intent route", () => {
  test("rejects caller-selected paths before authorization or signing", async () => {
    const h = harness();
    const response = await h.request({
      ...validBody(),
      objectKey: "other/file",
    });
    expect(response.status).toBe(400);
    expect(h.events).toEqual([]);
  });

  test("conceals cross-tenant binding before the storage adapter is called", async () => {
    const h = harness({ allowed: false });
    const response = await h.request(validBody());
    expect(response.status).toBe(404);
    expect(h.events).toEqual([]);
  });

  test("the default-off switch never signs an upload", async () => {
    const h = harness({ enabled: false });
    const response = await h.request(validBody());
    expect(response.status).toBe(503);
    expect(h.events).toEqual([]);
  });

  test("authorizes and prepares before creating the server-owned capability", async () => {
    const h = harness();
    const response = await h.request(validBody());
    expect(response.status).toBe(201);
    expect(h.events).toEqual(["prepare", "sign", "issue"]);
    const body = await response.json() as Record<string, unknown>;
    expect(body.objectKey).toBeUndefined();
    expect(JSON.stringify(body)).not.toContain("quarantine/v1");
  });
});
