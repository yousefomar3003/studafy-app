/**
 * Strict MP4 (M4A) audio parser and metadata neutraliser (voice notes).
 *
 * Voice notes are AAC in an MP4 container, which iOS and Android both record
 * natively. What is accepted:
 *
 *   - the boxes tile the file exactly, with nothing after the last one (the
 *     polyglot guard), within depth and count limits;
 *   - `ftyp` first, with an MP4-family major brand; one `moov`; `mdat`;
 *   - every track is a sound track (`hdlr` = `soun`) - no video, no text;
 *   - every data reference is self-contained: a file that tells the player
 *     to fetch its media from a URL is refused;
 *   - nothing fragmented (`moof`) or otherwise outside the list below.
 *
 * Metadata (`udta`, `meta`, `uuid` - where titles, GPS, XMP and free-form
 * payloads live) is neutralised rather than removed: the box becomes `free`
 * and its payload zeros. Its size is unchanged, so the absolute sample
 * offsets in `stco`/`co64` stay right without being rewritten, and the
 * rewrite is deterministic.
 */

const MAX_BOXES = 10_000;
const MAX_DEPTH = 8;

/** Major brands of the MP4 family that phones record audio as. */
export const MP4_AUDIO_BRANDS = new Set([
  "M4A ",
  "mp42",
  "mp41",
  "isom",
  "iso2",
  "iso4",
  "iso5",
  "iso6",
  "3gp4",
  "3gp5",
  "3gp6",
]);

const TOP_LEVEL = new Set([
  "ftyp",
  "moov",
  "mdat",
  "free",
  "skip",
  "wide",
  "udta",
  "meta",
  "uuid",
]);
/** Boxes whose children are walked. Everything else is a leaf. */
const CONTAINERS = new Set([
  "moov",
  "trak",
  "mdia",
  "minf",
  "stbl",
  "edts",
  "dinf",
]);
const METADATA = new Set(["udta", "meta", "uuid"]);

export interface Mp4Box {
  type: string;
  offset: number;
  headerLength: number;
  size: number;
}

export type Mp4ParseResult =
  | { ok: true; metadata: Mp4Box[] }
  | { ok: false; reason: "malformed" | "polyglot" | "not_audio" | "external" };

type Failure = Extract<Mp4ParseResult, { ok: false }>;

function type4(bytes: Uint8Array, at: number): string {
  return String.fromCharCode(
    bytes[at]!,
    bytes[at + 1]!,
    bytes[at + 2]!,
    bytes[at + 3]!,
  );
}

function uint32(bytes: Uint8Array, at: number): number {
  return ((bytes[at]! << 24) | (bytes[at + 1]! << 16) |
    (bytes[at + 2]! << 8) | bytes[at + 3]!) >>> 0;
}

/** Reads the boxes in [start, end), or why they do not tile it. */
function readBoxes(
  bytes: Uint8Array,
  start: number,
  end: number,
  topLevel: boolean,
): Mp4Box[] | Failure {
  const boxes: Mp4Box[] = [];
  let cursor = start;
  while (cursor < end) {
    if (cursor + 8 > end) return { ok: false, reason: "malformed" };
    let size = uint32(bytes, cursor);
    const type = type4(bytes, cursor + 4);
    if (!/^[\x20-\x7e]{4}$/.test(type)) {
      return { ok: false, reason: "malformed" };
    }
    let headerLength = 8;
    if (size === 1) {
      if (cursor + 16 > end) return { ok: false, reason: "malformed" };
      const high = uint32(bytes, cursor + 8);
      const low = uint32(bytes, cursor + 12);
      // Nothing here comes near 4 GB; a high word means a lie or a bomb.
      if (high !== 0) return { ok: false, reason: "malformed" };
      size = low;
      headerLength = 16;
    } else if (size === 0) {
      // "To the end of the file" - only ever the last top-level box.
      if (!topLevel) return { ok: false, reason: "malformed" };
      size = end - cursor;
    }
    if (size < headerLength || cursor + size > end) {
      return { ok: false, reason: "malformed" };
    }
    boxes.push({ type, offset: cursor, headerLength, size });
    cursor += size;
  }
  return boxes;
}

export function parseMp4(bytes: Uint8Array): Mp4ParseResult {
  const top = readBoxes(bytes, 0, bytes.length, true);
  // Bytes after the last box never form one, so a second file appended to
  // this one fails here.
  if (!Array.isArray(top)) return top;
  if (top.length === 0 || top[0]!.type !== "ftyp" || top[0]!.size < 16) {
    return { ok: false, reason: "malformed" };
  }
  const brand = type4(bytes, top[0]!.offset + top[0]!.headerLength);
  if (!MP4_AUDIO_BRANDS.has(brand)) return { ok: false, reason: "malformed" };

  const count = (type: string) => top.filter((box) => box.type === type).length;
  if (count("ftyp") !== 1 || count("moov") !== 1 || count("mdat") < 1) {
    return { ok: false, reason: "malformed" };
  }
  for (const box of top) {
    if (!TOP_LEVEL.has(box.type)) return { ok: false, reason: "malformed" };
  }

  const metadata: Mp4Box[] = top.filter((box) => METADATA.has(box.type));
  let total = top.length;
  let tracks = 0;

  // Walks one container, collecting metadata boxes and checking tracks.
  const walk = (box: Mp4Box, depth: number): Failure | null => {
    if (depth > MAX_DEPTH) return { ok: false, reason: "malformed" };
    const children = readBoxes(
      bytes,
      box.offset + box.headerLength,
      box.offset + box.size,
      false,
    );
    if (!Array.isArray(children)) return children;
    total += children.length;
    if (total > MAX_BOXES) return { ok: false, reason: "malformed" };
    for (const child of children) {
      if (METADATA.has(child.type)) {
        metadata.push(child);
        continue;
      }
      if (child.type === "trak") tracks++;
      if (child.type === "hdlr" && box.type === "mdia") {
        // FullBox (4) + pre_defined (4) + handler_type (4).
        if (child.size < child.headerLength + 12) {
          return { ok: false, reason: "malformed" };
        }
        const handler = type4(bytes, child.offset + child.headerLength + 8);
        if (handler !== "soun") return { ok: false, reason: "not_audio" };
      }
      if (child.type === "dref") {
        const failure = checkDataReferences(bytes, child);
        if (failure) return failure;
      }
      if (CONTAINERS.has(child.type)) {
        const failure = walk(child, depth + 1);
        if (failure) return failure;
      }
    }
    return null;
  };

  const moov = top.find((box) => box.type === "moov")!;
  const failure = walk(moov, 1);
  if (failure) return failure;
  if (tracks === 0) return { ok: false, reason: "not_audio" };
  return { ok: true, metadata };
}

/**
 * Every `dref` entry must be a `url ` or `urn ` with the self-contained flag
 * and no location: the media is in this file, nowhere else.
 */
function checkDataReferences(bytes: Uint8Array, dref: Mp4Box): Failure | null {
  const start = dref.offset + dref.headerLength;
  const end = dref.offset + dref.size;
  if (start + 8 > end) return { ok: false, reason: "malformed" };
  const entries = uint32(bytes, start + 4);
  const boxes = readBoxes(bytes, start + 8, end, false);
  if (!Array.isArray(boxes)) return boxes;
  if (boxes.length !== entries) return { ok: false, reason: "malformed" };
  for (const entry of boxes) {
    if (entry.type !== "url " && entry.type !== "urn ") {
      return { ok: false, reason: "external" };
    }
    const flags = uint32(bytes, entry.offset + entry.headerLength) & 0xffffff;
    if ((flags & 1) !== 1 || entry.size !== entry.headerLength + 4) {
      return { ok: false, reason: "external" };
    }
  }
  return null;
}

/** Payloads of the metadata boxes, for the malware signature scan. */
export function mp4MetadataPayloads(
  bytes: Uint8Array,
  metadata: Mp4Box[],
): Uint8Array[] {
  return metadata.map((box) =>
    bytes.subarray(box.offset + box.headerLength, box.offset + box.size)
  );
}

/** Deterministic copy with every metadata box turned into zeroed `free`. */
export function neutralizeMp4Metadata(
  bytes: Uint8Array,
  metadata: Mp4Box[],
): Uint8Array {
  const out = bytes.slice();
  for (const box of metadata) {
    out.set([0x66, 0x72, 0x65, 0x65], box.offset + 4); // "free"
    out.fill(0, box.offset + box.headerLength, box.offset + box.size);
  }
  return out;
}
