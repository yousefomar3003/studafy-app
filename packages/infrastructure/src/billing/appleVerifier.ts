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
  AutoRenewStatus,
  Environment as AppleLibraryEnvironment,
  type JWSTransactionDecodedPayload,
  RevocationReason,
  SignedDataVerifier,
} from "@apple/app-store-server-library";
import { STORE_API_TIMEOUT_MS, withDeadline } from "./deadline";

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
  /** App Store Server API `status` (1 active ... 5 revoked). Set only by a
   * status lookup; a bare signed transaction does not carry it. */
  subscriptionStatus?: number | null;
  /** From the signed renewal info, when one came with the transaction. */
  autoRenewing?: boolean | null;
  /** Epoch milliseconds; set while Apple's billing grace period is open. */
  gracePeriodExpiresDate?: number | null;
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
  /** Time limit per call (STORE_API_TIMEOUT_MS). Signed data is checked
   * online (certificate revocation), so decoding can wait on Apple too. */
  timeoutMs?: number;
}

export class RealAppleTransactionVerifier implements AppleTransactionVerifier {
  readonly #verifier: SignedDataVerifier;
  readonly #client: AppStoreServerAPIClient;
  readonly #environment: "Sandbox" | "Production";
  readonly #timeoutMs: number;

  constructor(config: AppleVerifierConfig) {
    this.#timeoutMs = config.timeoutMs ?? STORE_API_TIMEOUT_MS;
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
      const decoded = await withDeadline(
        this.#verifier.verifyAndDecodeTransaction(signedTransaction),
        this.#timeoutMs,
        "apple transaction check",
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
      const decoded = await withDeadline(
        this.#verifier.verifyAndDecodeNotification(signedPayload),
        this.#timeoutMs,
        "apple notification check",
      );
      const signedTransactionInfo = decoded.data?.signedTransactionInfo;
      const transaction = signedTransactionInfo
        ? {
          ...await this.verifyTransaction(signedTransactionInfo),
          ...await this.renewal(decoded.data?.signedRenewalInfo),
        }
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
      const statuses = await withDeadline(
        this.#client.getAllSubscriptionStatuses(originalTransactionId),
        this.#timeoutMs,
        "apple status lookup",
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
          .map(async (row): Promise<VerifiedAppleTransaction> => ({
            ...await this.verifyTransaction(row.signedTransactionInfo!),
            ...await this.renewal(row.signedRenewalInfo),
            subscriptionStatus: typeof row.status === "number"
              ? row.status
              : null,
          })),
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

  /** Auto-renew and grace end from Apple's signed renewal info. The same
   * chain verification applies as for transactions; an absent or
   * unverifiable renewal info leaves both unknown rather than guessed. */
  private async renewal(
    signedRenewalInfo: string | undefined,
  ): Promise<
    Pick<VerifiedAppleTransaction, "autoRenewing" | "gracePeriodExpiresDate">
  > {
    if (!signedRenewalInfo) return {};
    try {
      const info = await withDeadline(
        this.#verifier.verifyAndDecodeRenewalInfo(signedRenewalInfo),
        this.#timeoutMs,
        "apple renewal info check",
      );
      return {
        autoRenewing: info.autoRenewStatus === undefined
          ? null
          : info.autoRenewStatus === AutoRenewStatus.ON,
        gracePeriodExpiresDate: info.gracePeriodExpiresDate ?? null,
      };
    } catch {
      return {};
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
