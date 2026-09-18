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

export class GoogleVerificationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GoogleVerificationError";
  }
}

export interface VerifiedGooglePurchase {
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
}

export class RealGooglePurchaseVerifier implements GooglePurchaseVerifier {
  readonly #auth: GoogleAuth;
  readonly #oauth2 = new OAuth2Client();
  readonly #pubsubAudience: string;
  readonly #pubsubServiceAccountEmail: string;

  constructor(config: GoogleVerifierConfig) {
    let credentials: Record<string, unknown>;
    try {
      credentials = JSON.parse(config.serviceAccountJson);
    } catch {
      throw new GoogleVerificationError("service account JSON is not valid JSON");
    }
    this.#auth = new GoogleAuth({
      credentials,
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    this.#pubsubAudience = config.pubsubAudience;
    this.#pubsubServiceAccountEmail = config.pubsubServiceAccountEmail;
  }

  async verifySubscription(
    packageName: string,
    purchaseToken: string,
  ): Promise<VerifiedGooglePurchase> {
    try {
      const client = await this.#auth.getClient();
      const androidpublisher = google.androidpublisher({
        version: "v3",
        auth: client as never,
      });
      const response = await androidpublisher.purchases.subscriptionsv2.get({
        packageName,
        token: purchaseToken,
      });
      const data = response.data;
      const lineItem = data.lineItems?.[0];
      if (!data.subscriptionState || !lineItem?.productId) {
        throw new GoogleVerificationError("incomplete subscription response");
      }
      return {
        packageName,
        productId: lineItem.productId,
        purchaseToken,
        originalTransactionId: data.linkedPurchaseToken ?? purchaseToken,
        transactionId: purchaseToken,
        subscriptionState: data.subscriptionState,
        startTime: data.startTime ?? null,
        expiryTime: lineItem.expiryTime ?? null,
        acknowledgementState: data.acknowledgementState ?? "0",
      };
    } catch (error) {
      if (error instanceof GoogleVerificationError) throw error;
      throw new GoogleVerificationError(
        error instanceof Error ? error.message : "subscription verification failed",
      );
    }
  }

  async acknowledgeSubscription(
    packageName: string,
    purchaseToken: string,
  ): Promise<void> {
    try {
      const client = await this.#auth.getClient();
      const androidpublisher = google.androidpublisher({
        version: "v3",
        auth: client as never,
      });
      await androidpublisher.purchases.subscriptions.acknowledge({
        packageName,
        token: purchaseToken,
      });
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
      const ticket = await this.#oauth2.verifyIdToken({
        idToken,
        audience: this.#pubsubAudience,
      });
      const payload = ticket.getPayload();
      return payload?.email === this.#pubsubServiceAccountEmail &&
        payload?.email_verified === true;
    } catch {
      return false;
    }
  }
}