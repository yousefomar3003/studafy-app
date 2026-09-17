import { describe, expect, test } from "bun:test";
import { deflateSync } from "node:zlib";
import {
  analyzeBytes,
  containsBytes,
  containsEicarSignature,
  createDeliveryNonce,
  EICAR_SIGNATURE,
  hashDeliveryNonce,
  isDedupeEligible,
  parseJpeg,
  parsePng,
  parseWebp,
  signDeliveryToken,
  stripPngMetadata,
  stripWebpMetadata,
  transformBytes,
  verifyDeliveryToken,
} from "../src";

// ---------------------------------------------------------------------------
// Fixture builders. Everything is synthesized: no binary files in the repo,
// every fixture deterministic.
// ---------------------------------------------------------------------------

function asciiBytes(text: string): Uint8Array {
  return Uint8Array.from([...text].map((char) => char.charCodeAt(0)));
}

/** A structurally valid minimal JPEG: SOI, DQT, SOF0, DHT, SOS scan, EOI. */
function buildJpeg(
  extraSegments: { marker: number; payload: Uint8Array[] }[] = [],
): Uint8Array {
  const parts: number[] = [0xff, 0xd8];
  const emit = (marker: number, payload: number[]) => {
    parts.push(
      0xff,
      marker,
      (payload.length + 2) >> 8,
      (payload.length + 2) & 0xff,
      ...payload,
    );
  };
  for (const extra of extraSegments) {
    for (const payload of extra.payload) emit(extra.marker, [...payload]);
  }
  emit(0xdb, [0x00, 1, 2, 3]); // DQT
  emit(0xc0, [8, 1, 1, 1, 1, 1]); // SOF0
  emit(0xc4, [0x00, 0x01]); // DHT
  // SOS header then entropy bytes that never look like a marker.
  parts.push(0xff, 0xda, 0x00, 0x04, 0x01, 0x00);
  parts.push(0x12, 0x34, 0x56, 0x78);
  parts.push(0xff, 0xd9);
  return Uint8Array.from(parts);
}

function jpegSegment(
  marker: number,
  payload: string,
): { marker: number; payload: Uint8Array[] } {
  return { marker, payload: [asciiBytes(payload)] };
}

function crc32Of(data: Uint8Array): number {
  let c = ~0;
  for (const byte of data) {
    c ^= byte;
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return ~c >>> 0;
}

function pngChunk(type: string, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(12 + data.length);
  const view = new DataView(out.buffer);
  view.setUint32(0, data.length);
  out.set(asciiBytes(type), 4);
  out.set(data, 8);
  const crcInput = new Uint8Array(4 + data.length);
  crcInput.set(asciiBytes(type), 0);
  crcInput.set(data, 4);
  view.setUint32(8 + data.length, crc32Of(crcInput));
  return out;
}

function buildPng(
  extraChunks: { type: string; data: Uint8Array }[] = [],
): Uint8Array {
  const signature = Uint8Array.from([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
  ]);
  const ihdr = pngChunk("IHDR", new Uint8Array(13));
  const idat = pngChunk(
    "IDAT",
    Uint8Array.from([0x78, 0x9c, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01]),
  );
  const iend = pngChunk("IEND", new Uint8Array(0));
  const chunks = [
    signature,
    ihdr,
    ...extraChunks.map((chunk) => pngChunk(chunk.type, chunk.data)),
    idat,
    iend,
  ];
  return concat(chunks);
}

function buildWebp(
  extraChunks: { type: string; data: Uint8Array }[] = [],
): Uint8Array {
  const vp8 = withSize("VP8 ", Uint8Array.from([0x30, 0x01]));
  const body = [
    vp8,
    ...extraChunks.map((chunk) => withSize(chunk.type, chunk.data)),
  ];
  const bodySize = body.reduce((total, part) => total + part.length, 0);
  const out = new Uint8Array(12 + bodySize);
  out.set(asciiBytes("RIFF"), 0);
  new DataView(out.buffer).setUint32(4, bodySize + 4, true);
  out.set(asciiBytes("WEBP"), 8);
  let cursor = 12;
  for (const part of body) {
    out.set(part, cursor);
    cursor += part.length;
  }
  return out;
}

function withSize(type: string, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(8 + data.length);
  out.set(asciiBytes(type), 0);
  new DataView(out.buffer).setUint32(4, data.length, true);
  out.set(data, 8);
  return out;
}

function concat(parts: Uint8Array[]): Uint8Array {
  const size = parts.reduce((total, part) => total + part.length, 0);
  const out = new Uint8Array(size);
  let cursor = 0;
  for (const part of parts) {
    out.set(part, cursor);
    cursor += part.length;
  }
  return out;
}

function buildPdf(body: string, flateStreams: Uint8Array[] = []): Uint8Array {
  const parts: Uint8Array[] = [
    asciiBytes("%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n"),
  ];
  let objectNumber = 2;
  for (const stream of flateStreams) {
    parts.push(
      asciiBytes(
        `${objectNumber} 0 obj\n<< /Length ${stream.length} /Filter /FlateDecode >>\nstream\n`,
      ),
      stream,
      asciiBytes("\nendstream\nendobj\n"),
    );
    objectNumber += 1;
  }
  parts.push(asciiBytes(body));
  parts.push(asciiBytes("trailer\n<< /Size 2 >>\nstartxref\n0\n%%EOF\n"));
  return concat(parts);
}

const TEXT = "plain text body";
const FLATE_TEXT = new Uint8Array(
  // PDF FlateDecode is zlib format (RFC 1950), not the gzip wrapper.
  deflateSync(new TextEncoder().encode(TEXT)),
);

// ---------------------------------------------------------------------------
// Byte search
// ---------------------------------------------------------------------------

describe("containsBytes", () => {
  test("finds the EICAR signature anywhere", () => {
    const file = concat([
      asciiBytes("header\n"),
      asciiBytes(EICAR_SIGNATURE),
      asciiBytes("\ntrailer"),
    ]);
    expect(containsEicarSignature(file)).toBe(true);
    expect(containsBytes(asciiBytes("abc"), asciiBytes("abcd"))).toBe(false);
    expect(containsBytes(asciiBytes("abcd"), asciiBytes(""))).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// JPEG
// ---------------------------------------------------------------------------

describe("jpeg", () => {
  test("accepts a well-formed jpeg and strips its metadata deterministically", () => {
    const jpeg = buildJpeg([
      jpegSegment(0xe1, "Exif\0\0GPSDATA"),
      jpegSegment(0xfe, "a comment"),
    ]);
    const parsed = parseJpeg(jpeg);
    expect(parsed.ok).toBe(true);
    const transform = transformBytes(jpeg, "image/jpeg");
    expect(transform.bytes).not.toBeNull();
    expect(transform.transformPolicyVersion).toBe(
      "file051-structural-strip-v1",
    );
    const once = transform.bytes!;
    const twice = transformBytes(once, "image/jpeg").bytes!;
    expect([...twice]).toEqual([...once]);
    expect(once.byteLength).toBeLessThan(jpeg.byteLength);
    expect(once.includes(0xe1)).toBe(false); // no APP1 in the output
    const reparsed = parseJpeg(once);
    expect(reparsed.ok).toBe(true);
  });

  test("rejects trailing bytes after EOI as a polyglot", () => {
    const jpeg = concat([buildJpeg(), asciiBytes("PK\x03\x04 appended zip")]);
    const parsed = parseJpeg(jpeg);
    expect(parsed).toEqual({ ok: false, reason: "polyglot" });
  });

  test("rejects truncation", () => {
    const jpeg = buildJpeg().subarray(0, 20);
    expect(parseJpeg(jpeg).ok).toBe(false);
  });

  test("flags EICAR inside an EXIF segment", async () => {
    const jpeg = buildJpeg([jpegSegment(0xe1, `Exif\0\0${EICAR_SIGNATURE}`)]);
    const verdict = await analyzeBytes(jpeg, "image/jpeg");
    expect(verdict).toEqual({
      verdict: "malicious",
      errorCode: "malware_detected",
    });
  });
});

// ---------------------------------------------------------------------------
// PNG
// ---------------------------------------------------------------------------

describe("png", () => {
  test("accepts a well-formed png and strips ancillary chunks", () => {
    const png = buildPng([
      { type: "tEXt", data: asciiBytes("Comment\0school data") },
      { type: "eXIf", data: asciiBytes("EXIF-GPS") },
    ]);
    const parsed = parsePng(png);
    if (!parsed.ok) throw new Error("fixture png must parse");
    const stripped = stripPngMetadata(png, parsed.chunks);
    const reparsed = parsePng(stripped);
    expect(reparsed.ok).toBe(true);
    expect(stripped.byteLength).toBeLessThan(png.byteLength);
    if (!reparsed.ok) throw new Error("stripped png must parse");
    expect(reparsed.chunks.map((chunk) => chunk.type)).toEqual([
      "IHDR",
      "IDAT",
      "IEND",
    ]);
    const twice = transformBytes(stripped, "image/png").bytes!;
    expect([...twice]).toEqual([...stripped]);
  });

  test("rejects an appended payload after IEND", () => {
    const png = concat([buildPng(), asciiBytes("%PDF-1.4 appended document")]);
    expect(parsePng(png)).toEqual({ ok: false, reason: "polyglot" });
  });

  test("rejects a corrupted CRC", () => {
    const broken = buildPng();
    broken[broken.length - 1]! ^= 0xff; // last byte of the IEND CRC
    expect(parsePng(broken).ok).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// WebP
// ---------------------------------------------------------------------------

describe("webp", () => {
  test("accepts a simple webp and drops EXIF chunks", () => {
    const webp = buildWebp([{ type: "EXIF", data: asciiBytes("Exif-GPS") }]);
    const parsed = parseWebp(webp);
    if (!parsed.ok) throw new Error("fixture webp must parse");
    const stripped = stripWebpMetadata(webp, parsed.chunks);
    expect(parseWebp(stripped).ok).toBe(true);
    expect(stripped.byteLength).toBeLessThan(webp.byteLength);
  });

  test("a chunk size with the top bit set is malformed, not a backwards walk", () => {
    const bytes = buildWebp([{ type: "EXIF", data: asciiBytes("abcd") }]);
    const exifSizeOffset = bytes.length - 8;
    new DataView(bytes.buffer).setUint32(exifSizeOffset, 0xfffffff8, true);
    expect(parseWebp(bytes)).toEqual({ ok: false, reason: "malformed" });
  });

  test("rejects size-mismatch polyglots and animation", async () => {
    const webp = buildWebp();
    const appended = concat([webp, asciiBytes("junkjunk")]);
    expect(parseWebp(appended)).toEqual({ ok: false, reason: "polyglot" });
    const animated = buildWebp([{ type: "ANIM", data: new Uint8Array(6) }]);
    expect(parseWebp(animated)).toEqual({ ok: false, reason: "unsupported" });
    const verdict = await analyzeBytes(animated, "image/webp");
    expect(verdict).toEqual({
      verdict: "policy_rejected",
      errorCode: "unsupported_animation",
    });
  });
});

// ---------------------------------------------------------------------------
// PDF
// ---------------------------------------------------------------------------

describe("pdf", () => {
  test("accepts a clean pdf with an inflated stream", async () => {
    const pdf = buildPdf("", [FLATE_TEXT]);
    const verdict = await analyzeBytes(pdf, "application/pdf");
    expect(verdict.verdict).toBe("clean");
    const transform = transformBytes(pdf, "application/pdf");
    expect(transform.bytes).toBeNull();
    expect(transform.transformPolicyVersion).toBeNull();
  });

  test("rejects active content, encryption and embedded files", async () => {
    const js = await analyzeBytes(
      buildPdf("<< /OpenAction << /S /JavaScript /JS (alert(1)) >> >>\n"),
      "application/pdf",
    );
    expect(js).toEqual({
      verdict: "policy_rejected",
      errorCode: "active_content",
    });
    const encrypted = await analyzeBytes(
      buildPdf("<< /Filter /Standard /Encrypt >>\n"),
      "application/pdf",
    );
    expect(encrypted).toEqual({
      verdict: "policy_rejected",
      errorCode: "encrypted_document",
    });
    const embedded = await analyzeBytes(
      buildPdf("<< /EmbeddedFile 2 0 R >>\n"),
      "application/pdf",
    );
    expect(embedded).toEqual({
      verdict: "policy_rejected",
      errorCode: "embedded_file",
    });
  });

  test("catches EICAR and active content hidden inside inflated streams", async () => {
    const eicarStream = new Uint8Array(
      deflateSync(new TextEncoder().encode(EICAR_SIGNATURE)),
    );
    const verdict = await analyzeBytes(
      buildPdf("", [eicarStream]),
      "application/pdf",
    );
    expect(verdict).toEqual({
      verdict: "malicious",
      errorCode: "malware_detected",
    });
    const jsStream = new Uint8Array(
      deflateSync(new TextEncoder().encode("<< /S /JavaScript /JS (x) >>")),
    );
    const jsVerdict = await analyzeBytes(
      buildPdf("", [jsStream]),
      "application/pdf",
    );
    expect(jsVerdict).toEqual({
      verdict: "policy_rejected",
      errorCode: "active_content",
    });
  });

  test("rejects a decompression bomb by inflated size", async () => {
    // 101 MiB of zeros inflates from a few hundred KiB; the policy cap is
    // 100 MiB, so this stream must be rejected by size, not stored.
    const bomb = new Uint8Array(deflateSync(new Uint8Array(101 * 1024 * 1024)));
    const verdict = await analyzeBytes(buildPdf("", [bomb]), "application/pdf");
    expect(verdict).toEqual({
      verdict: "policy_rejected",
      errorCode: "decompression_limit",
    });
  });

  test("rejects an appended second document and missing EOF", async () => {
    const appended = concat([
      buildPdf(""),
      asciiBytes("%PDF-1.4 second copy\n%%EOF\n"),
    ]);
    const verdict = await analyzeBytes(appended, "application/pdf");
    expect(verdict).toEqual({
      verdict: "malformed",
      errorCode: "polyglot_file",
    });
    const noEof = asciiBytes("%PDF-1.7\n1 0 obj\n<< >>\nendobj\n");
    const eofVerdict = await analyzeBytes(noEof, "application/pdf");
    expect(eofVerdict).toEqual({
      verdict: "malformed",
      errorCode: "malformed_file",
    });
  });
});

// ---------------------------------------------------------------------------
// Dedupe policy twin
// ---------------------------------------------------------------------------

describe("dedupe eligibility", () => {
  const eligible = {
    sameSchool: true,
    samePurpose: true,
    sameSha256: true,
    bothClean: true,
    neitherUnderLegalHold: true,
    canonicalIsRoot: true,
    incomingIsRoot: true,
  };
  test("eligibility requires every condition", () => {
    expect(isDedupeEligible(eligible)).toBe(true);
    for (const key of Object.keys(eligible) as (keyof typeof eligible)[]) {
      expect(isDedupeEligible({ ...eligible, [key]: false })).toBe(false);
    }
  });
});

// ---------------------------------------------------------------------------
// Verdict composition
// ---------------------------------------------------------------------------

describe("verdict", () => {
  test("a type mismatch is malformed, never clean", async () => {
    expect(await analyzeBytes(buildJpeg(), "image/png")).toEqual({
      verdict: "malformed",
      errorCode: "malformed_file",
    });
    expect((await analyzeBytes(buildPng(), "application/pdf")).verdict).not
      .toBe("clean");
    expect((await analyzeBytes(buildPdf(""), "image/webp")).verdict).not.toBe(
      "clean",
    );
  });

  test("an unknown detected type is never clean", async () => {
    for (const type of ["", "text/html", "application/zip", "image/svg+xml"]) {
      expect((await analyzeBytes(asciiBytes("<svg/>"), type)).verdict).toBe(
        "malformed",
      );
    }
  });

  test("the bare EICAR file is malicious whatever type it claims", async () => {
    for (
      const type of [
        "image/png",
        "image/jpeg",
        "image/webp",
        "application/pdf",
        "text/plain",
      ]
    ) {
      expect(await analyzeBytes(asciiBytes(EICAR_SIGNATURE), type)).toEqual({
        verdict: "malicious",
        errorCode: "malware_detected",
      });
    }
  });

  test("transformation is idempotent, so a retried scan converges", async () => {
    const cases: [Uint8Array, string][] = [
      [buildJpeg([jpegSegment(0xe1, "Exif\0\0camera")]), "image/jpeg"],
      [
        buildPng([{ type: "tEXt", data: asciiBytes("Author\0someone") }]),
        "image/png",
      ],
      [buildWebp([{ type: "EXIF", data: asciiBytes("gpsx") }]), "image/webp"],
    ];
    for (const [bytes, type] of cases) {
      const once = transformBytes(bytes, type).bytes!;
      expect(once).not.toEqual(bytes);
      expect((await analyzeBytes(once, type)).verdict).toBe("clean");
      expect(transformBytes(once, type).bytes).toEqual(once);
    }
  });

  test("transformation is deterministic and leaves pdfs untouched", () => {
    const jpeg = buildJpeg([jpegSegment(0xe1, "Exif\0\0GPS 51.5N 0.1W")]);
    const first = transformBytes(jpeg, "image/jpeg");
    const second = transformBytes(jpeg, "image/jpeg");
    expect(first.bytes).not.toBeNull();
    expect(first.bytes).toEqual(second.bytes);
    expect(containsBytes(first.bytes!, asciiBytes("GPS"))).toBe(false);
    expect(transformBytes(buildPdf(""), "application/pdf")).toEqual({
      bytes: null,
      transformPolicyVersion: null,
    });
  });
});

// ---------------------------------------------------------------------------
// Delivery tokens
// ---------------------------------------------------------------------------

describe("delivery tokens", () => {
  // Synthetic, deliberately low-entropy signing material.
  const key = "synthetic-".repeat(4);
  const input = {
    fileId: "11111111-1111-4111-8111-111111111111",
    userId: "22222222-2222-4222-8222-222222222222",
    nonce: "n".repeat(43),
    ttlSeconds: 120,
  };

  test("round-trips and binds to the file", async () => {
    const now = 1_000_000;
    const token = await signDeliveryToken({ ...input, nowSeconds: now }, key);
    const payload = await verifyDeliveryToken(
      token,
      key,
      input.fileId,
      now + 60,
    );
    expect(payload?.userId).toBe(input.userId);
    expect(await verifyDeliveryToken(token, key, input.fileId, now + 121))
      .toBeNull();
    const otherFile = "33333333-3333-4333-8333-333333333333";
    expect(await verifyDeliveryToken(token, key, otherFile, now + 60))
      .toBeNull();
  });

  test("rejects tampering, wrong key and malformed input", async () => {
    const now = 1_000_000;
    const token = await signDeliveryToken({ ...input, nowSeconds: now }, key);
    const parts = token.split(".");
    const tampered = `${parts[0]}.${"A".repeat(parts[1]!.length)}`;
    expect(await verifyDeliveryToken(tampered, key, input.fileId, now + 60))
      .toBeNull();
    expect(
      await verifyDeliveryToken(
        token,
        "wrong-key-wrong-key-wrong-key-xx",
        input.fileId,
        now + 60,
      ),
    ).toBeNull();
    expect(
      await verifyDeliveryToken("not-a-token", key, input.fileId, now + 60),
    ).toBeNull();
    expect(await verifyDeliveryToken("aaaa.bbbb", key, input.fileId, now + 60))
      .toBeNull();
  });

  test("rejects malformed base64 and oversized tokens without throwing", async () => {
    expect(await verifyDeliveryToken("aaaa.!!!!", key, input.fileId))
      .toBeNull();
    expect(await verifyDeliveryToken("@@@@.bbbb", key, input.fileId))
      .toBeNull();
    expect(await verifyDeliveryToken("a".repeat(2000), key, input.fileId))
      .toBeNull();
  });

  test("nonces are random, well-formed, and persisted only as a hash", async () => {
    const first = createDeliveryNonce();
    const second = createDeliveryNonce();
    expect(first).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(first).not.toBe(second);
    const hash = await hashDeliveryNonce(first);
    expect(hash).toMatch(/^[0-9a-f]{64}$/);
    expect(hash).toBe(await hashDeliveryNonce(first));
    expect(hash).not.toContain(first);
    const token = await signDeliveryToken({ ...input, nonce: first }, key);
    expect(token).not.toContain(hash);
    const payload = await verifyDeliveryToken(token, key, input.fileId);
    expect(payload?.nonce).toBe(first);
  });

  test("a malformed nonce is refused at signing time", async () => {
    expect(signDeliveryToken({ ...input, nonce: "short" }, key)).rejects
      .toThrow();
  });

  test("TTL bounds are enforced at signing time", async () => {
    expect(signDeliveryToken({ ...input, ttlSeconds: 10 }, key)).rejects
      .toThrow();
    expect(signDeliveryToken({ ...input, ttlSeconds: 9999 }, key)).rejects
      .toThrow();
  });
});
