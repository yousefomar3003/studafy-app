import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import {
  type BillingRoutesDependencies,
  createBillingRoutes,
} from "../../src/billing/routes";
import {
  type AppleTransactionVerifier,
  AppleVerificationError,
  peekAppleSignedEnvironment,
  type VerifiedAppleNotification,
  type VerifiedAppleTransaction,
} from "@studafy/infrastructure";
import type {
  BillingRepository,
  BillingReservation,
  NormalizedTransaction,
} from "../../src/billing/repository";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { requestContext } from "../../src/platform/middleware";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";
import { createJsonLogger } from "@studafy/observability";

const subject = "aaaaaaaa-0000-4000-8000-000000000001";
const approvalId = "cccccccc-0000-4000-8000-000000000003";
function harness(
  options: {
    environment?: string;
    apple?: BillingRoutesDependencies["apple"];
    outcome?: string;
  } = {},
) {
  const environment = options.environment ?? "production";
  const idem = new FakeIdempotencyRepository();
  const seen: NormalizedTransaction[] = [];
  let testPurchase = false;
  let accountId: string | null = subject;
  let currentState = "SUBSCRIPTION_STATE_ACTIVE";
  let verifierCalls = 0;
  const logger = createJsonLogger("api", "test", "error", () => undefined);
  async function write(
    body: NormalizedTransaction,
    reservation: BillingReservation,
    restored = false,
  ) {
    seen.push(body);
    if (options.outcome) return { outcome: options.outcome };
    const response = {
      featureKey: body.productFeatureKey,
      derivation: "granted",
      ...(restored ? { restored: true } : {}),
    };
    await idem.complete(
      subject,
      reservation.id,
      reservation.generation,
      200,
      response,
    );
    return { outcome: "ok", response };
  }
  const repository: BillingRepository = {
    catalogue: async () => ({ products: [] }),
    selfPurchaseStatus: async () => [],
    setSelfPurchase: async (_c, schoolId, enabled, reservation) => {
      await idem.complete(
        subject,
        reservation.id,
        reservation.generation,
        200,
        { schoolId, selfPurchaseEnabled: enabled },
      );
      return true;
    },
    submitVerification: async (_c, b, r) => write(b, r),
    restore: async (_c, b, r) => write(b, r, true),
    listEntitlements: async () => [],
    recordEvent: async () => ({ outcome: "duplicate" }),
  };
  const app = new Hono<AuthorizationEnv>();
  app.use("*", requestContext() as never);
  app.use("*", async (c, next) => {
    c.set(
      "actor",
      {
        token: { subject, sessionId: "dddddddd-0000-4000-8000-000000000004" },
        context: { userId: subject, memberships: [] },
        aal2: true,
      } as never,
    );
    await next();
  });
  app.route(
    "/",
    createBillingRoutes(
      {
        repository,
        environment,
        apple: options.apple ?? null,
        google: {
          packageName: "io.studafy.app",
          verifier: {
            verifySubscription: async () => {
              verifierCalls++;
              return {
                packageName: "io.studafy.app",
                productId: "notebook",
                purchaseToken: "signed-store-token",
                originalTransactionId: "original",
                transactionId: "transaction",
                subscriptionState: currentState,
                startTime: new Date().toISOString(),
                expiryTime: new Date(Date.now() + 86400000).toISOString(),
                acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
                testPurchase,
                obfuscatedExternalAccountId: accountId,
              };
            },
            acknowledgeSubscription: async () => {},
            verifyPubSubToken: async () => false,
          },
        },
      },
      createAuthorizationDependencies(logger),
      { repository: idem, logger },
    ),
  );
  return {
    app,
    seen,
    idem,
    verifierCalls: () => verifierCalls,
    setTest: (v: boolean) => {
      testPurchase = v;
    },
    setAccount: (v: string | null) => {
      accountId = v;
    },
    setState: (v: string) => {
      currentState = v;
    },
  };
}
const body = {
  platform: "play_store",
  environment: "production",
  productFeatureKey: "student_notebook",
  storeProductId: "notebook",
  verificationPayload: "signed-store-token",
};
async function send(
  h: ReturnType<typeof harness>,
  path: string,
  payload: object,
  key = "billing-regression-request-0001",
) {
  return await h.app.request(path, {
    method: "POST",
    headers: { "content-type": "application/json", "idempotency-key": key },
    body: JSON.stringify(payload),
  });
}

describe("billing trust boundary", () => {
  for (const path of ["/v1/billing/purchases", "/v1/billing/restore"]) {
    test(`${path}: a client-asserted parental gate is rejected by the schema`, async () => {
      const h = harness();
      const res = await send(h, path, {
        ...body,
        parentalGate: { token: "forged", answer: 0 },
      });
      expect(res.status).toBe(400);
      expect(h.seen).toHaveLength(0);
      expect(h.verifierCalls()).toBe(0);
    });
    test(`${path}: environment cannot be selected by caller`, async () => {
      const h = harness();
      expect(
        (await send(h, path, { ...body, environment: "synthetic" })).status,
      ).toBe(422);
      expect(h.verifierCalls()).toBe(0);
    });
    test(`${path}: a license tester's purchase is recorded as a test purchase`, async () => {
      // DL-080: Play license testers (and Play's own review) always make
      // test purchases, also against production.
      const h = harness();
      h.setTest(true);
      expect((await send(h, path, body)).status).toBe(200);
      expect(h.seen[0]).toMatchObject({
        environment: "production",
        sandbox: true,
      });
    });
    test(`${path}: a real purchase is recorded as a real one`, async () => {
      const h = harness();
      expect((await send(h, path, body)).status).toBe(200);
      expect(h.seen[0]?.sandbox).toBe(false);
    });
    test(`${path}: development still takes test purchases only`, async () => {
      const real = harness({ environment: "development" });
      expect(
        (await send(real, path, { ...body, environment: "development" }))
          .status,
      ).toBe(422);
      expect(real.seen).toHaveLength(0);

      const tester = harness({ environment: "development" });
      tester.setTest(true);
      expect(
        (await send(tester, path, { ...body, environment: "development" }))
          .status,
      ).toBe(200);
      expect(tester.seen[0]?.sandbox).toBe(true);
    });
    test(`${path}: missing or foreign account binding is refused`, async () => {
      for (const account of [null, "bbbbbbbb-0000-4000-8000-000000000002"]) {
        const h = harness();
        h.setAccount(account);
        expect((await send(h, path, body)).status).toBe(422);
        expect(h.seen).toHaveLength(0);
      }
    });
    test(`${path}: successful retry replays without store verification`, async () => {
      const h = harness();
      const first = await send(h, path, body);
      const second = await send(h, path, body);
      expect(first.status).toBe(200);
      expect(second.status).toBe(200);
      expect(await second.json()).toEqual(await first.json());
      expect(second.headers.get("Idempotency-Replayed")).toBe("true");
      expect(h.seen).toHaveLength(1);
      expect(h.verifierCalls()).toBe(1);
    });
  }
  test("restore uses current revoked state", async () => {
    const h = harness();
    h.setState("SUBSCRIPTION_STATE_EXPIRED");
    expect((await send(h, "/v1/billing/restore", body)).status).toBe(200);
    expect(h.seen[0]?.state).toBe("expired");
  });
  test("catalogue provides the authenticated account binding", async () => {
    const h = harness();
    const res = await h.app.request("/v1/billing/catalogue");
    expect(
      ((await res.json()) as { purchaseAccountToken: string })
        .purchaseAccountToken,
    ).toBe(subject);
  });
});

/** A compact JWS naming an Apple environment, as the app sends it. */
function signedTransaction(environment: string): string {
  const encode = (value: unknown) =>
    Buffer.from(JSON.stringify(value)).toString("base64url");
  return `${encode({ alg: "ES256" })}.${
    encode({ environment, bundleId: "com.studafy.light" })
  }.signature`;
}

/**
 * Stands in for Apple's SignedDataVerifier for one environment: like the
 * library, it refuses signed data that names another environment.
 */
class FakeAppleVerifier implements AppleTransactionVerifier {
  calls: string[] = [];
  constructor(
    readonly environment: "Sandbox" | "Production",
    readonly overrides: Partial<VerifiedAppleTransaction> = {},
  ) {}
  transaction(): VerifiedAppleTransaction {
    return {
      appAccountToken: subject,
      bundleId: "com.studafy.light",
      environment: this.environment,
      originalTransactionId: `${this.environment}-original`,
      transactionId: `${this.environment}-transaction`,
      productId: "studafy_plus_monthly",
      purchaseDate: Date.now() - 1000,
      expiresDate: Date.now() + 86400000,
      revocationReason: null,
      subscriptionStatus: 1,
      autoRenewing: true,
      ...this.overrides,
    };
  }
  async verifyTransaction(signed: string) {
    this.calls.push("verifyTransaction");
    if (peekAppleSignedEnvironment(signed) !== this.environment) {
      throw new AppleVerificationError("environment mismatch");
    }
    return this.transaction();
  }
  async getSubscriptionStatus() {
    this.calls.push("getSubscriptionStatus");
    return this.transaction();
  }
  verifyNotification(): Promise<VerifiedAppleNotification> {
    throw new Error("not used");
  }
}

describe("DL-080: App Review, TestFlight and sandbox testers", () => {
  const appleBody = (environment: string, server = "production") => ({
    platform: "app_store",
    environment: server,
    productFeatureKey: "studafy_plus",
    storeProductId: "studafy_plus_monthly",
    verificationPayload: signedTransaction(environment),
  });
  function productionApple(
    sandboxOverrides: Partial<VerifiedAppleTransaction> = {},
  ) {
    const production = new FakeAppleVerifier("Production");
    const sandbox = new FakeAppleVerifier("Sandbox", sandboxOverrides);
    return {
      production,
      sandbox,
      apple: {
        verifier: production,
        sandboxVerifier: sandbox,
        bundleId: "com.studafy.light",
        platformEnvironment: "Production" as const,
      },
    };
  }

  for (const path of ["/v1/billing/purchases", "/v1/billing/restore"]) {
    test(`${path}: production takes an Apple Sandbox purchase as a test purchase`, async () => {
      const { production, sandbox, apple } = productionApple();
      const h = harness({ apple });
      const res = await send(h, path, appleBody("Sandbox"));
      expect(res.status).toBe(200);
      // Verified, and its status read, in the Sandbox only.
      expect(sandbox.calls).toEqual([
        "verifyTransaction",
        "getSubscriptionStatus",
      ]);
      expect(production.calls).toEqual([]);
      expect(h.seen[0]).toMatchObject({
        platform: "app_store",
        environment: "production",
        originalTransactionId: "Sandbox-original",
        state: "active",
        sandbox: true,
      });
    });

    test(`${path}: production takes a real App Store purchase as a real one`, async () => {
      const { production, sandbox, apple } = productionApple();
      const h = harness({ apple });
      const res = await send(h, path, appleBody("Production"));
      expect(res.status).toBe(200);
      expect(production.calls).toEqual([
        "verifyTransaction",
        "getSubscriptionStatus",
      ]);
      expect(sandbox.calls).toEqual([]);
      expect(h.seen[0]).toMatchObject({
        environment: "production",
        sandbox: false,
      });
    });

    test(`${path}: a Sandbox purchase for another app or account is still refused`, async () => {
      for (
        const overrides of [
          { bundleId: "com.evil.app" },
          { appAccountToken: "bbbbbbbb-0000-4000-8000-000000000002" },
          { appAccountToken: null },
          { productId: "studafy_max_monthly" },
          // The Sandbox verifier only ever trusts Sandbox data.
          { environment: "Production" as const },
        ]
      ) {
        const { apple } = productionApple(overrides);
        const h = harness({ apple });
        expect((await send(h, path, appleBody("Sandbox"))).status).toBe(422);
        expect(h.seen).toHaveLength(0);
      }
    });

    test(`${path}: unreadable signed data goes to the Production verifier and is refused`, async () => {
      const { production, sandbox, apple } = productionApple();
      const h = harness({ apple });
      const res = await send(h, path, {
        ...appleBody("Sandbox"),
        verificationPayload: "signed.payload",
      });
      expect(res.status).toBe(422);
      expect(production.calls).toEqual(["verifyTransaction"]);
      expect(sandbox.calls).toEqual([]);
    });

    test(`${path}: a test purchase on a real lineage is refused`, async () => {
      const { apple } = productionApple();
      const h = harness({ apple, outcome: "store_environment_mismatch" });
      const res = await send(h, path, appleBody("Sandbox"));
      expect(res.status).toBe(422);
      expect(((await res.json()) as { code: string }).code).toBe(
        "RECEIPT_INVALID",
      );
    });

    test(`${path}: development still refuses a real App Store purchase`, async () => {
      const own = new FakeAppleVerifier("Sandbox");
      const apple = {
        verifier: own,
        bundleId: "com.studafy.light",
        platformEnvironment: "Sandbox" as const,
      };
      const real = harness({ environment: "development", apple });
      expect(
        (await send(real, path, appleBody("Production", "development")))
          .status,
      ).toBe(422);
      expect(real.seen).toHaveLength(0);

      // Even with Production Apple keys by mistake: still refused.
      const misconfigured = harness({
        environment: "development",
        apple: {
          ...apple,
          verifier: new FakeAppleVerifier("Production"),
          platformEnvironment: "Production",
        },
      });
      expect(
        (await send(
          misconfigured,
          path,
          appleBody("Production", "development"),
        )).status,
      ).toBe(422);

      const tester = harness({ environment: "development", apple });
      expect(
        (await send(tester, path, appleBody("Sandbox", "development")))
          .status,
      ).toBe(200);
      expect(tester.seen[0]?.sandbox).toBe(true);
    });
  }
});

// DL-071: students buy their own plans; the approval routes stay only so an
// older app (Play build 100) gets a stable answer instead of a crash.
describe("retired guardian purchase approval", () => {
  async function code(res: Response) {
    return ((await res.json()) as { code: string }).code;
  }
  test("the list is always empty", async () => {
    const h = harness();
    const res = await h.app.request("/v1/billing/purchase-approvals");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ approvals: [] });
  });
  test("a request from an older app is refused with a stable code", async () => {
    const h = harness();
    for (const featureKey of ["studafy_plus", "studafy_max"]) {
      const res = await send(h, "/v1/billing/purchase-approvals", {
        featureKey,
      });
      expect(res.status).toBe(422);
      expect(await code(res)).toBe("PURCHASE_APPROVAL_RETIRED");
    }
    expect(h.idem.entries.size).toBe(0);
  });
  test("a decision is refused without a recent-auth challenge", async () => {
    const h = harness();
    const res = await send(
      h,
      `/v1/billing/purchase-approvals/${approvalId}/decision`,
      { approve: true },
    );
    expect(res.status).toBe(422);
    expect(await code(res)).toBe("PURCHASE_APPROVAL_RETIRED");
    expect(h.idem.entries.size).toBe(0);
  });
  test("a malformed request is still a validation error", async () => {
    const h = harness();
    const res = await send(h, "/v1/billing/purchase-approvals", {
      featureKey: "student_ai",
    });
    expect(res.status).toBe(400);
  });
});
