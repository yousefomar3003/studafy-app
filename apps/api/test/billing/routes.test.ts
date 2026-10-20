import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { createBillingRoutes } from "../../src/billing/routes";
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
function harness() {
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
        environment: "production",
        apple: null,
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
    test(`${path}: test receipts cannot grant production access`, async () => {
      const h = harness();
      h.setTest(true);
      expect((await send(h, path, body)).status).toBe(422);
      expect(h.seen).toHaveLength(0);
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
