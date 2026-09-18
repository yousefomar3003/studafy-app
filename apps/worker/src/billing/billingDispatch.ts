/**
 * The database half of the PAY-071 billing-events drain — SECURITY DEFINER
 * functions only (`studafy_worker_runtime` holds no table grants). Claims
 * come from `private.billing_claim_events_for_dispatch` (FOR UPDATE SKIP
 * LOCKED); the BullMQ processor is handed an opaque job id and re-fetches
 * the raw payload through `private.billing_event_payload`, which is scoped
 * to an event currently in `processing`, so §10's "workers re-fetch and
 * re-authorize current state" holds and the provider's restricted payload
 * never rides in a Redis-resident job body.
 */
import type { Sql } from "@studafy/database";

export interface ClaimedBillingEvent {
  eventId: number;
  platform: string;
  environment: string;
  rawPayload: string | null;
  bullmqJobId: string | null;
  attempt: number;
}

export interface BillingEventPayload {
  platform: "app_store" | "play_store" | string;
  environment: string;
  rawPayload: string | null;
}

/** `billing_finish_event` outcomes (also refined by `billing_reconcile_transaction`). */
export type BillingFinishOutcome = "completed" | "terminal" | "lost" | "retry";

export interface ReconciliationCandidate {
  transactionId: string;
  platform: "app_store" | "play_store" | string;
  environment: string;
  /** The current store token/transaction id (`store_transactions.transaction_id`). */
  storeTransactionId: string;
  originalTransactionId: string;
  state: string;
  acknowledgedAt: string | null;
  purchasedAt: string;
}

export interface BillingDispatchPort {
  claim(workerId: string, limit: number): Promise<ClaimedBillingEvent[]>;
  recordDispatched(
    workerId: string,
    eventId: number,
    jobId: string,
  ): Promise<boolean>;
  releaseDispatch(
    workerId: string,
    eventId: number,
    errorCode: string,
  ): Promise<boolean>;
  failDispatch(eventId: number, errorCode: string): Promise<boolean>;
  eventPayload(eventId: number): Promise<BillingEventPayload | null>;
  finishEvent(
    eventId: number,
    body: Record<string, unknown>,
  ): Promise<BillingFinishOutcome>;
  reconcileTransaction(
    transactionId: string,
    body: Record<string, unknown>,
  ): Promise<string>;
  reconciliationScan(limit: number): Promise<ReconciliationCandidate[]>;
}

/** Deterministic BullMQ job id for one store event, mirroring OPS-061. */
export function billingEventJobId(eventId: number): string {
  return `billing-event-${eventId}`;
}

/** Parses the store event id back out of a deterministic BullMQ job id. */
export function billingEventIdFromJobId(jobId: string): number | null {
  const prefix = "billing-event-";
  if (!jobId.startsWith(prefix)) return null;
  const raw = jobId.slice(prefix.length);
  if (!/^\d+$/.test(raw)) return null;
  const eventId = Number(raw);
  return Number.isSafeInteger(eventId) && eventId > 0 ? eventId : null;
}

export function postgresBillingDispatch(sql: Sql): BillingDispatchPort {
  return {
    async claim(workerId, limit) {
      const rows = await sql<{ jobs: ClaimedBillingEvent[] }[]>`
        select private.billing_claim_events_for_dispatch(${workerId},${limit}) as jobs
      `;
      return rows[0]?.jobs ?? [];
    },
    async recordDispatched(workerId, eventId, jobId) {
      const rows = await sql<{ recorded: boolean }[]>`
        select private.billing_record_event_dispatched(
          ${workerId},${eventId},${jobId}
        ) as recorded
      `;
      return rows[0]?.recorded === true;
    },
    async releaseDispatch(workerId, eventId, errorCode) {
      const rows = await sql<{ released: boolean }[]>`
        select private.billing_release_event(
          ${workerId},${eventId},${errorCode}
        ) as released
      `;
      return rows[0]?.released === true;
    },
    async failDispatch(eventId, errorCode) {
      const rows = await sql<{ failed: boolean }[]>`
        select private.billing_fail_event(${eventId},${errorCode}) as failed
      `;
      return rows[0]?.failed === true;
    },
    async eventPayload(eventId) {
      const rows = await sql<{ payload: BillingEventPayload | null }[]>`
        select private.billing_event_payload(${eventId}) as payload
      `;
      return rows[0]?.payload ?? null;
    },
    async finishEvent(eventId, body) {
      const rows = await sql<{ outcome: BillingFinishOutcome }[]>`
        select private.billing_finish_event(${eventId},${sql.json(body as never)}) as outcome
      `;
      return rows[0]?.outcome ?? "lost";
    },
    async reconcileTransaction(transactionId, body) {
      const rows = await sql<{ outcome: string }[]>`
        select private.billing_reconcile_transaction(
          ${transactionId}::uuid, ${sql.json(body as never)}
        ) as outcome
      `;
      return rows[0]?.outcome ?? "lost";
    },
    async reconciliationScan(limit) {
      const rows = await sql<{ candidates: ReconciliationCandidate[] }[]>`
        select private.billing_reconciliation_scan(${limit}) as candidates
      `;
      return rows[0]?.candidates ?? [];
    },
  };
}