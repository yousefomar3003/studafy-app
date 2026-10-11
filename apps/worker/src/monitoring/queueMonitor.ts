import type { Logger } from "@studafy/observability";
import type { AlertSender } from "@studafy/infrastructure";

/**
 * Launch plan 4.7: alerts on background work, sent to Telegram.
 *
 * Every interval the monitor samples each source - the BullMQ queues and the
 * Postgres-polled backlogs (notification outbox, file scan) - and compares
 * the sample with thresholds from config:
 *
 *   depth     waiting jobs, pending outbox rows or quarantined files;
 *   age       the oldest of those, in seconds;
 *   failed    new failed jobs or dead letters within the window;
 *   stalled   a job active for longer than the stall limit, or BullMQ
 *             reporting a stalled job (its worker lost the lock) in the
 *             window.
 *
 * One incident sends one alert. The alert state lives in Redis, so several
 * worker machines send it once between them: the first to see a condition
 * opens it, a reminder goes out after the cooldown while it lasts, and the
 * one that sees it clear first sends the resolution. Alerts carry counts and
 * queue names only.
 *
 * A worker that is down cannot report itself; Axiom's "Worker silent"
 * monitor covers that (docs/deployment/fly-io.md section 6), and
 * `queue_monitor_tick` (always kept, never sampled) is one more line it can
 * count (docs/deployment/queue-alerts.md).
 */

export interface QueueSample {
  name: string;
  waiting: number;
  failed: number;
  oldestWaitingSeconds: number;
  oldestActiveSeconds: number;
  /** Stalled-job events since the previous sample. */
  stalledEvents: number;
}

export interface BacklogSample {
  name: string;
  /** Items waiting: pending outbox rows, quarantined files. */
  pending: number;
  oldestSeconds: number;
  /** Cumulative dead letters; the monitor alerts on their growth. */
  deadLetters: number;
}

export interface MonitorSnapshot {
  at: number;
  queues: QueueSample[];
  backlogs: BacklogSample[];
}

export interface Thresholds {
  maxDepth: number;
  maxAgeSeconds: number;
  maxFailedPerWindow: number;
  windowSeconds: number;
  stallSeconds: number;
}

export interface Finding {
  /** Stable identity of the condition, for de-duplication: "notifications:depth". */
  key: string;
  summary: string;
}

const CONDITIONS = ["depth", "age", "failed", "stalled"] as const;

/** Every key a source can raise, so cleared conditions can be resolved. */
export function possibleKeys(snapshot: MonitorSnapshot): string[] {
  return [
    ...snapshot.queues.map((q) => q.name),
    ...snapshot.backlogs.map((b) => b.name),
  ].flatMap((name) => CONDITIONS.map((condition) => `${name}:${condition}`));
}

/**
 * The conditions firing now. `history` is oldest first and ends with the
 * current snapshot; growth is measured against the oldest snapshot inside
 * the window.
 */
export function evaluate(
  history: MonitorSnapshot[],
  thresholds: Thresholds,
): Finding[] {
  const current = history.at(-1);
  if (!current) return [];
  const windowStart = current.at - thresholds.windowSeconds * 1000;
  const inWindow = history.filter((s) => s.at >= windowStart);
  const baseline = inWindow[0] ?? current;
  const findings: Finding[] = [];

  for (const queue of current.queues) {
    const name = `${queue.name} queue`;
    if (queue.waiting > thresholds.maxDepth) {
      findings.push({
        key: `${queue.name}:depth`,
        summary:
          `${name}: ${queue.waiting} jobs waiting (limit ${thresholds.maxDepth})`,
      });
    }
    if (queue.oldestWaitingSeconds > thresholds.maxAgeSeconds) {
      findings.push({
        key: `${queue.name}:age`,
        summary: `${name}: oldest job has waited ${
          duration(queue.oldestWaitingSeconds)
        } (limit ${duration(thresholds.maxAgeSeconds)})`,
      });
    }
    const before = baseline.queues.find((q) => q.name === queue.name);
    // Failed jobs are trimmed by the queue's removal policy, so the count
    // can fall; growth below zero is no growth.
    const newFailures = Math.max(
      0,
      queue.failed - (before?.failed ?? queue.failed),
    );
    if (newFailures >= thresholds.maxFailedPerWindow) {
      findings.push({
        key: `${queue.name}:failed`,
        summary: `${name}: ${newFailures} jobs failed in the last ${
          duration(thresholds.windowSeconds)
        } (limit ${thresholds.maxFailedPerWindow})`,
      });
    }
    const stalledEvents = inWindow.reduce(
      (sum, s) =>
        sum + (s.queues.find((q) => q.name === queue.name)?.stalledEvents ?? 0),
      0,
    );
    if (queue.oldestActiveSeconds > thresholds.stallSeconds) {
      findings.push({
        key: `${queue.name}:stalled`,
        summary: `${name}: a job has been running for ${
          duration(queue.oldestActiveSeconds)
        } (limit ${
          duration(thresholds.stallSeconds)
        }); its worker may be stuck`,
      });
    } else if (stalledEvents > 0) {
      findings.push({
        key: `${queue.name}:stalled`,
        summary: `${name}: ${stalledEvents} jobs stalled in the last ${
          duration(thresholds.windowSeconds)
        } (a worker stopped while processing them)`,
      });
    }
  }

  for (const backlog of current.backlogs) {
    if (backlog.pending > thresholds.maxDepth) {
      findings.push({
        key: `${backlog.name}:depth`,
        summary:
          `${backlog.name}: ${backlog.pending} waiting (limit ${thresholds.maxDepth})`,
      });
    }
    if (backlog.oldestSeconds > thresholds.maxAgeSeconds) {
      findings.push({
        key: `${backlog.name}:age`,
        summary: `${backlog.name}: oldest has waited ${
          duration(backlog.oldestSeconds)
        } (limit ${duration(thresholds.maxAgeSeconds)})`,
      });
    }
    const before = baseline.backlogs.find((b) => b.name === backlog.name);
    const newDead = Math.max(
      0,
      backlog.deadLetters - (before?.deadLetters ?? backlog.deadLetters),
    );
    if (newDead >= thresholds.maxFailedPerWindow) {
      findings.push({
        key: `${backlog.name}:failed`,
        summary: `${backlog.name}: ${newDead} new dead letters in the last ${
          duration(thresholds.windowSeconds)
        } (limit ${thresholds.maxFailedPerWindow})`,
      });
    }
  }
  return findings;
}

export function duration(seconds: number): string {
  const s = Math.round(seconds);
  if (s < 120) return `${s}s`;
  if (s < 7200) return `${Math.round(s / 60)} min`;
  return `${Math.round(s / 3600)} h`;
}

/**
 * Shared alert state. `open` returns "new" for a condition nobody has
 * reported, "reminder" once its cooldown has passed, and null while it is
 * cooling down. `close` returns true for exactly one caller once a reported
 * condition clears.
 */
export interface AlertState {
  open(
    key: string,
    cooldownSeconds: number,
  ): Promise<"new" | "reminder" | null>;
  close(key: string): Promise<boolean>;
}

/** The subset of ioredis the alert state uses. */
export interface AlertRedis {
  set(
    key: string,
    value: string,
    mode: "EX",
    seconds: number,
    flag: "NX",
  ): Promise<"OK" | null>;
  set(key: string, value: string, flag: "NX"): Promise<"OK" | null>;
  del(...keys: string[]): Promise<number>;
}

export function redisAlertState(redis: AlertRedis, prefix: string): AlertState {
  // `cool:` expires after the cooldown and gates sending; `open:` stays until
  // the condition clears and says whether this is the first report.
  return {
    async open(key, cooldownSeconds) {
      const cool = await redis.set(
        `${prefix}:alerts:cool:${key}`,
        "1",
        "EX",
        cooldownSeconds,
        "NX",
      );
      if (cool !== "OK") return null;
      const first = await redis.set(`${prefix}:alerts:open:${key}`, "1", "NX");
      return first === "OK" ? "new" : "reminder";
    },
    async close(key) {
      const removed = await redis.del(`${prefix}:alerts:open:${key}`);
      if (removed === 0) return false;
      await redis.del(`${prefix}:alerts:cool:${key}`);
      return true;
    },
  };
}

/** Per-process state, for tests and as the fallback when Redis fails. */
export function memoryAlertState(now: () => number = Date.now): AlertState {
  const open = new Set<string>();
  const coolUntil = new Map<string, number>();
  return {
    open(key, cooldownSeconds) {
      if ((coolUntil.get(key) ?? 0) > now()) return Promise.resolve(null);
      coolUntil.set(key, now() + cooldownSeconds * 1000);
      if (open.has(key)) return Promise.resolve("reminder");
      open.add(key);
      return Promise.resolve("new");
    },
    close(key) {
      coolUntil.delete(key);
      return Promise.resolve(open.delete(key));
    },
  };
}

export interface QueueMonitorOptions {
  /** Takes one sample of every source. */
  sample: () => Promise<Omit<MonitorSnapshot, "at">>;
  thresholds: Thresholds;
  cooldownSeconds: number;
  state: AlertState;
  sender: AlertSender;
  logger: Logger;
  environment: string;
  intervalMs: number;
  now?: () => number;
}

export interface QueueMonitorRuntime {
  /** One sample, evaluation and round of alerts; returns the findings. */
  runOnce(): Promise<Finding[]>;
  close(): Promise<void>;
}

export function startQueueMonitor(
  options: QueueMonitorOptions,
): QueueMonitorRuntime {
  const now = options.now ?? Date.now;
  const fallback = memoryAlertState(now);
  const history: MonitorSnapshot[] = [];
  let running: Promise<Finding[]> | null = null;
  let closed = false;

  const withState = async <T>(
    use: (state: AlertState) => Promise<T>,
  ): Promise<T> => {
    try {
      return await use(options.state);
    } catch (error) {
      options.logger.warn("queue_alert_state_unavailable", {
        error_name: error instanceof Error ? error.name : "unknown",
      });
      return use(fallback);
    }
  };

  const send = async (text: string, key: string, kind: string) => {
    try {
      await options.sender.send(text);
      options.logger.info("queue_alert_sent", { key, kind });
    } catch (error) {
      options.logger.error("queue_alert_send_failed", {
        key,
        kind,
        error_code: error instanceof Error ? error.message : "unknown",
      });
    }
  };

  const runOnce = async (): Promise<Finding[]> => {
    const snapshot = { at: now(), ...(await options.sample()) };
    history.push(snapshot);
    const keep = snapshot.at - options.thresholds.windowSeconds * 1000;
    while (history.length > 1 && (history[0]?.at ?? keep) < keep) {
      history.shift();
    }

    const findings = evaluate(history, options.thresholds);
    const firing = new Set(findings.map((f) => f.key));
    const env = options.environment;
    for (const finding of findings) {
      const kind = await withState((state) =>
        state.open(finding.key, options.cooldownSeconds)
      );
      if (kind === "new") {
        await send(
          `ALERT Studafy ${env}: ${finding.summary}`,
          finding.key,
          kind,
        );
      } else if (kind === "reminder") {
        await send(
          `STILL HAPPENING Studafy ${env}: ${finding.summary}`,
          finding.key,
          kind,
        );
      }
    }
    for (const key of possibleKeys(snapshot)) {
      if (firing.has(key)) continue;
      if (await withState((state) => state.close(key))) {
        await send(
          `RESOLVED Studafy ${env}: ${
            key.replace(":", " ")
          } is back within its limit`,
          key,
          "resolved",
        );
      }
    }
    options.logger.info("queue_monitor_tick", {
      firing: findings.length,
      sources: snapshot.queues.length + snapshot.backlogs.length,
    });
    return findings;
  };

  const tick = () => {
    if (running || closed) return;
    running = runOnce().catch((error) => {
      options.logger.error("queue_monitor_failed", {
        error_name: error instanceof Error ? error.name : "unknown",
      });
      return [];
    }).finally(() => running = null);
  };
  // The first sample comes one interval after start: a restart is not an
  // incident, and the failed-job window needs a baseline anyway.
  const timer = setInterval(tick, options.intervalMs);

  return {
    runOnce,
    async close() {
      closed = true;
      clearInterval(timer);
      await running;
    },
  };
}
