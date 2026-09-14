import { describe, expect, test } from "bun:test";
import { JwksKeySource } from "../../src/auth/jwks";
import {
  bearerToken,
  TokenError,
  verifyAccessToken,
} from "../../src/auth/verify";
import {
  AUDIENCE,
  base64Url,
  generateKey,
  ISSUER,
  JwksServer,
  mintToken,
  staticJwks,
  SUBJECT,
  type TestKey,
} from "./support";

const CLOCK_SKEW = 30;

async function verifierFor(
  server: { fetch: typeof fetch },
  overrides: Partial<{ issuer: string; audience: string; now: () => number }> =
    {},
) {
  const keys = new JwksKeySource("https://jwks.test/keys", {
    fetchImpl: server.fetch,
  });
  return (token: string) =>
    verifyAccessToken(token, {
      keys,
      issuer: overrides.issuer ?? ISSUER,
      audience: overrides.audience ?? AUDIENCE,
      clockSkewSeconds: CLOCK_SKEW,
      ...(overrides.now ? { now: overrides.now } : {}),
    });
}

async function rejection(promise: Promise<unknown>): Promise<string> {
  try {
    await promise;
    return "accepted";
  } catch (error) {
    return error instanceof TokenError ? error.rejection : "other";
  }
}

let es256: TestKey;
let rs256: TestKey;

describe("a correctly signed token", () => {
  test("ES256 verifies and exposes only verified claims", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const result = await verify(await mintToken({ key: es256 }));

    expect(result.subject).toBe(SUBJECT);
    expect(result.assuranceLevel).toBe("aal1");
    expect(result.claims["iss"]).toBe(ISSUER);
  });

  test("RS256 verifies", async () => {
    rs256 ??= await generateKey("key-rs-1", "RS256");
    const verify = await verifierFor(new JwksServer([rs256]));
    const result = await verify(await mintToken({ key: rs256 }));
    expect(result.subject).toBe(SUBJECT);
  });

  test("an array audience containing the expected value is accepted", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const result = await verify(
      await mintToken({ key: es256, audience: ["other", AUDIENCE] }),
    );
    expect(result.subject).toBe(SUBJECT);
  });

  test("aal2 and amr timestamps survive verification", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const result = await verify(
      await mintToken({
        key: es256,
        aal: "aal2",
        amr: [{ method: "totp", timestamp: 1_700_000_000 }],
      }),
    );
    expect(result.assuranceLevel).toBe("aal2");
    expect(result.authMethods).toEqual([
      { method: "totp", timestamp: 1_700_000_000 },
    ]);
  });
});

describe("signature and algorithm forgeries", () => {
  test("a tampered payload fails the signature check", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const token = await mintToken({ key: es256 });
    const [header, , signature] = token.split(".") as [string, string, string];
    const forgedPayload = base64Url(JSON.stringify({
      iss: ISSUER,
      aud: AUDIENCE,
      sub: "99999999-9999-4999-8999-999999999999",
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
    }));

    expect(await rejection(verify(`${header}.${forgedPayload}.${signature}`)))
      .toBe("bad_signature");
  });

  test("alg:none is rejected even with an empty signature", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const token = await mintToken({
      key: es256,
      alg: "none",
      kid: es256.kid,
      forgedSignature: "",
    });
    expect(await rejection(verify(token))).toBe("malformed");
  });

  test("alg:none with a non-empty signature is still rejected", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const token = await mintToken({
      key: es256,
      alg: "none",
      kid: es256.kid,
      forgedSignature: base64Url("anything"),
    });
    expect(await rejection(verify(token))).toBe("unsupported_algorithm");
  });

  test("an HS256 token signed with the published public key is rejected", async () => {
    // The classic algorithm-confusion forgery: the attacker knows the public
    // key, so if the verifier honoured the header's `alg` it would accept a
    // symmetric signature made with that same public material.
    es256 ??= await generateKey("key-es-1");
    const server = new JwksServer([es256]);
    const verify = await verifierFor(server);

    const publicMaterial = JSON.stringify(es256.publicJwk);
    const hmacKey = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(publicMaterial) as never,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const header = base64Url(
      JSON.stringify({ alg: "HS256", typ: "JWT", kid: es256.kid }),
    );
    const payload = base64Url(JSON.stringify({
      iss: ISSUER,
      aud: AUDIENCE,
      sub: SUBJECT,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
    }));
    const signature = await crypto.subtle.sign(
      "HMAC",
      hmacKey,
      new TextEncoder().encode(`${header}.${payload}`) as never,
    );
    const forged = `${header}.${payload}.${
      base64Url(new Uint8Array(signature))
    }`;

    expect(await rejection(verify(forged))).toBe("unsupported_algorithm");
  });

  test("a JWKS offering a symmetric key publishes no usable key", async () => {
    // Defence in depth: even if the provider served an `oct` key, it must not
    // become usable verification material. The token below is well formed and
    // names that kid, so the request reaches key resolution and is refused
    // there rather than being rejected earlier as malformed.
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor({
      fetch: staticJwks({
        keys: [{ kid: "oct-1", kty: "oct", alg: "HS256", k: "c2VjcmV0" }],
      }),
    });
    const token = await mintToken({ key: es256, kid: "oct-1" });
    expect(await rejection(verify(token))).toBe("other");
  });

  test("a token signed by a key outside the published set is rejected", async () => {
    es256 ??= await generateKey("key-es-1");
    const attacker = await generateKey("key-es-1");
    // Same kid, different key: resolves a key, then fails the signature.
    const verify = await verifierFor(new JwksServer([es256]));
    expect(await rejection(verify(await mintToken({ key: attacker }))))
      .toBe("bad_signature");
  });
});

describe("claim validation", () => {
  test("an expired token is rejected", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const past = Math.floor(Date.now() / 1000) - 7200;
    expect(
      await rejection(
        verify(
          await mintToken({
            key: es256,
            issuedAt: past,
            expiresAt: past + 60,
          }),
        ),
      ),
    ).toBe("expired");
  });

  test("expiry inside the clock-skew window is still accepted", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const now = Math.floor(Date.now() / 1000);
    const result = await verify(
      await mintToken({ key: es256, expiresAt: now - 5 }),
    );
    expect(result.subject).toBe(SUBJECT);
  });

  test("skew does not extend an expiry beyond its bound", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const now = Math.floor(Date.now() / 1000);
    expect(
      await rejection(
        verify(
          await mintToken({ key: es256, expiresAt: now - CLOCK_SKEW - 5 }),
        ),
      ),
    ).toBe("expired");
  });

  test("a not-yet-valid token is rejected", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const future = Math.floor(Date.now() / 1000) + 3600;
    expect(
      await rejection(
        verify(await mintToken({ key: es256, notBefore: future })),
      ),
    ).toBe("not_yet_valid");
  });

  test("a token issued far in the future is rejected", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    const future = Math.floor(Date.now() / 1000) + 7200;
    expect(
      await rejection(
        verify(
          await mintToken({
            key: es256,
            issuedAt: future,
            expiresAt: future + 3600,
          }),
        ),
      ),
    ).toBe("not_yet_valid");
  });

  test("another project's issuer is rejected", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    expect(
      await rejection(
        verify(
          await mintToken({
            key: es256,
            issuer: "https://attacker.supabase.test/auth/v1",
          }),
        ),
      ),
    ).toBe("wrong_issuer");
  });

  test("an issuer that merely starts with the expected value is rejected", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    expect(
      await rejection(
        verify(await mintToken({ key: es256, issuer: `${ISSUER}.attacker` })),
      ),
    ).toBe("wrong_issuer");
  });

  test("a service-role audience is rejected", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    expect(
      await rejection(
        verify(await mintToken({ key: es256, audience: "service_role" })),
      ),
    ).toBe("wrong_audience");
  });

  test("a token with no subject is rejected", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    expect(
      await rejection(verify(await mintToken({ key: es256, subject: null }))),
    )
      .toBe("missing_subject");
  });
});

describe("malformed input", () => {
  test.each([
    ["empty string", ""],
    ["two segments", "a.b"],
    ["four segments", "a.b.c.d"],
    ["non-json header", `${base64Url("not json")}.e30.sig`],
    [
      "array payload",
      `${base64Url('{"alg":"ES256","kid":"k"}')}.${base64Url("[]")}.sig`,
    ],
  ])("%s is rejected without a crash", async (_name, token) => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    expect(await rejection(verify(token))).not.toBe("accepted");
  });

  test("an oversized token is rejected before any parsing work", async () => {
    es256 ??= await generateKey("key-es-1");
    const verify = await verifierFor(new JwksServer([es256]));
    expect(await rejection(verify("x".repeat(20_000)))).toBe("malformed");
  });
});

describe("key rotation and caching", () => {
  test("an unknown kid triggers a refetch and the rotated key is accepted", async () => {
    // Rotation is picked up without a restart, bounded by the refetch
    // cooldown. The cooldown is the deliberate trade against unknown-kid
    // request amplification; the next test pins the other side of it.
    const oldKey = await generateKey("key-old");
    const newKey = await generateKey("key-new");
    const server = new JwksServer([oldKey]);
    let clock = 1_000_000;
    const keys = new JwksKeySource("https://jwks.test/keys", {
      fetchImpl: server.fetch,
      now: () => clock,
    });
    const verify = (token: string) =>
      verifyAccessToken(token, {
        keys,
        issuer: ISSUER,
        audience: AUDIENCE,
        clockSkewSeconds: CLOCK_SKEW,
      });

    await verify(await mintToken({ key: oldKey }));
    const fetchesBefore = server.fetchCount;

    server.rotate([newKey]);
    clock += 31_000;
    const result = await verify(await mintToken({ key: newKey }));

    expect(result.subject).toBe(SUBJECT);
    expect(server.fetchCount).toBeGreaterThan(fetchesBefore);
  });

  test("a rotation inside the cooldown is not yet visible", async () => {
    const oldKey = await generateKey("key-old-2");
    const newKey = await generateKey("key-new-2");
    const server = new JwksServer([oldKey]);
    const keys = new JwksKeySource("https://jwks.test/keys", {
      fetchImpl: server.fetch,
    });
    await keys.keyFor(oldKey.kid);
    server.rotate([newKey]);

    // Supabase publishes a new key before issuing tokens signed with it, so
    // this window is not normally reachable; it is asserted so the bound is
    // recorded rather than discovered during an incident.
    await expect(keys.keyFor(newKey.kid)).rejects.toThrow();
  });

  test("a withdrawn key stops verifying once the set is refetched", async () => {
    const retired = await generateKey("key-retired");
    const current = await generateKey("key-current");
    const server = new JwksServer([retired, current]);
    const verify = await verifierFor(server);
    await verify(await mintToken({ key: retired }));

    server.rotate([current]);
    // Force the cached set to be discarded the way an expiry would.
    const fresh = new JwksKeySource("https://jwks.test/keys", {
      fetchImpl: server.fetch,
    });
    expect(
      await rejection(
        verifyAccessToken(await mintToken({ key: retired }), {
          keys: fresh,
          issuer: ISSUER,
          audience: AUDIENCE,
          clockSkewSeconds: CLOCK_SKEW,
        }),
      ),
    ).toBe("other");
  });

  test("repeated unknown kids do not refetch on every request", async () => {
    // Otherwise a stream of random kids becomes an outbound-request amplifier
    // against the provider.
    es256 ??= await generateKey("key-es-1");
    const server = new JwksServer([es256]);
    const keys = new JwksKeySource("https://jwks.test/keys", {
      fetchImpl: server.fetch,
    });
    for (let attempt = 0; attempt < 25; attempt += 1) {
      await keys.keyFor(`unknown-${attempt}`).catch(() => undefined);
    }
    expect(server.fetchCount).toBeLessThanOrEqual(2);
  });

  test("cache-control max-age is honoured between requests", async () => {
    es256 ??= await generateKey("key-es-1");
    const server = new JwksServer([es256], 300);
    const keys = new JwksKeySource("https://jwks.test/keys", {
      fetchImpl: server.fetch,
    });
    await keys.keyFor(es256.kid);
    await keys.keyFor(es256.kid);
    await keys.keyFor(es256.kid);
    expect(server.fetchCount).toBe(1);
  });

  test("the key set is refetched once max-age has elapsed", async () => {
    es256 ??= await generateKey("key-es-1");
    const server = new JwksServer([es256], 60);
    let clock = 1_000_000;
    const keys = new JwksKeySource("https://jwks.test/keys", {
      fetchImpl: server.fetch,
      now: () => clock,
    });
    await keys.keyFor(es256.kid);
    clock += 61_000;
    await keys.keyFor(es256.kid);
    expect(server.fetchCount).toBe(2);
  });
});

describe("bearer header parsing", () => {
  test.each([
    ["absent", undefined, null],
    ["empty", "", null],
    ["wrong scheme", "Basic abc", null],
    ["lowercase scheme", "bearer abc", null],
    ["no token", "Bearer ", null],
    ["two tokens", "Bearer a b", null],
    ["valid", "Bearer abc.def.ghi", "abc.def.ghi"],
  ])("%s", (_name, header, expected) => {
    expect(bearerToken(header as string | undefined)).toBe(
      expected as string | null,
    );
  });
});
