import { describe, expect, test } from "bun:test";
import { generateKeyPairSync } from "node:crypto";
import {
  type AppleTransactionVerifier,
  type AppleVerifierConfig,
  chooseAppleVerifier,
  chooseAppleVerifierFor,
  createAppleVerifiers,
  peekAppleSignedEnvironment,
} from "../src";

/** A compact JWS with the given payload; the signature is never checked
 * by the peek, only by the verifier it chooses. */
function jws(payload: unknown): string {
  const encode = (value: unknown) =>
    Buffer.from(JSON.stringify(value)).toString("base64url");
  return `${encode({ alg: "ES256" })}.${encode(payload)}.signature`;
}

const verifier = (
  name: string,
) => ({ name } as unknown as AppleTransactionVerifier);

describe("DL-080: choosing the Apple verifier", () => {
  test("the environment is read from a transaction or a notification", () => {
    expect(peekAppleSignedEnvironment(jws({ environment: "Sandbox" }))).toBe(
      "Sandbox",
    );
    expect(
      peekAppleSignedEnvironment(jws({ data: { environment: "Production" } })),
    ).toBe("Production");
    expect(
      peekAppleSignedEnvironment(jws({ summary: { environment: "Sandbox" } })),
    ).toBe("Sandbox");
    expect(
      peekAppleSignedEnvironment(jws({ appData: { environment: "Sandbox" } })),
    ).toBe("Sandbox");
  });

  test("anything else names no environment", () => {
    for (
      const signed of [
        "",
        "signed.payload",
        "a.b.c.d",
        "header.@@@.sig",
        jws("Sandbox"),
        jws({ environment: "Xcode" }),
        jws({ environment: "LocalTesting" }),
        jws({ data: { environment: "sandbox" } }),
      ]
    ) {
      expect(peekAppleSignedEnvironment(signed)).toBeNull();
    }
  });

  test("Sandbox data goes to the Sandbox verifier only when there is one", () => {
    const production = verifier("production");
    const sandbox = verifier("sandbox");
    const both = { verifier: production, sandboxVerifier: sandbox };
    expect(chooseAppleVerifierFor(both, jws({ environment: "Sandbox" })))
      .toEqual({ verifier: sandbox, sandbox: true });
    expect(chooseAppleVerifierFor(both, jws({ environment: "Production" })))
      .toEqual({ verifier: production, sandbox: false });
    // Unreadable data goes to the server's own verifier, which refuses it.
    expect(chooseAppleVerifierFor(both, "signed.payload"))
      .toEqual({ verifier: production, sandbox: false });

    const only = { verifier: verifier("own"), sandboxVerifier: null };
    expect(chooseAppleVerifier(only, "Sandbox")).toEqual({
      verifier: only.verifier,
      sandbox: false,
    });
  });

  test("only a production server with Production Apple keys gets a Sandbox verifier", () => {
    const { privateKey } = generateKeyPairSync("ec", {
      namedCurve: "prime256v1",
    });
    const config: AppleVerifierConfig = {
      rootCertificates: [],
      bundleId: "com.studafy.light",
      environment: "Production",
      appAppleId: 1234567890,
      api: {
        signingKey: privateKey.export({ type: "pkcs8", format: "pem" })
          .toString(),
        keyId: "KEYID",
        issuerId: "issuer",
      },
    };
    const production = createAppleVerifiers(config, "production");
    expect(production.verifier.environment).toBe("Production");
    expect(production.sandboxVerifier?.environment).toBe("Sandbox");

    for (const server of ["development", "staging", "synthetic"]) {
      expect(createAppleVerifiers(config, server).sandboxVerifier).toBeNull();
    }
    const sandboxKeys = createAppleVerifiers(
      { ...config, environment: "Sandbox" },
      "production",
    );
    expect(sandboxKeys.verifier.environment).toBe("Sandbox");
    expect(sandboxKeys.sandboxVerifier).toBeNull();
  });
});
