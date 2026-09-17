import type { Sql } from "@studafy/database";
import { withRequestContext } from "../auth/context";
import type { RequestDbContext } from "../platform/catalogueRoutes";

export interface File050Result {
  outcome: string;
  response?: unknown;
  status?: number;
  code?: string | null;
  [key: string]: unknown;
}

export interface FileRepository {
  prepareIntent(
    context: RequestDbContext,
    body: unknown,
  ): Promise<File050Result>;
  issueIntent(
    context: RequestDbContext,
    body: unknown,
    internal: unknown,
    reservation: { id: string; generation: number },
  ): Promise<File050Result>;
  query(
    context: RequestDbContext,
    operation: string,
    id: string,
  ): Promise<File050Result>;
  prepareCompletion(
    context: RequestDbContext,
    uploadId: string,
  ): Promise<File050Result>;
  complete(
    context: RequestDbContext,
    uploadId: string,
    observed: unknown,
    reservation: { id: string; generation: number },
  ): Promise<File050Result>;
}

export class PostgresFileRepository implements FileRepository {
  constructor(readonly sql: Sql) {}

  async prepareIntent(
    context: RequestDbContext,
    body: unknown,
  ): Promise<File050Result> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: File050Result }[]>`
        select private.api050_prepare_intent(${
        tx.json(body as never)
      }) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async issueIntent(
    context: RequestDbContext,
    body: unknown,
    internal: unknown,
    reservation: { id: string; generation: number },
  ): Promise<File050Result> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: File050Result }[]>`
        select private.api050_issue_intent(
          ${tx.json(body as never)}, ${tx.json(internal as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async query(
    context: RequestDbContext,
    operation: string,
    id: string,
  ): Promise<File050Result> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: File050Result }[]>`
        select private.api050_query(${operation},${id}::uuid) as result
      `;
      return rows[0]?.result ?? { outcome: "not_found" };
    });
  }

  async prepareCompletion(
    context: RequestDbContext,
    uploadId: string,
  ): Promise<File050Result> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: File050Result }[]>`
        select private.api050_prepare_completion(${uploadId}::uuid) as result
      `;
      return rows[0]?.result ?? { outcome: "not_found" };
    });
  }

  async complete(
    context: RequestDbContext,
    uploadId: string,
    observed: unknown,
    reservation: { id: string; generation: number },
  ): Promise<File050Result> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: File050Result }[]>`
        select private.api050_complete_upload(
          ${uploadId}::uuid,${tx.json(observed as never)},
          ${reservation.id}::uuid,${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}
