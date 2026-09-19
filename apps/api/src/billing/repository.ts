import type { Sql } from "@studafy/database";
import { withRequestContext } from "../auth/context";
import type { RequestDbContext } from "../platform/catalogueRoutes";

export interface BillingReservation {
  id: string;
  generation: number;
}

export interface BillingResult {
  outcome: string;
  response?: unknown;
}

export interface NormalizedTransaction {
  platform: "app_store" | "play_store";
  environment: string;
  productFeatureKey: string;
  storeProductId: string;
  originalTransactionId: string;
  transactionId: string;
  signedDataHash: string;
  state:
    | "pending"
    | "active"
    | "grace_period"
    | "on_hold"
    | "refunded"
    | "revoked"
    | "expired";
  purchasedAt: string;
  effectiveUntil: string | null;
  beneficiaryStudentId?: string | null;
}

export interface BillingRepository {
  catalogue(environment: string): Promise<{
    products: {
      featureKey: string;
      platform: string;
      storeProductId: string;
    }[];
  }>;
  selfPurchaseStatus(
    context: RequestDbContext,
  ): Promise<{ schoolId: string; selfPurchaseEnabled: boolean }[]>;
  setSelfPurchase(
    context: RequestDbContext,
    schoolId: string,
    enabled: boolean,
    reservation: BillingReservation,
  ): Promise<boolean>;
  submitVerification(
    context: RequestDbContext,
    body: NormalizedTransaction,
    reservation: BillingReservation,
  ): Promise<BillingResult>;
  restore(
    context: RequestDbContext,
    body: NormalizedTransaction,
    reservation: BillingReservation,
  ): Promise<BillingResult>;
  requestPurchaseApproval(
    context: RequestDbContext,
    featureKey: string,
    reservation: BillingReservation,
  ): Promise<BillingResult>;
  listPurchaseApprovals(context: RequestDbContext): Promise<unknown[]>;
  decidePurchaseApproval(
    context: RequestDbContext,
    approvalId: string,
    approve: boolean,
    reservation: BillingReservation,
  ): Promise<BillingResult>;
  listEntitlements(context: RequestDbContext, environment: string): Promise<
    {
      featureKey: string;
      status: string;
      startsAt: string;
      endsAt: string | null;
      beneficiaryStudentId: string | null;
    }[]
  >;
  /** Durable webhook dedupe. Returns the new event id, or null on a duplicate. */
  recordEvent(
    platform: "app_store" | "play_store",
    environment: string,
    externalEventId: string | null,
    payloadHash: string,
    rawPayload: string,
  ): Promise<{ outcome: "new" | "duplicate"; eventId?: number }>;
}

export class PostgresBillingRepository implements BillingRepository {
  constructor(readonly sql: Sql) {}

  async catalogue(environment: string) {
    const rows = await this.sql<{ result: unknown }[]>`
      select private.billing_catalogue(${environment}) as result
    `;
    return { products: (rows[0]?.result ?? []) as never };
  }

  async selfPurchaseStatus(context: RequestDbContext) {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: unknown }[]>`
        select private.billing_self_purchase_status() as result
      `;
      return (rows[0]?.result ?? []) as never;
    });
  }

  async setSelfPurchase(
    context: RequestDbContext,
    schoolId: string,
    enabled: boolean,
    reservation: BillingReservation,
  ) {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: boolean }[]>`
        select private.billing_set_self_purchase(${schoolId}::uuid, ${enabled}) as result
      `;
      const ok = rows[0]?.result ?? false;
      if (ok) {
        await this.complete(tx, reservation, {
          schoolId,
          selfPurchaseEnabled: enabled,
        });
      }
      return ok;
    });
  }

  async submitVerification(
    context: RequestDbContext,
    body: NormalizedTransaction,
    reservation: BillingReservation,
  ): Promise<BillingResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: BillingResult }[]>`
        select private.billing_submit_verification(${
        tx.json(body as never)
      }) as result
      `;
      const result = rows[0]?.result ?? { outcome: "invalid" };
      if (result.outcome === "ok") {
        await this.complete(tx, reservation, result.response);
      }
      return result;
    });
  }

  async restore(
    context: RequestDbContext,
    body: NormalizedTransaction,
    reservation: BillingReservation,
  ): Promise<BillingResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: BillingResult }[]>`
        select private.billing_restore(${tx.json(body as never)}) as result
      `;
      const result = rows[0]?.result ?? { outcome: "invalid" };
      if (result.outcome === "ok") {
        result.response = {
          restored: true,
          ...(result.response as object ?? {}),
        };
        await this.complete(tx, reservation, result.response);
      }
      return result;
    });
  }

  async requestPurchaseApproval(
    context: RequestDbContext,
    featureKey: string,
    reservation: BillingReservation,
  ): Promise<BillingResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: BillingResult }[]>`
        select private.billing_request_purchase_approval(${featureKey}) as result
      `;
      const result = rows[0]?.result ?? { outcome: "invalid" };
      if (result.outcome === "ok") {
        await this.complete(tx, reservation, result.response, 201);
      }
      return result;
    });
  }

  async listPurchaseApprovals(context: RequestDbContext) {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: unknown[] }[]>`
        select private.billing_list_purchase_approvals() as result
      `;
      return rows[0]?.result ?? [];
    });
  }

  async decidePurchaseApproval(
    context: RequestDbContext,
    approvalId: string,
    approve: boolean,
    reservation: BillingReservation,
  ): Promise<BillingResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: BillingResult }[]>`
        select private.billing_decide_purchase_approval(
          ${approvalId}::uuid, ${approve}
        ) as result
      `;
      const result = rows[0]?.result ?? { outcome: "invalid" };
      if (result.outcome === "ok") {
        await this.complete(tx, reservation, result.response);
      }
      return result;
    });
  }

  async listEntitlements(context: RequestDbContext, environment: string) {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: unknown }[]>`
        select private.billing_list_entitlements(${environment}) as result
      `;
      return (rows[0]?.result ?? []) as never;
    });
  }

  private async complete(
    tx: Sql,
    reservation: BillingReservation,
    response: unknown,
    status = 200,
  ) {
    const rows = await tx<{ completed: boolean }[]>`
      select private.api_idempotency_complete(${reservation.id}::uuid,
        ${reservation.generation}, ${status}, ${
      tx.json(response as never)
    }) as completed
    `;
    // Throwing rolls back the business mutation as well as its response when
    // another request has superseded the lease. Never commit unfenced work.
    if (!rows[0]?.completed) throw new Error("billing idempotency fence lost");
  }

  async recordEvent(
    platform: "app_store" | "play_store",
    environment: string,
    externalEventId: string | null,
    payloadHash: string,
    rawPayload: string,
  ) {
    const rows = await this.sql<
      { result: { outcome: "new" | "duplicate"; eventId?: number } }[]
    >`
      select private.billing_record_event(
        ${platform}, ${environment}, ${externalEventId}, ${payloadHash}, ${rawPayload}
      ) as result
    `;
    return rows[0]?.result ?? { outcome: "duplicate" as const };
  }
}
