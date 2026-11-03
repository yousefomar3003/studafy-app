/**
 * Word, PowerPoint and Excel files built in code for tests (ADR-0037). No binary
 * fixtures: each ZIP is assembled here, deflated or stored, byte for byte.
 */
import { deflateRawSync } from "node:zlib";

const encoder = new TextEncoder();

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

export interface ZipPart {
  name: string;
  data: string | Uint8Array;
  /** Stored instead of deflated. */
  stored?: boolean;
}

/** A plain, valid ZIP of [parts]. */
export function buildZip(parts: ZipPart[]): Uint8Array {
  const locals: number[] = [];
  const central: number[] = [];
  const push = (into: number[], value: number, size: 2 | 4) => {
    for (let i = 0; i < size; i++) into.push((value >>> (8 * i)) & 0xff);
  };
  for (const part of parts) {
    const raw = typeof part.data === "string"
      ? encoder.encode(part.data)
      : part.data;
    const body = part.stored ? raw : new Uint8Array(deflateRawSync(raw));
    const name = encoder.encode(part.name);
    const offset = locals.length;
    const crc = crc32(raw);
    const method = part.stored ? 0 : 8;
    push(locals, 0x04034b50, 4);
    push(locals, 20, 2);
    push(locals, 0, 2);
    push(locals, method, 2);
    push(locals, 0, 2);
    push(locals, 0, 2);
    push(locals, crc, 4);
    push(locals, body.length, 4);
    push(locals, raw.length, 4);
    push(locals, name.length, 2);
    push(locals, 0, 2);
    // One by one: a large part would overflow the stack as spread arguments.
    for (const byte of name) locals.push(byte);
    for (const byte of body) locals.push(byte);

    push(central, 0x02014b50, 4);
    push(central, 20, 2);
    push(central, 20, 2);
    push(central, 0, 2);
    push(central, method, 2);
    push(central, 0, 2);
    push(central, 0, 2);
    push(central, crc, 4);
    push(central, body.length, 4);
    push(central, raw.length, 4);
    push(central, name.length, 2);
    push(central, 0, 2);
    push(central, 0, 2);
    push(central, 0, 2);
    push(central, 0, 2);
    push(central, 0, 4);
    push(central, offset, 4);
    central.push(...name);
  }
  const end: number[] = [];
  push(end, 0x06054b50, 4);
  push(end, 0, 2);
  push(end, 0, 2);
  push(end, parts.length, 2);
  push(end, parts.length, 2);
  push(end, central.length, 4);
  push(end, locals.length, 4);
  push(end, 0, 2);
  return Uint8Array.from([...locals, ...central, ...end]);
}

const escape = (text: string) =>
  text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const contentTypes = (main: string, extra = "") =>
  `<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="${main}"/>${extra}</Types>`;

export type DocxBlock =
  | { heading: string; level?: number }
  | { paragraph: string }
  | { table: string[][] }
  | { pageBreak: true };

export interface OfficeOptions {
  /** Extra parts, for building hostile files. */
  extraParts?: ZipPart[];
  /** Extra text inside [Content_Types].xml. */
  extraContentTypes?: string;
  /** The document's own relationships part. */
  documentRels?: string;
}

/** A .docx with headings, paragraphs, tables and page breaks. */
export function buildDocx(
  blocks: DocxBlock[],
  options: OfficeOptions = {},
): Uint8Array {
  const body = blocks.map((block) => {
    if ("heading" in block) {
      return `<w:p><w:pPr><w:pStyle w:val="Heading${
        block.level ?? 1
      }"/></w:pPr><w:r><w:t>${escape(block.heading)}</w:t></w:r></w:p>`;
    }
    if ("paragraph" in block) {
      return `<w:p><w:r><w:t xml:space="preserve">${
        escape(block.paragraph)
      }</w:t></w:r></w:p>`;
    }
    if ("table" in block) {
      return `<w:tbl>${
        block.table.map((row) =>
          `<w:tr>${
            row.map((cell) =>
              `<w:tc><w:p><w:r><w:t>${escape(cell)}</w:t></w:r></w:p></w:tc>`
            ).join("")
          }</w:tr>`
        ).join("")
      }</w:tbl>`;
    }
    return `<w:p><w:r><w:br w:type="page"/></w:r></w:p>`;
  }).join("");
  return buildZip([
    {
      name: "[Content_Types].xml",
      data: contentTypes("/word/document.xml", options.extraContentTypes),
    },
    {
      name: "_rels/.rels",
      data:
        `<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>`,
    },
    {
      name: "word/document.xml",
      data:
        `<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${body}</w:body></w:document>`,
    },
    ...(options.documentRels
      ? [{ name: "word/_rels/document.xml.rels", data: options.documentRels }]
      : []),
    ...(options.extraParts ?? []),
  ]);
}

/** A .pptx with one slide per entry: its title, bullet lines and notes. */
export function buildPptx(
  slides: { title: string; lines?: string[]; notes?: string }[],
  options: OfficeOptions = {},
): Uint8Array {
  const shape = (text: string, title = false) =>
    `<p:sp><p:nvSpPr><p:nvPr>${
      title ? '<p:ph type="title"/>' : ""
    }</p:nvPr></p:nvSpPr><p:txBody><a:p><a:r><a:t>${
      escape(text)
    }</a:t></a:r></a:p></p:txBody></p:sp>`;
  const parts: ZipPart[] = [
    {
      name: "[Content_Types].xml",
      data: contentTypes("/ppt/presentation.xml", options.extraContentTypes),
    },
    {
      name: "_rels/.rels",
      data:
        `<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>`,
    },
    {
      name: "ppt/presentation.xml",
      data:
        `<?xml version="1.0"?><p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"/>`,
    },
  ];
  slides.forEach((slide, index) => {
    const n = index + 1;
    parts.push({
      name: `ppt/slides/slide${n}.xml`,
      data:
        `<?xml version="1.0"?><p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree>${
          shape(slide.title, true)
        }${
          (slide.lines ?? []).map((line) => shape(line)).join("")
        }</p:spTree></p:cSld></p:sld>`,
    });
    if (slide.notes) {
      parts.push({
        name: `ppt/notesSlides/notesSlide${n}.xml`,
        data:
          `<?xml version="1.0"?><p:notes xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree>${
            shape(slide.notes)
          }</p:spTree></p:cSld></p:notes>`,
      });
      parts.push({
        name: `ppt/slides/_rels/slide${n}.xml.rels`,
        data:
          `<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId9" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide" Target="../notesSlides/notesSlide${n}.xml"/></Relationships>`,
      });
    }
  });
  parts.push(...(options.extraParts ?? []));
  return buildZip(parts);
}

/** One cell of a test workbook. */
export type XlsxCell =
  | string
  | number
  | boolean
  | null
  /** A formula with the value Excel saved with it. */
  | { formula: string; cached: string | number }
  /** A string written inline rather than in the shared table. */
  | { inline: string }
  /** A date, as Excel stores it: a serial number in a date style. */
  | { date: number };

export interface XlsxSheet {
  name: string;
  rows: XlsxCell[][];
  state?: "hidden" | "veryHidden";
  /** 1-based rows hidden in Excel. */
  hiddenRows?: number[];
  /** 1-based columns hidden in Excel. */
  hiddenColumns?: number[];
}

export interface XlsxOptions extends OfficeOptions {
  /** Replaces the workbook's main content type (a template, a macro file). */
  mainContentType?: string;
}

const columnName = (index: number) => {
  let name = "";
  for (let n = index + 1; n > 0; n = Math.floor((n - 1) / 26)) {
    name = String.fromCharCode(65 + ((n - 1) % 26)) + name;
  }
  return name;
};

/**
 * A .xlsx with shared strings, numbers, booleans, formulas with cached
 * values, inline strings, dates, and hidden sheets, rows and columns.
 */
export function buildXlsx(
  sheets: XlsxSheet[],
  options: XlsxOptions = {},
): Uint8Array {
  const shared: string[] = [];
  const sharedIndex = (text: string) => {
    const at = shared.indexOf(text);
    if (at >= 0) return at;
    shared.push(text);
    return shared.length - 1;
  };
  const cellXml = (cell: XlsxCell, ref: string): string => {
    if (cell === null) return "";
    if (typeof cell === "string") {
      return `<c r="${ref}" t="s"><v>${sharedIndex(cell)}</v></c>`;
    }
    if (typeof cell === "number") return `<c r="${ref}"><v>${cell}</v></c>`;
    if (typeof cell === "boolean") {
      return `<c r="${ref}" t="b"><v>${cell ? 1 : 0}</v></c>`;
    }
    if ("inline" in cell) {
      return `<c r="${ref}" t="inlineStr"><is><t>${
        escape(cell.inline)
      }</t></is></c>`;
    }
    if ("date" in cell) return `<c r="${ref}" s="1"><v>${cell.date}</v></c>`;
    return typeof cell.cached === "number"
      ? `<c r="${ref}"><f>${escape(cell.formula)}</f><v>${cell.cached}</v></c>`
      : `<c r="${ref}" t="str"><f>${escape(cell.formula)}</f><v>${
        escape(cell.cached)
      }</v></c>`;
  };
  // Built before the shared-string table, which the cells fill.
  const sheetParts: ZipPart[] = sheets.map((sheet, index) => {
    const cols = (sheet.hiddenColumns ?? []).map((c) =>
      `<col min="${c}" max="${c}" width="9" hidden="1"/>`
    ).join("");
    const rows = sheet.rows.map((row, r) =>
      `<row r="${r + 1}"${
        sheet.hiddenRows?.includes(r + 1) ? ' hidden="1"' : ""
      }>${
        row.map((cell, c) => cellXml(cell, `${columnName(c)}${r + 1}`)).join(
          "",
        )
      }</row>`
    ).join("");
    return {
      name: `xl/worksheets/sheet${index + 1}.xml`,
      data:
        `<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">${
          cols ? `<cols>${cols}</cols>` : ""
        }<sheetData>${rows}</sheetData></worksheet>`,
    };
  });
  const main = options.mainContentType ??
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml";
  return buildZip([
    {
      name: "[Content_Types].xml",
      data:
        `<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/xl/workbook.xml" ContentType="${main}"/>${
          options.extraContentTypes ?? ""
        }</Types>`,
    },
    {
      name: "_rels/.rels",
      data:
        `<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
    },
    {
      name: "xl/workbook.xml",
      data:
        `<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${
          sheets.map((sheet, index) =>
            `<sheet name="${escape(sheet.name)}" sheetId="${index + 1}"${
              sheet.state ? ` state="${sheet.state}"` : ""
            } r:id="rId${index + 1}"/>`
          ).join("")
        }</sheets></workbook>`,
    },
    {
      name: "xl/_rels/workbook.xml.rels",
      data: options.documentRels ??
        `<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${
          sheets.map((_, index) =>
            `<Relationship Id="rId${
              index + 1
            }" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${
              index + 1
            }.xml"/>`
          ).join("")
        }</Relationships>`,
    },
    {
      name: "xl/styles.xml",
      data:
        `<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="14" applyNumberFormat="1"/></cellXfs></styleSheet>`,
    },
    ...sheetParts,
    {
      name: "xl/sharedStrings.xml",
      data:
        `<?xml version="1.0" encoding="UTF-8"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${shared.length}" uniqueCount="${shared.length}">${
          shared.map((text) =>
            `<si><t xml:space="preserve">${escape(text)}</t></si>`
          ).join("")
        }</sst>`,
    },
    ...(options.extraParts ?? []),
  ]);
}
