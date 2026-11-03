import { describe, expect, test } from "bun:test";
import {
  analyzeBytes,
  CSV_MEDIA_TYPE,
  csvText,
  EICAR_SIGNATURE,
  parseCsvText,
} from "../src";

/**
 * CSV uploads (DL-077). A CSV has no signature, so it is accepted only as
 * plain UTF-8 text: anything binary that calls itself CSV is refused.
 */
describe("CSV files", () => {
  const encode = (text: string) => new TextEncoder().encode(text);

  test("plain text, Arabic and quoted line breaks included, is clean", async () => {
    const file = encode(
      'Name,Score,Note\n"Lina",18,"good, ""clear""\nwork"\r\nسارة,17,ممتاز\n',
    );
    expect(parseCsvText(file)).toEqual({ ok: true, bomStripped: false });
    expect(await analyzeBytes(file, CSV_MEDIA_TYPE)).toEqual({
      verdict: "clean",
    });
  });

  test("a UTF-8 byte-order mark is allowed and not part of the text", () => {
    const file = new Uint8Array([0xef, 0xbb, 0xbf, ...encode("a;b\n1;2\n")]);
    expect(parseCsvText(file)).toEqual({ ok: true, bomStripped: true });
    expect(csvText(file)).toBe("a;b\n1;2\n");
  });

  test("binary bytes declared as CSV are refused", async () => {
    const png = new Uint8Array([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
      0x00,
    ]);
    expect(await analyzeBytes(png, CSV_MEDIA_TYPE)).toEqual({
      verdict: "malformed",
      errorCode: "malformed_file",
    });
    // A NUL anywhere, even in otherwise valid text.
    expect(parseCsvText(encode("a,b\n1,\u00002\n")).ok).toBe(false);
    // Other control bytes.
    expect(parseCsvText(encode("a,b\u001b[31m\n")).ok).toBe(false);
    // Not UTF-8 (Latin-1 "é").
    expect(parseCsvText(new Uint8Array([0x61, 0x2c, 0xe9, 0x0a])).ok).toBe(
      false,
    );
  });

  test("an empty or blank file is refused", () => {
    expect(parseCsvText(new Uint8Array())).toEqual({
      ok: false,
      reason: "malformed",
    });
    expect(parseCsvText(new Uint8Array([0xef, 0xbb, 0xbf])).ok).toBe(false);
    expect(parseCsvText(encode(" \n\n")).ok).toBe(false);
  });

  test("a web page or an SVG called CSV is a polyglot", async () => {
    for (
      const text of [
        "<!DOCTYPE html><script>alert(1)</script>",
        "  <html><body>x</body></html>",
        '<svg xmlns="http://www.w3.org/2000/svg"/>',
        '<?xml version="1.0"?><x/>',
      ]
    ) {
      expect(await analyzeBytes(encode(text), CSV_MEDIA_TYPE)).toEqual({
        verdict: "malformed",
        errorCode: "polyglot_file",
      });
    }
    // A cell that merely mentions a tag is still a CSV.
    expect(parseCsvText(encode("tag,meaning\n<b>,bold\n")).ok).toBe(true);
  });

  test("the EICAR test file is malicious", async () => {
    expect(await analyzeBytes(encode(EICAR_SIGNATURE), CSV_MEDIA_TYPE))
      .toEqual({ verdict: "malicious", errorCode: "malware_detected" });
  });
});
