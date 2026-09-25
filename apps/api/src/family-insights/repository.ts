import type { Sql } from "@studafy/database";
import { withVerifiedActor } from "../auth/context";

/** The child's permitted records, exactly as SQL returned them. */
export interface RawInsightFacts {
  studentId: string;
  studentName: string;
  period: "last30" | "term" | "year";
  from: string;
  to: string;
  grades: {
    subject: string;
    score: number;
    maximumScore: number;
    at: string;
  }[];
  attendance: {
    state: "present" | "late" | "absent" | "excused";
    at: string;
  }[];
  homework: {
    assignmentId: string;
    title: string;
    dueAt: string;
    submittedAt: string | null;
  }[];
  wellbeing: { id: string; kind: string; title: string; createdAt: string }[];
}

export interface FamilyInsightsRepository {
  /** Null when the caller may not read this child's insights. */
  read(
    context: { subject: string; requestId: string },
    studentId: string,
    period: "last30" | "term" | "year",
  ): Promise<RawInsightFacts | null>;
}

/**
 * Reads the facts behind Family+.
 *
 * Deliberately thin. Which records a guardian may see, and whether they have
 * paid for them, are both decided in `private.api042_query`, so there is no
 * second opinion here that could drift from it.
 */
export class PostgresFamilyInsightsRepository
  implements FamilyInsightsRepository {
  constructor(readonly sql: Sql) {}

  async read(
    context: { subject: string; requestId: string },
    studentId: string,
    period: "last30" | "term" | "year",
  ): Promise<RawInsightFacts | null> {
    return await withVerifiedActor(this.sql, context.subject, async (tx) => {
      const rows = await tx<
        { result: (RawInsightFacts & { outcome: string }) | null }[]
      >`
        select private.api042_query(
          'getFamilyInsights', null,
          ${tx.json({ studentId, period } as never)}
        ) as result
      `;
      const result = rows[0]?.result ?? null;
      if (!result || result.outcome !== "ok") return null;
      return result;
    });
  }
}
