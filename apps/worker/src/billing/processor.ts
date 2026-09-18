/**
 * PAY-071 billing-events processor (§10 queue table, attempts 8). Runs
 * at-least-once; effects are exactly-once because the ledger transition
 * (`private.billing_finish_event`) is an idempotent SECURITY DEFINER write
 * keyed on the store event id and the known original transaction.
 *
 * A job carries opaque identifiers only. The processor derives the store
 * event id from the deterministic job id, re-fetches the raw provider
 * payload from `private.billing_event_payload` (scoped to a `processing`
 * event), re-verifies authoritative state against the official provider API,
 * and only then calls `billing_finish_event`. Neither the webhook payload
 * nor the BullMQ job body is ever trusted for state or identity; a sandbox
 * event can never move a production ledger row because every normalized
 * body is scoped by the event's own `environment` and the verifier's
 * bundle/package + Apple environment trust checks.
 *
 * Outcomes:
 * - `completed` — the ledger write + entitlement derivation committed, the
 *   event is completed;
 * - `terminal` — the event was already dead-lettered; return quietly;
 * - `retry` — the original transaction is not on file yet (a webhook can
 *   legitimately race the client's submit); throw so BullMQ retries with
 *   backoff, and the reconciliation sweep is the backstop;
 * - `lost` — the processing lease disappeared; throw to retry.
 *
 * A failed attempt at the final attempt dead-letters the event through
 * `private.billing_fail_event` (the Postgres DLQ), never by throwing into a
 * forever-retry.
 */
import { BillingEventsJobV1 } from "@studafy/contracts";
import {
  isAppleTransactionTrusted,
  isGooglePackageNameTrusted,
  mapAppleNotificationToTransactionState,
  mapAppleTransactionTypeToState,
  mapGoogleSubscriptionStateToTransactionState,
} from "@studafy/domain";
import type {
  AppleTransactionVerifier,
  GooglePurchaseVerifier,
} from "@studafy/infrastructure";
import type { Logger } from "@studafy/observability";
import { type Processor, UnrecoverableError } from "bullmq";
import { isFinalAttempt, normalizedErrorCode } from "../platform/jobGuards";
import {
  billingEventIdFromJobId,
  type BillingDispatchPort,
  type BillingEventPayload,
} from "./billingDispatch";

/** Store-facing verifiers the processor can re-verify webhook events with. */
export interface BillingVerifierDependencies {
  environment: string;
  apple: {
    verifier: AppleTransactionVerifier;
    bundleId: string;
    platformEnvironment: "Sandbox" | "Production";
  } | null;
  google: { verifier: GooglePurchaseVerifier; packageName: string } | null;
}

/** The normalized ledger body `private.billing_finish_event` accepts. */
interface FinishBody {
  platform: "app_store" | "play_store";
  environment: string;
  originalTransactionId?: string;
  purchasedAt?: string;
  effectiveUntil?: string | null;
  state?: string;
  acknowledged?: boolean;
  noop?: boolean;
}

export function createBillingEventProcessor(
  dispatch: BillingDispatchPort,
  verifiers: BillingVerifierDependencies,
  logger: Logger,
): Processor {
  return async (job) => {
    const parsed = BillingEventsJobV1.safeParse(job.data);
    if (!parsed.success) {
      logger.warn("billing_job_invalid_payload", {
        queue: "billing-events",
        job_id: job.id,
        attempts_made: job.attemptsMade,
      });
      throw new UnrecoverableError(
        "billing job payload does not match the v1 contract",
      );
    }
    const eventId = billingEventIdFromJobId(job.id ?? "");
    if (eventId == null) {
      logger.warn("billing_job_unknown_event", {
        queue: "billing-events",
        job_id: job.id,
      });
      throw new UnrecoverableError(
        "billing job id does not match the deterministic event contract",
      );
    }

    const payload = await dispatch.eventPayload(eventId);
    if (!payload) {
      // The event is no longer being processed (claim lost/concurrent run):
      // a retry re-reads it; after the final attempt it dead-letters.
      throw new Error("billing event claim lost");
    }

    let body: FinishBody | null;
    try {
      body = await reverify(payload, verifiers);
    } catch (error) {
      const code = normalizedErrorCode(error);
      if (isFinalAttempt(job)) {
        await dispatch.failDispatch(eventId, code).catch(() => undefined);
        logger.error("billing_job_exhausted", {
          queue: "billing-events",
          job_id: job.id,
          event_id: eventId,
          error_code: code,
        });
        throw new UnrecoverableError(code);
      }
      logger.warn("billing_job_retry", {
        queue: "billing-events",
        job_id: job.id,
        event_id: eventId,
        attempt: job.attemptsMade + 1,
        error_code: code,
      });
      throw error;
    }

    const outcome = await dispatch.finishEvent(eventId, body as never);
    if (outcome === "completed") {
      logger.info("billing_job_completed", {
        queue: "billing-events",
        job_id: job.id,
        event_id: eventId,
        platform: payload.platform,
        attempt: job.attemptsMade + 1,
      });
      return { ok: true };
    }
    if (outcome === "terminal") {
      logger.warn("billing_job_terminal", {
        queue: "billing-events",
        job_id: job.id,
        event_id: eventId,
      });
      return { ok: true, deadLetter: true };
    }
    if (outcome === "retry") {
      logger.info("billing_job_retry_unknown_transaction", {
        queue: "billing-events",
        job_id: job.id,
        event_id: eventId,
      });
      throw new Error("billing original transaction unknown");
    }
    throw new Error("billing event claim lost");
  };
}

/**
 * Re-verifies a recorded provider event against the official store API and
 * normalizes it for the ledger. Returns `null` on a genuinely ignorable
 * notification (no transaction / no lifecycle state) so the caller can finish
 * the event without a ledger change; throws on anything that must not be
 * recorded as processed.
 */
export async function reverify(
  payload: BillingEventPayload,
  verifiers: BillingVerifierDependencies,
): Promise<FinishBody | null> {
  const environment = payload.environment || verifiers.environment;
  if (payload.platform === "app_store") {
    const body = await reverifyApple(payload.rawPayload, verifiers.apple, environment);
    return body ?? { platform: "app_store", environment, noop: true };
  }
  if (payload.platform === "play_store") {
    const body = await reverifyGoogle(payload.rawPayload, verifiers.google, environment);
    return body ?? { platform: "play_store", environment, noop: true };
  }
  return { platform: payload.platform as never, environment, noop: true };
}

async function reverifyApple(
  rawPayload: string | null,
  apple: BillingVerifierDependencies["apple"],
  environment: string,
): Promise<FinishBody | null> {
  if (!apple) throw new AppleVerificationErrorShim("apple verifier not configured");
  if (!rawPayload) throw new AppleVerificationErrorShim("billing payload is empty");
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawPayload);
  } catch {
    throw new AppleVerificationErrorShim("billing payload is not valid JSON");
  }
  if (typeof parsed !== "object" || parsed === null) {
    throw new AppleVerificationErrorShim("billing payload is not an object");
  }
  const signedPayload = (parsed as Record<string, unknown>).signedPayload;
  if (typeof signedPayload !== "string" || !signedPayload) {
    throw new AppleVerificationErrorShim("billing payload missing signedPayload");
  }
  const notification = await apple.verifier.verifyNotification(signedPayload);
  const transaction = notification.transaction;
  if (!transaction) return null; // no embedded transaction: nothing to derive.

  if (
    !isAppleTransactionTrusted({
      bundleId: transaction.bundleId,
      expectedBundleId: apple.bundleId,
      environment: transaction.environment,
      expectedEnvironment: apple.platformEnvironment,
    })
  ) {
    // A sandbox receipt must never move a production ledger row (and an
    // event for another app never moves ours).
    throw new AppleVerificationErrorShim("notification fails bundle/environment trust");
  }

  const signal = mapAppleNotificationToTransactionState(
    notification.notificationType,
    notification.subtype,
  );
  if (signal === null) {
    // Renewal-preference / consumption / price notifications: no lifecycle
    // change, even though they carry a signed transaction.
    return null;
  }

  // Authoritative status: re-verify through the App Store Server API instead
  // of trusting the embedded transaction alone. If the store is unreachable
  // the signed embedded transaction (still Apple-signed) is the fallback, so
  // a transient Apple outage does not dead-letter the event.
  let authoritative = transaction;
  try {
    const status = await apple.verifier.getSubscriptionStatus(
      transaction.originalTransactionId,
    );
    if (
      status &&
      isAppleTransactionTrusted({
        bundleId: status.bundleId,
        expectedBundleId: apple.bundleId,
        environment: status.environment,
        expectedEnvironment: apple.platformEnvironment,
      })
    ) {
      authoritative = status;
    }
  } catch {
    // Store outage: fall back to the embedded signed transaction.
  }

  let state = mapAppleTransactionTypeToState(
    null,
    authoritative.revocationReason,
    authoritative.expiresDate,
    Date.now(),
  );
  // REFUND and REVOKE are direct lifecycle signals carried in the signed
  // notification itself; a refund/revoke must remove access even if the
  // status lookup still shows an overlapping newer transaction.
  if (notification.notificationType === "REFUND") state = "refunded";
  else if (notification.notificationType === "REVOKE") state = "revoked";

  return {
    platform: "app_store",
    environment,
    originalTransactionId: authoritative.originalTransactionId,
    purchasedAt: new Date(authoritative.purchaseDate).toISOString(),
    effectiveUntil: authoritative.expiresDate
      ? new Date(authoritative.expiresDate).toISOString()
      : null,
    state,
    acknowledged: false,
  };
}

async function reverifyGoogle(
  rawPayload: string | null,
  google: BillingVerifierDependencies["google"],
  environment: string,
): Promise<FinishBody | null> {
  if (!google) throw new GoogleVerificationErrorShim("google verifier not configured");
  if (!rawPayload) throw new GoogleVerificationErrorShim("billing payload is empty");
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawPayload);
  } catch {
    throw new GoogleVerificationErrorShim("billing payload is not valid JSON");
  }
  if (typeof parsed !== "object" || parsed === null) {
    throw new GoogleVerificationErrorShim("billing payload is not an object");
  }
  const record = parsed as Record<string, unknown>;
  if (record.testNotification || record.oneTimeProductNotification) {
    // Console test message or one-time product event: nothing to derive.
    return null;
  }
  const sub = record.subscriptionNotification;
  if (typeof sub !== "object" || sub === null) {
    throw new GoogleVerificationErrorShim("billing payload is not a subscription notification");
  }
  const purchaseToken = (sub as Record<string, unknown>).purchaseToken;
  if (typeof purchaseToken !== "string" || !purchaseToken) {
    throw new GoogleVerificationErrorShim("subscription notification missing purchaseToken");
  }

  const verified = await google.verifier.verifySubscription(
    google.packageName,
    purchaseToken,
  );
  if (!isGooglePackageNameTrusted(verified.packageName, google.packageName)) {
    throw new GoogleVerificationErrorShim("package name mismatch");
  }
  const state =
    mapGoogleSubscriptionStateToTransactionState(verified.subscriptionState) ??
    "on_hold";

  let acknowledged = verified.acknowledgementState === "2";
  if (
    !acknowledged &&
    verified.subscriptionState !== "SUBSCRIPTION_STATE_EXPIRED"
  ) {
    // Google auto-refunds any purchase left unacknowledged for 3 days. Ack
    // here on the authoritative state; a failure is not fatal to the ledger
    // write (the reconciliation sweep retries within the refund window).
    try {
      await google.verifier.acknowledgeSubscription(
        google.packageName,
        purchaseToken,
      );
      acknowledged = true;
    } catch {
      // Sweep backstop.
    }
  }

  return {
    platform: "play_store",
    environment,
    originalTransactionId: verified.originalTransactionId,
    purchasedAt: verified.startTime ?? new Date().toISOString(),
    effectiveUntil: verified.expiryTime,
    state,
    acknowledged,
  };
}

/** Bounded error codes without importing SDK error classes here. */
class AppleVerificationErrorShim extends Error {
  name = "AppleVerificationError";
}
class GoogleVerificationErrorShim extends Error {
  name = "GoogleVerificationError";
}