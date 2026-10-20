import type { Logger } from "@studafy/observability";
import { errorFields } from "./jobGuards";

export interface GuardedPoll {
  /**
   * Starts a run now unless one is in flight; resolves when the run settles
   * (the one in flight, if there was one). Never rejects: a failed run is
   * logged as `<name>_poll_failed`.
   */
  run(): Promise<void>;
  /** Stops the interval, then waits for the run in flight. */
  close(): Promise<void>;
}

export interface GuardedPollOptions {
  /** Names the poll in logs: `<name>_poll_failed`, `poll_stalled`. */
  name: string;
  intervalMs: number;
  run: () => Promise<unknown>;
  logger: Logger;
  /** Run once straight away as well (a restart picks up at once). */
  runAtStart?: boolean;
  /**
   * How long a run may stay in flight before every skipped tick says so,
   * at most once per this period. Default: five intervals, at least a
   * minute.
   */
  stallAfterMs?: number;
  now?: () => number;
}

/**
 * A poll on an interval that never overlaps itself (worker stall,
 * 2026-10-20). A tick that finds the previous run still going is skipped,
 * so a slow or stuck run cannot pile up new ones that each wait for a
 * database connection and starve every other poller sharing the pool. A
 * run stuck for longer than `stallAfterMs` is logged as `poll_stalled`
 * (an error, so it reaches Sentry) instead of going quiet.
 */
export function startGuardedPoll(options: GuardedPollOptions): GuardedPoll {
  const now = options.now ?? Date.now;
  const stallAfterMs = options.stallAfterMs ??
    Math.max(options.intervalMs * 5, 60_000);
  let running: Promise<void> | null = null;
  let startedAt = 0;
  let lastStallReport = 0;
  let closed = false;

  const reportStall = () => {
    const inFlight = now() - startedAt;
    if (inFlight < stallAfterMs) return;
    if (lastStallReport && now() - lastStallReport < stallAfterMs) return;
    lastStallReport = now();
    options.logger.error("poll_stalled", {
      poll: options.name,
      in_flight_seconds: Math.round(inFlight / 1000),
    });
  };

  const run = (): Promise<void> => {
    if (running) {
      reportStall();
      return running;
    }
    if (closed) return Promise.resolve();
    startedAt = now();
    lastStallReport = 0;
    const current = Promise.resolve()
      .then(options.run)
      .then(() => undefined, (error: unknown) => {
        options.logger.error(
          `${options.name}_poll_failed`,
          errorFields(error),
        );
      })
      .finally(() => {
        if (running === current) running = null;
      });
    running = current;
    return current;
  };

  const timer = setInterval(() => void run(), options.intervalMs);
  if (options.runAtStart) void run();

  return {
    run,
    async close() {
      closed = true;
      clearInterval(timer);
      await running;
    },
  };
}
