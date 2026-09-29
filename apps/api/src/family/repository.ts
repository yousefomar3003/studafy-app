import type { Sql } from "@studafy/database";
import {
  type CatalogueRepository,
  PostgresDispatchRepository,
  SCHOOL_OPERATIONS,
} from "../platform/dispatchRepository";

export type FamilyRepository = CatalogueRepository;

/** S3 commands plus the guardian's own-links read (DL-050). */
export class PostgresFamilyRepository extends PostgresDispatchRepository {
  constructor(sql: Sql) {
    super(sql, SCHOOL_OPERATIONS);
  }
}
