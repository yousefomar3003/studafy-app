/**
 * Bounded Word / PowerPoint (OOXML) structural guard (ADR-0037).
 *
 * A .docx or .pptx is a ZIP of XML parts. Like the PDF guard this is a
 * security gate, not a renderer, and its limits are stated rather than
 * hidden:
 *  - the ZIP must start at offset zero and end exactly where its end record
 *    says - anything before or after is a second file riding along
 *    (a polyglot);
 *  - ZIP64, encrypted entries, unsafe or duplicate names, and compression
 *    methods other than stored/deflate are refused;
 *  - declared sizes are capped in total and by ratio, and every part is
 *    inflated under its declared size, so a bomb is refused before it grows;
 *  - macros (`vbaProject.bin`, macro-enabled content types), ActiveX and
 *    embedded OLE objects are refused outright;
 *  - relationships that fetch something remote when the file is opened
 *    (attached templates, frames, OLE links, sub-documents) are refused;
 *    ordinary hyperlinks are kept;
 *  - every inflated part is scanned for the EICAR test signature.
 *
 * Older binary .doc / .ppt files are not ZIPs and are not accepted at all.
 */
import { inflateRawSync } from "node:zlib";
import { containsEicarSignature } from "./eicar";

export const DOCX_MEDIA_TYPE =
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
export const PPTX_MEDIA_TYPE =
  "application/vnd.openxmlformats-officedocument.presentationml.presentation";

/** Most parts one document may have. A real lesson file has a few hundred. */
const MAX_ENTRIES = 5_000;
/** Total declared uncompressed size. */
export const OOXML_TOTAL_INFLATE_CAP_BYTES = 200 * 1024 * 1024;
/** One part's declared uncompressed size. */
const MAX_ENTRY_BYTES = 100 * 1024 * 1024;
/** Deflate rarely beats ~20:1 on XML; 200:1 is a bomb. */
const MAX_RATIO = 200;

export type OoxmlKind = "docx" | "pptx";

export type OoxmlRejectReason =
  | "malformed"
  | "polyglot"
  | "encrypted"
  | "embedded"
  | "active_content"
  | "external_reference"
  | "malicious"
  | "decompression_limit";

export interface ZipEntry {
  name: string;
  method: number;
  compressedSize: number;
  size: number;
  localHeaderOffset: number;
  encrypted: boolean;
}

export type ZipDirectory =
  | { ok: true; entries: ZipEntry[] }
  | { ok: false; reason: OoxmlRejectReason };

export type OoxmlParseResult =
  | { ok: true; kind: OoxmlKind; entryCount: number }
  | { ok: false; reason: OoxmlRejectReason };

function u16(bytes: Uint8Array, at: number): number {
  return bytes[at]! | (bytes[at + 1]! << 8);
}

function u32(bytes: Uint8Array, at: number): number {
  return (bytes[at]! | (bytes[at + 1]! << 8) | (bytes[at + 2]! << 16) |
    (bytes[at + 3]! << 24)) >>> 0;
}

const decoder = new TextDecoder("utf-8", { fatal: true });

function safeName(name: string): boolean {
  if (name.length === 0 || name.length > 512) return false;
  if (name.startsWith("/") || name.includes("\\") || name.includes("\0")) {
    return false;
  }
  return !name.split("/").some((part) => part === ".." || part === ".");
}

/**
 * Reads a ZIP's central directory without inflating anything. Refuses what
 * a well-formed Office file never contains.
 */
export function readZipDirectory(bytes: Uint8Array): ZipDirectory {
  if (bytes.length < 22 || u32(bytes, 0) !== 0x04034b50) {
    return { ok: false, reason: "malformed" };
  }
  // The end record is in the last 64 KiB + 22 bytes (its comment is at most
  // 65535 bytes long).
  let end = -1;
  const floor = Math.max(0, bytes.length - 22 - 0xffff);
  for (let at = bytes.length - 22; at >= floor; at--) {
    if (u32(bytes, at) === 0x06054b50) {
      end = at;
      break;
    }
  }
  if (end < 0) return { ok: false, reason: "malformed" };
  const commentLength = u16(bytes, end + 20);
  // Bytes after the end record: something was appended.
  if (end + 22 + commentLength !== bytes.length) {
    return { ok: false, reason: "polyglot" };
  }
  const count = u16(bytes, end + 10);
  const directorySize = u32(bytes, end + 12);
  const directoryOffset = u32(bytes, end + 16);
  if (
    count === 0xffff || directorySize === 0xffffffff ||
    directoryOffset === 0xffffffff
  ) {
    return { ok: false, reason: "malformed" }; // ZIP64: never needed here.
  }
  if (count === 0 || count > MAX_ENTRIES) {
    return {
      ok: false,
      reason: count === 0 ? "malformed" : "decompression_limit",
    };
  }
  if (directoryOffset + directorySize !== end) {
    return { ok: false, reason: "polyglot" };
  }
  const entries: ZipEntry[] = [];
  const seen = new Set<string>();
  let total = 0;
  let at = directoryOffset;
  for (let i = 0; i < count; i++) {
    if (at + 46 > end || u32(bytes, at) !== 0x02014b50) {
      return { ok: false, reason: "malformed" };
    }
    const flags = u16(bytes, at + 8);
    const method = u16(bytes, at + 10);
    const compressedSize = u32(bytes, at + 20);
    const size = u32(bytes, at + 24);
    const nameLength = u16(bytes, at + 28);
    const extraLength = u16(bytes, at + 30);
    const commentLen = u16(bytes, at + 32);
    const localHeaderOffset = u32(bytes, at + 42);
    if (at + 46 + nameLength > end) return { ok: false, reason: "malformed" };
    let name: string;
    try {
      name = decoder.decode(bytes.subarray(at + 46, at + 46 + nameLength));
    } catch {
      return { ok: false, reason: "malformed" };
    }
    if (!safeName(name) || seen.has(name.toLowerCase())) {
      return { ok: false, reason: "malformed" };
    }
    seen.add(name.toLowerCase());
    if ((flags & 0x1) !== 0) return { ok: false, reason: "encrypted" };
    if (method !== 0 && method !== 8) return { ok: false, reason: "malformed" };
    if (localHeaderOffset >= directoryOffset) {
      return { ok: false, reason: "malformed" };
    }
    if (size > MAX_ENTRY_BYTES) {
      return { ok: false, reason: "decompression_limit" };
    }
    if (compressedSize > 0 && size / compressedSize > MAX_RATIO) {
      return { ok: false, reason: "decompression_limit" };
    }
    if (compressedSize === 0 && size > 0) {
      return { ok: false, reason: "malformed" };
    }
    total += size;
    if (total > OOXML_TOTAL_INFLATE_CAP_BYTES) {
      return { ok: false, reason: "decompression_limit" };
    }
    entries.push({
      name,
      method,
      compressedSize,
      size,
      localHeaderOffset,
      encrypted: false,
    });
    at += 46 + nameLength + extraLength + commentLen;
  }
  if (at !== end) return { ok: false, reason: "malformed" };
  // The first file must be the one at offset zero: a ZIP whose entries start
  // later is carrying something in front of them.
  if (!entries.some((entry) => entry.localHeaderOffset === 0)) {
    return { ok: false, reason: "polyglot" };
  }
  return { ok: true, entries };
}

/**
 * One entry's bytes, inflated under its declared size. Null when the entry
 * does not inflate to exactly what the directory promised.
 */
export function readZipEntry(
  bytes: Uint8Array,
  entry: ZipEntry,
): Uint8Array | null {
  const at = entry.localHeaderOffset;
  if (at + 30 > bytes.length || u32(bytes, at) !== 0x04034b50) return null;
  const start = at + 30 + u16(bytes, at + 26) + u16(bytes, at + 28);
  const stop = start + entry.compressedSize;
  if (stop > bytes.length) return null;
  const raw = bytes.subarray(start, stop);
  if (entry.method === 0) {
    return raw.length === entry.size ? raw : null;
  }
  try {
    const out = inflateRawSync(raw, { maxOutputLength: entry.size + 1 });
    return out.length === entry.size ? new Uint8Array(out) : null;
  } catch {
    return null;
  }
}

/** Which Office format a ZIP is, from its part names alone. */
export function ooxmlKindOf(entries: ZipEntry[]): OoxmlKind | null {
  const names = new Set(entries.map((entry) => entry.name));
  if (!names.has("[Content_Types].xml")) return null;
  const word = names.has("word/document.xml");
  const slides = names.has("ppt/presentation.xml");
  if (word === slides) return null;
  return word ? "docx" : "pptx";
}

/** Cheap type detection for uploads: the directory only, nothing inflated. */
export function detectOoxmlMediaType(bytes: Uint8Array): string | null {
  const directory = readZipDirectory(bytes);
  if (!directory.ok) return null;
  const kind = ooxmlKindOf(directory.entries);
  return kind === "docx"
    ? DOCX_MEDIA_TYPE
    : kind === "pptx"
    ? PPTX_MEDIA_TYPE
    : null;
}

const ACTIVE_PART = /(^|\/)(vbaProject\.bin|vbaData\.xml)$|(^|\/)activeX\//i;
const EMBEDDED_PART = /(^|\/)embeddings\/|oleObject/i;
const MACRO_CONTENT_TYPE =
  /macroEnabled|vnd\.ms-office\.vbaProject|vnd\.ms-office\.activeX/i;
// Relationship types that make the reader fetch or run something remote when
// the file is opened. A hyperlink only goes anywhere when it is tapped.
const REMOTE_RELATIONSHIP =
  /Type="[^"]*\/(attachedTemplate|oleObject|frame|subDocument|externalLinkPath|package|control)"[^>]*TargetMode="External"|TargetMode="External"[^>]*Type="[^"]*\/(attachedTemplate|oleObject|frame|subDocument|externalLinkPath|package|control)"/i;

const latin = new TextDecoder("latin1");

/** The full structural check, run by the scan worker before `clean`. */
export function parseOoxml(
  bytes: Uint8Array,
  expected: OoxmlKind,
): OoxmlParseResult {
  const directory = readZipDirectory(bytes);
  if (!directory.ok) return directory;
  const kind = ooxmlKindOf(directory.entries);
  if (kind !== expected) return { ok: false, reason: "malformed" };
  for (const entry of directory.entries) {
    if (ACTIVE_PART.test(entry.name)) {
      return { ok: false, reason: "active_content" };
    }
    if (EMBEDDED_PART.test(entry.name)) {
      return { ok: false, reason: "embedded" };
    }
  }
  let inflated = 0;
  for (const entry of directory.entries) {
    if (entry.name.endsWith("/")) continue;
    const part = readZipEntry(bytes, entry);
    if (part === null) return { ok: false, reason: "malformed" };
    inflated += part.length;
    if (inflated > OOXML_TOTAL_INFLATE_CAP_BYTES) {
      return { ok: false, reason: "decompression_limit" };
    }
    if (containsEicarSignature(part)) return { ok: false, reason: "malicious" };
    if (entry.name === "[Content_Types].xml") {
      if (MACRO_CONTENT_TYPE.test(latin.decode(part))) {
        return { ok: false, reason: "active_content" };
      }
    } else if (entry.name.endsWith(".rels")) {
      if (REMOTE_RELATIONSHIP.test(latin.decode(part))) {
        return { ok: false, reason: "external_reference" };
      }
    }
  }
  return { ok: true, kind, entryCount: directory.entries.length };
}
