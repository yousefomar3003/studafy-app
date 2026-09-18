import type { Sql } from "@studafy/database";
import { withRequestContext } from "../auth/context";
import type { RequestDbContext } from "../platform/catalogueRoutes";

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
  parentalGateConfirmed?: boolean;
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
  ): Promise<boolean>;
  submitVerification(
    context: RequestDbContext,
    body: NormalizedTransaction,
  ): Promise<BillingResult>;
  restore(
    context: RequestDbContext,
    body: NormalizedTransaction,
  ): Promise<BillingResult>;
  listEntitlements(context: RequestDbContext): Promise<
    {
      featureKey: string;
      status: string;
      startsAt: string;
      endsAt: string | null;
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
  ) {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: boolean }[]>`
        select private.billing_set_self_purchase(${schoolId}::uuid, ${enabled}) as result
      `;
      return rows[0]?.result ?? false;
    });
  }

  async submitVerification(
    context: RequestDbContext,
    body: NormalizedTransaction,
  ): Promise<BillingResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: BillingResult }[]>`
        select private.billing_submit_verification(${
        tx.json(body as never)
      }) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async restore(
    context: RequestDbContext,
    body: NormalizedTransaction,
  ): Promise<BillingResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: BillingResult }[]>`
        select private.billing_restore(${tx.json(body as never)}) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async listEntitlements(context: RequestDbContext) {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: unknown }[]>`
        select private.billing_list_entitlements() as result
      `;
      return (rows[0]?.result ?? []) as never;
    });
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
