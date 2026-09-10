import type { LogLevel } from "@studafy/contracts";

export interface Logger {
  debug(event: string, fields?: Record<string, unknown>): void;
  info(event: string, fields?: Record<string, unknown>): void;
  warn(event: string, fields?: Record<string, unknown>): void;
  error(event: string, fields?: Record<string, unknown>): void;
  child(boundFields: Record<string, unknown>): Logger;
}

export type LogSink = (line: string) => void;

const LEVEL_WEIGHT: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

/** Values that cannot survive JSON serialization are rendered as markers. */
function safeValue(value: unknown): unknown {
  if (value === null) return null;
  switch (typeof value) {
    case "string":
    case "number":
    case "boolean":
      return value;
    case "undefined":
      return null;
    case "bigint":
      return "<bigint>";
    case "function":
      return "<function>";
    case "symbol":
      return "<symbol>";
    case "object":
      return value;
  }
}

function normalize(fields: Record<string, unknown>): Record<string, unknown> {
  const output: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    output[key] = safeValue(value);
  }
  return output;
}

export function createJsonLogger(
  service: string,
  version: string,
  level: LogLevel,
  sink: LogSink = (line) => console.log(line),
): Logger {
  function emit(
    entryLevel: LogLevel,
    event: string,
    fields: Record<string, unknown>,
  ): void {
    if (LEVEL_WEIGHT[entryLevel] < LEVEL_WEIGHT[level]) return;
    const line = JSON.stringify({
      timestamp: new Date().toISOString(),
      level: entryLevel,
      service,
      version,
      event,
      ...normalize(fields),
    });
    sink(line);
  }

  function makeLogger(
    bound: Record<string, unknown>,
  ): Logger {
    return {
      debug: (event, fields = {}) => emit("debug", event, { ...bound, ...fields }),
      info: (event, fields = {}) => emit("info", event, { ...bound, ...fields }),
      warn: (event, fields = {}) => emit("warn", event, { ...bound, ...fields }),
      error: (event, fields = {}) =>
        emit("error", event, { ...bound, ...fields }),
      child: (childFields) => makeLogger({ ...bound, ...childFields }),
    };
  }

  return makeLogger({});
}

/** Returns the given request id, or a fresh RFC 4122 v4 UUID. */
export function newRequestId(existing?: string): string {
  if (existing && existing.length > 0) return existing;
  return globalThis.crypto.randomUUID();
}
