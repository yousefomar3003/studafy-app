import type { Logger } from "@studafy/observability";

const SAFE_KEYS = new Set(["requestid", "route"]);
const SECRET_KEYS = [
  "authorization",
  "cookie",
  "token",
  "secret",
  "password",
  "grant",
  "receipt",
  "body",
  "content",
  "objectkey",
  "objectpath",
  "signedurl",
  "idtoken",
  "error",
  "message",
  "stack",
  "sql",
] as const;
const MAX_DEPTH = 5;
const MAX_ITEMS = 32;
const MAX_STRING = 512;

function redact(value: unknown, key: string, depth: number): unknown {
  const normalizedKey = key.replace(/[^a-z0-9]/gi, "").toLowerCase();
  if (
    !SAFE_KEYS.has(normalizedKey) &&
    SECRET_KEYS.some((secret) => normalizedKey.includes(secret))
  ) {
    return "<redacted>";
  }
  if (depth >= MAX_DEPTH) return "<max-depth>";
  if (typeof value === "string") {
    return value.length > MAX_STRING
      ? `${value.slice(0, MAX_STRING)}<truncated>`
      : value;
  }
  if (Array.isArray(value)) {
    return value.slice(0, MAX_ITEMS).map((entry) =>
      redact(entry, key, depth + 1)
    );
  }
  if (value && typeof value === "object") {
    const output: Record<string, unknown> = {};
    for (const [childKey, child] of Object.entries(value).slice(0, MAX_ITEMS)) {
      output[childKey] = redact(child, childKey, depth + 1);
    }
    return output;
  }
  return value;
}

export function redactApiFields(
  fields: Record<string, unknown>,
): Record<string, unknown> {
  return redact(fields, "fields", 0) as Record<string, unknown>;
}

/** Wraps every API log call so accidental nested secrets fail closed. */
export function createRedactingLogger(inner: Logger): Logger {
  const wrap =
    (method: "debug" | "info" | "warn" | "error") =>
    (event: string, fields: Record<string, unknown> = {}) =>
      inner[method](event, redactApiFields(fields));
  return {
    debug: wrap("debug"),
    info: wrap("info"),
    warn: wrap("warn"),
    error: wrap("error"),
    child: (fields) =>
      createRedactingLogger(inner.child(redactApiFields(fields))),
  };
}
