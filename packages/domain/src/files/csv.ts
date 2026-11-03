/**
 * CSV structural guard (DL-077).
 *
 * A CSV has no signature to detect, so it is accepted only as what it says
 * it is: plain text. Like the other guards this is a gate, not a parser:
 *  - the bytes must be UTF-8 (a leading byte-order mark is allowed);
 *  - no NUL and no control character other than tab, line feed and carriage
 *    return - binary data labelled as text fails here;
 *  - a file that opens like a web page, an SVG or an XML document is not a
 *    CSV, whatever its name (a polyglot);
 *  - nothing in it is ever executed: it is stored unchanged, served as a
 *    download, and the material reader only reads its cells as text.
 *
 * Size is bounded by the upload purpose's own ceiling (FILE-050), and the
 * material reader stops at its per-file character cap.
 */

export const CSV_MEDIA_TYPE = "text/csv";

export type CsvRejectReason = "malformed" | "polyglot";

export type CsvParseResult =
  | { ok: true; bomStripped: boolean }
  | { ok: false; reason: CsvRejectReason };

const strictUtf8 = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });

// deno-lint-ignore no-control-regex -- control bytes are what is refused
const CONTROL = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/;

// The start of a document a browser or an image viewer would render.
const MARKUP_START = /^\s*<(?:!doctype|html|head|body|script|svg|\?xml)\b/i;

function hasBom(bytes: Uint8Array): boolean {
  return bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb &&
    bytes[2] === 0xbf;
}

/** The text of a CSV the scan would accept, or null. */
export function csvText(bytes: Uint8Array): string | null {
  const result = parseCsvText(bytes);
  if (!result.ok) return null;
  return strictUtf8.decode(result.bomStripped ? bytes.subarray(3) : bytes);
}

/** The full check, run when a file is detected and again by the scan. */
export function parseCsvText(bytes: Uint8Array): CsvParseResult {
  const bom = hasBom(bytes);
  const body = bom ? bytes.subarray(3) : bytes;
  if (body.length === 0) return { ok: false, reason: "malformed" };
  let text: string;
  try {
    text = strictUtf8.decode(body);
  } catch {
    return { ok: false, reason: "malformed" };
  }
  if (CONTROL.test(text)) return { ok: false, reason: "malformed" };
  if (MARKUP_START.test(text.slice(0, 1024))) {
    return { ok: false, reason: "polyglot" };
  }
  if (text.trim().length === 0) return { ok: false, reason: "malformed" };
  return { ok: true, bomStripped: bom };
}
