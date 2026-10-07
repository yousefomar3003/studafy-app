/**
 * Strict JPEG structural parser and metadata stripper (FILE-051).
 *
 * Walks the segment structure (SOI, markers, entropy-coded scan data) and
 * rejects anything that is not exactly one well-formed JPEG: truncation,
 * bad segment lengths, missing EOI, and any trailing bytes after EOI (the
 * polyglot guard — a JPEG with an appended ZIP/PDF payload is not a JPEG).
 * The strip rewrite keeps only structural segments plus a JFIF APP0 header
 * and drops every other metadata segment (EXIF, GPS, XMP, ICC, comments),
 * deterministically, without decoding pixels. Two things a decoder needs
 * survive it: the restart interval (DRI) - a phone camera's JPEG has restart
 * markers in its scan, and without DRI it decodes as flat gray - and the
 * photo's orientation, rewritten as an EXIF block holding that one tag and
 * nothing else, so a portrait photo is not shown on its side.
 */

const SOI = 0xd8;
const EOI = 0xd9;
const SOS = 0xda;
const TEM = 0x01;
const DQT = 0xdb;
const DHT = 0xc4;
const DHP = 0xde;
const EXP = 0xdf;
/** Restart interval, line count and arithmetic conditioning: structure. */
const DRI = 0xdd;
const DNL = 0xdc;
const DAC = 0xcc;
const APP1 = 0xe1;
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
  DRI,
  DNL,
  DAC,
  SOS,
  ...SOF_MARKERS,
]);

/**
 * The EXIF orientation (1-8) of a JPEG, when it has one other than 1.
 * Reads IFD0 of an APP1 "Exif" segment only, bounds-checked; anything
 * unexpected is "no orientation".
 */
export function jpegOrientation(
  bytes: Uint8Array,
  segments: JpegSegment[],
): number | null {
  for (const segment of segments) {
    if (segment.marker !== APP1) continue;
    const start = segment.offset + 4;
    const end = segment.offset + segment.totalLength;
    if (end - start < 14) continue;
    const header = String.fromCharCode(...bytes.subarray(start, start + 6));
    if (header !== "Exif\0\0") continue;
    const tiff = start + 6;
    const little = bytes[tiff] === 0x49 && bytes[tiff + 1] === 0x49;
    const big = bytes[tiff] === 0x4d && bytes[tiff + 1] === 0x4d;
    if (!little && !big) return null;
    const u16 = (at: number) =>
      at + 2 > end
        ? -1
        : little
        ? bytes[at]! | (bytes[at + 1]! << 8)
        : (bytes[at]! << 8) | bytes[at + 1]!;
    const u32 = (at: number) =>
      at + 4 > end
        ? -1
        : little
        ? (bytes[at]! | (bytes[at + 1]! << 8) | (bytes[at + 2]! << 16) |
          (bytes[at + 3]! << 24)) >>> 0
        : ((bytes[at]! << 24) | (bytes[at + 1]! << 16) |
          (bytes[at + 2]! << 8) | bytes[at + 3]!) >>> 0;
    const ifd = tiff + u32(tiff + 4);
    const count = u16(ifd);
    if (count < 0 || count > 512) return null;
    for (let i = 0; i < count; i++) {
      const entry = ifd + 2 + i * 12;
      if (u16(entry) === 0x0112) {
        const value = u16(entry + 8);
        return value >= 2 && value <= 8 ? value : null;
      }
    }
    return null;
  }
  return null;
}

/** An APP1 EXIF segment holding only the orientation tag. */
function orientationSegment(orientation: number): Uint8Array {
  // "Exif\0\0", a big-endian TIFF header, IFD0 with one SHORT entry
  // (0x0112 = orientation), and no next IFD.
  const payload = [
    0x45,
    0x78,
    0x69,
    0x66,
    0x00,
    0x00,
    0x4d,
    0x4d,
    0x00,
    0x2a,
    0x00,
    0x00,
    0x00,
    0x08,
    0x00,
    0x01,
    0x01,
    0x12,
    0x00,
    0x03,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    orientation,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ];
  const length = payload.length + 2;
  return Uint8Array.from([0xff, APP1, length >> 8, length & 0xff, ...payload]);
}

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
  const orientation = jpegOrientation(bytes, segments);
  let oriented = orientation === null;
  for (const segment of segments) {
    const keep = segment.marker === APP0 ||
      KEEP_NON_APP.has(segment.marker);
    if (!keep) continue;
    // The orientation goes straight after the JFIF header, or first.
    if (!oriented && segment.marker !== APP0) {
      parts.push(orientationSegment(orientation!));
      oriented = true;
    }
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
