/**
 * Strict WebP (RIFF container) structural parser and metadata stripper
 * (FILE-051).
 *
 * Validates the RIFF size accounting exactly (the polyglot guard: appended
 * bytes make the declared RIFF size disagree with the file size), walks the
 * chunk list to its exact end, and rejects animation. The strip rewrite
 * drops EXIF, XMP and ICCP chunks and clears the VP8X flag bits that
 * announce them, deterministically, without decoding pixels.
 */

const KEEP = new Set(["VP8X", "VP8 ", "VP8L", "ALPH"]);
const MAX_CHUNKS = 1024;

export interface WebpChunk {
  type: string;
  offset: number;
  totalLength: number;
}

export type WebpParseResult =
  | { ok: true; chunks: WebpChunk[] }
  | { ok: false; reason: "malformed" | "polyglot" | "unsupported" };

export function parseWebp(bytes: Uint8Array): WebpParseResult {
  if (bytes.length < 12) return { ok: false, reason: "malformed" };
  if (asciiAt(bytes, 0, 4) !== "RIFF" || asciiAt(bytes, 8, 12) !== "WEBP") {
    return { ok: false, reason: "malformed" };
  }
  const riffSize = readU32LE(bytes, 4);
  // RIFF size counts everything after the size field; a mismatch means
  // appended or truncated bytes — an exact-size container only.
  if (riffSize !== bytes.length - 8) return { ok: false, reason: "polyglot" };

  const chunks: WebpChunk[] = [];
  let cursor = 12;
  while (cursor < bytes.length) {
    if (cursor + 8 > bytes.length) return { ok: false, reason: "malformed" };
    const type = asciiAt(bytes, cursor, cursor + 4);
    if (!/^[A-Za-z0-9 ]{4}$/.test(type)) {
      return { ok: false, reason: "malformed" };
    }
    const size = readU32LE(bytes, cursor + 4);
    if (cursor + 8 + size > bytes.length) {
      return { ok: false, reason: "malformed" };
    }
    const padded = size + (size % 2);
    if (cursor + 8 + padded > bytes.length) {
      return { ok: false, reason: "malformed" };
    }
    chunks.push({ type, offset: cursor, totalLength: 8 + padded });
    cursor += 8 + padded;
    if (chunks.length > MAX_CHUNKS) return { ok: false, reason: "malformed" };
  }
  if (cursor !== bytes.length) return { ok: false, reason: "polyglot" };
  if (chunks.some((chunk) => chunk.type === "ANIM" || chunk.type === "ANMF")) {
    return { ok: false, reason: "unsupported" };
  }
  const imageCount =
    chunks.filter((chunk) => chunk.type === "VP8 " || chunk.type === "VP8L")
      .length;
  if (imageCount !== 1) return { ok: false, reason: "malformed" };
  return { ok: true, chunks };
}

/** Payloads of metadata chunks — where WebP EXIF/XMP/ICC live. */
export function webpMetadataPayloads(
  bytes: Uint8Array,
  chunks: WebpChunk[],
): Uint8Array[] {
  return chunks
    .filter((chunk) => !KEEP.has(chunk.type))
    .map((chunk) =>
      bytes.subarray(chunk.offset + 8, chunk.offset + 8 + chunk.totalLength - 8)
    );
}

/**
 * Deterministic rewrite: keeps VP8X (with EXIF/XMP/ICC/ANIM flag bits
 * cleared), ALPH and the single VP8/VP8L image chunk; every other chunk is
 * removed. When no VP8X exists the output is the simple-format image alone.
 */
export function stripWebpMetadata(
  bytes: Uint8Array,
  chunks: WebpChunk[],
): Uint8Array {
  const parts: Uint8Array[] = [];
  const hasVp8x = chunks.some((chunk) => chunk.type === "VP8X");
  for (const chunk of chunks) {
    if (!KEEP.has(chunk.type)) continue;
    if (chunk.type === "VP8X" && hasVp8x) {
      const cleaned = bytes.slice(
        chunk.offset,
        chunk.offset + chunk.totalLength,
      );
      // Chunk layout: fourcc(4) size(4) reserved(1) flags(1) reserved(2)
      // width-1(3) height-1(3). Clear ICC(0x20), EXIF(0x08), XMP(0x04) and
      // ANIM(0x02) announcement bits; ALPH(0x10) survives only when an ALPH
      // chunk is kept, which the filter above guarantees.
      const flags = cleaned[9]! & ~0x2e;
      cleaned[9] = flags &
        (chunks.some((chunk2) => chunk2.type === "ALPH") ? 0xff : ~0x10);
      parts.push(cleaned);
      continue;
    }
    parts.push(bytes.subarray(chunk.offset, chunk.offset + chunk.totalLength));
  }
  const bodySize = parts.reduce((total, part) => total + part.length, 0);
  const out = new Uint8Array(12 + bodySize);
  out.set([0x52, 0x49, 0x46, 0x46], 0); // "RIFF"
  writeU32LE(out, 4, bodySize + 4);
  out.set([0x57, 0x45, 0x42, 0x50], 8); // "WEBP"
  let cursor = 12;
  for (const part of parts) {
    out.set(part, cursor);
    cursor += part.length;
  }
  return out;
}

function asciiAt(bytes: Uint8Array, start: number, end: number): string {
  return String.fromCharCode(...bytes.subarray(start, end));
}
function readU32LE(bytes: Uint8Array, offset: number): number {
  // `>>> 0` keeps sizes with the top bit set unsigned; a negative size
  // would otherwise walk the cursor backwards.
  return (bytes[offset]! | (bytes[offset + 1]! << 8) |
    (bytes[offset + 2]! << 16) | (bytes[offset + 3]! << 24)) >>> 0;
}
function writeU32LE(bytes: Uint8Array, offset: number, value: number): void {
  bytes[offset] = value & 0xff;
  bytes[offset + 1] = (value >>> 8) & 0xff;
  bytes[offset + 2] = (value >>> 16) & 0xff;
  bytes[offset + 3] = (value >>> 24) & 0xff;
}
