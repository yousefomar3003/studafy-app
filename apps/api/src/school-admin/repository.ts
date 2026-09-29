import type { Sql } from "@studafy/database";
import {
  type CatalogueRepository,
  PostgresDispatchRepository,
  SCHOOL_OPERATIONS,
} from "../platform/dispatchRepository";

export type SchoolAdminRepository = CatalogueRepository;

/** School administration is command-only: no GET route selects its query. */
export class PostgresSchoolAdminRepository extends PostgresDispatchRepository {
  constructor(sql: Sql) {
    super(sql, SCHOOL_OPERATIONS);
  }
}
