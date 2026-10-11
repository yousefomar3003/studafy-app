import { describe, expect, test } from "bun:test";
import { deflateSync } from "node:zlib";
import {
  analyzeBytes,
  imageDimensions,
  imageExceedsPixelCap,
  imageWithinPixelCap,
} from "../src/index";

function crc32(data: Uint8Array): number {
  let c = ~0;
  for (const byte of data) {
    c ^= byte;
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return ~c >>> 0;
}

function chunk(type: string, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(12 + data.length);
  const view = new DataView(out.buffer);
  view.setUint32(0, data.length);
  for (let i = 0; i < 4; i++) out[4 + i] = type.charCodeAt(i);
  out.set(data, 8);
  view.setUint32(8 + data.length, crc32(out.subarray(4, 8 + data.length)));
  return out;
}

/** A structurally valid greyscale PNG declaring [width] x [height]. */
function png(width: number, height: number): Uint8Array {
  const ihdr = new Uint8Array(13);
  const view = new DataView(ihdr.buffer);
  view.setUint32(0, width);
  view.setUint32(4, height);
  ihdr[8] = 8;
  const parts = [
    Uint8Array.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", deflateSync(new Uint8Array(width + 1))),
    chunk("IEND", new Uint8Array(0)),
  ];
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const part of parts) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}

/** SOI then an SOF0 frame header declaring [width] x [height]. */
function jpeg(width: number, height: number): Uint8Array {
  return Uint8Array.from([
    0xff,
    0xd8,
    0xff,
    0xe0,
    0x00,
    0x04,
    0x00,
    0x00, // APP0, skipped
    0xff,
    0xc0,
    0x00,
    0x0b,
    8,
    height >> 8,
    height & 0xff,
    width >> 8,
    width & 0xff,
    1,
    1,
    0x11,
    0,
  ]);
}

function webpVp8x(width: number, height: number): Uint8Array {
  const out = new Uint8Array(30);
  out.set([..."RIFF"].map((c) => c.charCodeAt(0)), 0);
  out.set([..."WEBP"].map((c) => c.charCodeAt(0)), 8);
  out.set([..."VP8X"].map((c) => c.charCodeAt(0)), 12);
  const w = width - 1;
  const h = height - 1;
  out.set([w & 0xff, (w >> 8) & 0xff, (w >> 16) & 0xff], 24);
  out.set([h & 0xff, (h >> 8) & 0xff, (h >> 16) & 0xff], 27);
  return out;
}

describe("image pixel caps (security audit 2026-10-08)", () => {
  test("dimensions are read from PNG, JPEG and WebP headers", () => {
    expect(imageDimensions(png(4032, 3024))).toEqual({
      width: 4032,
      height: 3024,
    });
    expect(imageDimensions(jpeg(4032, 3024))).toEqual({
      width: 4032,
      height: 3024,
    });
    expect(imageDimensions(webpVp8x(1600, 900))).toEqual({
      width: 1600,
      height: 900,
    });
  });

  test("an ordinary phone photo passes, a pixel bomb does not", () => {
    expect(imageWithinPixelCap(png(4032, 3024))).toBe(true);
    expect(imageWithinPixelCap(jpeg(8064, 6048))).toBe(true); // 48 MP
    expect(imageExceedsPixelCap(png(20_000, 20_000))).toBe(true);
    expect(imageExceedsPixelCap(jpeg(65_000, 65_000))).toBe(true);
    expect(imageExceedsPixelCap(webpVp8x(16_000, 16_000))).toBe(true);
    expect(imageExceedsPixelCap(png(30_000, 10))).toBe(true); // side cap
  });

  test("an unreadable header is never decoded", () => {
    expect(imageWithinPixelCap(Uint8Array.from([1, 2, 3]))).toBe(false);
  });

  test("the scan refuses a small file declaring a huge image", async () => {
    const bomb = png(20_000, 20_000);
    expect(bomb.length).toBeLessThan(1_000_000);
    expect(await analyzeBytes(bomb, "image/png")).toEqual({
      verdict: "policy_rejected",
      errorCode: "decompression_limit",
    });
    expect((await analyzeBytes(png(640, 480), "image/png")).verdict).toBe(
      "clean",
    );
  });
});
