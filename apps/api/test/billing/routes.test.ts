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
import { sha256Hex } from "../../src/auth/middleware";

const subject = "aaaaaaaa-0000-4000-8000-000000000001";
const approvalId = "cccccccc-0000-4000-8000-000000000003";
const reauthGrant = "reauth-grant-for-billing-approval-tests-0001";
const FIRST_DECISION = "billing-approval-decision-0001";
const SECOND_DECISION = "billing-approval-decision-0002";
function harness() {
  const idem = new FakeIdempotencyRepository();
  const seen: NormalizedTransaction[] = [];
  let testPurchase = false;
  let accountId: string | null = subject;
  let currentState = "SUBSCRIPTION_STATE_ACTIVE";
  let verifierCalls = 0;
  const decisions: { approvalId: string; approve: boolean }[] = [];
  const consumedGrants: string[] = [];
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
    requestPurchaseApproval: async (_c, featureKey, r) => {
      const response = { id: approvalId, featureKey, status: "requested" };
      await idem.complete(subject, r.id, r.generation, 201, response);
      return { outcome: "ok", response };
    },
    listPurchaseApprovals: async () => [],
    decidePurchaseApproval: async (_c, id, approve, r) => {
      decisions.push({ approvalId: id, approve });
      const response = { id, status: approve ? "approved" : "declined" };
      await idem.complete(subject, r.id, r.generation, 200, response);
      return { outcome: "ok", response };
    },
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
      {
        logger,
        repository: {
          recordEvent: async () => undefined,
          consumeReauthGrant: async (
            _subject: string,
            grant: { purpose: string; grantHash: string },
          ) => {
            if (
              grant.purpose !== "billing_purchase_approval" ||
              grant.grantHash !== await sha256Hex(reauthGrant)
            ) return false;
            consumedGrants.push(grant.grantHash);
            return true;
          },
        },
      } as never,
    ),
  );
  return {
    app,
    seen,
    idem,
    verifierCalls: () => verifierCalls,
    decisions,
    consumedGrants,
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

describe("guardian purchase approval", () => {
  test("a student request returns 201 and replays on retry", async () => {
    const h = harness();
    const first = await send(h, "/v1/billing/purchase-approvals", {
      featureKey: "student_notebook",
    });
    const second = await send(h, "/v1/billing/purchase-approvals", {
      featureKey: "student_notebook",
    });
    expect(first.status).toBe(201);
    expect(second.status).toBe(201);
    expect(second.headers.get("Idempotency-Replayed")).toBe("true");
  });
  test("approval cannot be requested for a retired AI product", async () => {
    const h = harness();
    const res = await send(h, "/v1/billing/purchase-approvals", {
      featureKey: "student_ai",
    });
    expect(res.status).toBe(400);
  });
  test("a decision without a recent-auth grant never reaches the database", async () => {
    const h = harness();
    const res = await send(
      h,
      `/v1/billing/purchase-approvals/${approvalId}/decision`,
      { approve: true },
    );
    expect(res.status).toBe(401);
    expect(((await res.json()) as { code: string }).code).toBe(
      "REAUTH_REQUIRED",
    );
    expect(h.decisions).toHaveLength(0);
  });
  test("a decision with a grant for another purpose is refused", async () => {
    const h = harness();
    const res = await h.app.request(
      `/v1/billing/purchase-approvals/${approvalId}/decision`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "idempotency-key": SECOND_DECISION,
          "x-studafy-reauth": "a-grant-minted-for-something-else",
        },
        body: JSON.stringify({ approve: true }),
      },
    );
    expect(res.status).toBe(401);
    expect(h.decisions).toHaveLength(0);
  });
  test("a guardian decision with a fresh grant is applied once", async () => {
    const h = harness();
    const res = await h.app.request(
      `/v1/billing/purchase-approvals/${approvalId}/decision`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "idempotency-key": FIRST_DECISION,
          "x-studafy-reauth": reauthGrant,
        },
        body: JSON.stringify({ approve: true }),
      },
    );
    expect(res.status).toBe(200);
    expect(h.decisions).toEqual([{ approvalId, approve: true }]);
    expect(h.consumedGrants).toHaveLength(1);
  });
});
