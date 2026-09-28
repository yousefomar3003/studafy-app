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
