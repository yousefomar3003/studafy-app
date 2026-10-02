import type { LogLevel } from "@studafy/contracts";

/**
 * Decides, line by line, whether a log line is worth keeping (OPS-090).
 *
 * Production ships every kept line to the log store, which charges by
 * volume, and most lines say only that a routine request went fine. So:
 *
 * - warnings and errors are always kept, and so is every request that
 *   failed (4xx/5xx) or was slow - these are what a problem is found by;
 * - the platform's own health checks are dropped;
 * - routine polling (the unread badge) keeps one line in `routineRate`;
 * - every other successful request, and every routine "job done", keeps
 *   one in `successRate`.
 *
 * A kept sampled line carries `sample_rate`, so a count in the log store
 * can be scaled back up (count / sample_rate). Lines that are never sampled
 * carry nothing. Audit history lives in the database, not in these lines,
 * and is never affected.
 */
export interface LogSamplingPolicy {
  /** Share of ordinary successful lines kept, 0..1. 1 keeps everything. */
  successRate: number;
  /** Share of routine polling requests kept, 0..1. */
  routineRate: number;
  /** A request at least this slow is always kept. */
  slowRequestMs: number;
  /** Routes whose successful requests are routine polling. */
  routineRoutes?: readonly string[];
  /** Routes whose successful requests are never kept (health checks). */
  droppedRoutes?: readonly string[];
  /** Events that only say a background job finished fine. */
  routineEvents?: readonly string[];
  /** Injected in tests; Math.random otherwise. */
  random?: () => number;
}

/** What to do with one line: drop it, or keep it (noting the rate if sampled). */
export type SamplingDecision =
  | { keep: false }
  | { keep: true; sampleRate?: number };

export type LogSampler = (
  level: LogLevel,
  event: string,
  fields: Record<string, unknown>,
) => SamplingDecision;

export const DEFAULT_ROUTINE_ROUTES = [
  "/v1/notifications/unread-count",
] as const;
export const DEFAULT_DROPPED_ROUTES = ["/healthz", "/readyz"] as const;
/**
 * Background work that finished fine, one line per item. Money (billing),
 * account rights and the per-minute backlog heartbeats the alerts read are
 * deliberately not here: those are always kept.
 */
export const DEFAULT_ROUTINE_EVENTS = [
  "notification_job_completed",
  "file_scan_completed",
  "channel_delivery",
  "job_processed",
] as const;

const KEEP: SamplingDecision = { keep: true };
const DROP: SamplingDecision = { keep: false };

function clampRate(rate: number): number {
  if (!Number.isFinite(rate)) return 1;
  return Math.min(1, Math.max(0, rate));
}

export function createLogSampler(policy: LogSamplingPolicy): LogSampler {
  const successRate = clampRate(policy.successRate);
  const routineRate = clampRate(policy.routineRate);
  const routineRoutes = new Set(policy.routineRoutes ?? DEFAULT_ROUTINE_ROUTES);
  const droppedRoutes = new Set(policy.droppedRoutes ?? DEFAULT_DROPPED_ROUTES);
  const routineEvents = new Set(policy.routineEvents ?? DEFAULT_ROUTINE_EVENTS);
  const random = policy.random ?? Math.random;

  const sample = (rate: number): SamplingDecision => {
    if (rate >= 1) return KEEP;
    if (rate <= 0) return DROP;
    return random() < rate ? { keep: true, sampleRate: rate } : DROP;
  };

  return (level, event, fields) => {
    if (level === "warn" || level === "error") return KEEP;

    if (event === "http_request_completed") {
      const status = Number(fields["status"]);
      if (!Number.isFinite(status) || status >= 400) return KEEP;
      const duration = Number(fields["duration_ms"]);
      if (Number.isFinite(duration) && duration >= policy.slowRequestMs) {
        return KEEP;
      }
      const route = String(fields["route"] ?? "");
      if (droppedRoutes.has(route)) return DROP;
      if (routineRoutes.has(route)) return sample(routineRate);
      return sample(successRate);
    }

    if (routineEvents.has(event)) return sample(successRate);
    return KEEP;
  };
}
