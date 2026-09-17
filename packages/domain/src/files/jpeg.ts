/**
 * Strict JPEG structural parser and metadata stripper (FILE-051).
 *
 * Walks the segment structure (SOI, markers, entropy-coded scan data) and
 * rejects anything that is not exactly one well-formed JPEG: truncation,
 * bad segment lengths, missing EOI, and any trailing bytes after EOI (the
 * polyglot guard — a JPEG with an appended ZIP/PDF payload is not a JPEG).
 * The strip rewrite keeps only structural segments plus a JFIF APP0 header
 * and drops every other metadata segment (EXIF, GPS, XMP, ICC, comments),
 * deterministically, without decoding pixels.
 */

const SOI = 0xd8;
const EOI = 0xd9;
const SOS = 0xda;
const TEM = 0x01;
const DQT = 0xdb;
const DHT = 0xc4;
const DHP = 0xde;
const EXP = 0xdf;
const COM = 0xfe;
const APP0 = 0xe0;
const RST_MIN = 0xd0;
const RST_MAX = 0xd7;
const SOF_MARKERS = new Set<number>([
  0xc0,
  0xc1,
  0xc2,
  0xc3,
  0xc5,
  0xc6,
  0xc7,
  0xc9,
  0xca,
  0xcb,
  0xcd,
  0xce,
  0xcf,
]);
const MAX_SEGMENTS = 512;

export interface JpegSegment {
  marker: number;
  /** Offset of the 0xFF that introduces the marker. */
  offset: number;
  /** Total segment size including marker bytes and length field. */
  totalLength: number;
}

export type JpegParseResult =
  | { ok: true; segments: JpegSegment[] }
  | { ok: false; reason: "malformed" | "polyglot" };

export function parseJpeg(bytes: Uint8Array): JpegParseResult {
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== SOI) {
    return { ok: false, reason: "malformed" };
  }
  const segments: JpegSegment[] = [];
  let cursor = 2;
  let sawEoi = false;
  while (cursor < bytes.length) {
    if (bytes[cursor] !== 0xff) return { ok: false, reason: "malformed" };
    const markerStart = cursor;
    let marker: number = bytes[cursor + 1]!;
    while (marker === 0xff) {
      // Fill bytes before a marker are legal padding.
      cursor += 1;
      if (cursor + 1 >= bytes.length) return { ok: false, reason: "malformed" };
      marker = bytes[cursor + 1]!;
    }
    if (marker === EOI) {
      segments.push({
        marker,
        offset: markerStart,
        totalLength: cursor + 2 - markerStart,
      });
      sawEoi = true;
      cursor += 2;
      break;
    }
    if (marker === TEM || (marker >= RST_MIN && marker <= RST_MAX)) {
      return { ok: false, reason: "malformed" };
    }
    if (marker === SOS) {
      // Entropy-coded data: scan for the next real marker. 0x00 after 0xFF
      // is byte stuffing; RST markers are part of the scan.
      let scan = cursor + 2;
      let found: number | null = null;
      while (scan + 1 < bytes.length) {
        if (bytes[scan] === 0xff) {
          const next = bytes[scan + 1]!;
          if (
            next !== 0x00 && !(next >= RST_MIN && next <= RST_MAX) &&
            next !== 0xff
          ) {
            found = scan;
            break;
          }
        }
        scan += 1;
      }
      if (found === null) return { ok: false, reason: "malformed" };
      segments.push({
        marker,
        offset: markerStart,
        totalLength: found - markerStart,
      });
      cursor = found;
      continue;
    }
    // Every remaining marker carries a two-byte big-endian length.
    if (cursor + 4 > bytes.length) return { ok: false, reason: "malformed" };
    const length = (bytes[cursor + 2]! << 8) | bytes[cursor + 3]!;
    if (length < 2) return { ok: false, reason: "malformed" };
    const totalLength = 2 + length; // marker pair + length + payload
    if (markerStart + totalLength > bytes.length) {
      return { ok: false, reason: "malformed" };
    }
    segments.push({
      marker: marker as number,
      offset: markerStart,
      totalLength,
    });
    cursor = markerStart + totalLength;
    if (segments.length > MAX_SEGMENTS) {
      return { ok: false, reason: "malformed" };
    }
  }
  if (!sawEoi) return { ok: false, reason: "malformed" };
  if (cursor !== bytes.length) {
    // Trailing bytes after EOI: appended payload, second file, anything.
    return { ok: false, reason: "polyglot" };
  }
  return { ok: true, segments };
}

/** Collects the payload bytes of every APPn and COM metadata segment. */
export function jpegMetadataPayloads(
  bytes: Uint8Array,
  segments: JpegSegment[],
): Uint8Array[] {
  const payloads: Uint8Array[] = [];
  for (const segment of segments) {
    const isApp = segment.marker >= 0xe0 && segment.marker <= 0xef;
    if (isApp || segment.marker === COM) {
      payloads.push(
        bytes.subarray(
          segment.offset + 4,
          segment.offset + segment.totalLength,
        ),
      );
    }
  }
  return payloads;
}

const KEEP_NON_APP = new Set<number>([
  EOI,
  DQT,
  DHT,
  DHP,
  EXP,
  SOS,
  ...SOF_MARKERS,
]);

/**
 * Deterministic metadata-strip rewrite. Keeps SOI/EOI, the quantization,
 * Huffman, frame and scan segments, and a JFIF APP0 header when present.
 * Every APP1..APP15 and COM segment is removed, which removes EXIF, GPS,
 * XMP, ICC profiles and author comments without touching pixel data.
 */
export function stripJpegMetadata(
  bytes: Uint8Array,
  segments: JpegSegment[],
): Uint8Array {
  const parts: Uint8Array[] = [bytes.subarray(0, 2)];
  for (const segment of segments) {
    const keep = segment.marker === APP0 ||
      KEEP_NON_APP.has(segment.marker);
    if (!keep) continue;
    parts.push(
      bytes.subarray(segment.offset, segment.offset + segment.totalLength),
    );
  }
  const size = parts.reduce((total, part) => total + part.length, 0);
  const out = new Uint8Array(size);
  let cursor = 0;
  for (const part of parts) {
    out.set(part, cursor);
    cursor += part.length;
  }
  return out;
}
