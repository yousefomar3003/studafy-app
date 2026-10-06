/**
 * Word and PowerPoint files built in code for tests (ADR-0037). No binary
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
    locals.push(...name, ...body);

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
