import { describe, expect, test } from "bun:test";
import {
  appleRenewalStatus,
  googleRenewalStatus,
  isAppleTransactionTrusted,
  isGooglePackageNameTrusted,
  mapAppleNotificationToTransactionState,
  mapAppleTransactionTypeToState,
  mapGoogleSubscriptionStateToTransactionState,
  resolveAppleSubscriptionState,
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

describe("resolveAppleSubscriptionState", () => {
  const now = Date.UTC(2026, 8, 29);
  const past = now - 86_400_000;
  const future = now + 86_400_000;
  const graceEnd = now + 6 * 86_400_000;

  test("a billing grace period keeps access until the grace end", () => {
    // The renewal failed, so the transaction's own expiry is already past.
    expect(
      resolveAppleSubscriptionState({
        subscriptionStatus: 4,
        expiresDate: past,
        gracePeriodExpiresDate: graceEnd,
        nowMillis: now,
      }),
    ).toEqual({ state: "grace_period", effectiveUntil: graceEnd });
  });

  test("billing retry without grace removes access", () => {
    expect(
      resolveAppleSubscriptionState({
        subscriptionStatus: 3,
        expiresDate: past,
        nowMillis: now,
      }).state,
    ).toBe("on_hold");
  });

  test("the grace notification signal is honoured when status is unknown", () => {
    expect(
      resolveAppleSubscriptionState({
        expiresDate: past,
        gracePeriodExpiresDate: graceEnd,
        notificationSignal: "grace_period",
        nowMillis: now,
      }),
    ).toEqual({ state: "grace_period", effectiveUntil: graceEnd });
  });

  test("a refund notification wins over an active status", () => {
    expect(
      resolveAppleSubscriptionState({
        subscriptionStatus: 1,
        expiresDate: future,
        notificationSignal: "refunded",
        nowMillis: now,
      }).state,
    ).toBe("refunded");
  });

  test("a revocation reason always revokes", () => {
    expect(
      resolveAppleSubscriptionState({
        subscriptionStatus: 1,
        revocationReason: 0,
        expiresDate: future,
        nowMillis: now,
      }).state,
    ).toBe("revoked");
  });

  test("without status or signal the expiry decides", () => {
    expect(
      resolveAppleSubscriptionState({ expiresDate: future, nowMillis: now })
        .state,
    ).toBe("active");
    expect(
      resolveAppleSubscriptionState({ expiresDate: past, nowMillis: now })
        .state,
    ).toBe("expired");
  });
});

describe("renewal status", () => {
  test("Apple: billing retry and grace are payment issues", () => {
    expect(appleRenewalStatus(3, true)).toBe("payment_issue");
    expect(appleRenewalStatus(4, true)).toBe("payment_issue");
  });

  test("Apple: auto-renew off is cancelled, on is renewing", () => {
    expect(appleRenewalStatus(1, false)).toBe("cancelled");
    expect(appleRenewalStatus(1, true)).toBe("renewing");
    expect(appleRenewalStatus(null, null)).toBeNull();
  });

  test("Google: pause, payment problems and cancellation", () => {
    expect(googleRenewalStatus("SUBSCRIPTION_STATE_PAUSED", true)).toBe(
      "paused",
    );
    expect(googleRenewalStatus("SUBSCRIPTION_STATE_ON_HOLD", true)).toBe(
      "payment_issue",
    );
    expect(googleRenewalStatus("SUBSCRIPTION_STATE_IN_GRACE_PERIOD", true))
      .toBe("payment_issue");
    expect(googleRenewalStatus("SUBSCRIPTION_STATE_CANCELED", false)).toBe(
      "cancelled",
    );
    expect(googleRenewalStatus("SUBSCRIPTION_STATE_ACTIVE", false)).toBe(
      "cancelled",
    );
    expect(googleRenewalStatus("SUBSCRIPTION_STATE_ACTIVE", true)).toBe(
      "renewing",
    );
    expect(googleRenewalStatus("SUBSCRIPTION_STATE_EXPIRED", false))
      .toBeNull();
  });
});
