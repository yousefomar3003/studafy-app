/**
 * Pure Google Play Developer API / RTDN policy. Calling
 * `purchases.subscriptionsv2.get` and verifying the Pub/Sub push OIDC token
 * both happen in apps/api (I/O/SDK concerns); this module maps an
 * already-verified `SubscriptionPurchaseV2` to Studafy's ledger vocabulary
 * and checks the package-name fraud-prevention invariant.
 */
import type { StoreTransactionState } from "./appleTransaction";

/** Google's `subscriptionState` on `SubscriptionPurchaseV2`. */
export type GoogleSubscriptionState =
  | "SUBSCRIPTION_STATE_PENDING"
  | "SUBSCRIPTION_STATE_ACTIVE"
  | "SUBSCRIPTION_STATE_CANCELED"
  | "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
  | "SUBSCRIPTION_STATE_ON_HOLD"
  | "SUBSCRIPTION_STATE_PAUSED"
  | "SUBSCRIPTION_STATE_EXPIRED";

export function mapGoogleSubscriptionStateToTransactionState(
  state: string,
): StoreTransactionState | null {
  switch (state as GoogleSubscriptionState) {
    case "SUBSCRIPTION_STATE_PENDING":
      return "pending";
    case "SUBSCRIPTION_STATE_ACTIVE":
    // Cancelled retains access until the verified expiry, per §13; the
    // expiry date (not this state) is what eventually moves it to expired.
    case "SUBSCRIPTION_STATE_CANCELED":
      return "active";
    case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
      return "grace_period";
    case "SUBSCRIPTION_STATE_ON_HOLD":
    case "SUBSCRIPTION_STATE_PAUSED":
      return "on_hold";
    case "SUBSCRIPTION_STATE_EXPIRED":
      return "expired";
    default:
      return null;
  }
}

export function isGooglePackageNameTrusted(
  received: string,
  expected: string,
): boolean {
  return received === expected;
}
