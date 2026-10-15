import { describe, expect, test } from "bun:test";
import {
  APP_STORE_NOTIFICATIONS_PATH,
  PLAY_BILLING_PUSH_PATH,
} from "@studafy/config";
import type { GooglePurchaseVerifier } from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { createBillingWebhookRoutes } from "../../src/billing/webhookRoutes";
import type { BillingRepository } from "../../src/billing/repository";
import { flowFor } from "../../src/platform/rate-limit/policies";

type Recorded = [string, string, string | null, string, string];

function routes(google: GooglePurchaseVerifier | null) {
  const recorded: Recorded[] = [];
  const repository = {
    async recordEvent(...args: Recorded) {
      recorded.push(args);
      return { outcome: "new" as const, eventId: 1 };
    },
  } as unknown as BillingRepository;
  const app = createBillingWebhookRoutes({
    repository,
    environment: "production",
    apple: null,
    google: google ? { verifier: google } : null,
    logger: createJsonLogger("api", "test", "error", () => {}),
  });
  return { app, recorded };
}

function pubSubVerifier(accept: boolean): GooglePurchaseVerifier {
  return {
    verifySubscription: () => Promise.reject(new Error("not used")),
    acknowledgeSubscription: () => Promise.reject(new Error("not used")),
    verifyPubSubToken: (header) =>
      Promise.resolve(accept && header === "Bearer oidc-token"),
  };
}

/** A Pub/Sub push body around a recorded-shape voided purchase RTDN. */
const voidedPush = {
  message: {
    messageId: "pubsub-message-1",
    data: Buffer.from(JSON.stringify({
      version: "1.0",
      packageName: "com.studafy.app",
      eventTimeMillis: "1760518800000",
      voidedPurchaseNotification: {
        purchaseToken: "gpa.token-voided-1",
        orderId: "GPA.3384-5512-9087-12345",
        productType: 1,
        refundType: 1,
      },
    })).toString("base64"),
  },
  subscription: "projects/studafy/subscriptions/play-billing-to-test-api",
};

describe("store webhook routes", () => {
  test("Play notifications are served at the documented push path", async () => {
    const { app, recorded } = routes(pubSubVerifier(true));
    const response = await app.request(PLAY_BILLING_PUSH_PATH, {
      method: "POST",
      headers: { authorization: "Bearer oidc-token" },
      body: JSON.stringify(voidedPush),
    });
    expect(response.status).toBe(200);
    // A voided purchase is recorded like any other RTDN; the worker decides.
    expect(recorded).toHaveLength(1);
    expect(recorded[0]?.[0]).toBe("play_store");
    expect(recorded[0]?.[2]).toBe("pubsub-message-1");
    expect(JSON.parse(recorded[0]![4])).toHaveProperty(
      "voidedPurchaseNotification.productType",
      1,
    );
  });

  test("a push without the configured OIDC identity is refused", async () => {
    const { app, recorded } = routes(pubSubVerifier(false));
    const response = await app.request(PLAY_BILLING_PUSH_PATH, {
      method: "POST",
      headers: { authorization: "Bearer oidc-token" },
      body: JSON.stringify(voidedPush),
    });
    expect(response.status).toBe(403);
    expect(recorded).toHaveLength(0);
  });

  test("both store paths are mounted and rate-limited as store webhooks", async () => {
    const { app } = routes(null);
    for (const path of [PLAY_BILLING_PUSH_PATH, APP_STORE_NOTIFICATIONS_PATH]) {
      const response = await app.request(path, { method: "POST" });
      expect(response.status).toBe(503);
      expect(flowFor("post", path).flow).toBe("storeWebhook");
    }
  });
});
