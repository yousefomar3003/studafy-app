/**
 * Text from Word and PowerPoint files (ADR-0037).
 *
 * Only files the scan already cleared reach here, and they are read through
 * the same bounded ZIP reader the scan used. The XML is read with patterns,
 * not executed or resolved: no external entities, no includes.
 *
 * Kept: headings, paragraphs, tables (as "a | b" rows), slide order, slide
 * titles and speaker notes, and a Word file's page breaks where Word wrote
 * them. Not read: pictures inside the document, charts, SmartArt and
 * equations stored as images.
 */
import { readZipDirectory, readZipEntry, type ZipEntry } from "@studafy/domain";
import type { MaterialSection } from "./chunks";

const utf8 = new TextDecoder("utf-8");

function decodeXml(text: string): string {
  return text
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#x([0-9a-f]{1,6});/gi, (_, hex: string) => {
      const code = parseInt(hex, 16);
      return code > 0 && code < 0x110000 ? String.fromCodePoint(code) : "";
    })
    .replace(/&#(\d{1,7});/g, (_, dec: string) => {
      const code = Number(dec);
      return code > 0 && code < 0x110000 ? String.fromCodePoint(code) : "";
    })
    .replace(/&amp;/g, "&");
}

export class UnreadableDocumentError extends Error {
  constructor() {
    super("unreadable_document");
    this.name = "UnreadableDocumentError";
  }
}

function openZip(bytes: Uint8Array): Map<string, ZipEntry> {
  const directory = readZipDirectory(bytes);
  if (!directory.ok) throw new UnreadableDocumentError();
  return new Map(directory.entries.map((entry) => [entry.name, entry]));
}

function part(
  bytes: Uint8Array,
  entries: Map<string, ZipEntry>,
  name: string,
): string | null {
  const entry = entries.get(name);
  if (!entry) return null;
  const raw = readZipEntry(bytes, entry);
  if (raw === null) throw new UnreadableDocumentError();
  return utf8.decode(raw);
}

/** The text runs of a Word paragraph, with tabs and line breaks. */
function wordRuns(xml: string): string {
  let text = "";
  for (
    const match of xml.matchAll(
      /<w:t(?:\s[^>]*)?>([\s\S]*?)<\/w:t>|<w:tab\/>|<w:br(?:\s[^>]*)?\/>|<w:cr\/>/g,
    )
  ) {
    if (match[1] !== undefined) text += decodeXml(match[1]);
    else if (match[0].startsWith("<w:tab")) text += "\t";
    else if (!/w:type="page"/.test(match[0])) text += "\n";
  }
  return text;
}

/** Each top-level element's span in [xml]: `<tag ...>...</tag>` with nesting. */
function topLevel(xml: string, tag: string): string[] {
  const out: string[] = [];
  const open = new RegExp(`<${tag}[\\s>]|<${tag}/>|</${tag}>`, "g");
  let depth = 0;
  let start = -1;
  for (const match of xml.matchAll(open)) {
    const token = match[0];
    if (token === `<${tag}/>`) continue;
    if (token.startsWith("</")) {
      depth--;
      if (depth === 0 && start >= 0) {
        out.push(xml.slice(start, match.index! + token.length));
        start = -1;
      }
    } else {
      if (depth === 0) start = match.index!;
      depth++;
    }
  }
  return out;
}

function tableRows(
  xml: string,
  row: string,
  cell: string,
  runs: (x: string) => string,
): string {
  return topLevel(xml, row).map((r) =>
    topLevel(r, cell).map((c) => runs(c).replace(/\s+/g, " ").trim()).join(
      " | ",
    )
  ).filter((line) => line.replace(/[|\s]/g, "").length > 0).join("\n");
}

/** A .docx as sections: one per heading, and per page where Word marked it. */
export function extractDocx(bytes: Uint8Array): {
  sections: MaterialSection[];
  pages: number | null;
} {
  const entries = openZip(bytes);
  const xml = part(bytes, entries, "word/document.xml");
  if (xml === null) throw new UnreadableDocumentError();
  const body = xml.match(/<w:body>([\s\S]*)<\/w:body>/)?.[1] ?? xml;
  const hasPages = /<w:lastRenderedPageBreak\/>|<w:br\s[^>]*w:type="page"/.test(
    body,
  );
  const sections: MaterialSection[] = [];
  let page = 1;
  let heading: string | null = null;
  let lines: string[] = [];
  const flush = () => {
    if (lines.join("").trim()) {
      sections.push({
        page: hasPages ? page : null,
        heading,
        text: lines.join("\n\n"),
      });
    }
    lines = [];
  };
  // Paragraphs and tables, in document order.
  const blocks = /<w:tbl[\s>][\s\S]*?<\/w:tbl>|<w:p[\s>][\s\S]*?<\/w:p>/g;
  let cursor = 0;
  for (const match of body.matchAll(blocks)) {
    let block = match[0];
    if (match.index! < cursor) continue;
    if (block.startsWith("<w:tbl")) {
      // A nested table closes early in the lazy match: take the whole one.
      const whole = topLevel(body.slice(match.index!), "w:tbl")[0] ?? block;
      block = whole;
      cursor = match.index! + whole.length;
      lines.push(tableRows(block, "w:tr", "w:tc", wordRuns));
      continue;
    }
    const breaks = (block.match(
      /<w:lastRenderedPageBreak\/>|<w:br\s[^>]*w:type="page"[^>]*\/>/g,
    ) ?? []).length;
    if (breaks > 0 && hasPages) {
      flush();
      page += breaks;
    }
    const style = block.match(/<w:pStyle\s+w:val="([^"]+)"/)?.[1] ?? "";
    const text = wordRuns(block).trim();
    if (/^(heading\d?|title|subtitle)$/i.test(style) && text) {
      flush();
      heading = text.slice(0, 300);
      continue;
    }
    if (text) lines.push(text);
  }
  flush();
  return { sections, pages: hasPages ? page : null };
}

/** The text of a slide's shapes: paragraphs and tables. */
function slideText(xml: string): { title: string | null; text: string } {
  let title: string | null = null;
  const lines: string[] = [];
  const runs = (x: string) =>
    [...x.matchAll(/<a:t>([\s\S]*?)<\/a:t>|<a:br\/>/g)]
      .map((m) => m[1] === undefined ? "\n" : decodeXml(m[1])).join("");
  for (const shape of topLevel(xml, "p:sp")) {
    const paragraphs = topLevel(shape, "a:p").map((p) => runs(p).trim())
      .filter((line) => line.length > 0);
    if (paragraphs.length === 0) continue;
    if (!title && /<p:ph\s[^>]*type="(title|ctrTitle)"/.test(shape)) {
      title = paragraphs.join(" ").slice(0, 300);
      continue;
    }
    lines.push(...paragraphs);
  }
  for (const frame of topLevel(xml, "a:tbl")) {
    lines.push(tableRows(frame, "a:tr", "a:tc", runs));
  }
  return { title, text: lines.join("\n\n") };
}

function relationships(
  xml: string | null,
): Map<string, { type: string; target: string }> {
  const out = new Map<string, { type: string; target: string }>();
  for (const match of (xml ?? "").matchAll(/<Relationship\s[^>]*>/g)) {
    const id = match[0].match(/\bId="([^"]+)"/)?.[1];
    const type = match[0].match(/\bType="([^"]+)"/)?.[1] ?? "";
    const target = match[0].match(/\bTarget="([^"]+)"/)?.[1];
    if (id && target) out.set(id, { type, target });
  }
  return out;
}

function resolve(base: string, target: string): string {
  const parts = base.split("/").slice(0, -1);
  for (const piece of target.split("/")) {
    if (piece === "..") parts.pop();
    else if (piece !== ".") parts.push(piece);
  }
  return parts.join("/");
}

/** A .pptx as one section per slide, in the deck's own order, with notes. */
export function extractPptx(bytes: Uint8Array): {
  sections: MaterialSection[];
  slides: number;
} {
  const entries = openZip(bytes);
  const presentation = part(bytes, entries, "ppt/presentation.xml");
  if (presentation === null) throw new UnreadableDocumentError();
  const rels = relationships(
    part(bytes, entries, "ppt/_rels/presentation.xml.rels"),
  );
  let order = [...presentation.matchAll(/<p:sldId\s[^>]*r:id="([^"]+)"/g)]
    .map((m) => rels.get(m[1]!)?.target)
    .filter((t): t is string => Boolean(t))
    .map((t) => resolve("ppt/presentation.xml", t));
  if (order.length === 0) {
    order = [...entries.keys()]
      .filter((name) => /^ppt\/slides\/slide\d+\.xml$/.test(name))
      .sort((a, b) =>
        Number(a.match(/\d+/g)!.pop()) - Number(b.match(/\d+/g)!.pop())
      );
  }
  const sections: MaterialSection[] = [];
  order.forEach((name, index) => {
    const xml = part(bytes, entries, name);
    if (xml === null) return;
    const { title, text } = slideText(xml);
    const slideRels = relationships(
      part(
        bytes,
        entries,
        name.replace(/slides\/(slide\d+\.xml)$/, "slides/_rels/$1.rels"),
      ),
    );
    let notes = "";
    for (const rel of slideRels.values()) {
      if (rel.type.endsWith("/notesSlide")) {
        const notesXml = part(bytes, entries, resolve(name, rel.target));
        if (notesXml) notes = slideText(notesXml).text;
      }
    }
    const body = [text, notes ? `Speaker notes: ${notes}` : ""].filter(Boolean)
      .join("\n\n");
    if (body.trim() || title) {
      sections.push({
        slide: index + 1,
        heading: title,
        text: body || (title ?? ""),
      });
    }
  });
  return { sections, slides: order.length };
}
