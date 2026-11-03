/**
 * Bounded structural guard for the older binary Office files - Word .doc,
 * Excel .xls and PowerPoint .ppt (DL-078).
 *
 * All three are OLE2 Compound File Binary (CFB) containers: a small FAT file
 * system of "storages" (folders) and "streams" (files) inside one file. Like
 * the OOXML guard (ooxml.ts) this is a security gate, not a reader, and its
 * limits are stated rather than hidden:
 *  - the container must start at offset zero with the CFB signature, use a
 *    standard header (version 3 or 4, little-endian, standard sector sizes)
 *    and leave nothing after its last used sector that another reader would
 *    open as a ZIP or a PDF (a polyglot); a PDF header in the first 1 KiB is
 *    refused too;
 *  - every sector chain (FAT, DIFAT, directory, mini FAT, every stream) is
 *    followed under caps: a chain may not leave the file, loop, or share a
 *    sector with another chain, and no stream may be longer than its chain.
 *    At most 20,000 directory entries and 32 nested storages are read, so a
 *    crafted file costs at most one pass over its own bytes;
 *  - the main stream must match the declared type: `WordDocument` for .doc,
 *    `Workbook` (or the Excel 95 `Book`) for .xls, `PowerPoint Document` for
 *    .ppt - and only one of them;
 *  - macros are refused: VBA projects (`VBA`, `Macros`, `_VBA_PROJECT_CUR`
 *    storages, `_VBA_PROJECT` streams), ActiveX controls (`Ctls`), Excel 4.0
 *    macro sheets and VBA module sheets (BOUNDSHEET types 1 and 6), and a
 *    presentation's VBA and ActiveX records;
 *  - embedded OLE objects are refused: a non-empty Word `ObjectPool`, Excel
 *    `MBDxxxxxxxx` object storages, `\x01Ole10Native` packages anywhere, and a
 *    presentation's embedded-object records;
 *  - links that fetch from elsewhere are refused: a workbook's references to
 *    other workbooks (SUPBOOK), its data connections and web queries, and a
 *    presentation's linked OLE objects;
 *  - password-protected files are refused: an `EncryptedPackage` (an
 *    encrypted OOXML file), Word's fEncrypted flag, Excel's FILEPASS record,
 *    PowerPoint's `EncryptedSummary` stream and CryptSession10 record;
 *  - every stream is reassembled and scanned for the EICAR test signature
 *    (a stream's sectors need not be contiguous in the file).
 *
 * Known limit: a presentation's records are walked linearly (containers
 * descended). Bytes a crafted file hides inside another record's body are
 * not seen. That is defence in depth only: the converter that opens these
 * files runs with macros disabled, no network, and the malware scanner sees
 * the whole file.
 */
import { containsEicarSignature } from "./eicar";
import { DOCX_MEDIA_TYPE, PPTX_MEDIA_TYPE, XLSX_MEDIA_TYPE } from "./ooxml";

export const DOC_MEDIA_TYPE = "application/msword";
export const XLS_MEDIA_TYPE = "application/vnd.ms-excel";
export const PPT_MEDIA_TYPE = "application/vnd.ms-powerpoint";

export type CfbKind = "doc" | "xls" | "ppt";

/** The media type each binary Office format is stored and served as. */
export const CFB_MEDIA_TYPES: Record<CfbKind, string> = {
  doc: DOC_MEDIA_TYPE,
  xls: XLS_MEDIA_TYPE,
  ppt: PPT_MEDIA_TYPE,
};

/**
 * The OOXML format each binary format is converted to, so the material
 * reader can read it with the Word, Excel and PowerPoint readers it has.
 */
export const LEGACY_OFFICE_OOXML: Readonly<Record<string, string>> = {
  [DOC_MEDIA_TYPE]: DOCX_MEDIA_TYPE,
  [XLS_MEDIA_TYPE]: XLSX_MEDIA_TYPE,
  [PPT_MEDIA_TYPE]: PPTX_MEDIA_TYPE,
};

/** True for .doc, .xls and .ppt. */
export function isLegacyOfficeType(mediaType: string | null | undefined) {
  return mediaType != null &&
    Object.prototype.hasOwnProperty.call(LEGACY_OFFICE_OOXML, mediaType);
}

export type CfbRejectReason =
  | "malformed"
  | "polyglot"
  | "encrypted"
  | "embedded"
  | "active_content"
  | "external_reference"
  | "malicious"
  | "decompression_limit";

export interface CfbEntry {
  /** Index in the directory. */
  id: number;
  name: string;
  /** Names from the root down, this entry's own name last. */
  path: string[];
  type: "storage" | "stream";
  size: number;
}

export type CfbDirectory =
  | {
    ok: true;
    entries: CfbEntry[];
    /** A stream's bytes, reassembled from its chain. */
    read(entry: CfbEntry): Uint8Array;
  }
  | { ok: false; reason: CfbRejectReason };

export type CfbParseResult =
  | { ok: true; kind: CfbKind; streamCount: number }
  | { ok: false; reason: CfbRejectReason };

const SIGNATURE = [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1];
const ENDOFCHAIN = 0xfffffffe;
const FREESECT = 0xffffffff;
const MAXREGSECT = 0xfffffffa;
const NOSTREAM = 0xffffffff;
const DIRECTORY_ENTRY_BYTES = 128;
const MINI_SECTOR_BYTES = 64;
const MINI_STREAM_CUTOFF = 4096;
/** Most directory entries read. A real lesson file has a few dozen. */
const MAX_DIRECTORY_ENTRIES = 20_000;
/** Deepest storage nesting followed. */
const MAX_DEPTH = 32;
/** Most records walked in one workbook or presentation stream. */
const MAX_RECORDS = 4_000_000;

function u16(bytes: Uint8Array, at: number): number {
  return bytes[at]! | (bytes[at + 1]! << 8);
}

function u32(bytes: Uint8Array, at: number): number {
  return (bytes[at]! | (bytes[at + 1]! << 8) | (bytes[at + 2]! << 16) |
    (bytes[at + 3]! << 24)) >>> 0;
}

function fail(reason: CfbRejectReason): { ok: false; reason: CfbRejectReason } {
  return { ok: false, reason };
}

function hasSignature(bytes: Uint8Array): boolean {
  return bytes.length >= 8 && SIGNATURE.every((b, i) => bytes[i] === b);
}

function contains(haystack: Uint8Array, needle: number[]): boolean {
  outer:
  for (let i = 0; i + needle.length <= haystack.length; i++) {
    for (let j = 0; j < needle.length; j++) {
      if (haystack[i + j] !== needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

const PDF_HEADER = [0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-
const ZIP_LOCAL = [0x50, 0x4b, 0x03, 0x04];
const ZIP_END = [0x50, 0x4b, 0x05, 0x06];

/**
 * Reads the container's directory, following every chain once under the
 * caps above. Nothing is decompressed: CFB streams are stored as is.
 */
export function readCfbDirectory(bytes: Uint8Array): CfbDirectory {
  if (bytes.length < 512 || !hasSignature(bytes)) return fail("malformed");
  // A PDF reader accepts "%PDF-" anywhere in the first 1 KiB.
  if (contains(bytes.subarray(0, 1024), PDF_HEADER)) return fail("polyglot");
  const major = u16(bytes, 0x1a);
  if (u16(bytes, 0x1c) !== 0xfffe) return fail("malformed");
  const shift = u16(bytes, 0x1e);
  if (!((major === 3 && shift === 9) || (major === 4 && shift === 12))) {
    return fail("malformed");
  }
  if (u16(bytes, 0x20) !== 6) return fail("malformed");
  if (u32(bytes, 0x38) !== MINI_STREAM_CUTOFF) return fail("malformed");
  const sectorSize = 1 << shift;
  // A version 4 header fills its whole first 4 KiB sector.
  const headerSize = sectorSize;
  if (bytes.length <= headerSize) return fail("malformed");
  const sectorCount = Math.ceil((bytes.length - headerSize) / sectorSize);
  const perSector = sectorSize / 4;
  const sectorAt = (sector: number) => headerSize + sector * sectorSize;

  const fatCount = u32(bytes, 0x2c);
  const firstDirectory = u32(bytes, 0x30);
  const firstMiniFat = u32(bytes, 0x3c);
  const firstDifat = u32(bytes, 0x44);
  const difatCount = u32(bytes, 0x48);
  if (fatCount === 0 || fatCount > sectorCount || difatCount > sectorCount) {
    return fail("malformed");
  }

  // Every sector belongs to at most one chain: a second claim is a loop or
  // a cross-link, and either is refused.
  const claimed = new Uint8Array(sectorCount);
  const claim = (sector: number): boolean => {
    if (sector >= sectorCount || claimed[sector]) return false;
    claimed[sector] = 1;
    return true;
  };
  const wholeSector = (sector: number) =>
    sectorAt(sector) + sectorSize <= bytes.length;

  // The FAT's own sectors: 109 in the header, the rest in the DIFAT chain.
  const fatSectors: number[] = [];
  for (let i = 0; i < 109 && fatSectors.length < fatCount; i++) {
    fatSectors.push(u32(bytes, 0x4c + 4 * i));
  }
  let difat = firstDifat;
  for (let i = 0; i < difatCount && fatSectors.length < fatCount; i++) {
    if (difat > MAXREGSECT || !wholeSector(difat) || !claim(difat)) {
      return fail("malformed");
    }
    const at = sectorAt(difat);
    for (let j = 0; j < perSector - 1 && fatSectors.length < fatCount; j++) {
      fatSectors.push(u32(bytes, at + 4 * j));
    }
    difat = u32(bytes, at + 4 * (perSector - 1));
  }
  if (fatSectors.length !== fatCount) return fail("malformed");
  const fat = new Uint32Array(fatCount * perSector);
  for (let i = 0; i < fatSectors.length; i++) {
    const sector = fatSectors[i]!;
    if (sector > MAXREGSECT || !wholeSector(sector) || !claim(sector)) {
      return fail("malformed");
    }
    const at = sectorAt(sector);
    for (let j = 0; j < perSector; j++) {
      fat[i * perSector + j] = u32(bytes, at + 4 * j);
    }
  }
  // The FAT must describe every sector the file holds; bytes it does not
  // describe would be a second file riding along.
  if (fat.length < sectorCount) return fail("polyglot");

  /** A regular chain, claimed; null when it leaves the file or loops. */
  const chain = (start: number): number[] | null => {
    const out: number[] = [];
    let sector = start;
    while (sector !== ENDOFCHAIN) {
      if (sector > MAXREGSECT || !claim(sector)) return null;
      out.push(sector);
      sector = fat[sector]!;
    }
    return out;
  };

  const directoryChain = chain(firstDirectory);
  if (directoryChain === null || directoryChain.length === 0) {
    return fail("malformed");
  }
  const entriesPerSector = sectorSize / DIRECTORY_ENTRY_BYTES;
  if (directoryChain.length * entriesPerSector > MAX_DIRECTORY_ENTRIES) {
    return fail("decompression_limit");
  }

  interface RawEntry {
    name: string;
    type: number;
    left: number;
    right: number;
    child: number;
    start: number;
    size: number;
  }
  const raw: (RawEntry | null)[] = [];
  for (const sector of directoryChain) {
    if (!wholeSector(sector)) return fail("malformed");
    for (let k = 0; k < entriesPerSector; k++) {
      const at = sectorAt(sector) + k * DIRECTORY_ENTRY_BYTES;
      const type = bytes[at + 0x42]!;
      if (type === 0) {
        raw.push(null);
        continue;
      }
      if (type !== 1 && type !== 2 && type !== 5) return fail("malformed");
      const nameBytes = u16(bytes, at + 0x40);
      if (nameBytes < 2 || nameBytes > 64 || nameBytes % 2 !== 0) {
        return fail("malformed");
      }
      let name = "";
      for (let c = 0; c < nameBytes / 2 - 1; c++) {
        name += String.fromCharCode(u16(bytes, at + 2 * c));
      }
      // Version 3 files may leave junk in the size's high half; version 4
      // files may not, and nothing here is 4 GiB anyway.
      const high = u32(bytes, at + 0x7c);
      if (major === 4 && high !== 0) return fail("malformed");
      raw.push({
        name,
        type,
        left: u32(bytes, at + 0x44),
        right: u32(bytes, at + 0x48),
        child: u32(bytes, at + 0x4c),
        start: u32(bytes, at + 0x74),
        size: u32(bytes, at + 0x78),
      });
    }
  }
  const root = raw[0];
  if (!root || root.type !== 5) return fail("malformed");

  // The tree: each storage's children are a binary tree of siblings. Every
  // entry is reached at most once.
  const entries: CfbEntry[] = [];
  const visited = new Uint8Array(raw.length);
  visited[0] = 1;
  const stack: { id: number; parent: string[]; depth: number }[] = [];
  if (root.child !== NOSTREAM) {
    stack.push({ id: root.child, parent: [], depth: 1 });
  }
  while (stack.length > 0) {
    const { id, parent, depth } = stack.pop()!;
    if (id >= raw.length || visited[id]) return fail("malformed");
    visited[id] = 1;
    const entry = raw[id];
    if (!entry || entry.type === 5) return fail("malformed");
    const path = [...parent, entry.name];
    entries.push({
      id,
      name: entry.name,
      path,
      type: entry.type === 1 ? "storage" : "stream",
      size: entry.type === 2 ? entry.size : 0,
    });
    if (entry.left !== NOSTREAM) stack.push({ id: entry.left, parent, depth });
    if (entry.right !== NOSTREAM) {
      stack.push({ id: entry.right, parent, depth });
    }
    if (entry.type === 1 && entry.child !== NOSTREAM) {
      if (depth >= MAX_DEPTH) return fail("decompression_limit");
      stack.push({ id: entry.child, parent: path, depth: depth + 1 });
    }
  }

  // The mini stream (small streams, 64-byte sectors) lives in the root's
  // own chain; the mini FAT links its sectors.
  const miniChain = root.size > 0 ? chain(root.start) : [];
  if (miniChain === null || miniChain.length * sectorSize < root.size) {
    return fail("malformed");
  }
  const miniFatChain = firstMiniFat === ENDOFCHAIN || firstMiniFat === FREESECT
    ? []
    : chain(firstMiniFat);
  if (miniFatChain === null) return fail("malformed");
  const miniFat: number[] = [];
  for (const sector of miniFatChain) {
    if (!wholeSector(sector)) return fail("malformed");
    for (let j = 0; j < perSector; j++) {
      miniFat.push(u32(bytes, sectorAt(sector) + 4 * j));
    }
  }
  const miniSectorCount = Math.floor(root.size / MINI_SECTOR_BYTES);
  const miniClaimed = new Uint8Array(miniSectorCount);

  // Each stream's pieces, as [file offset, length] runs.
  const pieces = new Map<number, [number, number][]>();
  for (const entry of entries) {
    if (entry.type !== "stream" || entry.size === 0) continue;
    const start = raw[entry.id]!.start;
    const runs: [number, number][] = [];
    if (entry.size < MINI_STREAM_CUTOFF) {
      const needed = Math.ceil(entry.size / MINI_SECTOR_BYTES);
      let mini = start;
      for (let n = 0; n < needed; n++) {
        if (mini >= miniSectorCount || miniClaimed[mini]) {
          return fail("malformed");
        }
        miniClaimed[mini] = 1;
        const offsetInMini = mini * MINI_SECTOR_BYTES;
        const container = miniChain[Math.floor(offsetInMini / sectorSize)]!;
        const at = sectorAt(container) + (offsetInMini % sectorSize);
        const length = Math.min(
          MINI_SECTOR_BYTES,
          entry.size - n * MINI_SECTOR_BYTES,
        );
        if (at + length > bytes.length) return fail("malformed");
        runs.push([at, length]);
        if (n < needed - 1) {
          if (mini >= miniFat.length) return fail("malformed");
          mini = miniFat[mini]!;
        }
      }
    } else {
      const sectors = chain(start);
      if (
        sectors === null ||
        sectors.length < Math.ceil(entry.size / sectorSize)
      ) {
        return fail("malformed");
      }
      let left = entry.size;
      for (const sector of sectors) {
        if (left <= 0) break;
        const length = Math.min(sectorSize, left);
        if (sectorAt(sector) + length > bytes.length) return fail("malformed");
        runs.push([sectorAt(sector), length]);
        left -= length;
      }
    }
    pieces.set(entry.id, runs);
  }

  // Free sectors after the last used one can carry an appended ZIP or PDF
  // that another reader would open instead.
  let lastUsed = -1;
  for (let s = sectorCount - 1; s >= 0; s--) {
    if (claimed[s]) {
      lastUsed = s;
      break;
    }
  }
  const tail = bytes.subarray(Math.min(bytes.length, sectorAt(lastUsed + 1)));
  if (
    contains(tail, ZIP_LOCAL) || contains(tail, ZIP_END) ||
    contains(tail, PDF_HEADER)
  ) {
    return fail("polyglot");
  }

  return {
    ok: true,
    entries,
    read(entry) {
      const runs = pieces.get(entry.id) ?? [];
      const out = new Uint8Array(entry.size);
      let at = 0;
      for (const [offset, length] of runs) {
        out.set(bytes.subarray(offset, offset + length), at);
        at += length;
      }
      return out;
    },
  };
}

const lower = (name: string) => name.toLowerCase();

/** Which binary Office format a container is, from its main stream. */
export function cfbKindOf(entries: CfbEntry[]): CfbKind | null {
  const top = new Set(
    entries.filter((e) => e.path.length === 1 && e.type === "stream")
      .map((e) => lower(e.name)),
  );
  const kinds: CfbKind[] = [];
  if (top.has("worddocument")) kinds.push("doc");
  if (top.has("workbook") || top.has("book")) kinds.push("xls");
  if (top.has("powerpoint document")) kinds.push("ppt");
  return kinds.length === 1 ? kinds[0]! : null;
}

/** Cheap type detection for uploads: the directory, nothing interpreted. */
export function detectCfbMediaType(bytes: Uint8Array): string | null {
  if (!hasSignature(bytes)) return null;
  const directory = readCfbDirectory(bytes);
  if (!directory.ok) return null;
  const kind = cfbKindOf(directory.entries);
  return kind === null ? null : CFB_MEDIA_TYPES[kind];
}

const ACTIVE_STORAGES = new Set(["vba", "macros", "_vba_project_cur"]);
const ACTIVE_STREAMS = new Set(["_vba_project", "ctls"]);
const ENCRYPTED_STREAMS = new Set([
  "encryptedpackage",
  "encryptioninfo",
  "encryptedsummary",
]);
const EXCEL_OBJECT_STORAGE = /^mbd[0-9a-f]{8}$/;

/** The full structural check, run by the scan worker before `clean`. */
export function parseCfb(
  bytes: Uint8Array,
  expected: CfbKind,
): CfbParseResult {
  const directory = readCfbDirectory(bytes);
  if (!directory.ok) return directory;
  const { entries } = directory;
  for (const entry of entries) {
    if (entry.type === "stream" && ENCRYPTED_STREAMS.has(lower(entry.name))) {
      return fail("encrypted");
    }
  }
  const kind = cfbKindOf(entries);
  if (kind !== expected) return fail("malformed");

  let streamCount = 0;
  for (const entry of entries) {
    const name = lower(entry.name);
    if (entry.type === "storage") {
      if (ACTIVE_STORAGES.has(name)) return fail("active_content");
      if (entry.path.length === 1 && EXCEL_OBJECT_STORAGE.test(name)) {
        return fail("embedded");
      }
    } else {
      streamCount++;
      if (ACTIVE_STREAMS.has(name)) return fail("active_content");
      if (name === "\u0001ole10native") return fail("embedded");
    }
    // Word keeps embedded and linked objects (and ActiveX) under ObjectPool;
    // an empty ObjectPool is normal.
    if (entry.path.length > 1 && lower(entry.path[0]!) === "objectpool") {
      return fail("embedded");
    }
  }

  for (const entry of entries) {
    if (entry.type !== "stream") continue;
    if (containsEicarSignature(directory.read(entry))) {
      return fail("malicious");
    }
  }

  const main = (names: string[]) =>
    entries.find((e) =>
      e.path.length === 1 && e.type === "stream" &&
      names.includes(lower(e.name))
    )!;
  const refused = kind === "doc"
    ? checkWordDocument(directory.read(main(["worddocument"])))
    : kind === "xls"
    ? checkWorkbook(directory.read(main(["workbook", "book"])))
    : checkPresentation(directory.read(main(["powerpoint document"])));
  if (refused !== null) return fail(refused);
  return { ok: true, kind, streamCount };
}

/** Word's File Information Block: the signature and the encryption flag. */
function checkWordDocument(stream: Uint8Array): CfbRejectReason | null {
  if (stream.length < 32) return "malformed";
  const ident = u16(stream, 0);
  // Word 97 and later (0xA5EC); Word 6 and 95 (0xA5DC).
  if (ident !== 0xa5ec && ident !== 0xa5dc) return "malformed";
  const flags = u16(stream, 0x0a);
  if ((flags & 0x0100) !== 0) return "encrypted"; // fEncrypted
  return null;
}

const BIFF_FILEPASS = 0x002f;
const BIFF_BOUNDSHEET = 0x0085;
const BIFF_SUPBOOK = 0x01ae;
const BIFF_QSI = 0x01ad;
const BIFF_DCONN = 0x0876;

/**
 * An Excel workbook stream: BIFF records, walked once. A record that runs
 * past the stream ends the walk (Excel pads its streams with zeros).
 */
function checkWorkbook(stream: Uint8Array): CfbRejectReason | null {
  let at = 0;
  let records = 0;
  while (at + 4 <= stream.length) {
    if (++records > MAX_RECORDS) return "decompression_limit";
    const type = u16(stream, at);
    const size = u16(stream, at + 2);
    const body = at + 4;
    if (body + size > stream.length) break;
    switch (type) {
      case BIFF_FILEPASS:
        return "encrypted";
      case BIFF_BOUNDSHEET:
        // dt: 0 worksheet, 1 Excel 4.0 macro sheet, 2 chart, 6 VBA module.
        if (size >= 6) {
          const sheetType = stream[body + 5]!;
          if (sheetType === 0x01 || sheetType === 0x06) return "active_content";
        }
        break;
      case BIFF_SUPBOOK:
        // 0x0401 is this workbook itself, 0x3A01 add-in functions; anything
        // else names another workbook, or a DDE or OLE source.
        if (size >= 4) {
          const marker = u16(stream, body + 2);
          if (marker !== 0x0401 && marker !== 0x3a01) {
            return "external_reference";
          }
        }
        break;
      case BIFF_QSI:
      case BIFF_DCONN:
        return "external_reference";
    }
    at = body + size;
  }
  return null;
}

const PPT_VBA_INFO = 0x03ff;
const PPT_VBA_INFO_ATOM = 0x0400;
const PPT_EX_OLE_EMBED = 0x0fcc;
const PPT_EX_OLE_LINK = 0x0fce;
const PPT_EX_CONTROL = 0x0fee;
const PPT_EX_OLE_OBJ_STG = 0x1011;
const PPT_CRYPT_SESSION = 0x2f14;

/**
 * A PowerPoint document stream: records, containers descended. A record
 * that overruns its container is malformed; at the top level the walk stops
 * (incremental saves may leave padding).
 */
function checkPresentation(stream: Uint8Array): CfbRejectReason | null {
  const ends: number[] = [];
  let end = stream.length;
  let at = 0;
  let records = 0;
  for (;;) {
    while (at >= end && ends.length > 0) end = ends.pop()!;
    if (at + 8 > end) {
      if (ends.length === 0) break;
      return "malformed";
    }
    if (++records > MAX_RECORDS) return "decompression_limit";
    const version = u16(stream, at) & 0x0f;
    const type = u16(stream, at + 2);
    const length = u32(stream, at + 4);
    const stop = at + 8 + length;
    if (stop > end) {
      if (ends.length === 0) break;
      return "malformed";
    }
    switch (type) {
      case PPT_VBA_INFO:
      case PPT_VBA_INFO_ATOM:
      case PPT_EX_CONTROL:
        return "active_content";
      case PPT_EX_OLE_EMBED:
      case PPT_EX_OLE_OBJ_STG:
        return "embedded";
      case PPT_EX_OLE_LINK:
        return "external_reference";
      case PPT_CRYPT_SESSION:
        return "encrypted";
    }
    if (version === 0x0f && length > 0) {
      if (ends.length >= MAX_DEPTH * 2) return "decompression_limit";
      ends.push(end);
      end = stop;
      at += 8;
    } else {
      at = stop;
    }
  }
  return null;
}
