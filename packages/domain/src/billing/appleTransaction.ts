/**
 * Pure Apple App Store Server Notifications V2 policy. JWS signature
 * verification against Apple's root CAs happens in apps/api (it needs the
 * `app-store-server-library` and its certificate bundle, which are I/O/SDK
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
  ownershipType: string | null | undefined,
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
