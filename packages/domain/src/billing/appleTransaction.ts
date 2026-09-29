/**
 * Pure Apple App Store Server Notifications V2 policy. JWS signature
 * verification against Apple's root CAs happens in apps/api (it needs the
 * `@apple/app-store-server-library` and its certificate bundle, which are I/O/SDK
 * concerns); this module only maps an already-decoded, already-verified
 * payload to Studafy's ledger vocabulary, and checks the fraud-prevention
 * invariants §13 requires: a sandbox transaction must never be accepted as a
 * production one, and a transaction for a different app must never be
 * accepted at all.
 */

export type StoreTransactionState =
  | "pending"
  | "active"
  | "grace_period"
  | "on_hold"
  | "refunded"
  | "revoked"
  | "expired";

/** The seven notification types §13/§20 name explicitly. Apple sends others
 * (DID_CHANGE_RENEWAL_STATUS, PRICE_INCREASE, ...); an unmapped type or
 * subtype returns `null` so the caller can safely no-op rather than guess. */
export type AppleNotificationType =
  | "SUBSCRIBED"
  | "DID_RENEW"
  | "DID_FAIL_TO_RENEW"
  | "EXPIRED"
  | "REFUND"
  | "REVOKE"
  | "GRACE_PERIOD_EXPIRED";

export function mapAppleNotificationToTransactionState(
  notificationType: string,
  subtype?: string | null,
): StoreTransactionState | null {
  switch (notificationType as AppleNotificationType) {
    case "SUBSCRIBED":
    case "DID_RENEW":
      return "active";
    case "DID_FAIL_TO_RENEW":
      // Apple sets subtype GRACE_PERIOD while the grace window is open;
      // without it, the subscription is already in billing retry with no
      // access.
      return subtype === "GRACE_PERIOD" ? "grace_period" : "on_hold";
    case "EXPIRED":
    case "GRACE_PERIOD_EXPIRED":
      return "expired";
    case "REFUND":
      return "refunded";
    case "REVOKE":
      return "revoked";
    default:
      return null;
  }
}

/** Apple's `JWSTransactionDecodedPayload.type` for a currently active state. */
export function mapAppleTransactionTypeToState(
  _ownershipType: string | null | undefined,
  revocationReason: number | null | undefined,
  expiresDate: number | null | undefined,
  nowMillis: number,
): StoreTransactionState {
  if (revocationReason !== null && revocationReason !== undefined) {
    return "revoked";
  }
  if (typeof expiresDate === "number" && expiresDate <= nowMillis) {
    return "expired";
  }
  return "active";
}

/**
 * What the subscriber has set up for the next billing period, shown in the
 * app beside the access date. It never decides access: `state` and the
 * effective-until date do.
 *
 * - `renewing` - it will renew on the date shown;
 * - `cancelled` - auto-renew is off; access lasts until the date shown;
 * - `paused` - Google Play pause; access resumes on its own later;
 * - `payment_issue` - the store could not charge and is retrying.
 */
export type RenewalStatus =
  | "renewing"
  | "cancelled"
  | "paused"
  | "payment_issue";

/** App Store Server API `status` (Get All Subscription Statuses). */
export const APPLE_SUBSCRIPTION_STATUS = {
  active: 1,
  expired: 2,
  billingRetry: 3,
  billingGracePeriod: 4,
  revoked: 5,
} as const;

/**
 * The ledger state and access end for an Apple subscription.
 *
 * Apple's own `status` wins when the status lookup returned one. The
 * transaction's expiry alone cannot tell a billing grace period (access
 * continues until `gracePeriodExpiresDate`) from a lapse, so without the
 * status a grace-period or billing-retry notification signal is honoured.
 * A revocation and a refund/revoke notification always remove access.
 */
export function resolveAppleSubscriptionState(input: {
  subscriptionStatus?: number | null;
  revocationReason?: number | null;
  expiresDate?: number | null;
  gracePeriodExpiresDate?: number | null;
  notificationSignal?: StoreTransactionState | null;
  nowMillis: number;
}): { state: StoreTransactionState; effectiveUntil: number | null } {
  const expires = input.expiresDate ?? null;
  const graceEnd = input.gracePeriodExpiresDate ?? expires;
  if (input.revocationReason !== null && input.revocationReason !== undefined) {
    return { state: "revoked", effectiveUntil: expires };
  }
  if (
    input.notificationSignal === "refunded" ||
    input.notificationSignal === "revoked"
  ) {
    return { state: input.notificationSignal, effectiveUntil: expires };
  }
  switch (input.subscriptionStatus) {
    case APPLE_SUBSCRIPTION_STATUS.active:
      return { state: "active", effectiveUntil: expires };
    case APPLE_SUBSCRIPTION_STATUS.expired:
      return { state: "expired", effectiveUntil: expires };
    case APPLE_SUBSCRIPTION_STATUS.billingRetry:
      return { state: "on_hold", effectiveUntil: expires };
    case APPLE_SUBSCRIPTION_STATUS.billingGracePeriod:
      return { state: "grace_period", effectiveUntil: graceEnd };
    case APPLE_SUBSCRIPTION_STATUS.revoked:
      return { state: "revoked", effectiveUntil: expires };
  }
  if (input.notificationSignal === "grace_period") {
    return { state: "grace_period", effectiveUntil: graceEnd };
  }
  if (input.notificationSignal === "on_hold") {
    return { state: "on_hold", effectiveUntil: expires };
  }
  return {
    state: mapAppleTransactionTypeToState(
      null,
      input.revocationReason,
      expires,
      input.nowMillis,
    ),
    effectiveUntil: expires,
  };
}

/** Renewal status from Apple's status and the renewal info's auto-renew flag. */
export function appleRenewalStatus(
  subscriptionStatus: number | null | undefined,
  autoRenewing: boolean | null | undefined,
): RenewalStatus | null {
  if (
    subscriptionStatus === APPLE_SUBSCRIPTION_STATUS.billingRetry ||
    subscriptionStatus === APPLE_SUBSCRIPTION_STATUS.billingGracePeriod
  ) {
    return "payment_issue";
  }
  if (autoRenewing === false) return "cancelled";
  if (autoRenewing === true) return "renewing";
  return null;
}

/**
 * Bundle id and environment must both match exactly, or the transaction is
 * rejected outright - a sandbox receipt must never grant production access,
 * and a transaction for a different app must never be trusted at all.
 */
export function isAppleTransactionTrusted(input: {
  bundleId: string;
  expectedBundleId: string;
  environment: "Sandbox" | "Production" | string;
  expectedEnvironment: "Sandbox" | "Production";
}): boolean {
  return input.bundleId === input.expectedBundleId &&
    input.environment === input.expectedEnvironment;
}
