/**
 * Text from a PDF, page by page (ADR-0037).
 *
 * The text layer is read with pdf.js. A page with no text layer but with
 * pictures is a scan: it is drawn to an image and read by the model, within
 * the per-file and per-school page budget. pdf.js 6 never evaluates code
 * from a file (the 5.x advisory GHSA-hq66-cqwq-w95j); XFA stays off, and
 * the file was already cleared by the scan.
 */
import type { MaterialSection } from "./chunks";
import { MAX_IMAGE_PIXELS } from "@studafy/domain";
import { encodeJpeg } from "./image";

/** Reads one page image; the reply's text and what it cost. */
export type PageReader = (
  jpeg: Uint8Array,
) => Promise<{ text: string; usage?: ProcessingUsage }>;

export interface ProcessingUsage {
  inputTokens: number;
  outputTokens: number;
  model: string;
}

export interface PdfExtraction {
  sections: MaterialSection[];
  pages: number;
  textPages: number;
  ocrPages: number;
  /** Scanned pages not read: over the budget, or no model to read them. */
  skippedPages: number;
  /** Pages past the per-file text limit. */
  unreadPages: number;
  usage: ProcessingUsage[];
}

/** Longest side of a page drawn for the model, in pixels. */
const OCR_MAX_SIDE = 1_600;
/** A page with less text than this is treated as a scan. */
const SCAN_TEXT_CHARS = 24;

let loaded:
  | Promise<typeof import("pdfjs-dist/legacy/build/pdf.mjs")>
  | undefined;

async function pdfjs() {
  loaded ??= (async () => {
    // pdf.js draws through the DOM's canvas classes; outside a browser they
    // come from @napi-rs/canvas, and must be in place before it loads.
    const canvas = await import("@napi-rs/canvas");
    const scope = globalThis as Record<string, unknown>;
    scope["DOMMatrix"] ??= canvas.DOMMatrix;
    scope["Path2D"] ??= canvas.Path2D;
    scope["ImageData"] ??= canvas.ImageData;
    return await import("pdfjs-dist/legacy/build/pdf.mjs");
  })();
  return await loaded;
}

export async function extractPdf(
  bytes: Uint8Array,
  options: {
    maxPages: number;
    /** How many scanned pages may be read by the model, asked once. */
    ocrAllowance: (scannedPages: number) => Promise<number>;
    readPage?: PageReader;
  },
): Promise<PdfExtraction> {
  const lib = await pdfjs();
  const { createCanvas } = await import("@napi-rs/canvas");
  const task = lib.getDocument({
    // pdf.js may transfer the buffer it is given: hand it a copy.
    data: bytes.slice(),
    enableXfa: false,
    useSystemFonts: false,
    stopAtErrors: false,
    isOffscreenCanvasSupported: false,
    // An embedded image is decoded to pixels when a page is drawn; without
    // a cap one PDF could ask for gigabytes (security audit 2026-10-08).
    maxImageSize: MAX_IMAGE_PIXELS,
    verbosity: 0,
  });
  const document = await task.promise;
  const result: PdfExtraction = {
    sections: [],
    pages: document.numPages,
    textPages: 0,
    ocrPages: 0,
    skippedPages: 0,
    unreadPages: Math.max(0, document.numPages - options.maxPages),
    usage: [],
  };
  const imageOps = new Set([
    lib.OPS.paintImageXObject,
    lib.OPS.paintInlineImageXObject,
    lib.OPS.paintImageMaskXObject,
  ]);
  const scanned: number[] = [];
  const byPage = new Map<number, string>();
  try {
    const last = Math.min(document.numPages, options.maxPages);
    for (let number = 1; number <= last; number++) {
      const page = await document.getPage(number);
      const content = await page.getTextContent();
      let text = "";
      for (const item of content.items) {
        if (!("str" in item)) continue;
        text += item.str + (item.hasEOL ? "\n" : "");
      }
      if (text.replace(/\s+/g, "").length >= SCAN_TEXT_CHARS) {
        byPage.set(number, text);
        result.textPages++;
      } else {
        const ops = await page.getOperatorList();
        if (ops.fnArray.some((op) => imageOps.has(op))) scanned.push(number);
        else if (text.trim()) byPage.set(number, text);
      }
      page.cleanup();
    }
    const allowed = scanned.length > 0 && options.readPage
      ? await options.ocrAllowance(scanned.length)
      : 0;
    result.skippedPages = scanned.length - allowed;
    for (const number of scanned.slice(0, allowed)) {
      const page = await document.getPage(number);
      const base = page.getViewport({ scale: 1 });
      const scale = Math.min(
        2.5,
        OCR_MAX_SIDE / Math.max(base.width, base.height),
      );
      const viewport = page.getViewport({ scale });
      const canvas = createCanvas(
        Math.ceil(viewport.width),
        Math.ceil(viewport.height),
      );
      const context = canvas.getContext("2d");
      context.fillStyle = "#ffffff";
      context.fillRect(0, 0, canvas.width, canvas.height);
      await page.render({
        canvas: canvas as never,
        canvasContext: context as never,
        viewport,
      }).promise;
      page.cleanup();
      const jpeg = await encodeJpeg(canvas);
      try {
        const read = await options.readPage!(jpeg);
        if (read.usage) result.usage.push(read.usage);
        if (read.text.trim()) byPage.set(number, read.text);
        result.ocrPages++;
      } catch (error) {
        // A blank scan reads as nothing; anything else is the provider's
        // failure and the whole file is tried again later.
        if ((error as { kind?: string }).kind !== "unreadable") throw error;
        result.ocrPages++;
      }
    }
  } finally {
    await task.destroy();
  }
  for (
    const [page, text] of [...byPage.entries()].sort((a, b) => a[0] - b[0])
  ) {
    result.sections.push({ page, text });
  }
  return result;
}
