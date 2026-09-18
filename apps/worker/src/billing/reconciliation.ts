/**
 * PAY-071 reconciliation sweep. Stores do not guarantee the delivery of every
 * lifecycle change (Apple notifications via APNs, Google RTDN) and a lost
 * webhook must never strand an entitlement or leave a purchase
 * unacknowledged. This poll re-reads open transactions with
 * `private.billing_reconciliation_scan`, re-verifies state against the
 * official store API, and converges the ledger through
 * `private.billing_reconcile_transaction` (no new event row; the row's own
 * event is re-run).
 *
 * It is also the ack backstop: Google auto-refunds any purchase not
 * acknowledged within 3 days, so a purchase missed by the processor ack is
 * re-acknowledged here using the row's stored `transaction_id` (the Play
 * purchase token).
 */
import type { Logger } from "@studafy/observability";
import {
  isAppleTransactionTrusted,
  isGooglePackageNameTrusted,
  mapAppleTransactionTypeToState,
  mapGoogleSubscriptionStateToTransactionState,
} from "@studafy/domain";
import { normalizedErrorCode } from "../platform/jobGuards";
import {
  type BillingDispatchPort,
  type ReconciliationCandidate,
} from "./billingDispatch";
import { type BillingVerifierDependencies } from "./processor";

export interface BillingReconciliationRuntime {
  close(): Promise<void>;
  runOnce(): Promise<number>;
}

export function startBillingReconciliation(
  dispatch: BillingDispatchPort,
  verifiers: BillingVerifierDependencies,
  logger: Logger,
  intervalMs = 60_000,
  batchSize = 25,
  onFinalIgnore: (candidate: ReconciliationCandidate) => boolean = () => false,
): BillingReconciliationRuntime {
  let closed = false;
  let running: Promise<number> | null = null;

  const runOnce = async (): Promise<number> => {
    if (closed) return 0;
    const candidates = await dispatch.reconciliationScan(batchSize);
    for (const candidate of candidates) {
      try {
        const outcome = await reconcileCandidate(candidate);
        if (outcome === "ignored" && !onFinalIgnore(candidate)) {
          logger.warn("billing_reconcile_ignored", {
            transaction_Id: candidate.transactionId,
            platform: candidate.platform,
            error_code: "FINAL_IGNORE_POLICY",
          });
        }
      } catch (error) {
        logger.warn("billing_reconcile_retry", {
          transaction_Id: candidate.transactionId,
          platform: candidate.platform,
          error_code: normalizedErrorCode(error),
        });
      }
    }
    return candidates.length;
  };

  /**
   * Re-verifies one open transaction and converges the ledger row. Returns
   * the outcome surfaced by `billing_reconcile_transaction` (or "ignored"
   * for a platform that must not be converged at all).
   */
  async function reconcileCandidate(
    candidate: ReconciliationCandidate,
  ): Promise<string> {
    if (candidate.platform === "app_store") {
      if (!verifiers.apple) throw new Error("apple verifier not configured");
      let signedStatus;
      try {
        signedStatus = await verifiers.apple.verifier.getSubscriptionStatus(
          candidate.originalTransactionId,
        );
      } catch (error) {
        // Apple outage: leave the row open for the next poll.
        throw error;
      }
      if (
        !signedStatus ||
        !isAppleTransactionTrusted({
          bundleId: signedStatus.bundleId,
          expectedBundleId: verifiers.apple.bundleId,
          environment: signedStatus.environment,
          expectedEnvironment: verifiers.apple.platformEnvironment,
        })
      ) {
        throw new Error("apple transaction fails bundle/environment trust");
      }
      const state = mapAppleTransactionTypeToState(
        null,
        signedStatus.revocationReason,
        signedStatus.expiresDate,
        Date.now(),
      );
      return dispatch.reconcileTransaction(candidate.transactionId, {
        platform: "app_store",
        environment: candidate.environment,
        originalTransactionId: signedStatus.originalTransactionId,
        purchasedAt: new Date(signedStatus.purchaseDate).toISOString(),
        effectiveUntil: signedStatus.expiresDate
          ? new Date(signedStatus.expiresDate).toISOString()
          : null,
        state,
        acknowledged: false,
      });
    }

    if (candidate.platform === "play_store") {
      if (!verifiers.google) throw new Error("google verifier not configured");
      const purchaseToken = candidate.storeTransactionId;
      if (!purchaseToken) throw new Error("google purchase token missing");
      const verified = await verifiers.google.verifier.verifySubscription(
        verifiers.google.packageName,
        purchaseToken,
      );
      if (
        !isGooglePackageNameTrusted(
          verified.packageName,
          verifiers.google.packageName,
        )
      ) {
        throw new Error("package name mismatch");
      }
      const state = mapGoogleSubscriptionStateToTransactionState(
        verified.subscriptionState,
      ) ??
        "on_hold";

      let acknowledged = verified.acknowledgementState === "2";
      if (
        !acknowledged &&
        verified.subscriptionState !== "SUBSCRIPTION_STATE_EXPIRED"
      ) {
        try {
          await verifiers.google.verifier.acknowledgeSubscription(
            verifiers.google.packageName,
            purchaseToken,
          );
          acknowledged = true;
        } catch {
          // Refund window backstop: try again next poll.
        }
      }

      return dispatch.reconcileTransaction(candidate.transactionId, {
        platform: "play_store",
        environment: candidate.environment,
        originalTransactionId: verified.originalTransactionId ||
          candidate.originalTransactionId,
        purchasedAt: verified.startTime ?? candidate.purchasedAt,
        effectiveUntil: verified.expiryTime,
        state,
        acknowledged,
      });
    }

    // `school` transactions have no store verifier: leave them open.
    return "ignored";
  }

  const timer = setInterval(() => {
    if (running) return;
    running = runOnce().catch((error) => {
      logger.error("billing_reconciliation_poll_failed", {
        error_name: error instanceof Error ? error.name : "unknown",
      });
      return 0;
    }).finally(() => (running = null));
  }, intervalMs);

  return {
    runOnce,
    async close() {
      closed = true;
      clearInterval(timer);
      await running;
    },
  };
}
