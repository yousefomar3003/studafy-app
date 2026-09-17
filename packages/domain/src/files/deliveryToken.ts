/**
 * FILE-051 single-use delivery tokens.
 *
 * The token is the URL-carried half of a delivery grant: an HMAC-SHA256
 * signature over a compact JSON payload binding one file, one user, one
 * random nonce and one expiry. It is *not* the authorization decision — the
 * database grant (which stores only the nonce's SHA-256) and the
 * consume-time authorization query are. A leaked token without the
 * recipient's own session, after its expiry, after a second use, or after a
 * withdrawal is worthless; a leaked grant row cannot be turned back into a
 * token because the row never holds the nonce itself.
 */

export const DELIVERY_TOKEN_TTL_MIN_SECONDS = 30;
export const DELIVERY_TOKEN_TTL_MAX_SECONDS = 10 * 60;
const NONCE_PATTERN = /^[A-Za-z0-9_-]{43}$/;

export interface DeliveryTokenPayload {
  fileId: string;
  userId: string;
  /** 32 random bytes, base64url. Only its SHA-256 is ever persisted. */
  nonce: string;
  /** Expiry in whole seconds since the Unix epoch. */
  exp: number;
}

export interface SignDeliveryTokenInput {
  fileId: string;
  userId: string;
  nonce: string;
  ttlSeconds: number;
  /** Epoch seconds; defaults to now. Injectable for deterministic tests. */
  nowSeconds?: number;
}

/** A fresh 256-bit delivery nonce. */
export function createDeliveryNonce(): string {
  return toBase64Url(crypto.getRandomValues(new Uint8Array(32)));
}

/** The grant's `nonce_hash`: lowercase hex SHA-256 of the nonce text. */
export async function hashDeliveryNonce(nonce: string): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(nonce)),
  );
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join(
    "",
  );
}

export async function signDeliveryToken(
  input: SignDeliveryTokenInput,
  key: string,
): Promise<string> {
  if (
    input.ttlSeconds < DELIVERY_TOKEN_TTL_MIN_SECONDS ||
    input.ttlSeconds > DELIVERY_TOKEN_TTL_MAX_SECONDS
  ) {
    throw new Error("delivery token TTL out of bounds");
  }
  if (!NONCE_PATTERN.test(input.nonce)) {
    throw new Error("delivery token nonce malformed");
  }
  const payload: DeliveryTokenPayload = {
    fileId: input.fileId,
    userId: input.userId,
    nonce: input.nonce,
    exp: (input.nowSeconds ?? unixNow()) + input.ttlSeconds,
  };
  const bodyBytes = new TextEncoder().encode(JSON.stringify(payload));
  const signature = await hmac(bodyBytes, key);
  return `${toBase64Url(bodyBytes)}.${toBase64Url(signature)}`;
}

/**
 * Returns the payload only when the signature, file binding and expiry all
 * hold. Every malformed input yields `null`; nothing here throws.
 */
export async function verifyDeliveryToken(
  token: string,
  key: string,
  fileId: string,
  nowSeconds = unixNow(),
): Promise<DeliveryTokenPayload | null> {
  if (token.length > 1024) return null;
  const parts = token.split(".");
  if (parts.length !== 2 || !parts[0] || !parts[1]) return null;
  const bodyBytes = fromBase64Url(parts[0]);
  const provided = fromBase64Url(parts[1]);
  if (!bodyBytes || !provided) return null;
  const expected = await hmac(bodyBytes, key);
  if (!constantTimeEquals(expected, provided)) return null;
  let payload: unknown;
  try {
    payload = JSON.parse(new TextDecoder().decode(bodyBytes));
  } catch {
    return null;
  }
  if (!isPayloadShape(payload)) return null;
  if (payload.fileId !== fileId) return null;
  if (payload.exp <= nowSeconds) return null;
  return payload;
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

function isPayloadShape(value: unknown): value is DeliveryTokenPayload {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return typeof candidate.fileId === "string" &&
    typeof candidate.userId === "string" &&
    typeof candidate.nonce === "string" &&
    NONCE_PATTERN.test(candidate.nonce) &&
    Number.isSafeInteger(candidate.exp) && (candidate.exp as number) > 0;
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
