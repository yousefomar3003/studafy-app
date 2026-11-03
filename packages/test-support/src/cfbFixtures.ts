/**
 * Old binary Word, Excel and PowerPoint files (OLE2 compound files) built in
 * code for tests (DL-078). No binary fixtures: each container is assembled
 * here, sector by sector, as a version 3 compound file with 512-byte
 * sectors. Streams under 4 KiB go in the mini stream, as real files do.
 */

const encoder = new TextEncoder();
const END = 0xfffffffe;
const FREE = 0xffffffff;
const FAT_SECTOR = 0xfffffffd;
const NONE = 0xffffffff;
const SECTOR = 512;
const MINI = 64;
const CUTOFF = 4096;

export interface CfbNode {
  /** Names from the root down. Missing parent storages are created. */
  path: string[];
  /** A stream's bytes; leave out for a storage. */
  data?: Uint8Array | string;
}

export interface CfbLayout {
  fatSectors: number[];
  directorySectors: number[];
  miniFatSectors: number[];
  /** Regular sectors of each large stream, by joined path. */
  streamSectors: Map<string, number[]>;
}

interface DirEntry {
  name: string;
  type: 1 | 2 | 5;
  children: number[];
  data: Uint8Array | null;
  start: number;
  size: number;
  left: number;
  right: number;
  child: number;
}

const compare = (a: string, b: string) =>
  a.length !== b.length
    ? a.length - b.length
    : a.toUpperCase() < b.toUpperCase()
    ? -1
    : a.toUpperCase() > b.toUpperCase()
    ? 1
    : 0;

/** A valid compound file holding [nodes], and where its parts went. */
export function buildCfbDetailed(
  nodes: CfbNode[],
): { bytes: Uint8Array; layout: CfbLayout } {
  const entries: DirEntry[] = [{
    name: "Root Entry",
    type: 5,
    children: [],
    data: null,
    start: END,
    size: 0,
    left: NONE,
    right: NONE,
    child: NONE,
  }];
  const byPath = new Map<string, number>([["", 0]]);
  const ensure = (path: string[], data: Uint8Array | null): number => {
    const key = path.join("/");
    const existing = byPath.get(key);
    if (existing !== undefined) return existing;
    const parent = ensure(path.slice(0, -1), null);
    const id = entries.length;
    entries.push({
      name: path[path.length - 1]!,
      type: data === null ? 1 : 2,
      children: [],
      data,
      start: END,
      size: data?.length ?? 0,
      left: NONE,
      right: NONE,
      child: NONE,
    });
    entries[parent]!.children.push(id);
    byPath.set(key, id);
    return id;
  };
  for (const node of nodes) {
    const data = node.data === undefined
      ? null
      : typeof node.data === "string"
      ? encoder.encode(node.data)
      : node.data;
    ensure(node.path, data);
  }
  // Siblings as a right-leaning chain in name order: a valid search tree.
  for (const entry of entries) {
    const sorted = [...entry.children].sort((a, b) =>
      compare(entries[a]!.name, entries[b]!.name)
    );
    if (sorted.length > 0) entry.child = sorted[0]!;
    for (let i = 0; i + 1 < sorted.length; i++) {
      entries[sorted[i]!]!.right = sorted[i + 1]!;
    }
  }

  // The mini stream and its FAT.
  const miniParts: Uint8Array[] = [];
  const miniFat: number[] = [];
  for (const entry of entries) {
    if (entry.type !== 2 || entry.size === 0 || entry.size >= CUTOFF) continue;
    const count = Math.ceil(entry.size / MINI);
    entry.start = miniFat.length;
    for (let i = 0; i < count; i++) {
      miniFat.push(i === count - 1 ? END : miniFat.length + 1);
    }
    const padded = new Uint8Array(count * MINI);
    padded.set(entry.data!);
    miniParts.push(padded);
  }
  const miniStream = concat(miniParts);

  // Regular sectors, in order: large streams, the mini stream, the mini
  // FAT, the directory, then the FAT itself.
  const fat: number[] = [];
  const sectors: Uint8Array[] = [];
  const allocate = (data: Uint8Array, minimum = 1): number[] => {
    const count = Math.max(minimum, Math.ceil(data.length / SECTOR));
    const first = sectors.length;
    const out: number[] = [];
    for (let i = 0; i < count; i++) {
      const sector = new Uint8Array(SECTOR);
      sector.set(data.subarray(i * SECTOR, (i + 1) * SECTOR));
      sectors.push(sector);
      fat.push(i === count - 1 ? END : first + i + 1);
      out.push(first + i);
    }
    return out;
  };
  const streamSectors = new Map<string, number[]>();
  for (const [key, id] of byPath) {
    const entry = entries[id]!;
    if (entry.type !== 2 || entry.size < CUTOFF) continue;
    const chain = allocate(entry.data!);
    entry.start = chain[0]!;
    streamSectors.set(key, chain);
  }
  if (miniStream.length > 0) {
    entries[0]!.start = allocate(miniStream)[0]!;
    entries[0]!.size = miniStream.length;
  }
  const miniFatBytes = new Uint8Array(
    Math.ceil(miniFat.length * 4 / SECTOR) * SECTOR,
  ).fill(0xff);
  miniFat.forEach((value, i) => putU32(miniFatBytes, i * 4, value));
  const miniFatSectors = miniFat.length > 0 ? allocate(miniFatBytes) : [];

  const directory = new Uint8Array(
    Math.ceil(entries.length * 128 / SECTOR) * SECTOR,
  );
  entries.forEach((entry, i) => writeEntry(directory, i * 128, entry));
  const directorySectors = allocate(directory);

  let fatCount = 1;
  while (fatCount * (SECTOR / 4) < sectors.length + fatCount) fatCount++;
  const fatSectors: number[] = [];
  for (let i = 0; i < fatCount; i++) {
    fatSectors.push(sectors.length);
    sectors.push(new Uint8Array(SECTOR));
    fat.push(FAT_SECTOR);
  }
  const fatBytes = new Uint8Array(fatCount * SECTOR).fill(0xff);
  fat.forEach((value, i) => putU32(fatBytes, i * 4, value));
  fatSectors.forEach((sector, i) =>
    sectors[sector]!.set(fatBytes.subarray(i * SECTOR, (i + 1) * SECTOR))
  );

  const header = new Uint8Array(SECTOR);
  header.set([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]);
  putU16(header, 0x18, 0x3e);
  putU16(header, 0x1a, 3);
  putU16(header, 0x1c, 0xfffe);
  putU16(header, 0x1e, 9);
  putU16(header, 0x20, 6);
  putU32(header, 0x2c, fatCount);
  putU32(header, 0x30, directorySectors[0]!);
  putU32(header, 0x38, CUTOFF);
  putU32(header, 0x3c, miniFatSectors[0] ?? END);
  putU32(header, 0x40, miniFatSectors.length);
  putU32(header, 0x44, END);
  putU32(header, 0x48, 0);
  for (let i = 0; i < 109; i++) {
    putU32(header, 0x4c + 4 * i, fatSectors[i] ?? FREE);
  }
  return {
    bytes: concat([header, ...sectors]),
    layout: { fatSectors, directorySectors, miniFatSectors, streamSectors },
  };
}

export function buildCfb(nodes: CfbNode[]): Uint8Array {
  return buildCfbDetailed(nodes).bytes;
}

/** The byte offset of a regular sector in a version 3 file. */
export function cfbSectorOffset(sector: number): number {
  return SECTOR + sector * SECTOR;
}

/** Points a FAT entry somewhere else (to build loops and cross-links). */
export function setCfbFatEntry(
  bytes: Uint8Array,
  layout: CfbLayout,
  sector: number,
  value: number,
): void {
  const perSector = SECTOR / 4;
  const fatSector = layout.fatSectors[Math.floor(sector / perSector)]!;
  putU32(bytes, cfbSectorOffset(fatSector) + (sector % perSector) * 4, value);
}

/** A Word 97 FIB: the signature, and the encryption flag when asked. */
export function wordDocumentStream(
  options: { encrypted?: boolean; ident?: number; text?: string } = {},
): Uint8Array {
  const body = encoder.encode(options.text ?? "A Word 97 lesson.");
  const stream = new Uint8Array(1536 + body.length);
  putU16(stream, 0, options.ident ?? 0xa5ec);
  putU16(stream, 2, 0x00c1);
  putU16(stream, 0x0a, options.encrypted ? 0x0100 | 0x0200 : 0x0200);
  stream.set(body, 1536);
  return stream;
}

/** One BIFF record. */
export function biffRecord(type: number, body: Uint8Array | number[] = []) {
  const data = body instanceof Uint8Array ? body : Uint8Array.from(body);
  const out = new Uint8Array(4 + data.length);
  putU16(out, 0, type);
  putU16(out, 2, data.length);
  out.set(data, 4);
  return out;
}

/** BOUNDSHEET8: sheet type 0 worksheet, 1 macro sheet, 6 VBA module. */
export function biffBoundSheet(name: string, sheetType = 0): Uint8Array {
  const body = [0, 0, 0, 0, 0, sheetType, name.length, 0];
  for (const char of name) body.push(char.charCodeAt(0));
  return biffRecord(0x0085, body);
}

/** A workbook stream: BOF, [records], EOF, zero-padded past the mini cutoff. */
export function workbookStream(
  records: Uint8Array[],
  options: { large?: boolean } = {},
): Uint8Array {
  const bof = biffRecord(0x0809, [
    0,
    6,
    5,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ]);
  const stream = concat([bof, ...records, biffRecord(0x000a)]);
  if (!options.large) return stream;
  const padded = new Uint8Array(Math.max(CUTOFF + 100, stream.length));
  padded.set(stream);
  return padded;
}

/** One PowerPoint record; a container when [children] are given. */
export function pptRecord(
  type: number,
  body: Uint8Array | Uint8Array[] = new Uint8Array(),
): Uint8Array {
  const container = Array.isArray(body);
  const data = container ? concat(body) : body;
  const out = new Uint8Array(8 + data.length);
  putU16(out, 0, container ? 0x000f : 0x0000);
  putU16(out, 2, type);
  putU32(out, 4, data.length);
  out.set(data, 8);
  return out;
}

export interface LegacyOfficeOptions {
  /** Extra streams and storages beside the format's usual ones. */
  extra?: CfbNode[];
}

/** A plain .doc: WordDocument, 1Table, summary, an empty ObjectPool. */
export function buildDoc(
  options: LegacyOfficeOptions & { word?: Uint8Array } = {},
): Uint8Array {
  return buildCfb([
    { path: ["WordDocument"], data: options.word ?? wordDocumentStream() },
    { path: ["1Table"], data: new Uint8Array(600) },
    { path: ["\u0005SummaryInformation"], data: new Uint8Array(200) },
    { path: ["ObjectPool"] },
    ...(options.extra ?? []),
  ]);
}

/** A plain .xls with one worksheet. */
export function buildXls(
  options: LegacyOfficeOptions & {
    records?: Uint8Array[];
    large?: boolean;
    streamName?: string;
  } = {},
): Uint8Array {
  const records = options.records ?? [biffBoundSheet("Sheet1")];
  return buildCfb([
    {
      path: [options.streamName ?? "Workbook"],
      data: workbookStream(records, { large: options.large ?? false }),
    },
    { path: ["\u0005SummaryInformation"], data: new Uint8Array(200) },
    ...(options.extra ?? []),
  ]);
}

/** A plain .ppt: a document container, a slide, the current-user stream. */
export function buildPpt(
  options: LegacyOfficeOptions & { records?: Uint8Array[] } = {},
): Uint8Array {
  const records = options.records ?? [
    pptRecord(0x03e8, [pptRecord(0x03e9, new Uint8Array(40))]),
    pptRecord(0x03ee, [pptRecord(0x0fa0, encoder.encode("Slide one"))]),
  ];
  return buildCfb([
    { path: ["PowerPoint Document"], data: concat(records) },
    { path: ["Current User"], data: new Uint8Array(40) },
    ...(options.extra ?? []),
  ]);
}

function writeEntry(into: Uint8Array, at: number, entry: DirEntry): void {
  for (let i = 0; i < entry.name.length; i++) {
    putU16(into, at + i * 2, entry.name.charCodeAt(i));
  }
  putU16(into, at + 0x40, (entry.name.length + 1) * 2);
  into[at + 0x42] = entry.type;
  into[at + 0x43] = 1;
  putU32(into, at + 0x44, entry.left);
  putU32(into, at + 0x48, entry.right);
  putU32(into, at + 0x4c, entry.child);
  putU32(into, at + 0x74, entry.type === 1 ? 0 : entry.start);
  putU32(into, at + 0x78, entry.type === 1 ? 0 : entry.size);
}

function putU16(into: Uint8Array, at: number, value: number): void {
  into[at] = value & 0xff;
  into[at + 1] = (value >>> 8) & 0xff;
}

function putU32(into: Uint8Array, at: number, value: number): void {
  for (let i = 0; i < 4; i++) into[at + i] = (value >>> (8 * i)) & 0xff;
}

function concat(parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const part of parts) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}
