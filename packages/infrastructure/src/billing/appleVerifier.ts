/**
 * Apple App Store Server API / JWS verification. Wraps Apple's own
 * `@apple/app-store-server-library`, which verifies the JWS signature chain against
 * Apple's bundled root CAs and decodes the payload - hand-rolling X.509
 * chain validation here would be exactly the kind of security-critical crypto
 * code that's easy to get subtly wrong.
 *
 * Shared by apps/api (client submit/restore and webhook signature check) and
 * apps/worker (re-verification of authoritative state when a webhook event is
 * processed), so store-facing cryptographic verification lives in exactly one
 * place (PAY-071).
 */
import {
  AppStoreServerAPIClient,
  Environment as AppleLibraryEnvironment,
  type JWSTransactionDecodedPayload,
  RevocationReason,
  SignedDataVerifier,
} from "@apple/app-store-server-library";

export class AppleVerificationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AppleVerificationError";
  }
}

export interface VerifiedAppleTransaction {
  appAccountToken?: string | null;
  bundleId: string;
  environment: "Sandbox" | "Production";
  originalTransactionId: string;
  transactionId: string;
  productId: string;
  /** Epoch milliseconds. */
  purchaseDate: number;
  expiresDate: number | null;
  revocationReason: RevocationReason | null;
}

export interface VerifiedAppleNotification {
  notificationType: string;
  subtype: string | null;
  notificationUUID: string;
  transaction: VerifiedAppleTransaction | null;
}

export interface AppleTransactionVerifier {
  verifyTransaction(
    signedTransaction: string,
  ): Promise<VerifiedAppleTransaction>;
  verifyNotification(signedPayload: string): Promise<VerifiedAppleNotification>;
  /** Authoritative current status, used by the webhook processor rather than
   * trusting the notification's embedded transaction alone. */
  getSubscriptionStatus(
    originalTransactionId: string,
  ): Promise<VerifiedAppleTransaction | null>;
}

export interface AppleVerifierConfig {
  /** DER-encoded Apple root CA certificates. */
  rootCertificates: Buffer[];
  bundleId: string;
  environment: "Sandbox" | "Production";
  appAppleId?: number;
  /** App Store Server API credentials, for reconciliation/status lookups. */
  api: {
    signingKey: string;
    keyId: string;
    issuerId: string;
  };
}

export class RealAppleTransactionVerifier implements AppleTransactionVerifier {
  readonly #verifier: SignedDataVerifier;
  readonly #client: AppStoreServerAPIClient;
  readonly #environment: "Sandbox" | "Production";

  constructor(config: AppleVerifierConfig) {
    const libraryEnvironment = config.environment === "Production"
      ? AppleLibraryEnvironment.PRODUCTION
      : AppleLibraryEnvironment.SANDBOX;
    this.#environment = config.environment;
    this.#verifier = new SignedDataVerifier(
      config.rootCertificates,
      true,
      libraryEnvironment,
      config.bundleId,
      config.appAppleId,
    );
    this.#client = new AppStoreServerAPIClient(
      config.api.signingKey,
      config.api.keyId,
      config.api.issuerId,
      config.bundleId,
      libraryEnvironment,
    );
  }

  async verifyTransaction(
    signedTransaction: string,
  ): Promise<VerifiedAppleTransaction> {
    try {
      const decoded = await this.#verifier.verifyAndDecodeTransaction(
        signedTransaction,
      );
      return toVerifiedTransaction(decoded);
    } catch (error) {
      throw new AppleVerificationError(
        error instanceof Error
          ? error.message
          : "transaction verification failed",
      );
    }
  }

  async verifyNotification(
    signedPayload: string,
  ): Promise<VerifiedAppleNotification> {
    try {
      const decoded = await this.#verifier.verifyAndDecodeNotification(
        signedPayload,
      );
      const signedTransactionInfo = decoded.data?.signedTransactionInfo;
      const transaction = signedTransactionInfo
        ? await this.verifyTransaction(signedTransactionInfo)
        : null;
      return {
        notificationType: String(decoded.notificationType ?? ""),
        subtype: decoded.subtype ? String(decoded.subtype) : null,
        notificationUUID: decoded.notificationUUID ?? "",
        transaction,
      };
    } catch (error) {
      throw new AppleVerificationError(
        error instanceof Error
          ? error.message
          : "notification verification failed",
      );
    }
  }

  async getSubscriptionStatus(
    originalTransactionId: string,
  ): Promise<VerifiedAppleTransaction | null> {
    try {
      const statuses = await this.#client.getAllSubscriptionStatuses(
        originalTransactionId,
      );
      const lastTransactions = statuses.data?.flatMap((group) =>
        group.lastTransactions ?? []
      ) ?? [];
      const verified = await Promise.all(
        lastTransactions
          .filter((row) =>
            row.originalTransactionId === originalTransactionId &&
            row.signedTransactionInfo
          )
          .map((row) => this.verifyTransaction(row.signedTransactionInfo!)),
      );
      return verified.filter((row) =>
        row.originalTransactionId === originalTransactionId
      )
        .sort((a, b) => b.purchaseDate - a.purchaseDate)[0] ?? null;
    } catch (error) {
      throw new AppleVerificationError(
        error instanceof Error ? error.message : "status lookup failed",
      );
    }
  }

  get environment(): "Sandbox" | "Production" {
    return this.#environment;
  }
}

function toVerifiedTransaction(
  payload: JWSTransactionDecodedPayload,
): VerifiedAppleTransaction {
  if (
    !payload.bundleId || !payload.originalTransactionId ||
    !payload.transactionId || !payload.productId ||
    typeof payload.purchaseDate !== "number"
  ) {
    throw new AppleVerificationError(
      "decoded transaction missing required fields",
    );
  }
  return {
    appAccountToken: payload.appAccountToken ?? null,
    bundleId: payload.bundleId,
    environment: payload.environment === AppleLibraryEnvironment.PRODUCTION
      ? "Production"
      : "Sandbox",
    originalTransactionId: payload.originalTransactionId,
    transactionId: payload.transactionId,
    productId: payload.productId,
    purchaseDate: payload.purchaseDate,
    expiresDate: payload.expiresDate ?? null,
    revocationReason: payload.revocationReason ?? null,
  };
}
