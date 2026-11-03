/**
 * Text from Excel (.xlsx) and CSV files (DL-077).
 *
 * Only files the scan already cleared reach here: a workbook through the
 * same bounded ZIP reader the scan used, a CSV as the UTF-8 text the scan
 * checked. Nothing is evaluated: formulas are read as the value Excel last
 * saved with them (`<v>`), never recalculated; links, macros and data
 * connections were refused by the scan and are never followed here.
 *
 * Each row becomes one line, its cells joined with " | ", and empty rows are
 * skipped. A workbook is read sheet by sheet, in the workbook's own order,
 * with the sheet's name as the heading. Hidden sheets, rows and columns are
 * not read: a teacher who hides a sheet of answers has not shared it.
 *
 * Rows are grouped into passages of about a paragraph, and every passage
 * after a sheet's first starts with that sheet's first row again, so a
 * passage found on its own still says what its columns are.
 *
 * Caps (SPREADSHEET_LIMITS), on top of the per-file character cap every
 * reader has: at most 50 sheets, 20,000 rows, 200,000 cells and 100 columns
 * a file, and 1,000 characters a cell. Past any of them the rest is left
 * out and the file is marked as partly read.
 */
import { csvText } from "@studafy/domain";
import type { MaterialSection } from "./chunks";
import {
  decodeXml,
  openZip,
  part,
  relationships,
  resolve,
  UnreadableDocumentError,
} from "./office";

export const SPREADSHEET_LIMITS = {
  /** Visible worksheets read from one workbook. */
  sheets: 50,
  /** Non-empty rows kept from one file. */
  rows: 20_000,
  /** Non-empty cells kept from one file. */
  cells: 200_000,
  /** Columns read from one row; the rest of the row is left out. */
  columns: 100,
  /** Characters kept from one cell. */
  cellChars: 1_000,
} as const;

/** Rows are grouped into passages of about this many characters. */
const BLOCK_CHARS = 1_000;

export interface TableExtraction {
  sections: MaterialSection[];
  /** Sheets read (1 for a CSV). */
  sheets: number;
  /** Non-empty rows kept. */
  rows: number;
  /** Whether a cap left something out. */
  truncated: boolean;
}

/** Collects rows into sections, under the caps. */
class TableWriter {
  readonly sections: MaterialSection[] = [];
  rows = 0;
  cells = 0;
  chars = 0;
  sheets = 0;
  truncated = false;
  #full = false;
  #heading: string | null = null;
  #header: string | null = null;
  #block: string[] = [];
  #blockChars = 0;

  constructor(private readonly maxChars: number) {}

  get full(): boolean {
    return this.#full;
  }

  startSheet(heading: string | null): void {
    this.#flush();
    this.#heading = heading ? heading.slice(0, 300) : null;
    this.#header = null;
    this.sheets++;
  }

  /** Stops the reading: something was left out. */
  stop(): void {
    this.truncated = true;
    this.#full = true;
  }

  /** Adds one row; false once a cap is reached and reading should stop. */
  addRow(raw: string[]): boolean {
    if (this.#full) return false;
    let cells = raw;
    if (cells.length > SPREADSHEET_LIMITS.columns) {
      cells = cells.slice(0, SPREADSHEET_LIMITS.columns);
      this.truncated = true;
    }
    cells = cells.map((cell) => {
      const text = cell.replace(/\s+/g, " ").trim();
      if (text.length <= SPREADSHEET_LIMITS.cellChars) return text;
      this.truncated = true;
      return `${text.slice(0, SPREADSHEET_LIMITS.cellChars)}…`;
    });
    while (cells.length > 0 && cells[cells.length - 1] === "") cells.pop();
    const filled = cells.filter((cell) => cell !== "").length;
    if (filled === 0) return true;
    const line = cells.join(" | ");
    if (
      this.rows + 1 > SPREADSHEET_LIMITS.rows ||
      this.cells + filled > SPREADSHEET_LIMITS.cells ||
      this.chars + line.length > this.maxChars
    ) {
      this.stop();
      return false;
    }
    this.rows++;
    this.cells += filled;
    this.chars += line.length + 1;
    if (this.#header === null) this.#header = line;
    else if (
      this.#block.length > 0 && this.#blockChars + line.length > BLOCK_CHARS
    ) {
      this.#flush();
      this.#block.push(this.#header);
      this.#blockChars = this.#header.length;
    }
    this.#block.push(line);
    this.#blockChars += line.length + 1;
    return true;
  }

  finish(): TableExtraction {
    this.#flush();
    return {
      sections: this.sections,
      sheets: this.sheets,
      rows: this.rows,
      truncated: this.truncated,
    };
  }

  #flush(): void {
    if (this.#block.length > 0) {
      this.sections.push({
        heading: this.#heading,
        text: this.#block.join("\n"),
      });
    }
    this.#block = [];
    this.#blockChars = 0;
  }
}

function attribute(attrs: string, name: string): string | null {
  const match = attrs.match(new RegExp(`(?:^|\\s)${name}="([^"]*)"`));
  return match ? decodeXml(match[1]!) : null;
}

const TAG_NAME_END = new Set([" ", "\t", "\n", "\r", ">", "/"]);

/**
 * Each `<tag ...>inner</tag>` or `<tag .../>` in [xml], in order. Scans
 * forward with indexOf only, so a part with unclosed elements costs one
 * pass, not one pass per element (no regex backtracking over the part).
 * The elements read here (rows, cells, strings) never nest in themselves.
 */
function* elements(
  xml: string,
  tag: string,
): Generator<{ attrs: string; inner: string | null }> {
  const open = `<${tag}`;
  const close = `</${tag}>`;
  let at = 0;
  for (;;) {
    const start = xml.indexOf(open, at);
    if (start < 0) return;
    at = start + open.length;
    if (!TAG_NAME_END.has(xml[at] ?? "")) continue;
    const tagEnd = xml.indexOf(">", at);
    if (tagEnd < 0) return;
    if (xml[tagEnd - 1] === "/") {
      yield { attrs: xml.slice(at, tagEnd - 1), inner: null };
      at = tagEnd + 1;
      continue;
    }
    const end = xml.indexOf(close, tagEnd + 1);
    if (end < 0) return;
    yield { attrs: xml.slice(at, tagEnd), inner: xml.slice(tagEnd + 1, end) };
    at = end + close.length;
  }
}

function firstInner(xml: string, tag: string): string | null {
  for (const element of elements(xml, tag)) return element.inner ?? "";
  return null;
}

/** The text of a rich or plain string item: its `<t>` runs, no phonetics. */
function stringItem(xml: string): string {
  // Phonetic guides (<rPh>) hold their own <t> runs: left out.
  let body = "";
  let at = 0;
  for (;;) {
    const start = xml.indexOf("<rPh", at);
    if (start < 0) {
      body += xml.slice(at);
      break;
    }
    body += xml.slice(at, start);
    const end = xml.indexOf("</rPh>", start);
    if (end < 0) break;
    at = end + "</rPh>".length;
  }
  let text = "";
  for (const run of elements(body, "t")) {
    if (run.inner !== null) text += decodeXml(run.inner);
    if (text.length > SPREADSHEET_LIMITS.cellChars) break;
  }
  return text.slice(0, SPREADSHEET_LIMITS.cellChars + 1);
}

function sharedStrings(xml: string | null): string[] {
  if (xml === null) return [];
  const out: string[] = [];
  for (const item of elements(xml, "si")) {
    out.push(item.inner === null ? "" : stringItem(item.inner));
  }
  return out;
}

// Excel's built-in number formats that show a date or a time.
const BUILT_IN_DATE_FORMATS = new Set([
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  45,
  46,
  47,
]);

/** Indexes of the cell styles whose number format shows a date or time. */
function dateStyles(xml: string | null): Set<number> {
  const out = new Set<number>();
  if (xml === null) return out;
  const custom = new Set<number>();
  for (const format of elements(xml, "numFmt")) {
    const id = Number(attribute(format.attrs, "numFmtId"));
    const code = (attribute(format.attrs, "formatCode") ?? "")
      .replace(/"[^"]*"/g, "")
      .replace(/\\./g, "")
      .replace(/\[[^\]]*\]/g, "");
    if (Number.isInteger(id) && /[dmyhs]/i.test(code)) custom.add(id);
  }
  const cellXfs = firstInner(xml, "cellXfs") ?? "";
  let index = 0;
  for (const xf of elements(cellXfs, "xf")) {
    const id = Number(attribute(xf.attrs, "numFmtId") ?? "0");
    if (BUILT_IN_DATE_FORMATS.has(id) || custom.has(id)) out.add(index);
    index++;
  }
  return out;
}

/** An Excel serial date as "2026-11-03", "08:30" or both. */
function serialDate(serial: number, date1904: boolean): string | null {
  if (!Number.isFinite(serial) || serial < 0 || serial > 2_958_465) {
    return null;
  }
  const days = date1904
    ? serial + 1462
    // 1900 is wrongly a leap year in Excel: serial 60 is 1900-02-29.
    : serial >= 61
    ? serial
    : serial + 1;
  const ms = Math.round((days - 25569) * 86_400_000);
  const iso = new Date(ms).toISOString();
  const whole = Number.isInteger(serial);
  if (whole) return iso.slice(0, 10);
  if (serial < 1) return iso.slice(11, 16);
  return `${iso.slice(0, 10)} ${iso.slice(11, 16)}`;
}

/** "B" -> 1, "AA" -> 26: the column of a cell reference like "AA12". */
function columnOf(reference: string | null): number | null {
  const letters = reference?.match(/^([A-Z]{1,3})\d*$/)?.[1];
  if (!letters) return null;
  let column = 0;
  for (const letter of letters) {
    column = column * 26 + letter.charCodeAt(0) - 64;
  }
  return column - 1;
}

function numberText(raw: string): string {
  const value = Number(raw);
  if (!Number.isFinite(value)) return raw.trim();
  // What Excel shows: 15 significant digits, so 0.1+0.2 is 0.3.
  return String(Number(value.toPrecision(15)));
}

interface SheetContext {
  shared: string[];
  dates: Set<number>;
  date1904: boolean;
}

function cellValue(attrs: string, inner: string, ctx: SheetContext): string {
  const type = attribute(attrs, "t") ?? "n";
  if (type === "inlineStr") {
    const is = firstInner(inner, "is");
    return is === null ? "" : stringItem(is);
  }
  const v = firstInner(inner, "v");
  if (v === null) return "";
  switch (type) {
    case "s":
      return ctx.shared[Number(v)] ?? "";
    case "b":
      return v.trim() === "1" ? "TRUE" : "FALSE";
    case "e":
      return "";
    case "str":
    case "d":
      return decodeXml(v);
    default: {
      const style = Number(attribute(attrs, "s") ?? "0");
      if (ctx.dates.has(style)) {
        const date = serialDate(Number(v), ctx.date1904);
        if (date) return date;
      }
      return numberText(decodeXml(v));
    }
  }
}

function readWorksheet(
  xml: string,
  ctx: SheetContext,
  writer: TableWriter,
): void {
  const hiddenColumns = new Set<number>();
  const start = xml.indexOf("<sheetData");
  if (start < 0) return;
  const cols = firstInner(xml.slice(0, start), "cols") ?? "";
  for (const col of elements(cols, "col")) {
    const hidden = attribute(col.attrs, "hidden");
    if (hidden !== "1" && hidden !== "true") continue;
    const min = Number(attribute(col.attrs, "min"));
    const max = Math.min(
      Number(attribute(col.attrs, "max")),
      SPREADSHEET_LIMITS.columns + 1,
    );
    for (let c = min; c <= max; c++) hiddenColumns.add(c - 1);
  }
  const data = xml.slice(start);
  for (const row of elements(data, "row")) {
    const hidden = attribute(row.attrs, "hidden");
    if (hidden === "1" || hidden === "true") continue;
    const inner = row.inner;
    if (!inner) continue;
    const cells: string[] = [];
    let next = 0;
    for (const cell of elements(inner, "c")) {
      const column = columnOf(attribute(cell.attrs, "r")) ?? next;
      next = column + 1;
      if (column > SPREADSHEET_LIMITS.columns) {
        writer.truncated = true;
        break;
      }
      if (hiddenColumns.has(column)) continue;
      const value = cell.inner === null
        ? ""
        : cellValue(cell.attrs, cell.inner, ctx);
      if (value === "") continue;
      while (cells.length < column) cells.push("");
      cells[column] = value;
    }
    // Hidden columns leave no gap.
    const visible = cells.filter((_, i) => !hiddenColumns.has(i));
    if (!writer.addRow(visible)) return;
  }
}

/** A .xlsx as sections: its visible sheets in order, rows as lines. */
export function extractXlsx(
  bytes: Uint8Array,
  maxChars = Number.POSITIVE_INFINITY,
): TableExtraction {
  const entries = openZip(bytes);
  const workbook = part(bytes, entries, "xl/workbook.xml");
  if (workbook === null) throw new UnreadableDocumentError();
  const rels = relationships(
    part(bytes, entries, "xl/_rels/workbook.xml.rels"),
  );
  const ctx: SheetContext = {
    shared: sharedStrings(part(bytes, entries, "xl/sharedStrings.xml")),
    dates: dateStyles(part(bytes, entries, "xl/styles.xml")),
    date1904: [...elements(workbook, "workbookPr")].some((pr) =>
      /^(1|true)$/.test(attribute(pr.attrs, "date1904") ?? "")
    ),
  };
  const writer = new TableWriter(maxChars);
  for (const sheet of elements(workbook, "sheet")) {
    const tag = sheet.attrs;
    const state = attribute(tag, "state");
    if (state === "hidden" || state === "veryHidden") continue;
    const id = tag.match(/(?:^|\s)[\w-]+:id="([^"]+)"/)?.[1];
    const rel = id ? rels.get(id) : undefined;
    if (!rel || !rel.type.endsWith("/worksheet")) continue;
    const xml = part(bytes, entries, resolve("xl/workbook.xml", rel.target));
    if (xml === null) continue;
    if (writer.sheets >= SPREADSHEET_LIMITS.sheets) {
      writer.stop();
      break;
    }
    writer.startSheet(attribute(tag, "name"));
    readWorksheet(xml, ctx, writer);
    if (writer.full) break;
  }
  return writer.finish();
}

/** The separator a CSV uses: the commonest of , ; and tab in its first row. */
function sniffDelimiter(text: string): string {
  const counts = new Map<string, number>([[",", 0], [";", 0], ["\t", 0]]);
  let quoted = false;
  for (let i = 0; i < text.length && i < 65_536; i++) {
    const char = text[i]!;
    if (char === '"') quoted = !quoted;
    else if (!quoted && (char === "\n" || char === "\r")) break;
    else if (!quoted && counts.has(char)) {
      counts.set(char, counts.get(char)! + 1);
    }
  }
  let best = ",";
  for (const [delimiter, count] of counts) {
    if (count > counts.get(best)!) best = delimiter;
  }
  return best;
}

/**
 * A CSV as sections of rows. Quoted fields may hold the separator, line
 * breaks and doubled quotes (""); a quote left open runs to the end.
 */
export function extractCsv(
  bytes: Uint8Array,
  maxChars = Number.POSITIVE_INFINITY,
): TableExtraction {
  const text = csvText(bytes);
  if (text === null) throw new UnreadableDocumentError();
  const delimiter = sniffDelimiter(text);
  const writer = new TableWriter(maxChars);
  writer.startSheet(null);
  let row: string[] = [];
  let at = 0;
  const length = text.length;
  while (at <= length) {
    let field: string;
    if (text[at] === '"') {
      const pieces: string[] = [];
      let from = at + 1;
      for (;;) {
        const close = text.indexOf('"', from);
        if (close < 0) {
          pieces.push(text.slice(from));
          at = length;
          break;
        }
        pieces.push(text.slice(from, close));
        if (text[close + 1] === '"') {
          pieces.push('"');
          from = close + 2;
          continue;
        }
        at = close + 1;
        break;
      }
      // Anything between the closing quote and the separator is kept.
      let end = at;
      while (
        end < length && text[end] !== delimiter && text[end] !== "\n" &&
        text[end] !== "\r"
      ) end++;
      pieces.push(text.slice(at, end));
      at = end;
      field = pieces.join("");
    } else {
      let end = at;
      while (
        end < length && text[end] !== delimiter && text[end] !== "\n" &&
        text[end] !== "\r"
      ) end++;
      field = text.slice(at, end);
      at = end;
    }
    // One column past the cap is kept, so the writer knows to say so.
    if (row.length <= SPREADSHEET_LIMITS.columns) {
      row.push(
        field.length > SPREADSHEET_LIMITS.cellChars * 2
          ? field.slice(0, SPREADSHEET_LIMITS.cellChars * 2)
          : field,
      );
    }
    if (at < length && text[at] === delimiter) {
      at++;
      continue;
    }
    // End of a row: \n, \r\n, \r or the end of the text.
    if (!writer.addRow(row)) break;
    row = [];
    if (at >= length) break;
    at += text[at] === "\r" && text[at + 1] === "\n" ? 2 : 1;
    if (at >= length) break;
  }
  return writer.finish();
}
