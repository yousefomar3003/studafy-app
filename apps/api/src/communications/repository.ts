import type { Sql } from "@studafy/database";
import {
  type CatalogueRepository,
  PostgresDispatchRepository,
  SCHOOL_OPERATIONS,
} from "../platform/dispatchRepository";

export type CommunicationsRepository = CatalogueRepository;

export class PostgresCommunicationsRepository
  extends PostgresDispatchRepository {
  constructor(sql: Sql) {
    super(sql, SCHOOL_OPERATIONS);
  }
}
