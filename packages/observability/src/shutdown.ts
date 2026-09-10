import type { Logger } from "./logger";
import { logShutdownStep } from "./events";

export interface SignalSource {
  on(signal: "SIGTERM" | "SIGINT", listener: () => void): void;
}

export interface GracefulShutdownOptions {
  logger: Logger;
  /** Runs once a signal is received: stop accepting, drain, close clients. */
  onClose: () => Promise<void>;
  /** Upper bound for the whole shutdown sequence before exiting uncleanly. */
  timeoutMs?: number;
  /** Injection point for tests. */
  signals?: SignalSource;
  /** Injection point for tests. */
  exit?: (code: number) => void;
}

/**
 * Installs SIGTERM/SIGINT handlers. The sequence is: stop accepting work and
 * close dependencies (onClose), then exit 0. If onClose exceeds the timeout,
 * the process exits 1 so orchestrators restart it instead of hanging.
 */
export function installGracefulShutdown(
  options: GracefulShutdownOptions,
): void {
  const {
    logger,
    onClose,
    timeoutMs = 10_000,
    signals = process,
    exit = (code: number) => process.exit(code),
  } = options;

  let closing = false;
  const handle = (signal: "SIGTERM" | "SIGINT") => {
    if (closing) return;
    closing = true;
    logShutdownStep(logger, "signal_received", { signal });

    const timeout = setTimeout(() => {
      logShutdownStep(logger, "timeout", { timeout_ms: timeoutMs });
      exit(1);
    }, timeoutMs);

    onClose()
      .then(() => {
        clearTimeout(timeout);
        logShutdownStep(logger, "complete");
        exit(0);
      })
      .catch((error: unknown) => {
        clearTimeout(timeout);
        logShutdownStep(logger, "failed", {
          error_message:
            error instanceof Error ? error.message : String(error),
        });
        exit(1);
      });
  };

  signals.on("SIGTERM", () => handle("SIGTERM"));
  signals.on("SIGINT", () => handle("SIGINT"));
}
