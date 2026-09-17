import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { signDeliveryToken } from "@studafy/domain";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import type { PrivateFileStorage } from "@studafy/infrastructure";
import { sha256Hex } from "@studafy/infrastructure";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { secureResponseHeaders } from "../../src/platform/middleware";
import {
  contentDisposition,
  createFileRoutes,
  type DeliveryConfig,
} from "../../src/files/routes";
import type {
  DownloadGrantInternal,
  EffectiveObject,
  File051DeliveryResult,
  FileRepository,
} from "../../src/files/repository";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";
import { baseContext } from "../auth/fake-repository";

const SCHOOL = "bbbbbbbb-0000-4000-8000-000000000001";
const FILE = "eeeeeeee-0000-4000-8000-000000000001";
const OTHER_FILE = "eeeeeeee-0000-4000-8000-000000000002";
// Synthetic, deliberately low-entropy signing material.
const KEY = "synthetic-delivery-".repeat(3);
const NOW_MS = Date.UTC(2026, 8, 17, 12, 0, 0);
const BYTES = new TextEncoder().encode("%PDF-1.7 synthetic body");
const USER = baseContext().userId;
const OTHER_USER = "99999999-2222-4333-8444-555555555555";

function actor(subject = USER): Actor {
  return {
    token: {
      subject,
      sessionId: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
      issuedAt: 1,
      expiresAt: 4_000_000_000,
      assuranceLevel: "aal1",
      authMethods: [],
      claims: {},
    },
    context: baseContext({ userId: subject }),
    aal2: false,
    mfaRequiredByPolicy: false,
  };
}

interface HarnessOptions {
  delivery?: boolean;
  publishEnabled?: boolean;
  allowed?: boolean;
  subject?: string;
  grantOutcome?: string;
  storedBytes?: Uint8Array;
}

async function harness(options: HarnessOptions = {}) {
  const events: string[] = [];
  const state = { allowed: options.allowed ?? true };
  const grants = new Map<string, { fileId: string; used: boolean }>();
  const issued: DownloadGrantInternal[] = [];
  const idem = new FakeIdempotencyRepository();
  const effective: EffectiveObject = {
    schoolId: SCHOOL,
    bucket: "private-school-files",
    objectKey: `quarantine/v1/${FILE}/abcdefghijklmnopqrstuv`,
    storedSha256: await sha256Hex(BYTES),
    storedSizeBytes: BYTES.byteLength,
    mediaType: "application/pdf",
    displayName: "Week 3 — notes\r\n.pdf",
    rootClean: true,
  };
  const repository: FileRepository = {
    prepareIntent: async () => ({ outcome: "invalid" }),
    issueIntent: async () => ({ outcome: "invalid" }),
    async query(_context, operation) {
      events.push(`query:${operation}`);
      return { outcome: "delivery_disabled" };
    },
    prepareCompletion: async () => ({ outcome: "not_found" }),
    complete: async () => ({ outcome: "invalid" }),
    async publish(_context, fileId, body, reservation) {
      events.push(`publish:${fileId}:${JSON.stringify(body)}`);
      const response = {
        file: {
          id: fileId,
          purpose: "lesson_resource",
          displayName: "notes.pdf",
          sizeBytes: 10,
          declaredMediaType: "application/pdf",
          detectedMediaType: "application/pdf",
          scanState: "clean",
          createdAt: "2026-09-17T10:00:00Z",
          scannedAt: "2026-09-17T10:01:00Z",
          failureCode: null,
        },
        resource: {
          id: "ffffffff-0000-4000-8000-000000000001",
          schoolId: SCHOOL,
          classroomId: "ffffffff-0000-4000-8000-000000000002",
          title: "notes.pdf",
          resourceType: "file",
          body: null,
          state: "published",
          version: 1,
          publishedAt: "2026-09-17T10:02:00Z",
        },
      };
      await idem.complete(
        USER,
        reservation.id,
        reservation.generation,
        201,
        response,
      );
      return { outcome: "ok", response };
    },
    async createDownloadGrant(_context, fileId, internal, reservation) {
      events.push("grant");
      if (options.grantOutcome) return { outcome: options.grantOutcome };
      issued.push(internal);
      grants.set(internal.nonceHash, { fileId, used: false });
      const response = {
        downloadUrl: internal.downloadUrl,
        expiresAt: internal.expiresAt,
        displayName: "notes.pdf",
        mediaType: "application/pdf",
      };
      await idem.complete(
        USER,
        reservation.id,
        reservation.generation,
        200,
        response,
      );
      return { outcome: "ok", response };
    },
    async consumeDownloadGrant(context, fileId, nonceHash) {
      events.push("consume");
      const grant = grants.get(nonceHash);
      if (!grant || grant.used || grant.fileId !== fileId) {
        return { outcome: "grant_invalid" } as File051DeliveryResult;
      }
      grant.used = true;
      if (!state.allowed) return { outcome: "not_found" };
      expect(context.subject).toBe(options.subject ?? USER);
      return { outcome: "ok", response: effective };
    },
  };
  const storage: PrivateFileStorage = {
    createUploadCapability: async () => {
      throw new Error("not used");
    },
    inspect: async () => ({ exists: false }),
    delete: async () => undefined,
    async openObject() {
      events.push("open");
      const bytes = options.storedBytes ?? BYTES;
      return { bytes, sizeBytes: bytes.byteLength };
    },
    replaceObject: async () => undefined,
  };
  const logger = createJsonLogger(
    "api",
    "file051-test",
    "debug" as LogLevel,
    new LogCollector().sink,
  );
  let nowMs = NOW_MS;
  const delivery: DeliveryConfig | null = options.delivery === false ? null : {
    signingKey: KEY,
    publicBaseUrl: "https://api.studafy.test",
    now: () => nowMs,
  };
  const app = new Hono<AuthorizationEnv>();
  app.use("*", secureResponseHeaders("production"));
  app.use("*", async (c, next) => {
    c.set("requestId", "dddddddd-0000-4000-8000-000000000001");
    c.set("actor", actor(options.subject));
    await next();
  });
  app.route(
    "/",
    createFileRoutes(
      {
        repository,
        storage,
        newIntentsEnabled: false,
        publishEnabled: options.publishEnabled ?? false,
        delivery,
      },
      createAuthorizationDependencies(logger, {
        authorize: async () => ({
          allowed: options.allowed ?? true,
          schoolId: SCHOOL,
          reason: (options.allowed ?? true) ? "allowed" : "denied",
        }),
      }),
      { logger, repository: idem },
    ),
  );
  return {
    events,
    issued,
    revoke: () => state.allowed = false,
    advance: (seconds: number) => nowMs += seconds * 1000,
    intent: (key = "file051-download-key-0001", fileId = FILE) =>
      app.request(`/v1/files/${fileId}/download-intent`, {
        method: "POST",
        headers: { "content-type": "application/json", "idempotency-key": key },
        body: "{}",
      }),
    publish: (body: unknown, key = "file051-publish-key-0001") =>
      app.request(`/v1/files/${FILE}/publish`, {
        method: "POST",
        headers: { "content-type": "application/json", "idempotency-key": key },
        body: JSON.stringify(body),
      }),
    get: (url: string) => {
      const parsed = new URL(url, "https://api.studafy.test");
      return app.request(`${parsed.pathname}${parsed.search}`);
    },
  };
}

async function issuedUrl(h: Awaited<ReturnType<typeof harness>>) {
  const response = await h.intent();
  expect(response.status).toBe(200);
  const body = await response.json() as { downloadUrl: string };
  return body.downloadUrl;
}

describe("FILE-051 publication route", () => {
  test("is disabled by default and never reaches the database", async () => {
    const h = await harness();
    const response = await h.publish({ audience: "students" });
    expect(response.status).toBe(503);
    expect((await response.json() as { code: string }).code).toBe(
      "FILE_PUBLISH_DISABLED",
    );
    expect(h.events).toEqual([]);
  });

  test("rejects copy-shaped or unknown fields before authorization", async () => {
    const h = await harness({ publishEnabled: true });
    for (
      const body of [
        { audience: "students", recipients: ["x"] },
        { audience: "students", bucket: "private-school-files" },
        { audience: "everyone" },
        {},
      ]
    ) {
      expect(
        (await h.publish(
          body,
          `file051-bad-${JSON.stringify(body).length}-key`,
        )).status,
      )
        .toBe(400);
    }
    expect(h.events).toEqual([]);
  });

  test("publishes one clean file through the single command", async () => {
    const h = await harness({ publishEnabled: true });
    const response = await h.publish({ audience: "both" });
    expect(response.status).toBe(201);
    const body = await response.json() as {
      resource: { resourceType: string };
    };
    expect(body.resource.resourceType).toBe("file");
    expect(h.events).toEqual([`publish:${FILE}:{"audience":"both"}`]);
  });

  test("conceals a denied file as not found", async () => {
    const h = await harness({ publishEnabled: true, allowed: false });
    expect((await h.publish({ audience: "students" })).status).toBe(404);
    expect(h.events).toEqual([]);
  });
});

describe("FILE-051 download intent", () => {
  test("keeps the FILE-050 disabled answer while delivery is off", async () => {
    const h = await harness({ delivery: false });
    const response = await h.intent();
    expect(response.status).toBe(409);
    expect((await response.json() as { code: string }).code).toBe(
      "FILE_DELIVERY_DISABLED",
    );
    expect(h.events).toEqual(["query:createFileDownloadIntent"]);
  });

  test("records a grant holding only the nonce hash, then discloses the link", async () => {
    const h = await harness();
    const url = await issuedUrl(h);
    expect(h.events).toEqual(["grant"]);
    const grant = h.issued[0]!;
    expect(grant.nonceHash).toMatch(/^[0-9a-f]{64}$/);
    expect(grant.downloadUrl).toBe(url);
    expect(
      url.startsWith(
        `https://api.studafy.test/delivery/v1/files/${FILE}/content?token=`,
      ),
    )
      .toBe(true);
    expect(url).not.toContain(grant.nonceHash);
    expect(Date.parse(grant.expiresAt) - NOW_MS).toBe(300_000);
  });

  test("a non-clean or unauthorized file never produces a link", async () => {
    for (const outcome of ["file_not_clean", "not_found", "invalid_state"]) {
      const h = await harness({ grantOutcome: outcome });
      const response = await h.intent();
      expect(response.status).not.toBe(200);
      expect(JSON.stringify(await response.json())).not.toContain("token=");
    }
  });
});

describe("FILE-051 delivery endpoint", () => {
  test("streams the exact stored bytes with safe headers, once", async () => {
    const h = await harness();
    const url = await issuedUrl(h);
    const response = await h.get(url);
    expect(response.status).toBe(200);
    expect(new Uint8Array(await response.arrayBuffer())).toEqual(BYTES);
    expect(response.headers.get("content-type")).toBe("application/pdf");
    expect(response.headers.get("content-disposition")).toStartWith(
      "attachment; ",
    );
    expect(response.headers.get("content-disposition")).not.toMatch(/[\r\n]/);
    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
    expect(response.headers.get("content-security-policy")).toBe(
      "sandbox; default-src 'none'",
    );
    expect(response.headers.get("cache-control")).toContain("no-store");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");

    const replay = await h.get(url);
    expect(replay.status).toBe(404);
    expect((await replay.json() as { code: string }).code).toBe(
      "DELIVERY_GRANT_INVALID",
    );
    expect(h.events).toEqual(["grant", "consume", "open", "consume"]);
  });

  test("a leaked link is useless to another account", async () => {
    const issuer = await harness();
    const url = await issuedUrl(issuer);
    const thief = await harness({ subject: OTHER_USER });
    const response = await thief.get(url);
    expect(response.status).toBe(404);
    expect(thief.events).toEqual([]);
  });

  test("expired, tampered, rebound or malformed links fail before the database", async () => {
    const h = await harness();
    const url = new URL(await issuedUrl(h));
    const token = url.searchParams.get("token")!;
    const [body, signature] = token.split(".");
    const cases = [
      `/delivery/v1/files/${FILE}/content?token=${body}.${
        signature!.slice(0, -2)
      }AA`,
      `/delivery/v1/files/${OTHER_FILE}/content?token=${token}`,
      `/delivery/v1/files/not-a-uuid/content?token=${token}`,
      `/delivery/v1/files/${FILE}/content`,
      `/delivery/v1/files/${FILE}/content?token=${token}&token=${token}`,
      `/delivery/v1/files/${FILE}/content?token=${token}&path=quarantine/v1/x`,
    ];
    for (const path of cases) {
      expect((await h.get(path)).status).toBe(404);
    }
    const forged = await signDeliveryToken({
      fileId: FILE,
      userId: USER,
      nonce: "x".repeat(43),
      ttlSeconds: 60,
      nowSeconds: NOW_MS / 1000,
    }, "an-attacker-key-an-attacker-key-00");
    expect(
      (await h.get(`/delivery/v1/files/${FILE}/content?token=${forged}`))
        .status,
    )
      .toBe(404);
    h.advance(301);
    expect((await h.get(url.toString())).status).toBe(404);
    expect(h.events).toEqual(["grant"]);
  });

  test("a validly signed link without a recorded grant is refused", async () => {
    const h = await harness();
    const unrecorded = await signDeliveryToken({
      fileId: FILE,
      userId: USER,
      nonce: "y".repeat(43),
      ttlSeconds: 60,
      nowSeconds: NOW_MS / 1000,
    }, KEY);
    const response = await h.get(
      `/delivery/v1/files/${FILE}/content?token=${unrecorded}`,
    );
    expect(response.status).toBe(404);
    expect(h.events).toEqual(["consume"]);
  });

  test("revocation after issue denies the link without touching storage", async () => {
    const h = await harness();
    const url = await issuedUrl(h);
    // e.g. publication withdrawn or enrollment ended between issue and use.
    h.revoke();
    const response = await h.get(url);
    expect(response.status).toBe(404);
    expect((await response.json() as { code: string }).code).toBe("NOT_FOUND");
    expect(h.events).toEqual(["grant", "consume"]);
  });

  test("bytes that differ from the recorded stored digest are never served", async () => {
    const h = await harness({
      storedBytes: new TextEncoder().encode("%PDF-1.7 swapped body!!"),
    });
    const response = await h.get(await issuedUrl(h));
    expect(response.status).toBe(503);
  });

  test("the route is absent while delivery is disabled", async () => {
    const h = await harness({ delivery: false });
    expect(
      (await h.get(`/delivery/v1/files/${FILE}/content?token=a.b`)).status,
    ).toBe(404);
    expect(h.events).toEqual([]);
  });
});

describe("content disposition", () => {
  test("is always an attachment with a header-safe name", () => {
    expect(contentDisposition("report.pdf")).toBe(
      `attachment; filename="report.pdf"; filename*=UTF-8''report.pdf`,
    );
    const hostile = contentDisposition('a"\r\nSet-Cookie: x=1/../é.pdf');
    expect(hostile).not.toMatch(/[\r\n]/);
    expect(hostile).toStartWith('attachment; filename="a_');
    expect(hostile).toContain("filename*=UTF-8''a_");
    expect(contentDisposition("")).toContain('filename="upload"');
  });
});
