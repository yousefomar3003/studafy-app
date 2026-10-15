/**
 * Queue Redis posture guard (OPS-061): queue keys must never be evicted, and
 * job payloads must survive a restart, so the allocation the worker connects
 * to must run `noeviction` with persistence enabled (§10 + ADR-0024 §2).
 *
 * Production fails closed at worker boot: an evicting or non-persistent
 * queue Redis refuses to start, and so does one whose posture cannot be read
 * at all. Development logs a warning instead, since the loopback instance is
 * disposable.
 *
 * Where it reads the posture from:
 * 1. `CONFIG GET maxmemory-policy | appendonly | save` (self-hosted Redis).
 * 2. When CONFIG is refused or does not answer, as on managed Redis (Redis
 *    Cloud and Redis Software allow CONFIG GET only for a short list of
 *    settings, none of these three; Upstash and others rename or block it):
 *    `INFO memory` (`maxmemory_policy`) and `INFO persistence`
 *    (`aof_enabled`, `rdb_saves`, `rdb_last_bgsave_status`).
 * The posture says which source answered, and the worker logs it.
 */
import type { Redis } from "./redis";

/** The two commands the probe needs; ioredis's `Redis` satisfies it. */
export interface PostureClient {
  call(command: string, ...args: string[]): Promise<unknown>;
}

export type QueuePostureSource = "config" | "info";

export interface QueueRedisPosture {
  /** Which commands answered: CONFIG GET, or INFO after CONFIG was refused. */
  source: QueuePostureSource;
  maxmemoryPolicy: string;
  /**
   * AOF on or off: CONFIG's `yes`/`no`, or INFO's `aof_enabled` `1`/`0`.
   * Empty when unknown.
   */
  appendonly: string;
  /**
   * CONFIG only: the RDB save policy, e.g. "3600 1 300 100"; empty when
   * snapshots are off or (INFO) unknown.
   */
  save: string;
  /**
   * INFO only: snapshots completed since the server started, and whether
   * the last one succeeded. Evidence of provider-run snapshots, since
   * managed Redis refuses BGSAVE from clients.
   */
  rdbSaves?: number;
  rdbLastBgsaveStatus?: string;
  /** Why CONFIG was not used, when it was not (a Redis error message). */
  configRefused?: string;
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

const reason = (error: unknown): string =>
  (error instanceof Error ? error.message : String(error)).slice(0, 200);

/** One CONFIG GET; undefined when the server does not report the key. */
async function configValue(
  client: PostureClient,
  key: string,
): Promise<string | undefined> {
  // One key per call: multi-key CONFIG GET needs Redis 7.
  const reply = await client.call("CONFIG", "GET", key);
  // [key, value] when known; [] when the server does not expose the key.
  const entries = Array.isArray(reply) ? reply.map(String) : [];
  const index = entries.indexOf(key);
  return index >= 0 && index + 1 < entries.length
    ? entries[index + 1]
    : undefined;
}

/** `key:value` lines of an INFO reply; section headers are skipped. */
export function parseInfo(text: string): Map<string, string> {
  const fields = new Map<string, string>();
  for (const line of text.split(/\r?\n/)) {
    if (line.startsWith("#")) continue;
    const at = line.indexOf(":");
    if (at > 0) fields.set(line.slice(0, at).trim(), line.slice(at + 1).trim());
  }
  return fields;
}

async function readFromConfig(
  client: PostureClient,
): Promise<QueueRedisPosture> {
  const maxmemoryPolicy = await configValue(client, "maxmemory-policy");
  const appendonly = await configValue(client, "appendonly");
  const save = await configValue(client, "save");
  if (!maxmemoryPolicy || appendonly === undefined) {
    throw new Error("CONFIG GET did not report maxmemory-policy/appendonly");
  }
  return {
    source: "config",
    maxmemoryPolicy,
    appendonly,
    save: save ?? "",
  };
}

async function readFromInfo(client: PostureClient): Promise<
  QueueRedisPosture
> {
  const memory = parseInfo(String(await client.call("INFO", "memory")));
  const persistence = parseInfo(
    String(await client.call("INFO", "persistence")),
  );
  const maxmemoryPolicy = memory.get("maxmemory_policy") ??
    persistence.get("maxmemory_policy") ?? "";
  if (!maxmemoryPolicy) {
    throw new Error("INFO memory did not report maxmemory_policy");
  }
  const rdbSaves = Number.parseInt(persistence.get("rdb_saves") ?? "", 10);
  return {
    source: "info",
    maxmemoryPolicy,
    appendonly: persistence.get("aof_enabled") ?? "",
    save: "",
    ...(Number.isFinite(rdbSaves) ? { rdbSaves } : {}),
    ...(persistence.has("rdb_last_bgsave_status")
      ? { rdbLastBgsaveStatus: persistence.get("rdb_last_bgsave_status")! }
      : {}),
  };
}

/**
 * Reads the server-side memory and persistence policy: CONFIG GET first,
 * INFO when CONFIG is refused. Throws QueuePostureError when neither
 * answers, so a production worker cannot start on an unknown posture.
 */
export async function readQueueRedisPosture(
  client: PostureClient | Redis,
): Promise<QueueRedisPosture> {
  const probe = client as PostureClient;
  let configRefused: string;
  try {
    return await readFromConfig(probe);
  } catch (error) {
    configRefused = reason(error);
  }
  try {
    return { ...(await readFromInfo(probe)), configRefused };
  } catch (error) {
    const problems = [
      `CONFIG GET refused (${configRefused})`,
      `INFO refused (${reason(error)})`,
    ];
    throw new QueuePostureError(
      `Queue Redis posture unreadable: ${problems.join("; ")}.`,
      problems,
    );
  }
}

const isOn = (value: string): boolean =>
  ["yes", "1"].includes(value.trim().toLowerCase());

/** Whether the posture proves the queue keys survive a restart. */
export function isPersisted(posture: QueueRedisPosture): boolean {
  if (isOn(posture.appendonly)) return true;
  if (posture.source === "config") return posture.save.trim().length > 0;
  // INFO shows no save policy. Snapshots that have run and succeeded are
  // the evidence: managed Redis refuses BGSAVE from clients, so they were
  // taken by the provider's schedule. A fresh server before its first
  // snapshot is not yet proven; AOF has no such gap.
  return (posture.rdbSaves ?? 0) > 0 && posture.rdbLastBgsaveStatus === "ok";
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
        }, from ${posture.source}); evicted queue keys lose jobs.`,
      );
    }
    if (!isPersisted(posture)) {
      problems.push(
        posture.source === "config"
          ? "queue keys must be persisted (appendonly yes or an RDB save policy) so a Redis restart cannot drop enqueued jobs."
          : "queue keys must be persisted, and INFO persistence shows neither aof_enabled:1 nor a successful snapshot; turn on AOF (Redis Cloud: Data persistence, Append-only file every 1 second).",
      );
    }
  }
  return problems;
}

/** Reads the posture and throws in production when problems exist. */
export async function assertQueueRedisPosture(
  client: PostureClient | Redis,
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
