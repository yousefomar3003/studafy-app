import type { Sql } from "@studafy/database";
import {
  type CatalogueRepository,
  PostgresDispatchRepository,
  SCHOOL_OPERATIONS_WITH_AAL2,
} from "../platform/dispatchRepository";

export type SafetyRepository = CatalogueRepository;

/** Moderation-access and legal-hold commands are MFA-gated, so the actor's real AAL2 status is forwarded (docs/planning/instructions.md section 7). */
export class PostgresSafetyRepository extends PostgresDispatchRepository {
  constructor(sql: Sql) {
    super(sql, SCHOOL_OPERATIONS_WITH_AAL2);
  }
}
