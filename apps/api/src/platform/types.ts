import type { IdempotencyMode, V1OperationId } from "@studafy/contracts";
import type { Context } from "hono";
import type { Reservation } from "./idempotency";
import type { AuthEnv } from "../auth/middleware";
import type { AuthorizationEnv } from "../authorization/middleware";

export interface PlatformEnv {
  Variables: {
    requestId: string;
    requestStartedAt: number;
    abortSignal: AbortSignal;
    validatedBody: unknown;
    validatedParams: unknown;
    validatedQuery: unknown;
    operationId: V1OperationId;
    idempotencyMode: IdempotencyMode;
    idempotencyReservation:
      | Extract<Reservation, { outcome: "reserved" }>
      | null;
    idempotencyCompleted: boolean;
  };
}

export interface PlatformLimits {
  maxBodyBytes: number;
  maxJsonDepth: number;
  maxJsonKeys: number;
  requestTimeoutMs: number;
}

/**
 * Larger body and key allowances for named routes only, fixed in code so
 * that widening one is a reviewed change. Every other route keeps the
 * strict defaults.
 *
 * The study helper carries its chat's recent turns so it can follow on -
 * up to its chat-memory budget, which is far more than 64 KB or 128 keys.
 * Its own schema still bounds every turn and the number of turns.
 */
export const ROUTE_LIMIT_OVERRIDES: Readonly<
  Record<string, Readonly<Pick<PlatformLimits, "maxBodyBytes" | "maxJsonKeys">>>
> = {
  "/v1/study-assistant/ask": { maxBodyBytes: 512 * 1024, maxJsonKeys: 1_024 },
};

export const DEFAULT_PLATFORM_LIMITS: PlatformLimits = {
  maxBodyBytes: 64 * 1024,
  maxJsonDepth: 12,
  maxJsonKeys: 128,
  requestTimeoutMs: 10_000,
};

/** Any context a /v1 handler runs in: platform-only, authenticated, or
 * authenticated and authorized. */
export type RouteContext =
  | Context<PlatformEnv>
  | Context<AuthEnv>
  | Context<AuthorizationEnv>;
