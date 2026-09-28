import type { Sql } from "@studafy/database";
import {
  type CatalogueRepository,
  PostgresDispatchRepository,
  SCHOOL_OPERATIONS,
} from "../platform/dispatchRepository";

export type AccountRepository = CatalogueRepository;

export class PostgresAccountRepository extends PostgresDispatchRepository {
  constructor(sql: Sql) {
    super(sql, SCHOOL_OPERATIONS);
  }
}
