import type { IdempotencyMode, V1OperationId } from "@studafy/contracts";
import type { Reservation } from "./idempotency";

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
