import { Redis } from "ioredis";

export type { Redis };

export interface RedisOptions {
  /** Seconds to wait for the initial connection and each command. */
  connectTimeout?: number;
  /** Fast-fail readiness probes instead of unbounded background retries. */
  maxRetriesPerRequest?: number;
}

/** Creates a Redis client tuned for health probes and graceful shutdown. */
export function createRedis(
  url: string,
  options: RedisOptions = {},
): Redis {
  return new Redis(url, {
    connectTimeout: (options.connectTimeout ?? 3) * 1000,
    maxRetriesPerRequest: options.maxRetriesPerRequest ?? 1,
    lazyConnect: false,
  });
}

/** Health probe. Throws when Redis is unreachable. */
export async function checkRedis(client: Redis): Promise<void> {
  const reply = await client.ping();
  if (reply !== "PONG") {
    throw new Error(`unexpected PING reply: ${reply}`);
  }
}

/** Closes the client cleanly. Idempotent: closing twice is a no-op. */
export async function closeRedis(client: Redis): Promise<void> {
  // ioredis 6 types "status" without the terminal "end" state, so the
  // comparison is widened on purpose.
  if ((client.status as string) === "end") return;
  try {
    await client.quit();
  } catch (error) {
    if ((client.status as string) === "end") return;
    throw error;
  }
}
