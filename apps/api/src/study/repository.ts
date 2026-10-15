import type { Sql } from "@studafy/database";
import { withRequestContext } from "../platform/dbContext";
import type { CatalogueCommandResult } from "../platform/dispatchRepository";
import type { RequestDbContext } from "../platform/dbContext";
import type { StudyFeature } from "@studafy/infrastructure";

export type { StudyFeature };

export interface UsageReservation {
  outcome: string;
  usageId?: string;
  plan?: string;
}

export interface UsageSummary {
  outcome: string;
  plan: "free" | "plus" | "max";
  features: StudyFeature[];
  allowance: {
    period: "week" | "month";
    total: number;
    used: number;
    remaining: number;
    resetsAt: string;
  };
  capMicroUsd: number;
  committedMicroUsd: number;
}

/**
 * The SQL behind Studafy Plus / Max: the cost ledger (api047) and the
 * notebook / study-set surface (api046). Every call runs as the requesting
 * user, so each function re-derives who may do what from auth.uid().
 */
export interface StudyRepository {
  usage(
    context: RequestDbContext,
    operation: "summary" | "reserve" | "settle" | "release",
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  query(
    context: RequestDbContext,
    operation: string,
    resourceId: string,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown> | null>;
  command(
    context: RequestDbContext,
    operation: string,
    resourceId: string,
    body: Record<string, unknown>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult>;
}

export class PostgresStudyRepository implements StudyRepository {
  constructor(readonly sql: Sql) {}

  async usage(
    context: RequestDbContext,
    operation: "summary" | "reserve" | "settle" | "release",
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> }[]>`
        select private.api047_ai_usage(${operation}, ${
        tx.json(input as never)
      }) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async query(
    context: RequestDbContext,
    operation: string,
    resourceId: string,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown> | null> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> | null }[]>`
        select private.api046_query(
          ${operation}, ${resourceId}::uuid, ${tx.json(input as never)}
        ) as result
      `;
      return rows[0]?.result ?? null;
    });
  }

  async command(
    context: RequestDbContext,
    operation: string,
    resourceId: string,
    body: Record<string, unknown>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: CatalogueCommandResult }[]>`
        select private.api046_command(
          ${operation}, ${resourceId}::uuid, ${tx.json({ body } as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}
