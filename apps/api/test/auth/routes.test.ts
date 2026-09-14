import { beforeEach, describe, expect, test } from "bun:test";
import type { LogLevel } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { createApp } from "../../src/bootstrap/app";
import { JwksKeySource } from "../../src/auth/jwks";
import { createAuthRoutes } from "../../src/auth/routes";
import type { AuthDependencies } from "../../src/auth/middleware";
import { UNAUTHENTICATED_MESSAGE } from "../../src/auth/errors";
import {
  AUDIENCE,
  generateKey,
  ISSUER,
  JwksServer,
  mintToken,
  SUBJECT,
  type TestKey,
} from "./support";
import { baseContext, FakeAuthRepository } from "./fake-repository";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";

let key: TestKey;
let repository: FakeAuthRepository;
let collector: LogCollector;

interface Harness {
  request: (
    path: string,
    init?: RequestInit & { token?: string; reauth?: string },
  ) => Promise<Response>;
  repository: FakeAuthRepository;
  collector: LogCollector;
  idempotency: FakeIdempotencyRepository;
}

async function harness(
  overrides: Partial<AuthDependencies> = {},
): Promise<Harness> {
  key ??= await generateKey("key-routes");
  repository = new FakeAuthRepository();
  repository.contexts.set(SUBJECT, baseContext());
  collector = new LogCollector();

  const logger = createJsonLogger(
    "api",
    "0.1.0-test",
    "debug" as LogLevel,
    collector.sink,
  );
  const deps: AuthDependencies = {
    keys: new JwksKeySource("https://jwks.test/keys", {
      fetchImpl: new JwksServer([key]).fetch,
    }),
    repository: repository.asRepository(),
    logger,
    issuer: ISSUER,
    audience: AUDIENCE,
    clockSkewSeconds: 30,
    revocationBudgetSeconds: 0,
    reauthTtlSeconds: 300,
    deletionGraceDays: 14,
    ...overrides,
  };
  const idempotency = new FakeIdempotencyRepository();

  const app = createApp({
    info: { service: "api", version: "0.1.0-test", environment: "development" },
    logger,
    checks: {},
    auth: createAuthRoutes(deps, undefined, {
      logger,
      repository: idempotency,
    }),
  });

  return {
    repository,
    collector,
    idempotency,
    // Hono's `request` can return a Response synchronously; awaiting here
    // gives callers one shape.
    request: async (path, init = {}) => {
      const { token, reauth, ...rest } = init;
      const headers = new Headers(rest.headers);
      if (token) headers.set("authorization", `Bearer ${token}`);
      if (reauth) headers.set("x-studafy-reauth", reauth);
      if (rest.body) headers.set("content-type", "application/json");
      if (
        rest.method === "POST" && path !== "/v1/auth/reauth/verify" &&
        !headers.has("idempotency-key")
      ) {
        headers.set("idempotency-key", crypto.randomUUID());
      }
      return await app.request(path, { ...rest, headers });
    },
  };
}

async function validToken(overrides: Parameters<typeof mintToken>[0] = {}) {
  key ??= await generateKey("key-routes");
  return await mintToken({ key, ...overrides });
}

/** Obtains a live reauth grant the way a client does. */
async function grantFor(
  h: Harness,
  token: string,
  purpose: string,
): Promise<string> {
  const response = await h.request("/v1/auth/reauth/verify", {
    method: "POST",
    token,
    body: JSON.stringify({ purpose }),
  });
  const body = await response.json() as { grant: string };
  return body.grant;
}

beforeEach(() => {
  collector = new LogCollector();
});

describe("authenticated context", () => {
  test("GET /v1/me returns the database profile and memberships", async () => {
    const h = await harness();
    const response = await h.request("/v1/me", { token: await validToken() });
    expect(response.status).toBe(200);
    const body = await response.json() as {
      id: string;
      memberships: { role: string; schoolId: string }[];
    };
    expect(body.id).toBe(SUBJECT);
    expect(body.memberships[0]!.role).toBe("teacher");
  });

  test("GET /v1/auth/context echoes the membership version", async () => {
    const h = await harness();
    const response = await h.request("/v1/auth/context", {
      token: await validToken(),
    });
    const body = await response.json() as {
      membershipVersion: string;
      assuranceLevel: string;
      mfaRequired: boolean;
    };
    expect(body.membershipVersion).toBe("v1");
    expect(body.assuranceLevel).toBe("aal1");
    expect(body.mfaRequired).toBe(false);
  });
});

describe("role metadata in the token is never trusted", () => {
  test("app_metadata claiming school_admin grants no admin authority", async () => {
    const h = await harness();
    const token = await validToken({
      extraClaims: {
        app_metadata: { role: "school_admin", roles: ["school_admin"] },
        user_metadata: { role: "school_admin" },
        role: "school_admin",
      },
    });

    const response = await h.request("/v1/auth/context", { token });
    const body = await response.json() as {
      memberships: { role: string }[];
      mfaRequired: boolean;
    };
    // The database says teacher, so the answer is teacher.
    expect(body.memberships.map((m) => m.role)).toEqual(["teacher"]);
    expect(body.mfaRequired).toBe(false);
  });

  test("a token claiming memberships for another school is ignored", async () => {
    const h = await harness();
    const token = await validToken({
      extraClaims: {
        memberships: [{ school_id: "attacker-school", role: "school_admin" }],
      },
    });
    const response = await h.request("/v1/auth/context", { token });
    const body = await response.json() as {
      memberships: { schoolId: string }[];
    };
    expect(body.memberships.map((m) => m.schoolId)).toEqual([
      "bbbbbbbb-0000-4000-8000-000000000001",
    ]);
  });
});

describe("anti-enumeration", () => {
  /** Every distinguishable authentication failure state. */
  async function denialBodies(): Promise<
    { label: string; status: number; body: unknown; headers: string[] }[]
  > {
    const results = [];

    const cases: { label: string; setup: () => Promise<Response> }[] = [
      {
        label: "no credentials",
        setup: async () => (await harness()).request("/v1/me"),
      },
      {
        label: "malformed token",
        setup: async () =>
          (await harness()).request("/v1/me", { token: "not.a.token" }),
      },
      {
        label: "expired token",
        setup: async () => {
          const past = Math.floor(Date.now() / 1000) - 7200;
          return (await harness()).request("/v1/me", {
            token: await validToken({ issuedAt: past, expiresAt: past + 60 }),
          });
        },
      },
      {
        label: "wrong issuer",
        setup: async () =>
          (await harness()).request("/v1/me", {
            token: await validToken({ issuer: "https://evil.test/auth/v1" }),
          }),
      },
      {
        label: "account that never existed",
        setup: async () => {
          const h = await harness();
          h.repository.contexts.clear();
          return h.request("/v1/me", { token: await validToken() });
        },
      },
      {
        label: "suspended profile",
        setup: async () => {
          const h = await harness();
          h.repository.contexts.set(
            SUBJECT,
            baseContext({ profileStatus: "suspended" }),
          );
          return h.request("/v1/me", { token: await validToken() });
        },
      },
      {
        label: "deleted profile",
        setup: async () => {
          const h = await harness();
          h.repository.contexts.set(
            SUBJECT,
            baseContext({ profileDeletedAt: new Date().toISOString() }),
          );
          return h.request("/v1/me", { token: await validToken() });
        },
      },
      {
        label: "signed out everywhere",
        setup: async () => {
          const h = await harness();
          h.repository.contexts.set(
            SUBJECT,
            baseContext({ revokedBefore: new Date().toISOString() }),
          );
          const past = Math.floor(Date.now() / 1000) - 60;
          return h.request("/v1/me", {
            token: await validToken({ issuedAt: past }),
          });
        },
      },
    ];

    for (const { label, setup } of cases) {
      const response = await setup();
      results.push({
        label,
        status: response.status,
        body: await response.json(),
        headers: [response.headers.get("www-authenticate") ?? ""],
      });
    }
    return results;
  }

  test("every authentication failure is indistinguishable to the caller", async () => {
    const results = await denialBodies();

    // Request ids differ by design; nothing else may.
    const normalized = results.map((result) => ({
      status: result.status,
      body: {
        ...(result.body as Record<string, unknown>),
        requestId: "<redacted>",
      } as Record<string, unknown>,
      headers: result.headers,
    }));

    const [first, ...rest] = normalized;
    for (const entry of rest) {
      expect(entry).toEqual(first!);
    }
    expect(first!.status).toBe(401);
    expect(first!.body["detail"]).toBe(UNAUTHENTICATED_MESSAGE);
  });

  test("no denial message names an account, provider, or reason", async () => {
    for (const result of await denialBodies()) {
      const serialized = JSON.stringify(result.body).toLowerCase();
      for (
        const leak of [
          "suspend",
          "delet",
          "revok",
          "expire",
          "issuer",
          "signature",
          "not found",
          "unknown",
          "profile",
        ]
      ) {
        expect({
          label: result.label,
          leak,
          present: serialized.includes(leak),
        })
          .toEqual({ label: result.label, leak, present: false });
      }
    }
  });

  test("the private reason is still recorded for operators", async () => {
    const h = await harness();
    h.repository.contexts.set(
      SUBJECT,
      baseContext({ profileStatus: "suspended" }),
    );
    await h.request("/v1/me", { token: await validToken() });

    const denial = h.collector.parsed().find((entry) =>
      entry["event"] === "auth_denied"
    );
    expect(denial?.["reason"]).toBe("profile_suspended");
  });

  test("no log line contains the bearer token", async () => {
    const h = await harness();
    const token = await validToken();
    await h.request("/v1/me", { token });
    h.repository.contexts.clear();
    await h.request("/v1/me", { token });

    const logged = h.collector.parsed().map((entry) => JSON.stringify(entry))
      .join("\n");
    expect(logged).not.toContain(token);
    expect(logged).not.toContain(token.split(".")[2]);
  });

  test("an audit sink failure still produces the uniform denial", async () => {
    const h = await harness();
    h.repository.failEventWrites = true;
    h.repository.contexts.clear();
    const response = await h.request("/v1/me", { token: await validToken() });
    expect(response.status).toBe(401);
  });
});

describe("revocation", () => {
  test("a token issued before the watermark is refused while still unexpired", async () => {
    const h = await harness();
    const issuedAt = Math.floor(Date.now() / 1000) - 120;
    h.repository.contexts.set(
      SUBJECT,
      baseContext({ revokedBefore: new Date().toISOString() }),
    );
    const response = await h.request("/v1/me", {
      // Comfortably inside its own validity window.
      token: await validToken({ issuedAt, expiresAt: issuedAt + 3600 }),
    });
    expect(response.status).toBe(401);
  });

  test("a token issued after the watermark still works", async () => {
    const h = await harness();
    h.repository.contexts.set(
      SUBJECT,
      baseContext({
        revokedBefore: new Date(Date.now() - 60_000).toISOString(),
      }),
    );
    const response = await h.request("/v1/me", { token: await validToken() });
    expect(response.status).toBe(200);
  });

  test("sign out everywhere sets a watermark that immediately denies", async () => {
    const h = await harness();
    const issuedAt = Math.floor(Date.now() / 1000) - 5;
    const token = await validToken({ issuedAt, expiresAt: issuedAt + 3600 });

    expect((await h.request("/v1/me", { token })).status).toBe(200);

    const signOut = await h.request("/v1/auth/sign-out", {
      method: "POST",
      token,
      body: JSON.stringify({ scope: "all" }),
    });
    expect(signOut.status).toBe(200);

    // The same token, unexpired, is now refused: the revocation budget is
    // "next request", not "next token expiry".
    expect((await h.request("/v1/me", { token })).status).toBe(401);
  });

  test("a revocation budget can widen the window deliberately", async () => {
    const h = await harness({ revocationBudgetSeconds: 300 });
    const issuedAt = Math.floor(Date.now() / 1000) - 5;
    h.repository.contexts.set(
      SUBJECT,
      baseContext({ revokedBefore: new Date().toISOString() }),
    );
    const response = await h.request("/v1/me", {
      token: await validToken({ issuedAt }),
    });
    expect(response.status).toBe(200);
  });
});

describe("recent authentication", () => {
  test("a privileged command without a grant is refused", async () => {
    const h = await harness();
    const response = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token: await validToken(),
      body: JSON.stringify({
        reasonCode: "undisclosed",
        confirmation: "DELETE",
      }),
    });
    expect(response.status).toBe(401);
    expect((await response.json() as { code: string }).code)
      .toBe("REAUTH_REQUIRED");
  });

  test("a grant permits the command exactly once", async () => {
    const h = await harness();
    const token = await validToken();
    const grant = await grantFor(h, token, "account_deletion");

    const first = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token,
      reauth: grant,
      body: JSON.stringify({
        reasonCode: "undisclosed",
        confirmation: "DELETE",
      }),
    });
    expect(first.status).toBe(200);

    const replay = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token,
      reauth: grant,
      body: JSON.stringify({
        reasonCode: "undisclosed",
        confirmation: "DELETE",
      }),
    });
    expect(replay.status).toBe(401);
  });

  test("a completed replay is resolved before consuming recent auth again", async () => {
    const h = await harness();
    const token = await validToken();
    const grant = await grantFor(h, token, "account_deletion");
    const headers = { "idempotency-key": "deletion-replay-000001" };
    const body = JSON.stringify({
      reasonCode: "undisclosed",
      confirmation: "DELETE",
    });

    const first = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token,
      reauth: grant,
      headers,
      body,
    });
    const replay = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token,
      reauth: grant,
      headers,
      body,
    });

    expect(first.status).toBe(200);
    expect(replay.status).toBe(200);
    expect(replay.headers.get("idempotency-replayed")).toBe("true");
    expect(await replay.json()).toEqual(await first.json());
    expect(
      h.repository.events.filter((event) =>
        event.eventType === "account_deletion_requested"
      ),
    )
      .toHaveLength(1);
  });

  test("a grant for one purpose does not authorize another", async () => {
    const h = await harness();
    const token = await validToken();
    const grant = await grantFor(h, token, "device_revoke");

    const response = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token,
      reauth: grant,
      body: JSON.stringify({
        reasonCode: "undisclosed",
        confirmation: "DELETE",
      }),
    });
    expect(response.status).toBe(401);
  });

  test("a grant minted for another session is refused", async () => {
    const h = await harness();
    const victimToken = await validToken();
    const grant = await grantFor(h, victimToken, "account_deletion");

    // Same user, different session: a grant lifted from one device must not
    // authorize a privileged action from another.
    const otherSession = await validToken({
      sessionId: "99999999-8888-4777-8666-555555555555",
    });
    const response = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token: otherSession,
      reauth: grant,
      body: JSON.stringify({
        reasonCode: "undisclosed",
        confirmation: "DELETE",
      }),
    });
    expect(response.status).toBe(401);
  });

  test("a fabricated grant value is refused", async () => {
    const h = await harness();
    const response = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token: await validToken(),
      reauth: "a".repeat(43),
      body: JSON.stringify({
        reasonCode: "undisclosed",
        confirmation: "DELETE",
      }),
    });
    expect(response.status).toBe(401);
  });

  test("an expired grant is refused", async () => {
    const h = await harness({ reauthTtlSeconds: 30 });
    const token = await validToken();
    const grant = await grantFor(h, token, "account_deletion");
    // Expire it in the store rather than waiting.
    for (const entry of h.repository.grants) entry.expiresAt = Date.now() - 1;

    const response = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token,
      reauth: grant,
      body: JSON.stringify({
        reasonCode: "undisclosed",
        confirmation: "DELETE",
      }),
    });
    expect(response.status).toBe(401);
  });

  test("the grant is returned once and stored only as a digest", async () => {
    const h = await harness();
    const token = await validToken();
    const grant = await grantFor(h, token, "account_deletion");
    expect(grant.length).toBeGreaterThanOrEqual(43);
    for (const stored of h.repository.grants) {
      expect(stored.grantHash).not.toBe(grant);
      expect(stored.grantHash).toMatch(/^[0-9a-f]{64}$/);
    }
  });
});

describe("admin MFA", () => {
  function adminContext() {
    return baseContext({
      memberships: [
        {
          id: "aaaaaaaa-0000-4000-8000-000000000009",
          school_id: "bbbbbbbb-0000-4000-8000-000000000001",
          school_name: "Al-Noor International",
          school_timezone: "Asia/Riyadh",
          role: "school_admin",
          active: true,
          active_term_id: null,
        },
      ],
    });
  }

  test("an admin session without a second factor cannot link an identity", async () => {
    const h = await harness();
    h.repository.contexts.set(SUBJECT, adminContext());
    const response = await h.request("/v1/auth/identities/link", {
      method: "POST",
      token: await validToken({ aal: "aal1" }),
      body: JSON.stringify({
        provider: "google",
        idToken: "x",
        makePrimary: false,
      }),
    });
    expect(response.status).toBe(403);
    expect((await response.json() as { code: string }).code)
      .toBe("MFA_REQUIRED");
  });

  test("enrolment alone does not satisfy the requirement", async () => {
    // A session that never presented the second factor stays aal1 even for a
    // user who has enrolled one.
    const h = await harness();
    h.repository.contexts.set(
      SUBJECT,
      baseContext({ ...adminContext(), mfaEnrolled: true }),
    );
    const response = await h.request("/v1/auth/identities/link", {
      method: "POST",
      token: await validToken({ aal: "aal1" }),
      body: JSON.stringify({
        provider: "google",
        idToken: "x",
        makePrimary: false,
      }),
    });
    expect(response.status).toBe(403);
  });

  test("an admin cannot mint a reauth grant at aal1", async () => {
    const h = await harness();
    h.repository.contexts.set(SUBJECT, adminContext());
    const response = await h.request("/v1/auth/reauth/verify", {
      method: "POST",
      token: await validToken({ aal: "aal1" }),
      body: JSON.stringify({ purpose: "school_admin_privileged" }),
    });
    expect(response.status).toBe(403);
  });

  test("a teacher is not held to the admin requirement", async () => {
    const h = await harness();
    const response = await h.request("/v1/auth/reauth/verify", {
      method: "POST",
      token: await validToken({ aal: "aal1" }),
      body: JSON.stringify({ purpose: "account_deletion" }),
    });
    expect(response.status).toBe(200);
  });
});

describe("identity linking", () => {
  test("linking refuses when no provider verifier is configured", async () => {
    // Fail closed: an unconfigured provider must not be linkable.
    const h = await harness();
    const token = await validToken();
    const grant = await grantFor(h, token, "account_link");
    const response = await h.request("/v1/auth/identities/link", {
      method: "POST",
      token,
      reauth: grant,
      body: JSON.stringify({
        provider: "google",
        idToken: "unverifiable",
        makePrimary: false,
      }),
    });
    expect(response.status).toBe(400);
  });

  test("an identity owned by another profile is a conflict, not a takeover", async () => {
    const h = await harness({
      verifyProviderIdentity: () => Promise.resolve("provider-subject-1"),
    });
    h.repository.identities.set("google:provider-subject-1", "someone-else");
    const token = await validToken();
    const grant = await grantFor(h, token, "account_link");

    const response = await h.request("/v1/auth/identities/link", {
      method: "POST",
      token,
      reauth: grant,
      body: JSON.stringify({
        provider: "google",
        idToken: "valid",
        makePrimary: false,
      }),
    });
    expect(response.status).toBe(409);
    expect(h.repository.identities.get("google:provider-subject-1")).toBe(
      "someone-else",
    );
  });
});

describe("device revocation", () => {
  test("a device belonging to someone else is not revoked", async () => {
    const h = await harness();
    h.repository.devices.set("victim-device", {
      id: "victim-device",
      user: "another-user",
      platform: "ios",
      app_version: null,
      display_label: null,
      first_seen_at: new Date().toISOString(),
      last_seen_at: new Date().toISOString(),
      revoked_at: null,
    });
    const token = await validToken();
    const grant = await grantFor(h, token, "device_revoke");

    const response = await h.request("/v1/auth/devices/revoke", {
      method: "POST",
      token,
      reauth: grant,
      body: JSON.stringify({
        deviceId: "00000000-0000-4000-8000-000000000001",
      }),
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ revoked: false });
    expect(h.repository.devices.get("victim-device")!.revoked_at).toBeNull();
  });

  test("the device list shows only the caller's devices", async () => {
    const h = await harness();
    h.repository.devices.set("mine", {
      id: "mine",
      user: SUBJECT,
      platform: "ios",
      app_version: "1.0.0",
      display_label: "iPad",
      first_seen_at: new Date().toISOString(),
      last_seen_at: new Date().toISOString(),
      revoked_at: null,
    });
    h.repository.devices.set("theirs", {
      id: "theirs",
      user: "another-user",
      platform: "android",
      app_version: null,
      display_label: null,
      first_seen_at: new Date().toISOString(),
      last_seen_at: new Date().toISOString(),
      revoked_at: null,
    });

    const response = await h.request("/v1/auth/devices", {
      token: await validToken(),
    });
    const body = await response.json() as { devices: { id: string }[] };
    expect(body.devices.map((device) => device.id)).toEqual(["mine"]);
  });
});

describe("account deletion", () => {
  test("the impact summary states retained school records", async () => {
    const h = await harness();
    const response = await h.request("/v1/account/deletion-impact", {
      token: await validToken(),
    });
    const body = await response.json() as {
      retainedSchoolRecords: { attendance: number };
      gracePeriodDays: number;
    };
    expect(body.retainedSchoolRecords.attendance).toBe(12);
    expect(body.gracePeriodDays).toBe(14);
  });

  test("requesting twice returns the live request rather than duplicating", async () => {
    const h = await harness();
    const token = await validToken();

    const first = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token,
      reauth: await grantFor(h, token, "account_deletion"),
      body: JSON.stringify({
        reasonCode: "undisclosed",
        confirmation: "DELETE",
      }),
    });
    expect((await first.json() as { created: boolean }).created).toBe(true);

    const second = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token,
      reauth: await grantFor(h, token, "account_deletion"),
      body: JSON.stringify({
        reasonCode: "undisclosed",
        confirmation: "DELETE",
      }),
    });
    expect((await second.json() as { created: boolean }).created).toBe(false);
  });

  test("cancellation needs no recent-auth grant", async () => {
    // Stopping a destructive action is the safe direction; friction here
    // would strand a user who cannot re-authenticate before the grace period
    // ends.
    const h = await harness();
    const token = await validToken();
    await h.request("/v1/account/deletion-request", {
      method: "POST",
      token,
      reauth: await grantFor(h, token, "account_deletion"),
      body: JSON.stringify({
        reasonCode: "undisclosed",
        confirmation: "DELETE",
      }),
    });

    const response = await h.request("/v1/account/deletion-cancel", {
      method: "POST",
      token,
      body: "{}",
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ cancelled: true });
  });

  test("a request without the typed confirmation is rejected", async () => {
    const h = await harness();
    const token = await validToken();
    const response = await h.request("/v1/account/deletion-request", {
      method: "POST",
      token,
      reauth: await grantFor(h, token, "account_deletion"),
      body: JSON.stringify({ reasonCode: "undisclosed", confirmation: "yes" }),
    });
    expect(response.status).toBe(400);
  });
});

describe("unmigrated paths still fail closed", () => {
  test("a /v1 path with no handler answers NOT_IMPLEMENTED", async () => {
    const h = await harness();
    const response = await h.request("/v1/classrooms", {
      token: await validToken(),
    });
    expect(response.status).toBe(404);
    expect((await response.json() as { code: string }).code)
      .toBe("NOT_IMPLEMENTED");
  });

  test("liveness stays reachable without a token", async () => {
    const h = await harness();
    expect((await h.request("/healthz")).status).toBe(200);
  });
});
