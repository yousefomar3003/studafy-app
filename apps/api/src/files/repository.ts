import type { Sql } from "@studafy/database";
import { withRequestContext } from "../platform/dbContext";
import type { RequestDbContext } from "../platform/dbContext";

export interface FileCommandResult {
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
  ): Promise<FileCommandResult>;
  issueIntent(
    context: RequestDbContext,
    body: unknown,
    internal: unknown,
    reservation: { id: string; generation: number },
  ): Promise<FileCommandResult>;
  query(
    context: RequestDbContext,
    operation: string,
    id: string,
  ): Promise<FileCommandResult>;
  prepareCompletion(
    context: RequestDbContext,
    uploadId: string,
  ): Promise<FileCommandResult>;
  complete(
    context: RequestDbContext,
    uploadId: string,
    observed: unknown,
    reservation: { id: string; generation: number },
  ): Promise<FileCommandResult>;
  /** FILE-051: one clean file becomes one resource/version/publication. */
  publish(
    context: RequestDbContext,
    fileId: string,
    body: unknown,
    reservation: { id: string; generation: number },
  ): Promise<FileCommandResult>;
  /** FILE-051: re-authorizes and records one single-use delivery grant. */
  createDownloadGrant(
    context: RequestDbContext,
    fileId: string,
    internal: DownloadGrantInternal,
    reservation: { id: string; generation: number },
  ): Promise<FileCommandResult>;
  /**
   * FILE-051: spends the grant, then re-authorizes against current state.
   * On `ok` the response names the effective (possibly deduplicated)
   * physical object to stream.
   */
  consumeDownloadGrant(
    context: RequestDbContext,
    fileId: string,
    nonceHash: string,
  ): Promise<FileDeliveryResult>;
}

export interface DownloadGrantInternal {
  nonceHash: string;
  downloadUrl: string;
  expiresAt: string;
}

export interface EffectiveObject {
  schoolId: string;
  bucket: string;
  objectKey: string;
  storedSha256: string;
  storedSizeBytes: number;
  mediaType: string;
  displayName: string;
  rootClean: boolean;
}

export type FileDeliveryResult =
  | { outcome: "ok"; response: EffectiveObject }
  | { outcome: string; response?: undefined };

export class PostgresFileRepository implements FileRepository {
  constructor(readonly sql: Sql) {}

  async prepareIntent(
    context: RequestDbContext,
    body: unknown,
  ): Promise<FileCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: FileCommandResult }[]>`
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
  ): Promise<FileCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: FileCommandResult }[]>`
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
  ): Promise<FileCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: FileCommandResult }[]>`
        select private.api050_query(${operation},${id}::uuid) as result
      `;
      return rows[0]?.result ?? { outcome: "not_found" };
    });
  }

  async prepareCompletion(
    context: RequestDbContext,
    uploadId: string,
  ): Promise<FileCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: FileCommandResult }[]>`
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
  ): Promise<FileCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: FileCommandResult }[]>`
        select private.api050_complete_upload(
          ${uploadId}::uuid,${tx.json(observed as never)},
          ${reservation.id}::uuid,${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async publish(
    context: RequestDbContext,
    fileId: string,
    body: unknown,
    reservation: { id: string; generation: number },
  ): Promise<FileCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: FileCommandResult }[]>`
        select private.api051_publish_file(
          ${fileId}::uuid,${tx.json(body as never)},
          ${reservation.id}::uuid,${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async createDownloadGrant(
    context: RequestDbContext,
    fileId: string,
    internal: DownloadGrantInternal,
    reservation: { id: string; generation: number },
  ): Promise<FileCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: FileCommandResult }[]>`
        select private.api051_create_download_grant(
          ${fileId}::uuid,${tx.json(internal as never)},
          ${reservation.id}::uuid,${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async consumeDownloadGrant(
    context: RequestDbContext,
    fileId: string,
    nonceHash: string,
  ): Promise<FileDeliveryResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: FileDeliveryResult }[]>`
        select private.api051_consume_download_grant(
          ${fileId}::uuid,${nonceHash}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "grant_invalid" };
    });
  }
}
