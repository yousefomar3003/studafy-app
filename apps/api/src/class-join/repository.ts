import type { Sql } from "@studafy/database";
import { withRequestContext } from "../auth/context";
import { sha256Hex } from "../auth/middleware";
import type {
  CatalogueCommandResult,
  CatalogueRepository,
  RequestDbContext,
} from "../platform/catalogueRoutes";

export type ClassJoinRepository = CatalogueRepository;

/** 43 base64url characters: 32 bytes of entropy, the shape invitations use. */
function opaqueToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

/**
 * JOIN-052 class join links.
 *
 * The token is minted and hashed here, never in SQL, exactly as invitations
 * do it: the dispatcher only ever sees a SHA-256 hash. Creation is the one
 * moment the raw token exists in a response, because whoever holds it can
 * join the class; it is unrecoverable afterwards, and a teacher who loses it
 * creates a new link, which supersedes the old one.
 */
export class PostgresClassJoinRepository implements CatalogueRepository {
  constructor(readonly sql: Sql) {}

  async query(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
  ): Promise<unknown> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: unknown }[]>`
        select private.api044_query(
          ${operation}, ${resourceId}::uuid, ${tx.json(input as never)}
        ) as result
      `;
      return rows[0]?.result ?? null;
    });
  }

  async command(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult> {
    const typed = input as { body?: Record<string, unknown> };
    const body = typed.body ?? {};

    if (operation === "createClassJoinLink") {
      const token = opaqueToken();
      const tokenHash = await sha256Hex(token);
      const result = await this.execute(
        context,
        operation,
        resourceId,
        { ...typed, body: { ...body, tokenHash } },
        reservation,
      );
      if (result.outcome !== "ok") return result;
      return {
        outcome: "ok",
        response: { ...(result.response as Record<string, unknown>), token },
      };
    }

    if (operation === "redeemClassJoinLink") {
      const token = body["token"];
      if (typeof token !== "string") return { outcome: "invalid" };
      const result = await this.execute(
        context,
        operation,
        resourceId,
        { ...typed, body: { tokenHash: await sha256Hex(token) } },
        reservation,
      );
      if (result.outcome !== "ok") return result;
      // The joiner is told which room they are now in, and nothing about the
      // link's remaining budget, which is the teacher's business.
      const link = result.response as Record<string, unknown>;
      return {
        outcome: "ok",
        response: {
          schoolId: link["schoolId"],
          classroomId: link["classroomId"],
          classroomName: link["classroomName"],
        },
      };
    }

    return await this.execute(
      context,
      operation,
      resourceId,
      input,
      reservation,
    );
  }

  private async execute(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: CatalogueCommandResult }[]>`
        select private.api044_command(
          ${operation}, ${resourceId}::uuid, ${tx.json(input as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}
