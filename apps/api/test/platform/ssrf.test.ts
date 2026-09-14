import { describe, expect, test } from "bun:test";
import {
  isBlockedAddress,
  SafeFetchError,
  SafeProviderClient,
} from "../../src/platform/ssrf";

const PUBLIC = [{ address: "93.184.216.34", family: 4 }];

function asFetch(implementation: unknown): typeof fetch {
  return implementation as unknown as typeof fetch;
}

function client(options: {
  origin?: string;
  fetchImpl?: typeof fetch;
  resolve?: (
    hostname: string,
  ) => Promise<{ address: string; family: number }[]>;
  timeoutMs?: number;
  maxResponseBytes?: number;
  maxRedirects?: number;
  environment?: "development" | "production" | "staging" | "synthetic";
} = {}) {
  return new SafeProviderClient({
    origins: [options.origin ?? "https://provider.test"],
    environment: options.environment ?? "production",
    fetchImpl: options.fetchImpl ?? asFetch(async () => new Response("ok")),
    resolve: options.resolve ?? (async () => PUBLIC),
    timeoutMs: options.timeoutMs,
    maxResponseBytes: options.maxResponseBytes,
    maxRedirects: options.maxRedirects,
  });
}

async function rejection(work: Promise<unknown>, code: SafeFetchError["code"]) {
  try {
    await work;
    throw new Error("expected rejection");
  } catch (error) {
    expect(error).toBeInstanceOf(SafeFetchError);
    expect((error as SafeFetchError).code).toBe(code);
  }
}

describe("SSRF address policy", () => {
  test("rejects loopback, RFC1918, link-local metadata, reserved, and local IPv6", () => {
    for (
      const address of [
        "0.0.0.0",
        "10.1.2.3",
        "127.0.0.1",
        "169.254.169.254",
        "172.16.0.1",
        "192.168.1.2",
        "100.64.0.1",
        "192.0.2.1",
        "::",
        "::1",
        "fc00::1",
        "fe80::1",
        "ff02::1",
        "::ffff:127.0.0.1",
        "::ffff:7f00:1",
        "0:0:0:0:0:ffff:a00:1",
      ]
    ) expect(isBlockedAddress(address)).toBe(true);
    expect(isBlockedAddress("93.184.216.34")).toBe(false);
    expect(isBlockedAddress("2606:4700:4700::1111")).toBe(false);
  });

  test("rejects IP literals and encoded loopback origins before fetch", async () => {
    let calls = 0;
    const fake = asFetch(async () => {
      calls += 1;
      return new Response("bad");
    });
    await rejection(
      client({ origin: "https://127.0.0.1", fetchImpl: fake }).fetch("/token"),
      "ADDRESS_REJECTED",
    );
    await rejection(
      client({ origin: "https://[::1]", fetchImpl: fake }).fetch("/token"),
      "ADDRESS_REJECTED",
    );
    await rejection(
      client({ origin: "https://%31%32%37.0.0.1", fetchImpl: fake }).fetch(
        "/token",
      ),
      "ADDRESS_REJECTED",
    );
    expect(calls).toBe(0);
  });

  test("rejects every hostname when any DNS answer is unsafe", async () => {
    let calls = 0;
    const provider = client({
      resolve:
        async () => [...PUBLIC, { address: "169.254.169.254", family: 4 }],
      fetchImpl: asFetch(async () => {
        calls += 1;
        return new Response("bad");
      }),
    });
    await rejection(provider.fetch("/token"), "ADDRESS_REJECTED");
    expect(calls).toBe(0);
  });
});

describe("SSRF URL and redirect policy", () => {
  test("accepts only relative paths on an allowlisted origin", async () => {
    const provider = client();
    await rejection(provider.fetch("https://evil.test/token"), "URL_REJECTED");
    await rejection(provider.fetch("//evil.test/token"), "URL_REJECTED");
  });

  test("requires HTTPS origins in production", () => {
    expect(() =>
      client({ origin: "http://provider.test", environment: "production" })
    )
      .toThrow(SafeFetchError);
    expect(() =>
      client({ origin: "http://provider.test", environment: "development" })
    )
      .not.toThrow();
  });

  test("rejects cross-origin and metadata redirects", async () => {
    const crossOrigin = client({
      fetchImpl: asFetch(async () =>
        new Response(null, {
          status: 302,
          headers: { location: "https://evil.test/steal" },
        })
      ),
    });
    await rejection(crossOrigin.fetch("/token"), "URL_REJECTED");

    const metadata = client({
      fetchImpl: asFetch(async () =>
        new Response(null, {
          status: 302,
          headers: { location: "http://169.254.169.254/latest/meta-data" },
        })
      ),
    });
    await rejection(metadata.fetch("/token"), "URL_REJECTED");
  });

  test("re-resolves and validates DNS on every redirect hop", async () => {
    let resolutions = 0;
    let requests = 0;
    const provider = client({
      resolve: async () =>
        ++resolutions === 1 ? PUBLIC : [{ address: "127.0.0.1", family: 4 }],
      fetchImpl: asFetch(async () => {
        requests += 1;
        return new Response(null, {
          status: 307,
          headers: { location: "/second" },
        });
      }),
    });
    await rejection(provider.fetch("/first"), "ADDRESS_REJECTED");
    expect(requests).toBe(1);
    expect(resolutions).toBe(2);
  });

  test("bounds redirect count", async () => {
    const provider = client({
      maxRedirects: 1,
      fetchImpl: asFetch(async () =>
        new Response(null, { status: 302, headers: { location: "/again" } })
      ),
    });
    await rejection(provider.fetch("/first"), "REDIRECT_REJECTED");
  });
});

describe("SSRF transfer bounds", () => {
  test("rejects declared and streamed response overflow", async () => {
    await rejection(
      client({
        maxResponseBytes: 4,
        fetchImpl: asFetch(async () =>
          new Response("small", { headers: { "content-length": "99" } })
        ),
      }).fetch("/token"),
      "RESPONSE_TOO_LARGE",
    );

    await rejection(
      client({
        maxResponseBytes: 4,
        fetchImpl: asFetch(async () => new Response("streamed-overflow")),
      }).fetch("/token"),
      "RESPONSE_TOO_LARGE",
    );
  });

  test("honors its deadline and the parent request abort signal", async () => {
    const hanging = asFetch(async (_url: never, init?: RequestInit) =>
      await new Promise<Response>((_resolve, reject) => {
        if (init?.signal?.aborted) {
          reject(new Error("aborted"));
          return;
        }
        init?.signal?.addEventListener(
          "abort",
          () => reject(new Error("aborted")),
          { once: true },
        );
      })
    );
    await rejection(
      client({ fetchImpl: hanging, timeoutMs: 5 }).fetch("/token"),
      "UPSTREAM_TIMEOUT",
    );

    const controller = new AbortController();
    const pending = client({ fetchImpl: hanging, timeoutMs: 5_000 }).fetch(
      "/token",
      {},
      controller.signal,
    );
    controller.abort();
    await rejection(pending, "UPSTREAM_TIMEOUT");
  });
});
