/**
 * AUTH-030 JWKS key source.
 *
 * Supabase signs access tokens with asymmetric keys and publishes the public
 * set at the project's JWKS endpoint. This module is the only place that
 * fetches them, so key handling has one implementation to review.
 *
 * Three properties matter and are each tested:
 *
 * - Only algorithms in ALLOWED_ALGORITHMS are ever imported. A key set that
 *   offers `none`, or a symmetric `oct` key that would let a forged HS256
 *   token be verified against a public key, is discarded rather than used.
 * - Rotation is handled by refetching on an unknown `kid`, but at most once
 *   per REFETCH_COOLDOWN_MS, so an attacker cannot use random `kid` values to
 *   drive unbounded outbound requests.
 * - HTTP cache metadata is honoured, so the steady state is one fetch per
 *   `max-age` rather than one per request.
 */

/**
 * Asymmetric signature algorithms only. `HS*` is absent deliberately: with a
 * published public key set, accepting a symmetric algorithm is the classic
 * algorithm-confusion forgery, because the "public" key becomes the shared
 * secret an attacker already has.
 */
export const ALLOWED_ALGORITHMS = ["ES256", "RS256"] as const;
export type AllowedAlgorithm = (typeof ALLOWED_ALGORITHMS)[number];

const DEFAULT_MAX_AGE_MS = 600_000;
const REFETCH_COOLDOWN_MS = 30_000;
const MAX_KEYS = 16;

// The workspace compiles without DOM types, so the WebCrypto parameter shapes
// are derived from the runtime signatures rather than named directly. This
// keeps them exact instead of approximating them with hand-written interfaces.
type ImportKeyAlgorithm = Parameters<typeof crypto.subtle.importKey>[2];
export type VerifyAlgorithm = Parameters<typeof crypto.subtle.verify>[0];
export type CryptoData = Parameters<typeof crypto.subtle.verify>[2];

/**
 * The runtime's type surface has no `JsonWebKey` and `Parameters<>` resolves
 * to the raw-key overload, so the JWK overload is bound once here. This is
 * the only cast in the module; every other reference stays typed as
 * `JwkEntry`.
 */
type ImportJwkKey = (
  format: "jwk",
  keyData: JwkEntry,
  algorithm: ImportKeyAlgorithm,
  extractable: boolean,
  keyUsages: readonly string[],
) => Promise<CryptoKey>;

const importJwkKey = crypto.subtle.importKey.bind(
  crypto.subtle,
) as unknown as ImportJwkKey;

interface JwkEntry {
  kid?: string;
  kty?: string;
  alg?: string;
  use?: string;
  crv?: string;
  n?: string;
  e?: string;
  x?: string;
  y?: string;
}

export interface JwksOptions {
  /** Injected in tests; defaults to the global fetch. */
  fetchImpl?: typeof fetch;
  /** Injected in tests so cache expiry does not need real time to pass. */
  now?: () => number;
}

export class JwksError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "JwksError";
  }
}

function isAllowedAlgorithm(
  value: string | undefined,
): value is AllowedAlgorithm {
  return ALLOWED_ALGORITHMS.includes(value as AllowedAlgorithm);
}

/** Derives the algorithm a key can verify, for entries that omit `alg`. */
function algorithmFor(key: JwkEntry): AllowedAlgorithm | null {
  if (key.alg !== undefined) {
    return isAllowedAlgorithm(key.alg) ? key.alg : null;
  }
  if (key.kty === "EC" && key.crv === "P-256") return "ES256";
  if (key.kty === "RSA") return "RS256";
  return null;
}

function importParams(algorithm: AllowedAlgorithm): {
  algorithm: ImportKeyAlgorithm;
  verify: VerifyAlgorithm;
} {
  if (algorithm === "ES256") {
    return {
      algorithm: { name: "ECDSA", namedCurve: "P-256" },
      verify: { name: "ECDSA", hash: "SHA-256" },
    };
  }
  return {
    algorithm: { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    verify: { name: "RSASSA-PKCS1-v1_5" },
  };
}

export interface VerificationKey {
  kid: string;
  algorithm: AllowedAlgorithm;
  key: CryptoKey;
  verifyParams: VerifyAlgorithm;
}

export class JwksKeySource {
  readonly #url: string;
  readonly #fetch: typeof fetch;
  readonly #now: () => number;

  #keys = new Map<string, VerificationKey>();
  #expiresAt = 0;
  #lastFetchAt = 0;
  #inFlight: Promise<void> | null = null;

  constructor(url: string, options: JwksOptions = {}) {
    this.#url = url;
    this.#fetch = options.fetchImpl ?? globalThis.fetch;
    this.#now = options.now ?? Date.now;
  }

  /**
   * Resolves the key for `kid`.
   *
   * A miss triggers at most one refetch per cooldown window, which is what
   * makes rotation automatic without turning an unknown `kid` into an
   * outbound-request amplifier.
   */
  async keyFor(kid: string): Promise<VerificationKey> {
    const now = this.#now();
    if (now >= this.#expiresAt) {
      await this.#refresh();
    }

    const cached = this.#keys.get(kid);
    if (cached) return cached;

    if (this.#now() - this.#lastFetchAt >= REFETCH_COOLDOWN_MS) {
      await this.#refresh();
      const rotated = this.#keys.get(kid);
      if (rotated) return rotated;
    }

    throw new JwksError("No verification key matches the token key id");
  }

  async #refresh(): Promise<void> {
    // Concurrent requests during a cold start or a rotation share one fetch.
    this.#inFlight ??= this.#fetchKeys().finally(() => {
      this.#inFlight = null;
    });
    await this.#inFlight;
  }

  async #fetchKeys(): Promise<void> {
    this.#lastFetchAt = this.#now();

    let response: Response;
    try {
      response = await this.#fetch(this.#url, {
        headers: { accept: "application/json" },
        redirect: "error",
      });
    } catch (cause) {
      throw new JwksError(`JWKS endpoint unreachable: ${String(cause)}`);
    }
    if (!response.ok) {
      throw new JwksError(`JWKS endpoint returned ${response.status}`);
    }

    const body = await response.json() as { keys?: JwkEntry[] };
    const entries = Array.isArray(body.keys)
      ? body.keys.slice(0, MAX_KEYS)
      : [];

    const imported = new Map<string, VerificationKey>();
    for (const entry of entries) {
      if (!entry.kid) continue;
      // A key published for encryption is not a signature key.
      if (entry.use !== undefined && entry.use !== "sig") continue;
      const algorithm = algorithmFor(entry);
      if (!algorithm) continue;

      const { algorithm: importAlgorithm, verify } = importParams(algorithm);
      try {
        const key = await importJwkKey(
          "jwk",
          entry,
          importAlgorithm,
          false,
          ["verify"],
        );
        imported.set(entry.kid, {
          kid: entry.kid,
          algorithm,
          key,
          verifyParams: verify,
        });
      } catch {
        // A key that will not import is skipped rather than failing the whole
        // set: one malformed entry must not lock every user out.
        continue;
      }
    }

    if (imported.size === 0) {
      throw new JwksError("JWKS endpoint published no usable signing key");
    }

    this.#keys = imported;
    this.#expiresAt = this.#now() + maxAgeMs(response);
  }
}

/** Reads `Cache-Control: max-age`, clamped to a sane window. */
function maxAgeMs(response: Response): number {
  const header = response.headers.get("cache-control");
  const match = header?.match(/max-age\s*=\s*(\d+)/i);
  if (!match?.[1]) return DEFAULT_MAX_AGE_MS;
  const seconds = Number(match[1]);
  if (!Number.isFinite(seconds) || seconds <= 0) return DEFAULT_MAX_AGE_MS;
  // Never cache longer than the default: a long max-age from the provider
  // would otherwise delay recognition of a rotation.
  return Math.min(seconds * 1000, DEFAULT_MAX_AGE_MS);
}
