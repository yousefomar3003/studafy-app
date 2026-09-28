import type { Sql } from "@studafy/database";
import {
  type CatalogueRepository,
  PostgresDispatchRepository,
  SCHOOL_OPERATIONS_WITH_AAL2,
} from "../platform/dispatchRepository";

export type SupportAccessRepository = CatalogueRepository;

/** Support-access commands require MFA, so the actor's real AAL2 status is forwarded (docs/planning/instructions.md section 7). */
export class PostgresSupportAccessRepository
  extends PostgresDispatchRepository {
  constructor(sql: Sql) {
    super(sql, SCHOOL_OPERATIONS_WITH_AAL2);
  }
}
