/**
 * Strict PNG structural parser and metadata stripper (FILE-051).
 *
 * Validates the chunk structure with real CRC32 checks: signature, exactly
 * one IHDR first, contiguous IDAT data, IEND last, nothing after IEND (the
 * polyglot guard). The strip rewrite keeps only the chunks needed to render
 * pixels — IHDR, PLTE, tRNS, IDAT, IEND — and drops every ancillary chunk
 * (tEXt, zTXt, iTXt, eXIf, pHYs, time, …), deterministically.
 */

const PNG_SIGNATURE = Uint8Array.from([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
]);
const MAX_CHUNKS = 4096;
const CRITICAL = new Set(["IHDR", "PLTE", "IDAT", "IEND"]);
const KEEP = new Set(["IHDR", "PLTE", "tRNS", "IDAT", "IEND"]);

export interface PngChunk {
  type: string;
  offset: number;
  totalLength: number;
}

export type PngParseResult =
  | { ok: true; chunks: PngChunk[] }
  | { ok: false; reason: "malformed" | "polyglot" };

export function parsePng(bytes: Uint8Array): PngParseResult {
  if (bytes.length < PNG_SIGNATURE.length + 12) {
    return { ok: false, reason: "malformed" };
  }
  for (let index = 0; index < PNG_SIGNATURE.length; index++) {
    if (bytes[index] !== PNG_SIGNATURE[index]) {
      return { ok: false, reason: "malformed" };
    }
  }
  const chunks: PngChunk[] = [];
  let cursor = PNG_SIGNATURE.length;
  let sawIend = false;
  let sawHeader = false;
  let sawIdat = false;
  let idatRunClosed = false;
  while (cursor < bytes.length && !sawIend) {
    if (cursor + 12 > bytes.length) return { ok: false, reason: "malformed" };
    const length = (bytes[cursor]! << 24) | (bytes[cursor + 1]! << 16) |
      (bytes[cursor + 2]! << 8) | bytes[cursor + 3]!;
    if (length < 0 || cursor + 12 + length > bytes.length) {
      return { ok: false, reason: "malformed" };
    }
    const type = String.fromCharCode(
      bytes[cursor + 4]!,
      bytes[cursor + 5]!,
      bytes[cursor + 6]!,
      bytes[cursor + 7]!,
    );
    if (!/^[A-Za-z]{4}$/.test(type)) return { ok: false, reason: "malformed" };
    const crcStored = ((bytes[cursor + 8 + length]! << 24) |
      (bytes[cursor + 9 + length]! << 16) |
      (bytes[cursor + 10 + length]! << 8) |
      bytes[cursor + 11 + length]!) >>> 0;
    const crcActual = crc32(bytes.subarray(cursor + 4, cursor + 8 + length));
    if (crcStored !== crcActual) return { ok: false, reason: "malformed" };
    // IHDR must come first and exactly once; IDAT chunks must be consecutive.
    if (type === "IHDR") {
      if (sawHeader || chunks.length > 0) {
        return { ok: false, reason: "malformed" };
      }
      sawHeader = true;
    } else if (!sawHeader) {
      return { ok: false, reason: "malformed" };
    }
    if (type === "IDAT") {
      if (idatRunClosed) return { ok: false, reason: "malformed" };
      sawIdat = true;
    } else if (sawIdat) {
      idatRunClosed = true;
    }
    // A critical chunk we do not implement is not something we can keep or
    // safely re-emit: reject instead of guessing. PLTE belongs before IDAT.
    const isAncillary = (bytes[cursor + 4]! & 0x20) !== 0;
    if (!isAncillary && !CRITICAL.has(type)) {
      return { ok: false, reason: "malformed" };
    }
    if (type === "PLTE" && sawIdat) return { ok: false, reason: "malformed" };
    const totalLength = 12 + length;
    chunks.push({ type, offset: cursor, totalLength });
    if (type === "IEND") sawIend = true;
    cursor += totalLength;
    if (chunks.length > MAX_CHUNKS) return { ok: false, reason: "malformed" };
  }
  if (!sawIend || !sawIdat) return { ok: false, reason: "malformed" };
  if (cursor !== bytes.length) return { ok: false, reason: "polyglot" };
  return { ok: true, chunks };
}

/** Payloads of every ancillary chunk — where PNG metadata lives. */
export function pngAncillaryPayloads(
  bytes: Uint8Array,
  chunks: PngChunk[],
): Uint8Array[] {
  return chunks
    .filter((chunk) => !CRITICAL.has(chunk.type) && chunk.type !== "tRNS")
    .map((chunk) =>
      bytes.subarray(chunk.offset + 8, chunk.offset + chunk.totalLength - 4)
    );
}

/** Deterministic rewrite keeping only IHDR, PLTE, tRNS, IDAT and IEND. */
export function stripPngMetadata(
  bytes: Uint8Array,
  chunks: PngChunk[],
): Uint8Array {
  const parts: Uint8Array[] = [bytes.subarray(0, PNG_SIGNATURE.length)];
  for (const chunk of chunks) {
    if (!KEEP.has(chunk.type)) continue;
    parts.push(bytes.subarray(chunk.offset, chunk.offset + chunk.totalLength));
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

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(data: Uint8Array): number {
  let crc = 0xffffffff;
  for (let index = 0; index < data.length; index++) {
    crc = CRC_TABLE[(crc ^ data[index]!) & 0xff]! ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
