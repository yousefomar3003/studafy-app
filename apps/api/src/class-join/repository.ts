import type { Sql } from "@studafy/database";
import { withRequestContext } from "../auth/context";
import { sha256Hex } from "../auth/middleware";
import {
  deriveJoinCredentials,
  formatClassCode,
  generateClassCode,
  generateDerivationSalt,
  hashClassCode,
  normalizeClassCode,
} from "./code";
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
  /**
   * [codeKey] turns on JOIN-053 short codes. Without it the link is the only
   * way in: a code is never minted, and one presented for redemption is
   * refused rather than looked up with a key that does not exist.
   */
  constructor(readonly sql: Sql, readonly codeKey?: string) {}

  async query(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
  ): Promise<unknown> {
    const result = await withRequestContext(
      this.sql,
      context,
      async (tx) => {
        const rows = await tx<{ result: unknown }[]>`
        select private.api044_query(
          ${operation}, ${resourceId}::uuid, ${tx.json(input as never)}
        ) as result
      `;
        return rows[0]?.result ?? null;
      },
    );
    if (operation !== "getClassJoinLink" || !result) return result;
    const record = result as Record<string, unknown>;
    if (typeof record["outcome"] === "string") return result;
    // The salt is for re-deriving, never for the client. What the teacher
    // gets is the same link and code they were given when it was made -
    // only for a link that can still be used, and only with the key.
    const { derivationSalt, ...link } = record;
    if (typeof derivationSalt === "string" && this.codeKey) {
      const { token, code } = await deriveJoinCredentials(
        this.codeKey,
        derivationSalt,
      );
      return { ...link, token, code: formatClassCode(code) };
    }
    return { ...link, token: null, code: null };
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
      // With the key, the token and code are derived from a stored salt, so
      // the class's staff can be shown the same ones again later. Without
      // it, they are random and exist only in this response.
      const salt = this.codeKey ? generateDerivationSalt() : null;
      const derived = salt && this.codeKey
        ? await deriveJoinCredentials(this.codeKey, salt)
        : null;
      const token = derived?.token ?? opaqueToken();
      const tokenHash = await sha256Hex(token);
      // The code is the same link spelled short, so it is minted in the same
      // command and dies with the same row.
      const code = derived?.code ?? (this.codeKey ? generateClassCode() : null);
      const codeHash = code && this.codeKey
        ? await hashClassCode(code, this.codeKey)
        : null;
      const result = await this.execute(
        context,
        operation,
        resourceId,
        {
          ...typed,
          body: {
            ...body,
            tokenHash,
            ...(codeHash ? { codeHash } : {}),
            ...(salt ? { derivationSalt: salt } : {}),
          },
        },
        reservation,
      );
      if (result.outcome !== "ok") return result;
      return {
        outcome: "ok",
        response: {
          ...(result.response as Record<string, unknown>),
          token,
          code: code ? formatClassCode(code) : null,
        },
      };
    }

    if (operation === "redeemClassJoinLink") {
      const credential = await this.redemptionCredential(body);
      if (!credential) return { outcome: "invalid" };
      const result = await this.execute(
        context,
        operation,
        resourceId,
        { ...typed, body: credential },
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

  /**
   * The hash the dispatcher looks the link up by, from a token or a code.
   *
   * Exactly one of the two: a request carrying both is not something a real
   * client sends. A code that cannot be one - wrong length, a character
   * outside the alphabet - is refused here, before it costs a query.
   */
  private async redemptionCredential(
    body: Record<string, unknown>,
  ): Promise<{ tokenHash: string } | { codeHash: string } | null> {
    const token = body["token"];
    const code = body["code"];
    if (typeof token === "string" && code === undefined) {
      return { tokenHash: await sha256Hex(token) };
    }
    if (typeof code === "string" && token === undefined && this.codeKey) {
      const canonical = normalizeClassCode(code);
      if (!canonical) return null;
      return { codeHash: await hashClassCode(canonical, this.codeKey) };
    }
    return null;
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
