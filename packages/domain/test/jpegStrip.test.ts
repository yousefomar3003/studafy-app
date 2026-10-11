import { describe, expect, test } from "bun:test";
import { jpegOrientation, parseJpeg, stripJpegMetadata } from "../src";

/**
 * The metadata strip on phone photos (2026-10-07). A phone camera's JPEG
 * has restart markers in its scan and an orientation in EXIF; the strip
 * once dropped the restart interval (DRI) with the metadata, and every
 * photo decoded as flat gray.
 */

/** A JPEG with EXIF (orientation + GPS-ish junk), DRI and restart markers. */
function phoneJpeg(orientation: number, littleEndian = false): Uint8Array {
  const parts: number[] = [0xff, 0xd8];
  const emit = (marker: number, payload: number[]) =>
    parts.push(
      0xff,
      marker,
      (payload.length + 2) >> 8,
      (payload.length + 2) & 0xff,
      ...payload,
    );
  const u16 = (v: number) =>
    littleEndian ? [v & 0xff, v >> 8] : [v >> 8, v & 0xff];
  const u32 = (v: number) =>
    littleEndian
      ? [v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, v >>> 24]
      : [v >>> 24, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];
  emit(0xe1, [
    ...[0x45, 0x78, 0x69, 0x66, 0, 0],
    ...(littleEndian ? [0x49, 0x49, 0x2a, 0x00] : [0x4d, 0x4d, 0x00, 0x2a]),
    ...u32(8),
    ...u16(2),
    // Make (a string elsewhere) and orientation.
    ...u16(0x010f),
    ...u16(2),
    ...u32(4),
    ...[0x41, 0x70, 0x70, 0x00],
    ...u16(0x0112),
    ...u16(3),
    ...u32(1),
    ...u16(orientation),
    0,
    0,
    ...u32(0),
  ]);
  emit(0xe2, [0x49, 0x43, 0x43]); // an ICC profile, dropped
  emit(0xdb, [0x00, 1, 2, 3]);
  emit(0xc0, [8, 1, 1, 1, 1, 1]);
  emit(0xc4, [0x00, 0x01]);
  emit(0xdd, [0x00, 0x96]); // DRI: a restart every 150 blocks
  parts.push(0xff, 0xda, 0x00, 0x04, 0x01, 0x00);
  parts.push(0x12, 0x34, 0xff, 0xd0, 0x56, 0x78, 0xff, 0xd1, 0x9a);
  parts.push(0xff, 0xd9);
  return Uint8Array.from(parts);
}

function markers(bytes: Uint8Array): number[] {
  const parsed = parseJpeg(bytes);
  if (!parsed.ok) throw new Error(parsed.reason);
  return parsed.segments.map((s) => s.marker);
}

describe("the photo metadata strip", () => {
  test("keeps the restart interval, without which a phone photo is gray", () => {
    const original = phoneJpeg(6);
    const parsed = parseJpeg(original);
    if (!parsed.ok) throw new Error("fixture");
    const stripped = stripJpegMetadata(original, parsed.segments);
    expect(markers(stripped)).toContain(0xdd);
    // The scan, restart markers and all, is untouched.
    const tail = (b: Uint8Array) => [...b.subarray(b.length - 15)];
    expect(tail(stripped)).toEqual(tail(original));
  });

  test("keeps the orientation and nothing else of the EXIF", () => {
    for (const little of [false, true]) {
      const original = phoneJpeg(6, little);
      const parsed = parseJpeg(original);
      if (!parsed.ok) throw new Error("fixture");
      expect(jpegOrientation(original, parsed.segments)).toBe(6);
      const stripped = stripJpegMetadata(original, parsed.segments);
      const again = parseJpeg(stripped);
      if (!again.ok) throw new Error("stripped");
      expect(jpegOrientation(stripped, again.segments)).toBe(6);
      // One APP1 of exactly the orientation block; the camera make and
      // the ICC profile are gone.
      const app1 = again.segments.filter((s) => s.marker === 0xe1);
      expect(app1).toHaveLength(1);
      expect(app1[0]!.totalLength).toBe(36);
      expect(markers(stripped)).not.toContain(0xe2);
      expect(new TextDecoder("latin1").decode(stripped)).not.toContain("App");
    }
  });

  test("an upright photo gets no EXIF at all", () => {
    const original = phoneJpeg(1);
    const parsed = parseJpeg(original);
    if (!parsed.ok) throw new Error("fixture");
    expect(markers(stripJpegMetadata(original, parsed.segments))).not.toContain(
      0xe1,
    );
  });

  test("the rewrite is deterministic, so identical photos still dedupe", () => {
    const original = phoneJpeg(8);
    const parsed = parseJpeg(original);
    if (!parsed.ok) throw new Error("fixture");
    expect(stripJpegMetadata(original, parsed.segments)).toEqual(
      stripJpegMetadata(original, parsed.segments),
    );
  });
});
