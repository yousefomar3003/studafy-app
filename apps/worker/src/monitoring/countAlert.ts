import type { AlertSender } from "@studafy/infrastructure";
import type { Logger } from "@studafy/observability";
import { type AlertState, memoryAlertState } from "./queueMonitor";
import { errorFields } from "../platform/jobGuards";

/**
 * One count that should be zero, reported to the same Telegram chat as the
 * queue alerts and with the same shared state (`queueMonitor.ts`): the first
 * time the count is above zero sends `ALERT`, a reminder goes out once per
 * cooldown (a day by default) while it stays above zero, and `RESOLVED` once
 * it is back to zero. With several worker machines each message is sent once.
 * The message carries the count only, never an address or an id.
 */
export interface CountAlertOptions {
  /** Stable identity of the condition, e.g. "inactive_warnings_undeliverable". */
  key: string;
  /** The sentence for a count above zero. */
  summary: (count: number) => string;
  /** The sentence for a count back at zero. */
  resolved: string;
  state: AlertState;
  sender: AlertSender;
  logger: Logger;
  environment: string;
  cooldownSeconds?: number;
  now?: () => number;
}

export type CountAlert = (
  count: number,
) => Promise<"new" | "reminder" | "resolved" | null>;

export const DAY_SECONDS = 86_400;

export function createCountAlert(options: CountAlertOptions): CountAlert {
  const cooldown = options.cooldownSeconds ?? DAY_SECONDS;
  const fallback = memoryAlertState(options.now);

  const withState = async <T>(
    use: (state: AlertState) => Promise<T>,
  ): Promise<T> => {
    try {
      return await use(options.state);
    } catch (error) {
      options.logger.warn("queue_alert_state_unavailable", {
        ...errorFields(error),
      });
      return use(fallback);
    }
  };

  const send = async (text: string, kind: string) => {
    try {
      await options.sender.send(text);
      options.logger.info("queue_alert_sent", { key: options.key, kind });
    } catch (error) {
      options.logger.error("queue_alert_send_failed", {
        key: options.key,
        kind,
        error_code: error instanceof Error ? error.message : "unknown",
      });
    }
  };

  return async (count) => {
    const env = options.environment;
    if (count > 0) {
      const kind = await withState((state) =>
        state.open(options.key, cooldown)
      );
      if (kind === "new") {
        await send(`ALERT Studafy ${env}: ${options.summary(count)}`, kind);
      } else if (kind === "reminder") {
        await send(
          `STILL HAPPENING Studafy ${env}: ${options.summary(count)}`,
          kind,
        );
      }
      return kind;
    }
    if (await withState((state) => state.close(options.key))) {
      await send(`RESOLVED Studafy ${env}: ${options.resolved}`, "resolved");
      return "resolved";
    }
    return null;
  };
}
