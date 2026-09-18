/**
 * Queue Redis posture guard (OPS-061): queue keys must never be evicted, and
 * job payloads must survive a restart, so the allocation the worker connects
 * to must run `noeviction` with persistence enabled (§10 + ADR-0024 §2).
 *
 * Production fails closed at worker boot: an evicting or non-persistent
 * queue Redis refuses to start. Development logs a warning instead, since
 * the loopback instance is disposable.
 */
import type { Redis } from "./redis";

export interface QueueRedisPosture {
  maxmemoryPolicy: string;
  appendonly: string;
  /** Non-empty RDB save policy, e.g. "3600 1 300 100". */
  save: string;
}

export class QueuePostureError extends Error {
  readonly code = "QUEUE_REDIS_POSTURE";
  constructor(
    message: string,
    readonly problems: string[],
  ) {
    super(message);
    this.name = "QueuePostureError";
  }
}

/** Reads the server-side memory/persistence policy through CONFIG GET. */
export async function readQueueRedisPosture(
  client: Redis,
): Promise<QueueRedisPosture> {
  const config = await client.config(
    "GET",
    "maxmemory-policy",
    "appendonly",
    "save",
  );
  // ioredis returns a flat array: [key, value, key, value, ...]
  const entries = Array.isArray(config) ? config : [];
  const value = (key: string): string => {
    const index = entries.findIndex((entry) => String(entry) === key);
    return index >= 0 && index + 1 < entries.length
      ? String(entries[index + 1])
      : "";
  };
  return {
    maxmemoryPolicy: value("maxmemory-policy"),
    appendonly: value("appendonly"),
    save: value("save"),
  };
}

/**
 * Posture problems by environment. Production fails closed on both rules;
 * non-production surfaces them for the operator log only.
 */
export function queuePostureProblems(
  posture: QueueRedisPosture,
  environment: string,
): string[] {
  const problems: string[] = [];
  if (environment === "production") {
    if (posture.maxmemoryPolicy !== "noeviction") {
      problems.push(
        `maxmemory-policy must be noeviction in production (got ${
          posture.maxmemoryPolicy || "unknown"
        }); evicted queue keys lose jobs.`,
      );
    }
    const persisted = posture.appendonly === "1" ||
      posture.save.trim().length > 0;
    if (!persisted) {
      problems.push(
        "queue keys must be persisted (appendonly yes or an RDB save policy) so a Redis restart cannot drop enqueued jobs.",
      );
    }
  }
  return problems;
}

/** Reads the posture and throws in production when problems exist. */
export async function assertQueueRedisPosture(
  client: Redis,
  environment: string,
): Promise<QueueRedisPosture> {
  const posture = await readQueueRedisPosture(client);
  const problems = queuePostureProblems(posture, environment);
  if (problems.length > 0) {
    throw new QueuePostureError(
      `Queue Redis posture rejected: ${problems.join(" ")}`,
      problems,
    );
  }
  return posture;
}
