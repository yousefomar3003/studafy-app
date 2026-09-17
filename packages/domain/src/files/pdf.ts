/**
 * Bounded PDF structural guard (FILE-051).
 *
 * This is not a full PDF renderer-level parser; it is the security gate the
 * Part 5B plan requires, with honest limits documented in the threat model:
 *  - `%PDF-` header exactly once, at offset zero (an appended second
 *    document is a polyglot, not a PDF);
 *  - `%%EOF` and `startxref` present;
 *  - raw scan of the whole file for `/Encrypt`, `/EmbeddedFile`,
 *    `/JavaScript`, `/JS`, `/Launch`, `/OpenAction` and the EICAR test
 *    signature;
 *  - every `/FlateDecode` stream is located and inflated under hard output
 *    caps (the archive-bomb guard), and the inflated bytes are scanned for
 *    the same patterns plus embedded `%PDF-` documents;
 *  - streams with other filters (for example DCTDecode images) are covered
 *    by the raw scan only — inflation is implemented for FlateDecode alone,
 *    and that boundary is recorded rather than hidden.
 *
 * A stream whose declared filter is FlateDecode but whose bytes do not
 * inflate is malformed, not skipped: a filter that cannot be inspected is a
 * filter that can hide anything.
 */
import { inflateSync } from "node:zlib";
import { asciiOf, containsEicarSignature } from "./eicar";

/** Per-stream inflated ceiling (policy cap). */
export const PDF_STREAM_INFLATE_CAP_BYTES = 100 * 1024 * 1024;
/** Hard allocation ceiling used to distinguish bombs from corruption. */
const PDF_STREAM_INFLATE_HARD_CAP_BYTES = 128 * 1024 * 1024;
/** Total inflated budget across the whole document. */
export const PDF_TOTAL_INFLATE_CAP_BYTES = 250 * 1024 * 1024;
/** Bounded retry when compressed data itself contains the bytes `endstream`. */
const MAX_ENDSTREAM_PROBES = 8;
const MAX_STREAM_CANDIDATES = 10_000;

export type PdfRejectReason =
  | "malformed"
  | "polyglot"
  | "encrypted"
  | "embedded"
  | "active_content"
  | "malicious"
  | "decompression_limit";

export type PdfParseResult =
  | { ok: true; streamCount: number; inflatedBytes: number }
  | { ok: false; reason: PdfRejectReason };

interface DangerPattern {
  needle: string;
  reason: Exclude<
    PdfRejectReason,
    "malformed" | "polyglot" | "decompression_limit" | "malicious"
  >;
}

const DANGER_PATTERNS: DangerPattern[] = [
  { needle: "/Encrypt", reason: "encrypted" },
  { needle: "/EmbeddedFile", reason: "embedded" },
  { needle: "/JavaScript", reason: "active_content" },
  { needle: "/Launch", reason: "active_content" },
  { needle: "/OpenAction", reason: "active_content" },
];

export async function parsePdf(bytes: Uint8Array): Promise<PdfParseResult> {
  const text = asciiOf(bytes);
  if (!text.startsWith("%PDF-")) return { ok: false, reason: "malformed" };
  if (text.indexOf("%PDF-", 5) !== -1) return { ok: false, reason: "polyglot" };
  if (!text.includes("%%EOF") || !text.includes("startxref")) {
    return { ok: false, reason: "malformed" };
  }
  const danger = scanDanger(text);
  if (danger) return { ok: false, reason: danger };
  if (containsEicarSignature(bytes)) return { ok: false, reason: "malicious" };

  let streamCount = 0;
  let inflatedBytes = 0;
  let cursor = 5;
  while (cursor < text.length) {
    const streamAt = nextStreamKeyword(text, cursor);
    if (streamAt === null) break;
    streamCount += 1;
    if (streamCount > MAX_STREAM_CANDIDATES) {
      return { ok: false, reason: "malformed" };
    }
    const dataStart = skipEol(text, streamAt + 6);
    if (dataStart === null) return { ok: false, reason: "malformed" };
    const dictionaryWindow = text.slice(Math.max(0, streamAt - 512), streamAt);
    if (dictionaryWindow.includes("/FlateDecode")) {
      const inflated = inflateStreamRegion(bytes, text, dataStart);
      if (inflated === null) return { ok: false, reason: "malformed" };
      if (inflated === "limit") {
        return { ok: false, reason: "decompression_limit" };
      }
      const inflatedText = asciiOf(inflated);
      if (inflatedText.includes("%PDF-")) {
        return { ok: false, reason: "embedded" };
      }
      const inflatedDanger = scanDanger(inflatedText);
      if (inflatedDanger) return { ok: false, reason: inflatedDanger };
      if (containsEicarSignature(inflated)) {
        return { ok: false, reason: "malicious" };
      }
      inflatedBytes += inflated.length;
      if (inflatedBytes > PDF_TOTAL_INFLATE_CAP_BYTES) {
        return { ok: false, reason: "decompression_limit" };
      }
    }
    // Continue after this stream's first endstream marker regardless of the
    // probe used, so overlapping regions are not re-inflated.
    const next = text.indexOf("endstream", dataStart);
    cursor = next === -1 ? text.length : next + 9;
  }
  return { ok: true, streamCount, inflatedBytes };
}

function scanDanger(
  text: string,
): DangerPattern["reason"] | "active_content" | null {
  for (const pattern of DANGER_PATTERNS) {
    if (text.includes(pattern.needle)) return pattern.reason;
  }
  // `/JS` needs a delimiter check so words like `/JSON`-shaped content do
  // not trip it, while the real PDF action `/JS (` does.
  let at = text.indexOf("/JS");
  while (at !== -1) {
    const following = text.charCodeAt(at + 3);
    const delimited = !following ||
      !(following >= 0x41 && following <= 0x5a) && // A-Z
        !(following >= 0x61 && following <= 0x7a) && // a-z
        !(following >= 0x30 && following <= 0x39) && // 0-9
        following !== 0x23 && following !== 0x2f; // # /
    if (delimited) return "active_content" as const;
    at = text.indexOf("/JS", at + 3);
  }
  return null;
}

function nextStreamKeyword(text: string, from: number): number | null {
  let at = text.indexOf("stream", from);
  while (at !== -1) {
    const prev = at > 0 ? text.charCodeAt(at - 1) : 0;
    const next1 = text.charCodeAt(at + 6);
    const next2 = text.charCodeAt(at + 7);
    const startsData = next1 === 0x0a || (next1 === 0x0d && next2 === 0x0a);
    const prevIsBoundary = prev === 0x20 || prev === 0x0a || prev === 0x0d ||
      prev === 0x3e; // '>' closes a dictionary
    // `endstream` also contains `stream`; the previous-character check
    // rejects it because 'd' precedes the match there.
    if (startsData && prevIsBoundary) return at;
    at = text.indexOf("stream", at + 6);
  }
  return null;
}

function skipEol(text: string, at: number): number | null {
  if (text.charCodeAt(at) === 0x0d && text.charCodeAt(at + 1) === 0x0a) {
    return at + 2;
  }
  if (text.charCodeAt(at) === 0x0a) return at + 1;
  return null;
}

/**
 * Inflates one stream region. The region extends from just after the
 * `stream` newline to a candidate `endstream` marker; because compressed
 * data may itself contain those bytes, later markers are probed in order
 * until the bytes inflate. `limit` means the inflated output exceeds the
 * policy cap; `null` means the bytes are not a zlib stream at all.
 */
function inflateStreamRegion(
  bytes: Uint8Array,
  text: string,
  dataStart: number,
): Uint8Array | "limit" | null {
  const ends: number[] = [];
  let search = dataStart;
  while (ends.length < MAX_ENDSTREAM_PROBES) {
    const at = text.indexOf("endstream", search);
    if (at === -1) break;
    ends.push(at);
    search = at + 9;
  }
  if (ends.length === 0) return null;
  for (const end of ends) {
    let dataEnd = end;
    if (bytes[dataEnd - 1] === 0x0a) dataEnd -= 1;
    if (bytes[dataEnd - 1] === 0x0d) dataEnd -= 1;
    if (dataEnd <= dataStart) continue;
    const region = bytes.subarray(dataStart, dataEnd);
    const attempt = tryInflate(region, PDF_STREAM_INFLATE_CAP_BYTES + 1);
    if (typeof attempt === "object") return attempt;
    if (attempt === "over-policy") {
      // Output passed the policy cap before the hard ceiling: a bomb or an
      // oversized stream — either way over the documented limit.
      return "limit";
    }
  }
  return null;
}

type InflateAttempt = Uint8Array | "over-policy" | "corrupt";

function tryInflate(region: Uint8Array, ceiling: number): InflateAttempt {
  try {
    const out = new Uint8Array(
      inflateSync(region, { maxOutputLength: ceiling }),
    );
    return out.byteLength > PDF_STREAM_INFLATE_CAP_BYTES ? "over-policy" : out;
  } catch {
    // Distinguish "genuinely corrupt" from "exceeded the attempted ceiling"
    // by retrying at the hard allocation ceiling: success there proves the
    // stream inflates but is over policy; failure proves corruption.
    try {
      inflateSync(region, {
        maxOutputLength: PDF_STREAM_INFLATE_HARD_CAP_BYTES,
      });
      return "over-policy";
    } catch {
      return "corrupt";
    }
  }
}
