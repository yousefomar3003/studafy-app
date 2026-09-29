import type { Sql } from "@studafy/database";
import {
  ACADEMIC,
  type CatalogueCommandResult,
  type CatalogueRepository,
  PostgresDispatchRepository,
} from "../platform/dispatchRepository";
import type { RequestDbContext } from "../platform/dbContext";

export type AcademicRepository = CatalogueRepository;

export interface AcademicPageResult {
  items: unknown[];
  nextPosition: string | null;
}

export type AcademicCommandResult = CatalogueCommandResult;
export type { RequestDbContext };

export class PostgresAcademicRepository extends PostgresDispatchRepository {
  constructor(sql: Sql) {
    super(sql, ACADEMIC);
  }
}
