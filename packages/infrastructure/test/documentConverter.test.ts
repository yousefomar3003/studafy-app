import { describe, expect, test } from "bun:test";
import { ConverterUnavailableError, HttpDocumentConverter } from "../src";

/**
 * The converter client (DL-078): one origin, one request shape, and every
 * answer other than bytes or a 422 refusal is "unavailable", never success.
 */
const KEY = "synthetic-converter-key-000000000000";

function converter(
  respond: (request: Request) => Response | Promise<Response>,
  seen: Request[] = [],
) {
  return new HttpDocumentConverter({
    url: "http://studafy-converter-test.internal:8080",
    apiKey: KEY,
    maxOutputBytes: 1_000,
    fetch: (async (input: string | URL | Request, init?: RequestInit) => {
      const request = new Request(String(input), init);
      seen.push(request);
      return await respond(request);
    }) as typeof fetch,
  });
}

describe("document converter client", () => {
  test("posts the bytes with the key and the two types, never following redirects", async () => {
    const seen: Request[] = [];
    const client = converter(
      () => new Response(new Uint8Array([0x25, 0x50, 0x44, 0x46])),
      seen,
    );
    const result = await client.convert(
      new Uint8Array([1, 2, 3]),
      "doc",
      "pdf",
    );
    expect(result).toEqual({
      ok: true,
      bytes: new Uint8Array([0x25, 0x50, 0x44, 0x46]),
    });
    const request = seen[0]!;
    expect(request.method).toBe("POST");
    expect(request.url).toBe(
      "http://studafy-converter-test.internal:8080/convert?from=doc&to=pdf",
    );
    expect(request.headers.get("authorization")).toBe(`Bearer ${KEY}`);
    expect(request.redirect).toBe("error");
    expect(new Uint8Array(await request.arrayBuffer())).toEqual(
      new Uint8Array([1, 2, 3]),
    );
  });

  test("a 422 refusal is an answer with a short code", async () => {
    const refused = converter(() =>
      Response.json({ error: "conversion_timeout" }, { status: 422 })
    );
    expect(await refused.convert(new Uint8Array(1), "ppt", "pptx")).toEqual({
      ok: false,
      code: "conversion_timeout",
    });
    // A code that is not a short snake_case word is not repeated.
    const odd = converter(() =>
      Response.json({ error: "<script>" }, { status: 422 })
    );
    expect(await odd.convert(new Uint8Array(1), "doc", "pdf")).toEqual({
      ok: false,
      code: "conversion_failed",
    });
  });

  test("too large an output is refused, not stored", async () => {
    const big = converter(() => new Response(new Uint8Array(2_000)));
    expect(await big.convert(new Uint8Array(1), "xls", "pdf")).toEqual({
      ok: false,
      code: "output_too_large",
    });
  });

  test("errors, 5xx, 401 and empty bodies are unavailable", async () => {
    for (
      const respond of [
        () => new Response("busy", { status: 503 }),
        () => new Response("no", { status: 401 }),
        () => new Response(new Uint8Array()),
        () => {
          throw new TypeError("connection refused");
        },
      ]
    ) {
      await expect(
        converter(respond).convert(new Uint8Array(1), "doc", "pdf"),
      ).rejects.toBeInstanceOf(ConverterUnavailableError);
    }
  });
});
