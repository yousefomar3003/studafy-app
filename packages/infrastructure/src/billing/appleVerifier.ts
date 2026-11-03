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
  readonly #appAppleId: number | undefined;

  constructor(config: AppleVerifierConfig) {
    this.#timeoutMs = config.timeoutMs ?? STORE_API_TIMEOUT_MS;
    this.#appAppleId = config.appAppleId;
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
      // Apple's library checks the app id in Production only, and Apple
      // leaves it out of Sandbox notifications. When one is there it must be
      // ours, in either environment (DL-080).
      const appAppleId = decoded.data?.appAppleId;
      if (
        this.#appAppleId !== undefined && appAppleId != null &&
        appAppleId !== this.#appAppleId
      ) {
        throw new AppleVerificationError("notification is for another app");
      }
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

/**
 * The verifiers a server holds for the App Store. A production server
 * (`PAY071_ENVIRONMENT=production`, `APPLE_ENVIRONMENT=Production`) also
 * holds a Sandbox verifier, because App Review, TestFlight and sandbox
 * testers always buy in Apple's Sandbox, even with the production build
 * (DL-080). Every other server holds only its own verifier.
 */
export interface AppleVerifierSet {
  verifier: AppleTransactionVerifier;
  /** Production servers only: verifies Apple's Sandbox signed data. */
  sandboxVerifier?: AppleTransactionVerifier | null;
}

/** The verifier chosen for one piece of signed data or one stored lineage. */
export interface ChosenAppleVerifier {
  verifier: AppleTransactionVerifier;
  /** True when a production server's Sandbox verifier was chosen. */
  sandbox: boolean;
}

/**
 * Builds a server's App Store verifiers. The Sandbox verifier uses the same
 * key, issuer, bundle id, app id and root certificates: Apple signs both
 * environments with the same chain, and one App Store Server API key works
 * against both.
 */
export function createAppleVerifiers(
  config: AppleVerifierConfig,
  serverEnvironment: string,
): {
  verifier: RealAppleTransactionVerifier;
  sandboxVerifier: RealAppleTransactionVerifier | null;
} {
  return {
    verifier: new RealAppleTransactionVerifier(config),
    sandboxVerifier:
      serverEnvironment === "production" && config.environment === "Production"
        ? new RealAppleTransactionVerifier({
          ...config,
          environment: "Sandbox",
        })
        : null,
  };
}

/**
 * Picks the verifier for an Apple environment: the Sandbox verifier when the
 * server has one and the environment is Sandbox, otherwise the server's own.
 * Choosing is not trusting: the chosen verifier checks the signature chain,
 * the bundle id and that the data's environment is its own, so data that
 * named the wrong environment is refused by the verifier it was sent to.
 */
export function chooseAppleVerifier(
  apple: AppleVerifierSet,
  environment: "Sandbox" | "Production" | null,
): ChosenAppleVerifier {
  if (environment === "Sandbox" && apple.sandboxVerifier) {
    return { verifier: apple.sandboxVerifier, sandbox: true };
  }
  return { verifier: apple.verifier, sandbox: false };
}

/** `chooseAppleVerifier` by the environment the signed data names. */
export function chooseAppleVerifierFor(
  apple: AppleVerifierSet,
  signedData: string,
): ChosenAppleVerifier {
  return chooseAppleVerifier(apple, peekAppleSignedEnvironment(signedData));
}

/**
 * The environment a compact JWS from Apple names, read WITHOUT verifying it:
 * only to choose the verifier that then verifies it in full. A transaction
 * or renewal info names it at the top level, a notification under `data`,
 * `summary` or `appData`. Anything else (unreadable data, Apple's Xcode or
 * local-testing environments) is null, and the server's own verifier is used.
 */
export function peekAppleSignedEnvironment(
  signedData: string,
): "Sandbox" | "Production" | null {
  const parts = signedData.trim().split(".");
  if (parts.length !== 3 || !parts[1]) return null;
  let payload: unknown;
  try {
    payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
  } catch {
    return null;
  }
  if (typeof payload !== "object" || payload === null) return null;
  const record = payload as Record<string, unknown>;
  const nested = (key: string): unknown => {
    const value = record[key];
    return typeof value === "object" && value !== null
      ? (value as Record<string, unknown>).environment
      : undefined;
  };
  const environment = record.environment ?? nested("data") ??
    nested("summary") ?? nested("appData");
  return environment === "Sandbox" || environment === "Production"
    ? environment
    : null;
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
