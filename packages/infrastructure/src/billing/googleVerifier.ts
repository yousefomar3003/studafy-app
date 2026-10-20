/**
 * Google Play Developer API / Real-Time Developer Notification verification.
 * Wraps `googleapis`' androidpublisher client (service-account JWT auth via
 * `google-auth-library`) rather than hand-rolling OAuth2/JWT signing.
 *
 * Shared by apps/api (client submit/restore and the RTDN webhook signature
 * check) and apps/worker (re-verification of authoritative state when a
 * webhook event is processed, plus the scheduled acknowledgement sweep), so
 * store-facing verification lives in exactly one place (PAY-071).
 */
import { google } from "googleapis";
import { GoogleAuth, OAuth2Client } from "google-auth-library";
import { STORE_API_TIMEOUT_MS, withDeadline } from "./deadline";

export class GoogleVerificationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GoogleVerificationError";
  }
}

export interface VerifiedGooglePurchase {
  testPurchase?: boolean;
  obfuscatedExternalAccountId?: string | null;
  packageName: string;
  productId: string;
  purchaseToken: string;
  /** The chain root: `linkedPurchaseToken` when this token replaced an
   * earlier one (upgrade/downgrade/resubscribe), else the token itself. */
  originalTransactionId: string;
  transactionId: string;
  subscriptionState: string;
  startTime: string | null;
  expiryTime: string | null;
  acknowledgementState: string;
  /** `autoRenewingPlan.autoRenewEnabled`; null for a prepaid plan. */
  autoRenewEnabled?: boolean | null;
}

export interface GooglePurchaseVerifier {
  verifySubscription(
    packageName: string,
    purchaseToken: string,
  ): Promise<VerifiedGooglePurchase>;
  /** Google auto-refunds any purchase left unacknowledged for 3 days. */
  acknowledgeSubscription(
    packageName: string,
    purchaseToken: string,
  ): Promise<void>;
  /** Verifies a Pub/Sub push request's OIDC bearer token: signature, audience
   * and that the token belongs to the configured service account. */
  verifyPubSubToken(authorizationHeader: string | undefined): Promise<boolean>;
}

export interface GoogleVerifierConfig {
  /** Raw service account JSON content (never the file path). */
  serviceAccountJson: string;
  /** The Pub/Sub push endpoint's own URL - the expected OIDC audience. */
  pubsubAudience: string;
  /** The service account whose OIDC token Pub/Sub push must present. */
  pubsubServiceAccountEmail: string;
  /** Time limit per call, token fetch included (STORE_API_TIMEOUT_MS). */
  timeoutMs?: number;
}

export class RealGooglePurchaseVerifier implements GooglePurchaseVerifier {
  readonly #auth: GoogleAuth;
  readonly #oauth2 = new OAuth2Client();
  readonly #pubsubAudience: string;
  readonly #pubsubServiceAccountEmail: string;
  readonly #timeoutMs: number;

  constructor(config: GoogleVerifierConfig) {
    let credentials: Record<string, unknown>;
    try {
      credentials = JSON.parse(config.serviceAccountJson);
    } catch {
      throw new GoogleVerificationError(
        "service account JSON is not valid JSON",
      );
    }
    this.#auth = new GoogleAuth({
      credentials,
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    this.#pubsubAudience = config.pubsubAudience;
    this.#pubsubServiceAccountEmail = config.pubsubServiceAccountEmail;
    this.#timeoutMs = config.timeoutMs ?? STORE_API_TIMEOUT_MS;
  }

  /** The Play Developer API client; each request is time-limited too. */
  async #publisher() {
    const client = await this.#auth.getClient();
    return google.androidpublisher({
      version: "v3",
      auth: client as never,
      timeout: this.#timeoutMs,
    });
  }

  async verifySubscription(
    packageName: string,
    purchaseToken: string,
  ): Promise<VerifiedGooglePurchase> {
    try {
      const response = await withDeadline(
        this.#publisher().then((androidpublisher) =>
          androidpublisher.purchases.subscriptionsv2.get({
            packageName,
            token: purchaseToken,
          })
        ),
        this.#timeoutMs,
        "google subscription lookup",
      );
      const data = response.data;
      const lineItem = data.lineItems?.[0];
      if (!data.subscriptionState || !lineItem?.productId) {
        throw new GoogleVerificationError("incomplete subscription response");
      }
      return {
        testPurchase: data.testPurchase != null,
        obfuscatedExternalAccountId:
          data.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null,
        packageName,
        productId: lineItem.productId,
        purchaseToken,
        originalTransactionId: data.linkedPurchaseToken ?? purchaseToken,
        transactionId: purchaseToken,
        subscriptionState: data.subscriptionState,
        startTime: data.startTime ?? null,
        expiryTime: lineItem.expiryTime ?? null,
        acknowledgementState: data.acknowledgementState ?? "0",
        autoRenewEnabled: lineItem.autoRenewingPlan?.autoRenewEnabled ?? null,
      };
    } catch (error) {
      if (error instanceof GoogleVerificationError) throw error;
      throw new GoogleVerificationError(
        error instanceof Error
          ? error.message
          : "subscription verification failed",
      );
    }
  }

  async acknowledgeSubscription(
    packageName: string,
    purchaseToken: string,
  ): Promise<void> {
    try {
      await withDeadline(
        this.#publisher().then((androidpublisher) =>
          androidpublisher.purchases.subscriptions.acknowledge({
            packageName,
            token: purchaseToken,
          })
        ),
        this.#timeoutMs,
        "google acknowledge",
      );
    } catch (error) {
      throw new GoogleVerificationError(
        error instanceof Error ? error.message : "acknowledge failed",
      );
    }
  }

  async verifyPubSubToken(
    authorizationHeader: string | undefined,
  ): Promise<boolean> {
    if (!authorizationHeader?.startsWith("Bearer ")) return false;
    const idToken = authorizationHeader.slice("Bearer ".length);
    try {
      const ticket = await withDeadline(
        this.#oauth2.verifyIdToken({
          idToken,
          audience: this.#pubsubAudience,
        }),
        this.#timeoutMs,
        "google pubsub token check",
      );
      const payload = ticket.getPayload();
      return payload?.email === this.#pubsubServiceAccountEmail &&
        payload?.email_verified === true;
    } catch {
      return false;
    }
  }
}
