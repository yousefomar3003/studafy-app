/**
 * Reads a launch-day secrets file without ever showing a value.
 *
 * The format is the one `fly secrets import` reads: one `NAME=value` per
 * line, `#` comments and blank lines ignored, and a value spanning lines
 * written between triple quotes:
 *
 *   DATABASE_CA_CERT="""
 *   -----BEGIN CERTIFICATE-----
 *   ...
 *   -----END CERTIFICATE-----
 *   """
 *
 * A value is taken literally. A single-line value wrapped in quotes is
 * refused, because Fly would store the quotes as part of the secret.
 *
 * A name may be scoped to one app with a prefix, `API__`, `WORKER__` or
 * `SCANNER__` (API__DATABASE_URL); the scoped value wins for that app.
 *
 * Errors name the line number and the variable, never its value.
 */
import { readFileSync, statSync } from "node:fs";

export type Secrets = ReadonlyMap<string, string>;

export class SecretsFileError extends Error {
  override name = "SecretsFileError";
}

const NAME = /^(?:(?:API|WORKER|SCANNER)__)?[A-Z][A-Z0-9_]*$/;
const TRIPLE = '"""';

export function parseSecrets(text: string): Map<string, string> {
  const secrets = new Map<string, string>();
  const lines = text.replace(/\r\n/g, "\n").split("\n");
  let open: { name: string; line: number; parts: string[] } | null = null;

  const store = (name: string, value: string, line: number) => {
    if (secrets.has(name)) {
      throw new SecretsFileError(`line ${line}: ${name} is set twice`);
    }
    if (value.length === 0) {
      throw new SecretsFileError(`line ${line}: ${name} is empty`);
    }
    secrets.set(name, value);
  };

  lines.forEach((raw, index) => {
    const line = index + 1;
    if (open) {
      const end = raw.trimEnd();
      if (end.endsWith(TRIPLE)) {
        open.parts.push(end.slice(0, -TRIPLE.length));
        const value = open.parts.join("\n").replace(/^\n+|\n+$/g, "");
        store(open.name, value, open.line);
        open = null;
      } else {
        open.parts.push(raw);
      }
      return;
    }
    const trimmed = raw.trim();
    if (trimmed === "" || trimmed.startsWith("#")) return;
    const equals = raw.indexOf("=");
    if (equals <= 0) {
      throw new SecretsFileError(
        `line ${line}: expected NAME=value (the line is not shown)`,
      );
    }
    const name = raw.slice(0, equals).trim();
    if (!NAME.test(name)) {
      throw new SecretsFileError(
        `line ${line}: "${
          name.slice(0, 64)
        }" is not a variable name (A-Z, 0-9, _)`,
      );
    }
    const value = raw.slice(equals + 1);
    if (value.startsWith(TRIPLE)) {
      const rest = value.slice(TRIPLE.length);
      if (rest.trimEnd().endsWith(TRIPLE) && rest.trim().length >= 3) {
        store(name, rest.trimEnd().slice(0, -TRIPLE.length), line);
      } else {
        open = { name, line, parts: [rest] };
      }
      return;
    }
    if (value !== value.trim()) {
      throw new SecretsFileError(
        `line ${line}: ${name} has spaces around its value; remove them`,
      );
    }
    if (
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'")))
    ) {
      throw new SecretsFileError(
        `line ${line}: ${name} is wrapped in quotes; Fly would keep them as part of the secret. Remove them`,
      );
    }
    store(name, value, line);
  });
  if (open) {
    const { name, line } = open;
    throw new SecretsFileError(
      `line ${line}: ${name} opens """ and never closes it`,
    );
  }
  return secrets;
}

/**
 * Reads [path]. Refuses a file others can read: it holds production keys.
 */
export function readSecretsFile(path: string): Map<string, string> {
  let mode: number;
  try {
    mode = statSync(path).mode;
  } catch {
    throw new SecretsFileError(`cannot read the secrets file ${path}`);
  }
  if (process.platform !== "win32" && (mode & 0o077) !== 0) {
    throw new SecretsFileError(
      `${path} can be read by other users; run: chmod 600 ${path}`,
    );
  }
  return parseSecrets(readFileSync(path, "utf8"));
}

/**
 * The `fly secrets import` input for [values]. Multi-line values go between
 * triple quotes; a value that itself holds triple quotes cannot be written.
 */
export function serializeForFly(values: ReadonlyMap<string, string>): string {
  const lines: string[] = [];
  for (const [name, value] of values) {
    if (value.includes(TRIPLE)) {
      throw new SecretsFileError(`${name} contains """ and cannot be imported`);
    }
    lines.push(
      value.includes("\n")
        ? `${name}=${TRIPLE}\n${value}\n${TRIPLE}`
        : `${name}=${value}`,
    );
  }
  return `${lines.join("\n")}\n`;
}

/**
 * Replaces every secret value that appears in [text] with [hidden]. For
 * messages from other code (a config error, a failed command) before they
 * are printed.
 */
export function redact(text: string, secrets: Iterable<string>): string {
  let out = text;
  const values = [...secrets].filter((value) => value.length >= 4).sort((
    a,
    b,
  ) => b.length - a.length);
  for (const value of values) {
    out = out.split(value).join("[hidden]");
    // A URL's password can appear percent-decoded or encoded.
    try {
      const url = new URL(value);
      if (url.password.length >= 4) {
        out = out.split(url.password).join("[hidden]");
        out = out.split(decodeURIComponent(url.password)).join("[hidden]");
      }
    } catch {
      // not a URL
    }
  }
  return out;
}
