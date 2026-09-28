/**
 * JOIN-053 short class codes.
 *
 * Eight characters from an alphabet with nothing a child can misread: no 0 or
 * O, no 1 or I. Thirty-two symbols, so each character is exactly five bits
 * and a random byte maps onto one without bias. Shown as two groups of four,
 * which is how people read them aloud and copy them off a board.
 */

export const CLASS_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const CLASS_CODE_LENGTH = 8;

/** A fresh code, unformatted. 256 is a multiple of 32, so `% 32` is unbiased. */
export function generateClassCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(CLASS_CODE_LENGTH));
  let code = "";
  for (const byte of bytes) {
    code += CLASS_CODE_ALPHABET[byte % CLASS_CODE_ALPHABET.length];
  }
  return code;
}

/** `ABCD-EFGH`, the form a teacher reads out and a student copies. */
export function formatClassCode(code: string): string {
  return `${code.slice(0, 4)}-${code.slice(4)}`;
}

/**
 * What the student typed, reduced to the canonical eight characters, or null
 * when it cannot be a code.
 *
 * Forgiving about everything a person gets wrong without meaning anything by
 * it - case, spaces, the dash - and strict about everything else, so the value
 * that gets hashed is always the one that was minted.
 */
export function normalizeClassCode(input: string): string | null {
  const compact = input.toUpperCase().replace(/[\s-]/g, "");
  if (compact.length !== CLASS_CODE_LENGTH) return null;
  for (const char of compact) {
    if (!CLASS_CODE_ALPHABET.includes(char)) return null;
  }
  return compact;
}

/**
 * HMAC-SHA256 of the canonical code under a key held outside the database.
 *
 * Keyed rather than a plain digest because a code is short: a plain SHA-256 of
 * forty bits is recoverable offline, so it would be the plaintext with extra
 * steps for anyone able to read the table.
 */
export async function hashClassCode(
  code: string,
  key: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    encoder.encode(code),
  );
  return [...new Uint8Array(signature)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function hmac(key: string, message: string): Promise<Uint8Array> {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(message)),
  );
}

/** A fresh salt for a link: 32 random bytes, base64url. */
export function generateDerivationSalt(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

/**
 * The link's token and code, re-derived from its salt.
 *
 * HMAC under a key the database never sees, so the stored salt reveals
 * nothing on its own - yet the same link always yields the same token and
 * code, which is what lets a teacher open the invite twice and see the code
 * they already shared. Domain-separated so the token and the code are
 * independent values.
 */
export async function deriveJoinCredentials(
  key: string,
  salt: string,
): Promise<{ token: string; code: string }> {
  const tokenBytes = await hmac(key, `class-join-token:${salt}`);
  const token = btoa(String.fromCharCode(...tokenBytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
  const codeBytes = await hmac(key, `class-join-code:${salt}`);
  let code = "";
  for (const byte of codeBytes.slice(0, CLASS_CODE_LENGTH)) {
    code += CLASS_CODE_ALPHABET[byte % CLASS_CODE_ALPHABET.length];
  }
  return { token, code };
}
