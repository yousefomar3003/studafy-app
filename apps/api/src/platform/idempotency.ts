import type { MiddlewareHandler } from "hono";
import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import type { IdempotencyModeType, V1OperationId } from "@studafy/contracts";
import { withVerifiedActor } from "../auth/context";
import type { AuthorizationEnv } from "../authorization/middleware";
import { problem } from "./errors";

export type Reservation =
  | { outcome: "reserved"; id: string; generation: number }
  | { outcome: "replay"; responseStatus: number; responseBody: unknown }
  | { outcome: "mismatch" | "inProgress" | "denied" | "invalid" };

export interface IdempotencyRepository {
  reserve(subject: string, input: {
    schoolId: string | null;
    scope: string;
    key: string;
    requestHash: string;
    retentionSeconds: number;
    leaseSeconds: number;
  }): Promise<Reservation>;
  complete(
    subject: string,
    id: string,
    generation: number,
    status: number,
    body: unknown,
  ): Promise<boolean>;
  fail(subject: string, id: string, generation: number): Promise<boolean>;
}

export class PostgresIdempotencyRepository implements IdempotencyRepository {
  constructor(readonly sql: Sql) {}

  async reserve(
    subject: string,
    input: Parameters<IdempotencyRepository["reserve"]>[1],
  ): Promise<Reservation> {
    return await withVerifiedActor(this.sql, subject, async (tx) => {
      const rows = await tx<{ result: Reservation }[]>`
        select private.api_idempotency_reserve(
          ${input.schoolId}::uuid, ${input.scope}, ${input.key},
          ${input.requestHash}, ${input.retentionSeconds}, ${input.leaseSeconds}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "denied" };
    });
  }

  async complete(
    subject: string,
    id: string,
    generation: number,
    status: number,
    body: unknown,
  ): Promise<boolean> {
    return await withVerifiedActor(this.sql, subject, async (tx) => {
      const rows = await tx<{ result: boolean }[]>`
        select private.api_idempotency_complete(
          ${id}::uuid, ${generation}, ${status}, ${tx.json(body as never)}
        ) as result
      `;
      return rows[0]?.result ?? false;
    });
  }

  async fail(
    subject: string,
    id: string,
    generation: number,
  ): Promise<boolean> {
    return await withVerifiedActor(this.sql, subject, async (tx) => {
      const rows = await tx<{ result: boolean }[]>`
        select private.api_idempotency_fail(${id}::uuid, ${generation}) as result
      `;
      return rows[0]?.result ?? false;
    });
  }
}

function canonical(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  return `{${
    Object.entries(value as Record<string, unknown>).sort(([a], [b]) =>
      a.localeCompare(b)
    ).map(([key, child]) => `${JSON.stringify(key)}:${canonical(child)}`).join(
      ",",
    )
  }}`;
}

export async function requestHash(
  method: string,
  scope: string,
  body: unknown,
): Promise<string> {
  const bytes = new TextEncoder().encode(
    canonical({ body: body ?? null, method, scope }),
  );
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

const KEY = /^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$/;

export interface IdempotencyDependencies {
  repository?: IdempotencyRepository;
  logger: Logger;
  retentionSeconds?: number;
  leaseSeconds?: number;
}

export function idempotency(
  deps: IdempotencyDependencies,
  operationId: V1OperationId,
  mode: IdempotencyModeType,
): MiddlewareHandler<AuthorizationEnv> {
  return async (c, next) => {
    const key = c.req.header("idempotency-key");
    if (mode === "forbidden") {
      if (key) return problem(c, "IDEMPOTENCY_KEY_NOT_ALLOWED", 400);
      await next();
      return;
    }
    if (mode === "none") {
      await next();
      return;
    }
    if (!key || !KEY.test(key)) {
      return problem(c, "IDEMPOTENCY_KEY_REQUIRED", 400);
    }
    if (!deps.repository) return problem(c, "SERVICE_UNAVAILABLE", 503);

    const actor = c.get("actor");
    const schoolId = c.get("authorization").tenant?.schoolId ?? null;
    const hash = await requestHash(
      c.req.method,
      operationId,
      c.get("validatedBody"),
    );
    let reservation: Reservation;
    try {
      reservation = await deps.repository.reserve(actor.token.subject, {
        schoolId,
        scope: `v1.${operationId}`,
        key,
        requestHash: hash,
        retentionSeconds: deps.retentionSeconds ?? 86_400,
        leaseSeconds: deps.leaseSeconds ?? 15,
      });
    } catch {
      deps.logger.error("idempotency_reservation_failed", {
        request_id: c.get("requestId"),
        operation: operationId,
      });
      return problem(c, "SERVICE_UNAVAILABLE", 503);
    }

    if (reservation.outcome === "mismatch") {
      return problem(c, "IDEMPOTENCY_KEY_REUSED", 409);
    }
    if (reservation.outcome === "inProgress") {
      c.header("Retry-After", "1");
      return problem(c, "IDEMPOTENCY_IN_PROGRESS", 409);
    }
    if (reservation.outcome === "denied" || reservation.outcome === "invalid") {
      return problem(c, "FORBIDDEN", 403);
    }
    if (reservation.outcome === "replay") {
      c.header("Idempotency-Replayed", "true");
      c.header("Content-Type", "application/json; charset=UTF-8");
      return c.body(
        JSON.stringify(reservation.responseBody),
        reservation.responseStatus as never,
      );
    }
    if (reservation.outcome !== "reserved") {
      return problem(c, "SERVICE_UNAVAILABLE", 503);
    }

    try {
      await next();
    } catch (error) {
      await deps.repository.fail(
        actor.token.subject,
        reservation.id,
        reservation.generation,
      ).catch(() => false);
      throw error;
    }

    if (c.res.status >= 200 && c.res.status <= 299) {
      try {
        const body = await c.res.clone().json() as unknown;
        const completed = await deps.repository.complete(
          actor.token.subject,
          reservation.id,
          reservation.generation,
          c.res.status,
          body,
        );
        if (!completed) {
          c.res = problem(c, "SERVICE_UNAVAILABLE", 503);
          return;
        }
      } catch {
        // Preserve the live lease when completion is uncertain. Releasing it
        // here would permit an immediate duplicate execution after the use
        // case already succeeded.
        deps.logger.error("idempotency_completion_failed", {
          request_id: c.get("requestId"),
          operation: operationId,
        });
        c.res = problem(c, "SERVICE_UNAVAILABLE", 503);
        return;
      }
    } else {
      await deps.repository.fail(
        actor.token.subject,
        reservation.id,
        reservation.generation,
      ).catch(() => false);
    }
  };
}
