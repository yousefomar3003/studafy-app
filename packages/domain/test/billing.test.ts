import { describe, expect, test } from "bun:test";
import {
  isAppleTransactionTrusted,
  isGooglePackageNameTrusted,
  issueParentalGateChallenge,
  mapAppleNotificationToTransactionState,
  mapAppleTransactionTypeToState,
  mapGoogleSubscriptionStateToTransactionState,
  verifyParentalGateAnswer,
} from "../src";

describe("mapAppleNotificationToTransactionState", () => {
  test("SUBSCRIBED and DID_RENEW grant active access", () => {
    expect(mapAppleNotificationToTransactionState("SUBSCRIBED")).toBe(
      "active",
    );
    expect(mapAppleNotificationToTransactionState("DID_RENEW")).toBe(
      "active",
    );
  });

  test("DID_FAIL_TO_RENEW with GRACE_PERIOD subtype keeps access", () => {
    expect(
      mapAppleNotificationToTransactionState(
        "DID_FAIL_TO_RENEW",
        "GRACE_PERIOD",
      ),
    ).toBe("grace_period");
  });

  test("DID_FAIL_TO_RENEW without grace removes access", () => {
    expect(mapAppleNotificationToTransactionState("DID_FAIL_TO_RENEW")).toBe(
      "on_hold",
    );
  });

  test("EXPIRED and GRACE_PERIOD_EXPIRED both expire the transaction", () => {
    expect(mapAppleNotificationToTransactionState("EXPIRED")).toBe("expired");
    expect(mapAppleNotificationToTransactionState("GRACE_PERIOD_EXPIRED"))
      .toBe("expired");
  });

  test("REFUND and REVOKE remove access distinctly", () => {
    expect(mapAppleNotificationToTransactionState("REFUND")).toBe("refunded");
    expect(mapAppleNotificationToTransactionState("REVOKE")).toBe("revoked");
  });

  test("an unmodeled notification type maps to null, never a guess", () => {
    expect(mapAppleNotificationToTransactionState("PRICE_INCREASE")).toBeNull();
    expect(mapAppleNotificationToTransactionState("DID_CHANGE_RENEWAL_STATUS"))
      .toBeNull();
  });
});

describe("mapAppleTransactionTypeToState", () => {
  const now = Date.UTC(2026, 8, 18);

  test("a revoked transaction is revoked regardless of expiry", () => {
    expect(mapAppleTransactionTypeToState(null, 1, now + 100_000, now)).toBe(
      "revoked",
    );
  });

  test("an unexpired, unrevoked transaction is active", () => {
    expect(mapAppleTransactionTypeToState(null, null, now + 100_000, now))
      .toBe("active");
  });

  test("a past expiry with no revocation is expired", () => {
    expect(mapAppleTransactionTypeToState(null, null, now - 1, now)).toBe(
      "expired",
    );
  });
});

describe("isAppleTransactionTrusted", () => {
  test("matching bundle id and environment is trusted", () => {
    expect(
      isAppleTransactionTrusted({
        bundleId: "io.studafy.app",
        expectedBundleId: "io.studafy.app",
        environment: "Production",
        expectedEnvironment: "Production",
      }),
    ).toBe(true);
  });

  test("a sandbox transaction is never trusted as production", () => {
    expect(
      isAppleTransactionTrusted({
        bundleId: "io.studafy.app",
        expectedBundleId: "io.studafy.app",
        environment: "Sandbox",
        expectedEnvironment: "Production",
      }),
    ).toBe(false);
  });

  test("a transaction for a different bundle id is never trusted", () => {
    expect(
      isAppleTransactionTrusted({
        bundleId: "com.attacker.app",
        expectedBundleId: "io.studafy.app",
        environment: "Production",
        expectedEnvironment: "Production",
      }),
    ).toBe(false);
  });
});

describe("mapGoogleSubscriptionStateToTransactionState", () => {
  test("active and cancelled both retain access", () => {
    expect(
      mapGoogleSubscriptionStateToTransactionState("SUBSCRIPTION_STATE_ACTIVE"),
    ).toBe("active");
    expect(
      mapGoogleSubscriptionStateToTransactionState(
        "SUBSCRIPTION_STATE_CANCELED",
      ),
    ).toBe("active");
  });

  test("grace period, hold and paused map distinctly", () => {
    expect(
      mapGoogleSubscriptionStateToTransactionState(
        "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
      ),
    ).toBe("grace_period");
    expect(
      mapGoogleSubscriptionStateToTransactionState(
        "SUBSCRIPTION_STATE_ON_HOLD",
      ),
    ).toBe("on_hold");
    expect(
      mapGoogleSubscriptionStateToTransactionState("SUBSCRIPTION_STATE_PAUSED"),
    ).toBe("on_hold");
  });

  test("pending grants no access yet, expired removes it", () => {
    expect(
      mapGoogleSubscriptionStateToTransactionState(
        "SUBSCRIPTION_STATE_PENDING",
      ),
    ).toBe("pending");
    expect(
      mapGoogleSubscriptionStateToTransactionState(
        "SUBSCRIPTION_STATE_EXPIRED",
      ),
    ).toBe("expired");
  });

  test("an unmodeled state maps to null, never a guess", () => {
    expect(mapGoogleSubscriptionStateToTransactionState("SOMETHING_NEW"))
      .toBeNull();
  });
});

describe("isGooglePackageNameTrusted", () => {
  test("matching package name is trusted", () => {
    expect(isGooglePackageNameTrusted("io.studafy.app", "io.studafy.app"))
      .toBe(true);
  });

  test("a different package name is never trusted", () => {
    expect(isGooglePackageNameTrusted("com.attacker.app", "io.studafy.app"))
      .toBe(false);
  });
});

describe("parental gate", () => {
  const key = "pay071-parental-gate-test-key-0000000000000000";

  test("the correct answer verifies", async () => {
    const challenge = await issueParentalGateChallenge(key, 1_000);
    const match = /(\d+) . (\d+)/.exec(challenge.question);
    const a = Number(match![1]);
    const b = Number(match![2]);
    expect(
      await verifyParentalGateAnswer(challenge.token, a * b, key, 1_010),
    ).toBe(true);
  });

  test("a client that never requests a challenge cannot fabricate a token", async () => {
    expect(await verifyParentalGateAnswer("not-a-real-token", 42, key, 1_000))
      .toBe(false);
  });

  test("the wrong answer is rejected", async () => {
    const challenge = await issueParentalGateChallenge(key, 1_000);
    expect(
      await verifyParentalGateAnswer(challenge.token, -1, key, 1_010),
    ).toBe(false);
  });

  test("an expired challenge is rejected even with the right answer", async () => {
    const challenge = await issueParentalGateChallenge(key, 1_000);
    const match = /(\d+) . (\d+)/.exec(challenge.question);
    const a = Number(match![1]);
    const b = Number(match![2]);
    expect(
      await verifyParentalGateAnswer(challenge.token, a * b, key, 1_000 + 121),
    ).toBe(false);
  });

  test("a token signed with a different key is rejected", async () => {
    const challenge = await issueParentalGateChallenge(key, 1_000);
    const match = /(\d+) . (\d+)/.exec(challenge.question);
    const a = Number(match![1]);
    const b = Number(match![2]);
    expect(
      await verifyParentalGateAnswer(
        challenge.token,
        a * b,
        "a-completely-different-key-value",
        1_010,
      ),
    ).toBe(false);
  });

  test("a tampered token body is rejected", async () => {
    const challenge = await issueParentalGateChallenge(key, 1_000);
    const [, signature] = challenge.token.split(".");
    const tampered = `${
      Buffer.from(JSON.stringify({ a: 9, b: 9, exp: 999_999 })).toString(
        "base64url",
      )
    }.${signature}`;
    expect(await verifyParentalGateAnswer(tampered, 81, key, 1_010)).toBe(
      false,
    );
  });
});
