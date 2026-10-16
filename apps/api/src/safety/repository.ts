import type { Sql } from "@studafy/database";
import {
  type CatalogueRepository,
  PostgresDispatchRepository,
  SCHOOL_OPERATIONS_WITH_AAL2,
} from "../platform/dispatchRepository";
import {
  type RequestDbContext,
  selectInRequestContext,
} from "../platform/dbContext";

export type SafetyRepository = CatalogueRepository;

/**
 * The platform operator's review reads (DL-063), answered by their own SQL
 * function instead of the school-operations dispatcher: opening a report
 * writes an audit event, which a read through api042_query (stable) cannot.
 */
const SAFETY_REVIEW_QUERIES: ReadonlySet<string> = new Set([
  "listSafetyReviewReports",
  "openSafetyReviewReport",
]);

/** Moderation-access and legal-hold commands are MFA-gated, so the actor's real AAL2 status is forwarded (docs/planning/instructions.md section 7). */
export class PostgresSafetyRepository extends PostgresDispatchRepository {
  constructor(sql: Sql) {
    super(sql, SCHOOL_OPERATIONS_WITH_AAL2);
  }

  override async query(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
  ): Promise<unknown> {
    if (!SAFETY_REVIEW_QUERIES.has(operation)) {
      return await super.query(context, operation, resourceId, input);
    }
    return await selectInRequestContext<unknown>(
      this.sql,
      context,
      "private.safety_review_query($1, $2::uuid, $3::jsonb)",
      [operation, resourceId, this.sql.json((input ?? null) as never)],
    );
  }
}
