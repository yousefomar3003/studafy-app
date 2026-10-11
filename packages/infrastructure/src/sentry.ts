/**
 * Error reports to Sentry (OPS-090), for the API and the worker.
 *
 * Most people on Studafy are children, so nothing personal leaves the
 * process: no user, no request body, headers, cookies or query string, no
 * database values, queue arguments, AI prompts or stack-frame variables, no
 * console breadcrumbs (those are our own log lines, which carry user ids),
 * and emails, long numbers and tokens are masked in any text that is sent.
 * Reports are machine codes and stack traces only.
 *
 * Two kinds of report:
 *
 * - `captureException`: an unexpected exception, with its stack - the API's
 *   500s;
 * - `captureLogLine`: an error-level log line that has no exception object
 *   (a background job that gave up, a poll that failed). It is grouped by
 *   service and event, so one failing job is one issue, not thousands.
 *
 * Reporting never throws and never blocks the request.
 */
import * as Sentry from "@sentry/bun";

export interface ErrorReporter {
  captureException(error: unknown, context?: Record<string, unknown>): void;
  captureLogLine(line: string): void;
  flush(timeoutMs?: number): Promise<boolean>;
}

export interface SentryReporterOptions {
  dsn: string;
  environment: string;
  release: string;
  service: "api" | "worker";
}

/** Log fields safe to attach to a report: codes and ids of work, never people. */
const SAFE_FIELDS = new Set([
  "event",
  "service",
  "route",
  "method",
  "status",
  "error_code",
  "error_kind",
  "queue",
  "job_id",
  "outbox_id",
  "attempt",
  "attempts_made",
  "request_id",
]);

/**
 * Events reported elsewhere: the API's `http_error` is captured with its
 * exception from the error handler, so its log line would be a duplicate.
 */
const REPORTED_WITH_EXCEPTION = new Set(["http_error"]);

const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
const JWT = /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g;
const BEARER = /Bearer\s+[A-Za-z0-9._~+/-]+=*/gi;
const LONG_NUMBER = /\d{7,}/g;

/** Masks anything in free text that could identify a person or grant access. */
export function scrubText(text: string): string {
  return text
    .replace(JWT, "[token]")
    .replace(BEARER, "Bearer [token]")
    .replace(EMAIL, "[email]")
    .replace(LONG_NUMBER, "[number]");
}

/** Only the safe fields of a log line, with any text masked. */
export function safeFields(
  fields: Record<string, unknown>,
): Record<string, string | number | boolean> {
  const out: Record<string, string | number | boolean> = {};
  for (const [key, value] of Object.entries(fields)) {
    if (!SAFE_FIELDS.has(key)) continue;
    if (typeof value === "number" || typeof value === "boolean") {
      out[key] = value;
    } else if (typeof value === "string") {
      out[key] = scrubText(value).slice(0, 200);
    }
  }
  return out;
}

/** What a Sentry report for an error-level log line contains, or null. */
export function logLineReport(line: string): {
  message: string;
  fingerprint: string[];
  tags: Record<string, string>;
  extra: Record<string, string | number | boolean>;
} | null {
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(line) as Record<string, unknown>;
  } catch {
    return null;
  }
  if (parsed["level"] !== "error") return null;
  const event = String(parsed["event"] ?? "");
  if (!event || REPORTED_WITH_EXCEPTION.has(event)) return null;
  const service = String(parsed["service"] ?? "unknown");
  const extra = safeFields(parsed);
  const code = typeof extra["error_code"] === "string"
    ? extra["error_code"]
    : undefined;
  return {
    message: code ? `${event}: ${code}` : event,
    fingerprint: [service, event, ...(code ? [code] : [])],
    tags: { service, event, ...(code ? { error_code: code } : {}) },
    extra,
  };
}

/** Removes everything personal from an event before it leaves the process. */
export function scrubEvent<T extends Sentry.ErrorEvent>(event: T): T {
  delete event.user;
  if (event.request) {
    const url = event.request.url?.split("?")[0];
    event.request = {
      method: event.request.method,
      ...(url ? { url } : {}),
    };
  }
  if (event.message) event.message = scrubText(event.message);
  for (const exception of event.exception?.values ?? []) {
    if (exception.value) exception.value = scrubText(exception.value);
  }
  for (const breadcrumb of event.breadcrumbs ?? []) {
    if (breadcrumb.message) breadcrumb.message = scrubText(breadcrumb.message);
    delete breadcrumb.data;
  }
  return event;
}

export function createSentryReporter(
  options: SentryReporterOptions,
): ErrorReporter {
  Sentry.init({
    dsn: options.dsn,
    environment: options.environment,
    release: `studafy-${options.service}@${options.release}`,
    // Sentry's defaults collect user info, headers, cookies, query strings,
    // request and response bodies, database query values, queue job
    // arguments, AI prompts and outputs, and local variable values in
    // stack frames. Any of these can hold a child's data, so every one is
    // off; scrubEvent below is the second line of defence.
    dataCollection: {
      userInfo: false,
      cookies: false,
      httpHeaders: false,
      httpBodies: [],
      urlQueryParams: false,
      graphQL: { document: false, variables: false },
      genAI: { inputs: false, outputs: false },
      databaseQueryData: false,
      queues: false,
      stackFrameVariables: false,
    },
    // Errors only: no performance tracing, which would also carry URLs and
    // timings for every request.
    tracesSampleRate: 0,
    initialScope: { tags: { service: options.service } },
    beforeBreadcrumb: (breadcrumb) =>
      // Console breadcrumbs are our own JSON log lines, which carry user ids.
      breadcrumb.category === "console" ? null : breadcrumb,
    beforeSend: (event) => scrubEvent(event),
  });

  return {
    captureException(error, context = {}) {
      try {
        Sentry.captureException(error, {
          tags: { service: options.service },
          extra: safeFields(context),
        });
      } catch {
        // Reporting must never break the request it describes.
      }
    },
    captureLogLine(line) {
      try {
        const report = logLineReport(line);
        if (!report) return;
        Sentry.captureMessage(report.message, {
          level: "error",
          fingerprint: report.fingerprint,
          tags: report.tags,
          extra: report.extra,
        });
      } catch {
        // As above.
      }
    },
    flush: (timeoutMs = 2_000) => Sentry.flush(timeoutMs).catch(() => false),
  };
}
