import type { Sql } from "@studafy/database";
import {
  type CatalogueRepository,
  PostgresDispatchRepository,
  SCHOOL_OPERATIONS,
} from "../platform/dispatchRepository";

export type MeetingsRepository = CatalogueRepository;

export class PostgresMeetingsRepository extends PostgresDispatchRepository {
  constructor(sql: Sql) {
    super(sql, SCHOOL_OPERATIONS);
  }
}
