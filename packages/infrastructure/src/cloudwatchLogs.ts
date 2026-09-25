/**
 * AWS CloudWatch Logs transport for the JSON logger.
 *
 * This is a `LogSink` — the extension point `createJsonLogger(service, version,
 * level, sink)` already exposes — not a second logger. Lines arrive already
 * serialized and already redacted, because `createRedactingLogger` wraps the
 * logger rather than the sink, so nothing secret can reach AWS through here.
 *
 * Two properties matter more than throughput:
 *
 * 1. A logging outage must never become a request failure. Every path is
 *    wrapped; `record` only ever enqueues, and the buffer is bounded so a long
 *    outage drops the oldest lines instead of exhausting memory.
 * 2. One stream per process, not per request. The stream is created once and
 *    reused; `PutLogEvents` is batched on an interval and on AWS's own size
 *    limits.
 */
import {
  CloudWatchLogsClient,
  CreateLogStreamCommand,
  type InputLogEvent,
  PutLogEventsCommand,
} from "@aws-sdk/client-cloudwatch-logs";

/** The subset of the AWS client this module uses, so tests can substitute one. */
export interface CloudWatchLogsSender {
  send(command: unknown): Promise<unknown>;
}

export interface CloudWatchSinkOptions {
  region: string;
  logGroupName: string;
  /** Distinguishes concurrent processes writing to one group. */
  streamPrefix?: string;
  /** How long lines may wait before a flush is forced. */
  flushIntervalMs?: number;
  /** Lines held while AWS is unreachable before the oldest are dropped. */
  maxBufferedEvents?: number;
  /** Attempts per batch, including the first. */
  maxAttempts?: number;
  client?: CloudWatchLogsSender;
  now?: () => number;
  /** Where transport failures are reported. Defaults to `console.warn`. */
  onFailure?: (message: string) => void;
}

export interface CloudWatchSink {
  /** A `LogSink`: enqueues one serialized line. Never throws, never blocks. */
  record(line: string): void;
  /** Sends everything buffered. Safe to call from a shutdown hook. */
  flush(): Promise<void>;
  /** Stops the timer. Does not flush — call `flush` first. */
  close(): void;
}

// PutLogEvents caps a batch at 10 000 events and 1 MiB, where each event costs
// its UTF-8 bytes plus 26 bytes of overhead. We stay under both deliberately.
const MAX_BATCH_EVENTS = 10_000;
const MAX_BATCH_BYTES = 1_000_000;
const EVENT_OVERHEAD_BYTES = 26;
// A single event larger than the batch limit can never be sent, so it is
// dropped rather than blocking the queue behind it forever.
const MAX_EVENT_BYTES = MAX_BATCH_BYTES - EVENT_OVERHEAD_BYTES;

function byteLength(value: string): number {
  return new TextEncoder().encode(value).length;
}

function errorName(error: unknown): string {
  if (error instanceof Error) return error.name;
  return "UnknownError";
}

export function createCloudWatchSink(
  options: CloudWatchSinkOptions,
): CloudWatchSink {
  const {
    region,
    logGroupName,
    streamPrefix = "api",
    flushIntervalMs = 2_000,
    maxBufferedEvents = 10_000,
    maxAttempts = 3,
    now = Date.now,
    onFailure = (message: string) => console.warn(message),
  } = options;

  const client: CloudWatchLogsSender = options.client ??
    new CloudWatchLogsClient({ region });

  const date = new Date(now()).toISOString().slice(0, 10);
  const logStreamName = `${streamPrefix}/${date}/${
    globalThis.crypto.randomUUID().slice(0, 8)
  }`;

  const buffer: InputLogEvent[] = [];
  let bufferedBytes = 0;
  let dropped = 0;
  // Serializes every AWS call: concurrent requests append to `buffer`, but only
  // one PutLogEvents is ever in flight, so batches cannot interleave.
  let pending: Promise<void> = Promise.resolve();
  let streamReady: Promise<void> | null = null;
  let reportedFailure = false;
  let closed = false;

  function report(message: string): void {
    // One warning per process. A failing transport must not itself become a
    // per-line log storm on stdout.
    if (reportedFailure) return;
    reportedFailure = true;
    onFailure(message);
  }

  async function ensureStream(): Promise<void> {
    streamReady ??= (async () => {
      try {
        await client.send(
          new CreateLogStreamCommand({ logGroupName, logStreamName }),
        );
      } catch (error) {
        // The stream already existing is the expected outcome on restart.
        if (errorName(error) === "ResourceAlreadyExistsException") return;
        // Anything else is retried on the next flush rather than cached.
        streamReady = null;
        throw error;
      }
    })();
    await streamReady;
  }

  function takeBatch(): InputLogEvent[] {
    const batch: InputLogEvent[] = [];
    let batchBytes = 0;
    while (buffer.length > 0 && batch.length < MAX_BATCH_EVENTS) {
      const event = buffer[0]!;
      const cost = byteLength(event.message ?? "") + EVENT_OVERHEAD_BYTES;
      if (batchBytes + cost > MAX_BATCH_BYTES) break;
      batch.push(event);
      batchBytes += cost;
      buffer.shift();
      bufferedBytes -= cost;
    }
    return batch;
  }

  async function sendBatch(batch: InputLogEvent[]): Promise<void> {
    let attempt = 0;
    for (;;) {
      attempt += 1;
      try {
        await client.send(
          new PutLogEventsCommand({
            logGroupName,
            logStreamName,
            // CloudWatch requires chronological order within a batch.
            logEvents: batch,
          }),
        );
        return;
      } catch (error) {
        const name = errorName(error);
        // Sequence tokens are no longer required, and a batch reported as
        // already accepted is a success from our side.
        if (name === "DataAlreadyAcceptedException") return;
        if (name === "InvalidSequenceTokenException" && attempt < maxAttempts) {
          continue;
        }
        if (attempt >= maxAttempts) throw error;
        await new Promise((resolve) =>
          setTimeout(resolve, 100 * 2 ** (attempt - 1))
        );
      }
    }
  }

  async function drain(): Promise<void> {
    if (buffer.length === 0) return;
    try {
      await ensureStream();
      while (buffer.length > 0) {
        const batch = takeBatch();
        if (batch.length === 0) break;
        await sendBatch(batch);
      }
      if (dropped > 0) {
        const lost = dropped;
        dropped = 0;
        report(
          `cloudwatch_logs_dropped: ${lost} log line(s) discarded while the transport was unavailable`,
        );
      }
    } catch (error) {
      // Deliberately swallowed: the caller is a request handler or a timer.
      report(
        `cloudwatch_logs_unavailable: ${
          errorName(error)
        } — logging continues on stdout`,
      );
    }
  }

  function schedule(): void {
    pending = pending.then(drain, drain);
  }

  const timer = setInterval(() => {
    if (buffer.length > 0) schedule();
  }, flushIntervalMs);
  // Never hold the process open for the sake of the log timer.
  (timer as unknown as { unref?: () => void }).unref?.();

  return {
    record(line: string): void {
      if (closed) return;
      try {
        const size = byteLength(line);
        if (size > MAX_EVENT_BYTES) {
          dropped += 1;
          return;
        }
        if (buffer.length >= maxBufferedEvents) {
          // Drop oldest: recent lines describe the current incident.
          const evicted = buffer.shift();
          if (evicted) {
            bufferedBytes -= byteLength(evicted.message ?? "") +
              EVENT_OVERHEAD_BYTES;
          }
          dropped += 1;
        }
        buffer.push({ timestamp: now(), message: line });
        bufferedBytes += size + EVENT_OVERHEAD_BYTES;
        if (
          buffer.length >= MAX_BATCH_EVENTS ||
          bufferedBytes >= MAX_BATCH_BYTES
        ) {
          schedule();
        }
      } catch {
        // A sink must never throw into the code that asked to log.
      }
    },
    async flush(): Promise<void> {
      schedule();
      await pending;
    },
    close(): void {
      closed = true;
      clearInterval(timer);
    },
  };
}
