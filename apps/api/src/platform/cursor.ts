import { timingSafeEqual } from "node:crypto";

export interface CursorPayload {
  version: 1;
  filterVersion: 1;
  operation: string;
  schoolId: string;
  filterHash: string;
  position: string;
}

function encode(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("base64url");
}

function decode(value: string): Uint8Array {
  return new Uint8Array(Buffer.from(value, "base64url"));
}

async function signature(key: string, payload: string): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      cryptoKey,
      new TextEncoder().encode(payload),
    ),
  );
}

export async function filterHash(value: unknown): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(JSON.stringify(value)),
  );
  return encode(new Uint8Array(digest));
}

export async function signCursor(
  key: string,
  payload: CursorPayload,
): Promise<string> {
  const body = encode(new TextEncoder().encode(JSON.stringify(payload)));
  return `${body}.${encode(await signature(key, body))}`;
}

export async function verifyCursor(
  key: string,
  token: string,
  expected: Omit<CursorPayload, "version" | "filterVersion" | "position">,
): Promise<CursorPayload | null> {
  try {
    const [body, supplied, extra] = token.split(".");
    if (!body || !supplied || extra) return null;
    const actual = await signature(key, body);
    const candidate = decode(supplied);
    if (
      actual.length !== candidate.length || !timingSafeEqual(actual, candidate)
    ) {
      return null;
    }
    const parsed = JSON.parse(
      new TextDecoder().decode(decode(body)),
    ) as CursorPayload;
    if (
      parsed.version !== 1 || parsed.filterVersion !== 1 ||
      parsed.operation !== expected.operation ||
      parsed.schoolId !== expected.schoolId ||
      parsed.filterHash !== expected.filterHash ||
      typeof parsed.position !== "string"
    ) return null;
    return parsed;
  } catch {
    return null;
  }
}
