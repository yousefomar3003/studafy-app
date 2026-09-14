/**
 * AUTH-030 access token verification.
 *
 * The order here is the point: the signature is checked before any claim is
 * read, and the header's `alg` is never used to choose the verification
 * algorithm. The algorithm comes from the key the `kid` resolves to, so a
 * token declaring `alg: none` or `alg: HS256` cannot talk the verifier into
 * a weaker check.
 *
 * Nothing in this module reads `app_metadata` or `user_metadata`. Role and
 * tenant come from the database (see context.ts); a token is only ever proof
 * of identity.
 */
import type { CryptoData, JwksKeySource } from "./jwks";

const MAX_TOKEN_BYTES = 8192;

export type TokenRejection =
  | "malformed"
  | "unsupported_algorithm"
  | "unknown_key"
  | "bad_signature"
  | "expired"
  | "not_yet_valid"
  | "wrong_issuer"
  | "wrong_audience"
  | "missing_subject";

export class TokenError extends Error {
  readonly rejection: TokenRejection;
  constructor(rejection: TokenRejection) {
    // The message is for logs only; callers map every rejection to the same
    // client-visible error.
    super(`token rejected: ${rejection}`);
    this.name = "TokenError";
    this.rejection = rejection;
  }
}

/** The claims the API is willing to act on, all of them verified. */
export interface VerifiedToken {
  subject: string;
  sessionId: string | null;
  issuedAt: number;
  expiresAt: number;
  assuranceLevel: "aal1" | "aal2";
  /** Authentication methods with the time each was last exercised. */
  authMethods: { method: string; timestamp: number }[];
  /** The raw verified payload, for claims-passthrough to Postgres. */
  claims: Record<string, unknown>;
}

export interface VerifyOptions {
  keys: JwksKeySource;
  issuer: string;
  audience: string;
  clockSkewSeconds: number;
  now?: () => number;
}

function decodeBase64Url(segment: string): Uint8Array {
  const normalized = segment.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(
    normalized.length + ((4 - (normalized.length % 4)) % 4),
    "=",
  );
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

function decodeJson(segment: string): Record<string, unknown> {
  const text = new TextDecoder().decode(decodeBase64Url(segment));
  const parsed = JSON.parse(text) as unknown;
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new TokenError("malformed");
  }
  return parsed as Record<string, unknown>;
}

/**
 * ECDSA JWS signatures are the raw r||s pair; WebCrypto's ECDSA verify wants
 * exactly that, so no DER conversion is needed. RSASSA-PKCS1-v1_5 is likewise
 * the raw signature.
 */
export async function verifyAccessToken(
  token: string,
  options: VerifyOptions,
): Promise<VerifiedToken> {
  const now = Math.floor((options.now?.() ?? Date.now()) / 1000);

  if (typeof token !== "string" || token.length === 0) {
    throw new TokenError("malformed");
  }
  // Bound the work before doing any of it.
  if (token.length > MAX_TOKEN_BYTES) throw new TokenError("malformed");

  const segments = token.split(".");
  if (segments.length !== 3) throw new TokenError("malformed");
  const [headerSegment, payloadSegment, signatureSegment] = segments as [
    string,
    string,
    string,
  ];
  if (!headerSegment || !payloadSegment || !signatureSegment) {
    throw new TokenError("malformed");
  }

  let header: Record<string, unknown>;
  try {
    header = decodeJson(headerSegment);
  } catch {
    throw new TokenError("malformed");
  }

  const kid = header["kid"];
  if (typeof kid !== "string" || kid.length === 0) {
    throw new TokenError("unknown_key");
  }

  // The declared algorithm is checked for agreement with the key, never used
  // to select it. A mismatch — including `none` — is a rejection.
  const declaredAlgorithm = header["alg"];
  if (typeof declaredAlgorithm !== "string") {
    throw new TokenError("unsupported_algorithm");
  }

  const verificationKey = await options.keys.keyFor(kid);
  if (declaredAlgorithm !== verificationKey.algorithm) {
    throw new TokenError("unsupported_algorithm");
  }

  let signature: Uint8Array;
  try {
    signature = decodeBase64Url(signatureSegment);
  } catch {
    throw new TokenError("malformed");
  }

  const signed = new TextEncoder().encode(
    `${headerSegment}.${payloadSegment}`,
  );
  const valid = await crypto.subtle.verify(
    verificationKey.verifyParams,
    verificationKey.key,
    signature as unknown as CryptoData,
    signed as unknown as CryptoData,
  );
  if (!valid) throw new TokenError("bad_signature");

  // Only now is the payload trustworthy enough to read.
  let claims: Record<string, unknown>;
  try {
    claims = decodeJson(payloadSegment);
  } catch {
    throw new TokenError("malformed");
  }

  const skew = options.clockSkewSeconds;

  const expiresAt = claims["exp"];
  if (typeof expiresAt !== "number") throw new TokenError("malformed");
  if (now - skew >= expiresAt) throw new TokenError("expired");

  const notBefore = claims["nbf"];
  if (typeof notBefore === "number" && now + skew < notBefore) {
    throw new TokenError("not_yet_valid");
  }

  const issuedAt = claims["iat"];
  if (typeof issuedAt !== "number") throw new TokenError("malformed");
  if (now + skew < issuedAt) throw new TokenError("not_yet_valid");

  if (claims["iss"] !== options.issuer) throw new TokenError("wrong_issuer");

  const audience = claims["aud"];
  const audienceMatches = Array.isArray(audience)
    ? audience.includes(options.audience)
    : audience === options.audience;
  if (!audienceMatches) throw new TokenError("wrong_audience");

  const subject = claims["sub"];
  if (typeof subject !== "string" || subject.length === 0) {
    throw new TokenError("missing_subject");
  }

  const sessionId = claims["session_id"];
  const assurance = claims["aal"];

  return {
    subject,
    sessionId: typeof sessionId === "string" ? sessionId : null,
    issuedAt,
    expiresAt,
    assuranceLevel: assurance === "aal2" ? "aal2" : "aal1",
    authMethods: readAuthMethods(claims["amr"]),
    claims,
  };
}

/**
 * `amr` records when each authentication method was last exercised. Unlike
 * `iat`, these timestamps survive a silent refresh unchanged, which is why
 * they are a usable recent-auth signal and `iat` is not.
 */
function readAuthMethods(
  value: unknown,
): { method: string; timestamp: number }[] {
  if (!Array.isArray(value)) return [];
  const methods: { method: string; timestamp: number }[] = [];
  for (const entry of value) {
    if (typeof entry !== "object" || entry === null) continue;
    const record = entry as Record<string, unknown>;
    const method = record["method"];
    const timestamp = record["timestamp"];
    if (typeof method === "string" && typeof timestamp === "number") {
      methods.push({ method, timestamp });
    }
  }
  return methods;
}

/** Extracts a bearer token, or null when the header is absent or malformed. */
export function bearerToken(header: string | undefined | null): string | null {
  if (!header) return null;
  const match = /^Bearer[ ]([A-Za-z0-9._-]+)$/.exec(header);
  return match?.[1] ?? null;
}
