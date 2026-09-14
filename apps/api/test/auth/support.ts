/**
 * Test support for AUTH-030: real ES256/RS256 keys, a real JWKS document, and
 * real signatures.
 *
 * Nothing here stubs the verifier. The tokens are genuinely signed, so a test
 * that passes proves the cryptography, and a forgery test proves the forgery
 * actually fails rather than that a mock said it did.
 */

export interface TestKey {
  kid: string;
  algorithm: "ES256" | "RS256";
  privateKey: CryptoKey;
  publicJwk: Record<string, unknown>;
}

type ExportJwk = (format: "jwk", key: CryptoKey) => Promise<
  Record<string, unknown>
>;
const exportJwk = crypto.subtle.exportKey.bind(
  crypto.subtle,
) as unknown as ExportJwk;

type SignData = Parameters<typeof crypto.subtle.sign>[2];

export async function generateKey(
  kid: string,
  algorithm: "ES256" | "RS256" = "ES256",
): Promise<TestKey> {
  const params = algorithm === "ES256"
    ? { name: "ECDSA", namedCurve: "P-256" }
    : {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
    };
  const pair = await crypto.subtle.generateKey(
    params as never,
    true,
    ["sign", "verify"],
  ) as CryptoKeyPair;

  const publicJwk = await exportJwk("jwk", pair.publicKey);
  delete publicJwk["key_ops"];
  delete publicJwk["ext"];

  return {
    kid,
    algorithm,
    privateKey: pair.privateKey,
    publicJwk: { ...publicJwk, kid, alg: algorithm, use: "sig" },
  };
}

export function base64Url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? bytes : String.fromCharCode(...bytes);
  return btoa(raw).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

export interface TokenOptions {
  key?: TestKey;
  kid?: string;
  alg?: string;
  issuer?: string;
  audience?: string | string[];
  subject?: string | null;
  sessionId?: string | null;
  issuedAt?: number;
  expiresAt?: number;
  notBefore?: number;
  aal?: string;
  amr?: { method: string; timestamp: number }[];
  extraClaims?: Record<string, unknown>;
  /** Replaces the signature with arbitrary bytes, for tamper cases. */
  forgedSignature?: string;
}

export const ISSUER = "https://project.supabase.test/auth/v1";
export const AUDIENCE = "authenticated";
export const SUBJECT = "11111111-2222-4333-8444-555555555555";
export const SESSION = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";

/** Signs a token with a real key unless the caller asks for a forgery. */
export async function mintToken(options: TokenOptions = {}): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const key = options.key;

  const header = {
    alg: options.alg ?? key?.algorithm ?? "ES256",
    typ: "JWT",
    kid: options.kid ?? key?.kid,
  };
  const payload: Record<string, unknown> = {
    iss: options.issuer ?? ISSUER,
    aud: options.audience ?? AUDIENCE,
    iat: options.issuedAt ?? nowSeconds,
    exp: options.expiresAt ?? nowSeconds + 3600,
    aal: options.aal ?? "aal1",
    amr: options.amr ?? [{ method: "oauth", timestamp: nowSeconds }],
    ...options.extraClaims,
  };
  if (options.subject !== null) payload["sub"] = options.subject ?? SUBJECT;
  if (options.sessionId !== null) {
    payload["session_id"] = options.sessionId ?? SESSION;
  }
  if (options.notBefore !== undefined) payload["nbf"] = options.notBefore;

  const headerSegment = base64Url(JSON.stringify(header));
  const payloadSegment = base64Url(JSON.stringify(payload));
  const signingInput = `${headerSegment}.${payloadSegment}`;

  if (options.forgedSignature !== undefined) {
    return `${signingInput}.${options.forgedSignature}`;
  }
  if (!key) throw new Error("mintToken needs a key or a forged signature");

  const algorithm = key.algorithm === "ES256"
    ? { name: "ECDSA", hash: "SHA-256" }
    : { name: "RSASSA-PKCS1-v1_5" };
  const signature = await crypto.subtle.sign(
    algorithm as never,
    key.privateKey,
    new TextEncoder().encode(signingInput) as unknown as SignData,
  );
  return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
}

/**
 * Serves a JWKS document and counts fetches, so cache and rotation behaviour
 * can be asserted rather than assumed.
 */
export class JwksServer {
  #keys: TestKey[];
  #maxAge: number | null;
  fetchCount = 0;

  constructor(keys: TestKey[], maxAgeSeconds: number | null = null) {
    this.#keys = keys;
    this.#maxAge = maxAgeSeconds;
  }

  rotate(keys: TestKey[]): void {
    this.#keys = keys;
  }

  readonly fetch: typeof fetch = (() => {
    this.fetchCount += 1;
    const headers: Record<string, string> = {
      "content-type": "application/json",
    };
    if (this.#maxAge !== null) {
      headers["cache-control"] = `public, max-age=${this.#maxAge}`;
    }
    return Promise.resolve(
      new Response(
        JSON.stringify({ keys: this.#keys.map((key) => key.publicJwk) }),
        { headers },
      ),
    );
  }) as unknown as typeof fetch;
}

/** A JWKS endpoint that serves an arbitrary document, including hostile ones. */
export function staticJwks(document: unknown): typeof fetch {
  return (() =>
    Promise.resolve(
      new Response(JSON.stringify(document), {
        headers: { "content-type": "application/json" },
      }),
    )) as unknown as typeof fetch;
}
