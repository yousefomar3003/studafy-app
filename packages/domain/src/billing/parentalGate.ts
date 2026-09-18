/**
 * ADR-0009's parental gate: a student-initiated purchase must not proceed
 * without one, and it must not be bypassable by a client simply asserting
 * "confirmed: true". The gate is a short-lived, stateless, HMAC-signed
 * arithmetic challenge (same construction as FILE-051's delivery token): the
 * server issues `{token, question}`, the app shows the question, and the
 * purchase submission must return the correct answer *with* the token. A
 * client that never requests a challenge, or answers wrong, cannot produce a
 * token+answer pair that verifies.
 */

const GATE_TTL_SECONDS = 120;

export interface ParentalGateChallenge {
  token: string;
  question: string;
}

interface GatePayload {
  a: number;
  b: number;
  exp: number;
}

export async function issueParentalGateChallenge(
  key: string,
  nowSeconds = unixNow(),
): Promise<ParentalGateChallenge> {
  const a = 2 + secureRandomInt(8); // 2..9
  const b = 2 + secureRandomInt(8); // 2..9
  const payload: GatePayload = { a, b, exp: nowSeconds + GATE_TTL_SECONDS };
  const bodyBytes = new TextEncoder().encode(JSON.stringify(payload));
  const signature = await hmac(bodyBytes, key);
  return {
    token: `${toBase64Url(bodyBytes)}.${toBase64Url(signature)}`,
    question: `What is ${a} × ${b}?`,
  };
}

/**
 * `true` only when the token's signature verifies, it has not expired, and
 * the answer matches. Every malformed input returns `false`; nothing throws.
 */
export async function verifyParentalGateAnswer(
  token: string,
  answer: number,
  key: string,
  nowSeconds = unixNow(),
): Promise<boolean> {
  if (typeof token !== "string" || token.length > 512) return false;
  if (!Number.isSafeInteger(answer)) return false;
  const parts = token.split(".");
  if (parts.length !== 2 || !parts[0] || !parts[1]) return false;
  const bodyBytes = fromBase64Url(parts[0]);
  const provided = fromBase64Url(parts[1]);
  if (!bodyBytes || !provided) return false;
  const expected = await hmac(bodyBytes, key);
  if (!constantTimeEquals(expected, provided)) return false;
  let payload: unknown;
  try {
    payload = JSON.parse(new TextDecoder().decode(bodyBytes));
  } catch {
    return false;
  }
  if (!isGatePayload(payload)) return false;
  if (payload.exp <= nowSeconds) return false;
  return payload.a * payload.b === answer;
}

function isGatePayload(value: unknown): value is GatePayload {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return Number.isSafeInteger(candidate.a) && (candidate.a as number) >= 2 &&
    (candidate.a as number) <= 9 &&
    Number.isSafeInteger(candidate.b) && (candidate.b as number) >= 2 &&
    (candidate.b as number) <= 9 &&
    Number.isSafeInteger(candidate.exp) && (candidate.exp as number) > 0;
}

function secureRandomInt(exclusiveMax: number): number {
  const bytes = crypto.getRandomValues(new Uint32Array(1));
  return (bytes[0] as number) % exclusiveMax;
}

async function hmac(data: Uint8Array, key: string): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, data));
}

function constantTimeEquals(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let index = 0; index < a.length; index++) {
    diff |= a[index]! ^ b[index]!;
  }
  return diff === 0;
}

function toBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (let start = 0; start < bytes.length; start += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(start, start + 0x8000));
  }
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll(
    "=",
    "",
  );
}

function fromBase64Url(value: string): Uint8Array | null {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) return null;
  try {
    const binary = atob(value.replaceAll("-", "+").replaceAll("_", "/"));
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index++) {
      bytes[index] = binary.charCodeAt(index);
    }
    return bytes;
  } catch {
    return null;
  }
}

function unixNow(): number {
  return Math.floor(Date.now() / 1000);
}
