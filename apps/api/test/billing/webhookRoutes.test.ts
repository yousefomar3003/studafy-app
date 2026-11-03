import { describe, expect, test } from "bun:test";
import {
  APP_STORE_NOTIFICATIONS_PATH,
  PLAY_BILLING_PUSH_PATH,
} from "@studafy/config";
import {
  type AppleTransactionVerifier,
  AppleVerificationError,
  type AppleVerifierSet,
  type GooglePurchaseVerifier,
  peekAppleSignedEnvironment,
  type VerifiedAppleNotification,
} from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { createBillingWebhookRoutes } from "../../src/billing/webhookRoutes";
import type { BillingRepository } from "../../src/billing/repository";
import { flowFor } from "../../src/platform/rate-limit/policies";

type Recorded = [string, string, string | null, string, string];

function routes(
  google: GooglePurchaseVerifier | null,
  apple: AppleVerifierSet | null = null,
) {
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
    apple,
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

  test("DL-080: a Sandbox notification is verified by the Sandbox verifier in production", async () => {
    // Apple sends App Review and TestFlight notifications to the Sandbox
    // Server URL, which points at production after launch.
    const verified: string[] = [];
    const fake = (environment: "Sandbox" | "Production") =>
      ({
        verifyTransaction: () => Promise.reject(new Error("not used")),
        getSubscriptionStatus: () => Promise.reject(new Error("not used")),
        verifyNotification: (signed: string) => {
          verified.push(environment);
          if (peekAppleSignedEnvironment(signed) !== environment) {
            return Promise.reject(new AppleVerificationError("environment"));
          }
          return Promise.resolve(
            {
              notificationType: "TEST",
              subtype: null,
              notificationUUID: `uuid-${environment}`,
              transaction: null,
            } satisfies VerifiedAppleNotification,
          );
        },
      }) as AppleTransactionVerifier;
    const { app, recorded } = routes(null, {
      verifier: fake("Production"),
      sandboxVerifier: fake("Sandbox"),
    });
    const notification = (environment: string) =>
      `${Buffer.from('{"alg":"ES256"}').toString("base64url")}.${
        Buffer.from(JSON.stringify({ data: { environment } })).toString(
          "base64url",
        )
      }.signature`;
    for (const environment of ["Sandbox", "Production"]) {
      const response = await app.request(APP_STORE_NOTIFICATIONS_PATH, {
        method: "POST",
        body: JSON.stringify({ signedPayload: notification(environment) }),
      });
      expect(response.status).toBe(200);
    }
    expect(verified).toEqual(["Sandbox", "Production"]);
    // Both are recorded for the server's own environment; the worker
    // re-verifies each with the matching verifier.
    expect(recorded.map((row) => [row[0], row[1], row[2]])).toEqual([
      ["app_store", "production", "uuid-Sandbox"],
      ["app_store", "production", "uuid-Production"],
    ]);

    // Unreadable data goes to the Production verifier, which refuses it.
    const refused = await app.request(APP_STORE_NOTIFICATIONS_PATH, {
      method: "POST",
      body: JSON.stringify({ signedPayload: "signed.payload" }),
    });
    expect(refused.status).toBe(422);
    expect(verified.at(-1)).toBe("Production");
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
